defmodule SertantaiLegal.Zenoh.SecondaryTaxaSubscriber do
  @moduledoc """
  Subscribes to fractalaw secondary source taxa enrichment over Zenoh.

  Fractalaw publishes per-provision DRRP enrichment for secondary sources
  (ACoPs, JSPs, HSGs) as Arrow IPC payloads, batched per source. This
  subscriber decodes them with Explorer and upserts the taxa fields into
  existing SecondarySourceProvision rows.

  Key expression: fractalaw/@{tenant}/taxa/secondary/{source_id}

  Phase 1 mapping:
  - drrp_types ← direct
  - governed_actors ← merged governed_actors + government_actors
  - taxa_enriched_at ← DateTime.utc_now()
  - obligation_strength, modal_verb, clause_refined → ignored (no columns yet)
  """

  use GenServer
  require Logger
  require Ash.Query

  alias SertantaiLegal.Legal.{
    Control,
    SecondaryMandatedArtefact,
    SecondaryTerm,
    SecondaryObligation,
    SecondaryRaci,
    SecondarySource,
    SecondarySourceProvision,
    SourceLink
  }

  alias SertantaiLegal.Zenoh.ActivityLog

  # Arrow column name → Ash attribute atom.
  # Only columns that map to existing SecondarySourceProvision fields.
  @field_atoms %{
    "drrp_types" => :drrp_types,
    "governed_actors" => :governed_actors
  }

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{state: :stopped, key_expr: nil}
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    ActivityLog.set_status(:secondary_taxa_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/taxa/secondary/*"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.SecondaryTaxaSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:secondary_taxa_subscriber, :ready)
        ActivityLog.record(:secondary_taxa_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.SecondaryTaxaSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    source_id = sample.key_expr |> String.split("/") |> List.last()
    ActivityLog.increment(:secondary_taxa_subscriber, :received)

    case decode_and_upsert(source_id, sample.payload) do
      {:ok, count} ->
        ActivityLog.increment(:secondary_taxa_subscriber, :updated)

        ActivityLog.record(:secondary_taxa_subscriber, :updated, %{
          source_id: source_id,
          provisions: count
        })

      {:error, reason} ->
        ActivityLog.increment(:secondary_taxa_subscriber, :failed)

        ActivityLog.record(:secondary_taxa_subscriber, :error, %{
          source_id: source_id,
          reason: inspect(reason)
        })

        Logger.error(
          "[Zenoh.SecondaryTaxaSubscriber] Failed to process #{source_id}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.SecondaryTaxaSubscriber] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      state: if(state.subscriber_id, do: :ready, else: :connecting),
      key_expr: state.key_expr
    }

    {:reply, status, state}
  end

  # --- Internal ---

  defp decode_and_upsert(source_id, ipc_bytes) do
    case decode_arrow_ipc(ipc_bytes) do
      {:ok, rows} ->
        now = DateTime.utc_now()

        # Clear existing RACI + mandated artefacts for this source before re-inserting
        # (full replace). Obligations use upsert so don't need clearing.
        clear_raci_for_source(source_id)
        clear_artefacts_for_source(source_id)
        clear_terms_for_source(source_id)
        clear_jsp_controls_for_source(source_id)

        results = Enum.map(rows, &upsert_provision(&1, now))
        ok_count = Enum.count(results, &match?(:ok, &1))
        not_found = Enum.count(results, &match?({:error, {:not_found, _}}, &1))

        real_errors =
          Enum.count(results, fn
            {:error, {:not_found, _}} -> false
            {:error, _} -> true
            _ -> false
          end)

        # Count enrichment extras for summary logging
        ref_counts = count_references(rows)
        ob_count = count_non_empty(rows, "obligations_json")
        raci_count = count_non_empty(rows, "raci_json")
        artefact_count = count_non_empty(rows, "mandated_artefacts_json")
        terms_count = count_non_empty(rows, "terms_json")
        # JSP controls are derived from artefacts — count same column
        jsp_controls_count = artefact_count

        skipped = if not_found > 0, do: " (#{not_found} skipped — not in provisions)", else: ""

        extras =
          [
            if(ref_counts.legislation > 0, do: "#{ref_counts.legislation} law refs"),
            if(ref_counts.jsp > 0, do: "#{ref_counts.jsp} JSP cross-refs parked"),
            if(ob_count > 0, do: "#{ob_count} obligations"),
            if(raci_count > 0, do: "#{raci_count} RACI"),
            if(artefact_count > 0, do: "#{artefact_count} artefacts"),
            if(terms_count > 0, do: "#{terms_count} terms"),
            if(jsp_controls_count > 0, do: "#{jsp_controls_count} JSP controls")
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(", ")

        extras_info = if extras != "", do: ", #{extras}", else: ""

        if real_errors > 0 do
          Logger.warning(
            "[Zenoh.SecondaryTaxaSubscriber] #{source_id}: #{ok_count} ok, #{real_errors} failed#{skipped}#{extras_info}"
          )
        else
          Logger.info(
            "[Zenoh.SecondaryTaxaSubscriber] Updated #{ok_count} provisions for #{source_id}#{skipped}#{extras_info}"
          )
        end

        {:ok, ok_count}

      {:error, :empty_payload} ->
        Logger.debug("[Zenoh.SecondaryTaxaSubscriber] Empty payload for #{source_id}")
        {:ok, 0}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_arrow_ipc(ipc_bytes) do
    df = Explorer.DataFrame.load_ipc_stream!(ipc_bytes)
    rows = Explorer.DataFrame.to_rows(df, atom_keys: false)

    case rows do
      [] -> {:error, :empty_payload}
      rows -> {:ok, rows}
    end
  rescue
    e -> {:error, {:decode_failed, Exception.message(e)}}
  end

  defp upsert_provision(row, now) do
    section_id = row["section_id"]

    if is_nil(section_id) or section_id == "" do
      {:error, :missing_section_id}
    else
      taxa = normalize_taxa(row) |> Map.put(:taxa_enriched_at, now)

      case find_provision(section_id) do
        {:ok, provision} ->
          with {:ok, _} <-
                 provision
                 |> Ash.Changeset.for_update(:update_taxa, taxa)
                 |> Ash.update() do
            # Process enrichment extras (fire-and-forget — don't fail the taxa update)
            process_references(row, provision)
            process_obligations(row, provision)
            process_raci(row, provision)
            process_mandated_artefacts(row, provision)
            process_terms(row, provision)
            :ok
          else
            {:error, reason} -> {:error, {:update_failed, section_id, reason}}
          end

        {:error, {:not_found, _}} ->
          {:error, {:not_found, section_id}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp find_provision(section_id) do
    SecondarySourceProvision
    |> Ash.Query.filter(section_id == ^section_id)
    |> Ash.read_one()
    |> case do
      {:ok, nil} -> {:error, {:not_found, section_id}}
      {:ok, provision} -> {:ok, provision}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Normalize an Arrow IPC row into Ash-compatible taxa fields.

  Maps payload columns to SecondarySourceProvision attributes:
  - `drrp_types` → `:drrp_types`
  - `governed_actors` + `government_actors` → merged `:governed_actors`
  - Phase 2 columns (obligation_strength, modal_verb, clause_refined) → ignored

  DuckDB sends array columns as comma-separated Utf8 strings (not Arrow List<Utf8>).
  The subscriber splits on "," and trims whitespace.

  Public for testing.
  """
  @spec normalize_taxa(map()) :: map()
  def normalize_taxa(row) do
    acc =
      Enum.reduce(@field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case to_string_list(Map.get(row, str_key)) do
          [] -> acc
          values -> Map.put(acc, atom_key, values)
        end
      end)

    # Merge government_actors into governed_actors (Phase 1 — single column)
    merge_government_actors(acc, row)
  end

  # Convert a value to a list of strings, handling:
  # - nil → []
  # - "" → []
  # - "Obligation,Permission" → ["Obligation", "Permission"]
  # - ["Obligation", "Permission"] → ["Obligation", "Permission"] (passthrough)
  defp to_string_list(nil), do: []
  defp to_string_list(""), do: []

  defp to_string_list(value) when is_binary(value) do
    value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp to_string_list(value) when is_list(value), do: value
  defp to_string_list(_), do: []

  # Merge government_actors into governed_actors, deduplicating.
  defp merge_government_actors(acc, row) do
    case to_string_list(Map.get(row, "government_actors")) do
      [] ->
        acc

      gov_actors ->
        existing = Map.get(acc, :governed_actors, [])
        merged = Enum.uniq(existing ++ gov_actors)
        Map.put(acc, :governed_actors, merged)
    end
  end

  # Count references by type across all rows in the batch (for summary logging).
  defp count_references(rows) do
    Enum.reduce(rows, %{legislation: 0, jsp: 0}, fn row, acc ->
      refs = parse_references(Map.get(row, "references_json"))

      %{
        legislation: acc.legislation + Enum.count(refs, &(&1["target_type"] == "legislation")),
        jsp: acc.jsp + Enum.count(refs, &(&1["target_type"] == "jsp"))
      }
    end)
  end

  # Count rows that have a non-nil, non-empty value for a given column.
  defp count_non_empty(rows, column) do
    Enum.count(rows, fn row ->
      val = Map.get(row, column)
      not is_nil(val) and val != ""
    end)
  end

  # --- References processing ---

  defp process_references(row, provision) do
    case parse_references(Map.get(row, "references_json")) do
      [] ->
        :ok

      refs ->
        case resolve_secondary_source_id(provision.source_id) do
          {:ok, secondary_source_id} ->
            legislation_refs = Enum.filter(refs, &(&1["target_type"] == "legislation"))

            Enum.each(legislation_refs, fn ref ->
              upsert_source_link(secondary_source_id, provision.section_id, ref)
            end)

          {:error, reason} ->
            Logger.warning(
              "[Zenoh.SecondaryTaxaSubscriber] Cannot process references for #{provision.source_id}: #{inspect(reason)}"
            )
        end
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] References processing failed for #{provision.section_id}: #{Exception.message(e)}"
      )
  end

  defp upsert_source_link(secondary_source_id, secondary_section_id, ref) do
    target_id = ref["target_id"]

    if is_nil(target_id) or target_id == "" do
      :ok
    else
      # Check if link already exists (can't rely on upsert identity — NULL columns
      # break PostgreSQL unique index semantics: NULL != NULL)
      existing =
        SourceLink
        |> Ash.Query.filter(
          secondary_source_id == ^secondary_source_id and
            secondary_section_id == ^secondary_section_id and
            law_name == ^target_id and
            is_nil(section_id) and
            link_type == :references
        )
        |> Ash.read_one()

      case existing do
        {:ok, %SourceLink{} = link} ->
          # Update notes if citation changed
          citation = ref["citation"]

          if link.notes != citation do
            link
            |> Ash.Changeset.for_update(:update, %{notes: citation})
            |> Ash.update()
          end

          :ok

        {:ok, nil} ->
          params = %{
            secondary_source_id: secondary_source_id,
            secondary_section_id: secondary_section_id,
            law_name: target_id,
            section_id: nil,
            link_type: :references,
            notes: ref["citation"]
          }

          case SourceLink
               |> Ash.Changeset.for_create(:create, params)
               |> Ash.create() do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.debug(
                "[Zenoh.SecondaryTaxaSubscriber] source_link create failed: #{inspect(reason)}"
              )
          end

        {:error, reason} ->
          Logger.debug(
            "[Zenoh.SecondaryTaxaSubscriber] source_link lookup failed: #{inspect(reason)}"
          )
      end
    end
  end

  # Resolve source_id (e.g. "JSP-375-CH23") → secondary_sources.id (UUID).
  # Uses process dictionary as a simple per-batch cache.
  defp resolve_secondary_source_id(source_id) do
    cache_key = {:secondary_source_id_cache, source_id}

    case Process.get(cache_key) do
      nil ->
        result =
          SecondarySource
          |> Ash.Query.filter(source_id == ^source_id)
          |> Ash.read_one()
          |> case do
            {:ok, %{id: id}} -> {:ok, id}
            {:ok, nil} -> {:error, {:not_found, source_id}}
            {:error, reason} -> {:error, reason}
          end

        if match?({:ok, _}, result), do: Process.put(cache_key, result)
        result

      cached ->
        cached
    end
  end

  @doc """
  Parse a DuckDB references_json string into a list of maps.

  Handles both JSON format and DuckDB struct syntax:
  - JSON: `[{"target_type": "legislation", ...}]`
  - DuckDB: `[{'target_type': legislation, 'target_id': UK_uksi_1989_635, ...}]`

  Public for testing.
  """
  @spec parse_references(term()) :: [map()]
  def parse_references(nil), do: []
  def parse_references(""), do: []

  def parse_references(value) when is_binary(value) do
    # Try JSON first (spec says JSON)
    case Jason.decode(value) do
      {:ok, refs} when is_list(refs) ->
        refs

      _ ->
        # Fall back to DuckDB struct syntax parser
        case parse_duckdb_structs(value) do
          [] ->
            Logger.warning(
              "[Zenoh.SecondaryTaxaSubscriber] Could not parse DuckDB structs: #{String.slice(value, 0, 200)}"
            )

            []

          structs ->
            structs
        end
    end
  end

  def parse_references(value) when is_list(value), do: value
  def parse_references(_), do: []

  # Parse DuckDB list-of-structs syntax directly to a list of maps.
  # DuckDB serialises structs with single-quoted keys and values that may contain
  # embedded quotes, colons, and commas. Regex normalisation to JSON is fragile,
  # so we scan for key boundaries (`'key':`) and extract values between them.
  @doc false
  def parse_duckdb_structs(str) do
    # Extract content of each {...} block
    Regex.scan(~r/\{(.+?)\}(?=\s*(?:,\s*\{|$|\]))/s, str, capture: :all_but_first)
    |> Enum.map(fn [content] -> parse_duckdb_struct(content) end)
    |> Enum.reject(&(&1 == %{}))
  end

  defp parse_duckdb_struct(content) do
    # Find all 'key': positions — these are the field boundaries.
    # This works because embedded quotes in values won't match 'word':
    key_matches = Regex.scan(~r/'(\w+)':\s*/, content, return: :index)
    key_names = Regex.scan(~r/'(\w+)':\s*/, content) |> Enum.map(fn [_, k] -> k end)

    if key_matches == [] do
      %{}
    else
      # For each key, extract the value from the end of the key match
      # to the start of the next key match (minus trailing ", ")
      positions =
        Enum.map(key_matches, fn [{start, len}, _cap] -> {start, start + len} end)

      Enum.zip(key_names, Enum.with_index(positions))
      |> Enum.map(fn {key, {{_start, val_start}, idx}} ->
        val_end =
          case Enum.at(positions, idx + 1) do
            {next_start, _} ->
              # Back up past ", " separator
              content
              |> String.slice(0, next_start)
              |> String.trim_trailing()
              |> String.trim_trailing(",")
              |> String.length()

            nil ->
              String.length(content)
          end

        len = max(val_end - val_start, 0)
        raw = String.slice(content, val_start, len) |> String.trim()
        value = strip_duckdb_quotes(raw)
        {key, coerce_duckdb_value(value)}
      end)
      |> Map.new()
    end
  end

  # Strip surrounding single quotes from DuckDB values
  defp strip_duckdb_quotes("'" <> rest) do
    if String.ends_with?(rest, "'") do
      String.slice(rest, 0, String.length(rest) - 1)
    else
      "'" <> rest
    end
  end

  defp strip_duckdb_quotes(value), do: value

  # Coerce DuckDB unquoted values: integers stay as integers, rest as strings
  defp coerce_duckdb_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp coerce_duckdb_value(value), do: value

  # --- Obligations processing ---

  defp process_obligations(row, provision) do
    case parse_references(Map.get(row, "obligations_json")) do
      [] ->
        :ok

      obligations ->
        Enum.each(obligations, fn ob ->
          index = ob["obligation_index"] || 0
          obligation_id = "#{provision.section_id}:ob.#{index}"

          params = %{
            obligation_id: obligation_id,
            section_id: provision.section_id,
            source_id: provision.source_id,
            obligation_index: index,
            text: ob["text"],
            modal_verb: ob["modal_verb"],
            strength: ob["strength"],
            clause_refined: ob["clause_refined"],
            competence_requirements: ob["competence"]
          }

          case SecondaryObligation
               |> Ash.Changeset.for_create(:upsert, params)
               |> Ash.create() do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.debug(
                "[Zenoh.SecondaryTaxaSubscriber] obligation upsert failed for #{obligation_id}: #{inspect(reason)}"
              )
          end
        end)
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Obligations processing failed for #{provision.section_id}: #{Exception.message(e)}"
      )
  end

  # Clear all RACI entries for a source before re-inserting (full replace per publish).
  defp clear_raci_for_source(source_id) do
    SertantaiLegal.Repo.query("DELETE FROM secondary_raci WHERE source_id = $1", [source_id])
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Failed to clear RACI for #{source_id}: #{Exception.message(e)}"
      )
  end

  # --- RACI processing ---

  defp process_raci(row, provision) do
    case parse_references(Map.get(row, "raci_json")) do
      [] ->
        :ok

      raci_entries ->
        Enum.each(raci_entries, fn entry ->
          index = entry["obligation_index"] || 0
          obligation_id = "#{provision.section_id}:ob.#{index}"

          params = %{
            obligation_id: obligation_id,
            section_id: provision.section_id,
            source_id: provision.source_id,
            role_label: entry["role_label"],
            assignment_type: entry["assignment_type"],
            obligation_index: index
          }

          # Skip if missing required fields
          if params.role_label && params.assignment_type do
            case SecondaryRaci
                 |> Ash.Changeset.for_create(:create, params)
                 |> Ash.create() do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                Logger.debug(
                  "[Zenoh.SecondaryTaxaSubscriber] RACI create failed for #{obligation_id}: #{inspect(reason)}"
                )
            end
          end
        end)
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] RACI processing failed for #{provision.section_id}: #{Exception.message(e)}"
      )
  end

  # --- Mandated artefacts processing ---

  defp clear_artefacts_for_source(source_id) do
    SertantaiLegal.Repo.query(
      "DELETE FROM secondary_mandated_artefacts WHERE source_id = $1",
      [source_id]
    )
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Failed to clear artefacts for #{source_id}: #{Exception.message(e)}"
      )
  end

  defp process_mandated_artefacts(row, provision) do
    case parse_references(Map.get(row, "mandated_artefacts_json")) do
      [] ->
        :ok

      artefacts ->
        # Look up which laws this JSP chapter references (for control.law_name)
        law_names = resolve_law_names_for_source(provision.source_id)
        # Look up RACI roles for building control titles
        raci_entries = parse_references(Map.get(row, "raci_json"))

        Enum.each(artefacts, fn entry ->
          obligation_id = entry["obligation_id"]
          artefact_type = entry["artefact_type"]

          if obligation_id && artefact_type do
            # 1. Create artefact row
            artefact_params = %{
              obligation_id: obligation_id,
              section_id: provision.section_id,
              source_id: provision.source_id,
              artefact_type: artefact_type,
              matched_text: entry["matched_text"]
            }

            case SecondaryMandatedArtefact
                 |> Ash.Changeset.for_create(:create, artefact_params)
                 |> Ash.create() do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                Logger.debug(
                  "[Zenoh.SecondaryTaxaSubscriber] artefact create failed: #{inspect(reason)}"
                )
            end

            # 2. Create JSP control for each artefact × law_name
            create_jsp_controls(
              provision,
              obligation_id,
              artefact_type,
              law_names,
              raci_entries
            )
          end
        end)
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Artefacts processing failed for #{provision.section_id}: #{Exception.message(e)}"
      )
  end

  # Clear JSP-derived controls for a source (full replace per publish).
  # Only deletes controls WHERE source_id = $1 — legislation controls (source_id IS NULL) untouched.
  defp clear_jsp_controls_for_source(source_id) do
    SertantaiLegal.Repo.query(
      "DELETE FROM controls WHERE source_id = $1",
      [source_id]
    )
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Failed to clear JSP controls for #{source_id}: #{Exception.message(e)}"
      )
  end

  # Look up law_names that this JSP chapter references (from source_links).
  defp resolve_law_names_for_source(source_id) do
    case resolve_secondary_source_id(source_id) do
      {:ok, secondary_source_id} ->
        {:ok, uuid_binary} = Ecto.UUID.dump(secondary_source_id)

        query = """
        SELECT DISTINCT law_name FROM source_links
        WHERE secondary_source_id = $1 AND link_type = 'references'
        """

        case SertantaiLegal.Repo.query(query, [uuid_binary]) do
          {:ok, %{rows: rows}} -> Enum.map(rows, fn [name] -> name end)
          _ -> []
        end

      _ ->
        []
    end
  end

  # Build the responsible role label from RACI entries for a given obligation_index.
  defp responsible_role_for(raci_entries, obligation_id) do
    raci_entries
    |> Enum.find(fn entry ->
      ob_idx = entry["obligation_index"] || 0
      candidate_id = String.replace(obligation_id, ~r/:ob\.\d+$/, ":ob.#{ob_idx}")
      candidate_id == obligation_id and entry["assignment_type"] == "R"
    end)
    |> case do
      %{"role_label" => role} when is_binary(role) -> role
      _ -> "the responsible person"
    end
  end

  defp create_jsp_controls(provision, obligation_id, artefact_type, law_names, raci_entries) do
    role = responsible_role_for(raci_entries, obligation_id)
    article = if String.match?(artefact_type, ~r/^[AEIOUaeiou]/), do: "An", else: "A"
    title = "#{article} #{artefact_type} is maintained by #{role}"

    Enum.each(law_names, fn law_name ->
      # Deterministic control_id: hash of obligation + artefact + law
      control_id = "jsp:#{obligation_id}:#{artefact_type}:#{law_name}"

      params = %{
        law_name: law_name,
        control_id: control_id,
        source_id: provision.source_id,
        title: title,
        control_type: "specific",
        status: "generated",
        tier: "Sector",
        linked_provisions: [provision.section_id],
        generation_model: "sertantai:jsp-artefact-v1"
      }

      case Control
           |> Ash.Changeset.for_create(:upsert_from_fractalaw, params)
           |> Ash.create() do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.debug(
            "[Zenoh.SecondaryTaxaSubscriber] JSP control upsert failed for #{control_id}: #{inspect(reason)}"
          )
      end
    end)
  end

  # --- Terms processing ---

  defp clear_terms_for_source(source_id) do
    SertantaiLegal.Repo.query(
      "DELETE FROM secondary_terms WHERE source_id = $1",
      [source_id]
    )
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Failed to clear terms for #{source_id}: #{Exception.message(e)}"
      )
  end

  defp process_terms(row, provision) do
    case parse_references(Map.get(row, "terms_json")) do
      [] ->
        :ok

      terms ->
        Enum.each(terms, fn entry ->
          normalised = entry["normalised"]
          term_text = entry["term"]

          if normalised && term_text do
            term_id = "#{provision.source_id}:#{normalised}"

            params = %{
              term_id: term_id,
              section_id: provision.section_id,
              source_id: provision.source_id,
              term: term_text,
              acronym: entry["acronym"],
              normalised: normalised
            }

            case SecondaryTerm
                 |> Ash.Changeset.for_create(:upsert, params)
                 |> Ash.create() do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                Logger.debug(
                  "[Zenoh.SecondaryTaxaSubscriber] term upsert failed for #{term_id}: #{inspect(reason)}"
                )
            end
          end
        end)
    end
  rescue
    e ->
      Logger.warning(
        "[Zenoh.SecondaryTaxaSubscriber] Terms processing failed for #{provision.section_id}: #{Exception.message(e)}"
      )
  end
end

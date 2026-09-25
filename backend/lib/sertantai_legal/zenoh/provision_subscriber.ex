defmodule SertantaiLegal.Zenoh.ProvisionSubscriber do
  @moduledoc """
  Subscribes to fractalaw provision-level taxa enrichment over Zenoh.

  Fractalaw publishes per-provision DRRP and fitness classifications as
  Arrow IPC payloads, batched per law. This subscriber decodes them with
  Explorer and upserts the taxa/fitness fields into existing LegalArticle rows.

  Key expression: fractalaw/@{tenant}/taxa/provisions/{law_name}
  """

  use GenServer
  require Logger

  alias SertantaiLegal.Legal.Taxa.ActorDefinitions
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Zenoh.ActivityLog

  # Arrow column name → Ash attribute atom.
  # Simple arrays/scalars — mapped directly without JSONB wrappers.
  # Note: governed_actors/government_actors removed — fractalaw no longer sends
  # flat actor columns. Use actors struct column instead (see @struct_columns).
  @field_atoms %{
    "drrp_types" => :drrp_types,
    "duty_family" => :duty_family,
    "duty_sub_type" => :duty_sub_type,
    "clause_refined" => :clause_refined,
    "purposes" => :purposes,
    "popimar" => :popimar,
    "taxa_confidence" => :taxa_confidence,
    "extraction_method" => :extraction_method,
    "holder_inferred_from" => :holder_inferred_from,
    "ancestor_distance" => :ancestor_distance,
    # Significance (provision-level)
    "significance_scope_duty_bearer" => :significance_scope_duty_bearer,
    "significance_scope_protected_class" => :significance_scope_protected_class,
    "significance_gravity" => :significance_gravity,
    "significance_strength" => :significance_strength,
    "significance_hierarchy" => :significance_hierarchy,
    "significance_confidence" => :significance_confidence,
    "significance_overall" => :significance_overall
  }

  # Actors column — now Utf8 (JSON string), was List<Struct>.
  # Handled separately in normalize_taxa/1 via JSON decode.
  @actors_key "actors"

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
    ActivityLog.set_status(:provision_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/taxa/provisions/*"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.ProvisionSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:provision_subscriber, :ready)
        ActivityLog.record(:provision_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.ProvisionSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    law_name = sample.key_expr |> String.split("/") |> List.last()
    ActivityLog.increment(:provision_subscriber, :received)

    case decode_and_upsert(law_name, sample.payload) do
      {:ok, count} ->
        ActivityLog.increment(:provision_subscriber, :updated)

        ActivityLog.record(:provision_subscriber, :updated, %{
          law_name: law_name,
          provisions: count
        })

      {:error, reason} ->
        ActivityLog.increment(:provision_subscriber, :failed)

        ActivityLog.record(:provision_subscriber, :error, %{
          law_name: law_name,
          reason: inspect(reason)
        })

        Logger.error(
          "[Zenoh.ProvisionSubscriber] Failed to process #{law_name}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.ProvisionSubscriber] Unexpected message: #{inspect(msg)}")
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

  defp decode_and_upsert(law_name, ipc_bytes) do
    case decode_arrow_ipc(ipc_bytes) do
      {:ok, rows} ->
        %{updated: updated, not_found: not_found, invalid: invalid} =
          upsert_rows(law_name, rows)

        skipped = if not_found > 0, do: " (#{not_found} skipped — not in LAT)", else: ""

        if invalid > 0 do
          Logger.warning(
            "[Zenoh.ProvisionSubscriber] #{law_name}: #{updated} ok, #{invalid} without section_id#{skipped}"
          )
        else
          Logger.info(
            "[Zenoh.ProvisionSubscriber] Updated #{updated} provisions for #{law_name}#{skipped}"
          )
        end

        {:ok, updated}

      {:error, :empty_payload} ->
        Logger.debug("[Zenoh.ProvisionSubscriber] Empty payload for #{law_name}")
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

  # Column → SQL type of the provision taxa fields written by upsert_rows/2.
  @column_types [
    drrp_types: :text_array,
    purposes: :text_array,
    popimar: :text_array,
    actors: :jsonb_array,
    duty_family: :text,
    duty_sub_type: :text,
    clause_refined: :text,
    extraction_method: :text,
    holder_inferred_from: :text,
    significance_scope_duty_bearer: :text,
    significance_scope_protected_class: :text,
    significance_gravity: :text,
    significance_strength: :text,
    significance_hierarchy: :text,
    significance_overall: :text,
    ancestor_distance: :integer,
    taxa_confidence: :float,
    significance_confidence: :float
  ]

  @batch_size 1_000

  @doc """
  Write a law's provision taxa rows in batches of #{@batch_size}: one UPDATE
  statement per batch instead of a lookup and an update per provision.

  Rows go through `normalize_taxa/1` (DRRP mapping, actor roles). Only keys
  present in a row are written; absent fields are left unchanged, as with the
  per-row `:update_taxa` action this replaces. Provisions not in the LAT are
  counted as `not_found` and skipped; rows without a section_id as `invalid`.
  """
  @spec upsert_rows(String.t(), [map()]) :: %{
          updated: non_neg_integer(),
          not_found: non_neg_integer(),
          invalid: non_neg_integer()
        }
  def upsert_rows(_law_name, rows) do
    now = NaiveDateTime.utc_now()

    {valid, invalid} = Enum.split_with(rows, &(&1["section_id"] not in [nil, ""]))

    payloads =
      valid
      |> Enum.map(fn row ->
        row
        |> normalize_taxa()
        |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.put("section_id", row["section_id"])
      end)
      |> Enum.uniq_by(& &1["section_id"])

    updated =
      payloads
      |> Enum.chunk_every(@batch_size)
      |> Enum.reduce(0, fn batch, acc ->
        %{num_rows: n} = Repo.query!(update_sql(), [batch, now], timeout: :timer.minutes(2))
        acc + n
      end)

    %{updated: updated, not_found: length(payloads) - updated, invalid: length(invalid)}
  end

  defp update_sql do
    sets =
      Enum.map_join(@column_types, ",\n    ", fn {col, type} ->
        "#{col} = CASE WHEN p ? '#{col}' THEN #{cast(col, type)} ELSE a.#{col} END"
      end)

    """
    UPDATE legal_articles AS a
    SET #{sets},
        taxa_enriched_at = $2,
        updated_at = $2
    FROM jsonb_array_elements($1::jsonb) AS p
    WHERE a.section_id = p->>'section_id'
    """
  end

  defp cast(col, :text), do: "p->>'#{col}'"
  defp cast(col, :integer), do: "(p->>'#{col}')::integer"
  defp cast(col, :float), do: "(p->>'#{col}')::float8"
  defp cast(col, :text_array), do: "ARRAY(SELECT jsonb_array_elements_text(p->'#{col}'))"
  defp cast(col, :jsonb_array), do: "ARRAY(SELECT jsonb_array_elements(p->'#{col}'))"

  @doc false
  def normalize_taxa(row) do
    # Simple fields (scalars + flat arrays)
    acc =
      Enum.reduce(@field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case Map.get(row, str_key) do
          nil -> acc
          value -> Map.put(acc, atom_key, value)
        end
      end)

    # Actors — now Utf8 (JSON string) instead of List<Struct>.
    # Decode JSON string to list of maps, or pass through if already a list.
    # Each actor entry is enriched with "role" => "governed" | "government"
    # using ActorDefinitions.actor_role/1 — the single canonical classifier.
    acc =
      case Map.get(row, @actors_key) do
        nil ->
          acc

        actors when is_list(actors) ->
          Map.put(acc, :actors, Enum.map(actors, &enrich_actor_role/1))

        actors when is_binary(actors) ->
          case Jason.decode(actors) do
            {:ok, parsed} when is_list(parsed) ->
              Map.put(acc, :actors, Enum.map(parsed, &enrich_actor_role/1))

            _ ->
              acc
          end

        _ ->
          acc
      end

    # Map fractalaw's Hohfeldian vocabulary to DRRP based on actor role (#134).
    # Obligation → Duty (governed) / Responsibility (government)
    # Liberty → Right (governed) / Power (government)
    map_drrp_types(acc)
  end

  # Map fractalaw's Hohfeldian vocabulary to the DRRP vocabulary (#134).
  #
  # Fractalaw classifies provisions as Obligation or Liberty. We translate
  # to the DRRP model based on which actor roles are present:
  #
  #   Obligation + governed  → Duty
  #   Obligation + government → Responsibility
  #   Liberty    + governed  → Right
  #   Liberty    + government → Power
  #
  # When both governed and government actors are present, the governed
  # mapping takes priority (Duty/Right) since those are the primary
  # compliance-relevant classifications.
  @doc false
  def map_drrp_types(%{drrp_types: drrp_types, actors: actors} = taxa)
      when is_list(drrp_types) and is_list(actors) do
    has_governed = has_role?(actors, "governed")
    has_government = has_role?(actors, "government")

    needs_mapping =
      Enum.any?(drrp_types, &(&1 in ["Obligation", "Liberty"]))

    if needs_mapping and (has_governed or has_government) do
      mapped =
        Enum.map(drrp_types, fn
          "Obligation" when has_governed -> "Duty"
          "Obligation" when has_government -> "Responsibility"
          "Liberty" when has_governed -> "Right"
          "Liberty" when has_government -> "Power"
          other -> other
        end)

      Map.put(taxa, :drrp_types, mapped)
    else
      taxa
    end
  end

  def map_drrp_types(taxa), do: taxa

  defp has_role?(actors, role) do
    Enum.any?(actors, fn
      %{"role" => ^role} -> true
      %{role: ^role} -> true
      _ -> false
    end)
  end

  # Stamp each actor map with "role" => "governed" | "government".
  # Handles both string-keyed maps (from JSON decode) and atom-keyed maps.
  defp enrich_actor_role(%{"label" => label} = actor) do
    Map.put(actor, "role", ActorDefinitions.actor_role(label))
  end

  defp enrich_actor_role(%{label: label} = actor) do
    Map.put(actor, :role, ActorDefinitions.actor_role(label))
  end

  defp enrich_actor_role(actor), do: actor
end

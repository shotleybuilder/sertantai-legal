defmodule SertantaiLegal.Zenoh.EvidenceSubscriber do
  @moduledoc """
  Subscribes to fractalaw AI-generated evidence patterns over Zenoh.

  Fractalaw publishes evidence patterns as Arrow IPC payloads, batched per law.
  This subscriber decodes them with Explorer, upserts into the evidence_patterns
  table, then unpacks `artefacts_json` into individual artefact_template records.

  Key expression:
  - `fractalaw/@{tenant}/evidence/{law_name}` — N evidence pattern rows per law (one per control)

  Evidence patterns are 1:1 with controls. The `control_id` field is the
  fractalaw UUID matching `controls.control_id`.
  """

  use GenServer
  require Logger
  require Ash.Query

  alias SertantaiLegal.Legal.{EvidencePattern, ArtefactTemplate}
  alias SertantaiLegal.Zenoh.ActivityLog

  # Arrow column name → Ash attribute atom.
  # Avoids String.to_existing_atom and any atom table exhaustion risk.
  @field_atoms %{
    "law_name" => :law_name,
    "control_id" => :control_id,
    "control_title" => :control_title,
    "needs_judgement" => :needs_judgement,
    "judgement_rationale" => :judgement_rationale,
    "recommended_method" => :recommended_method,
    "basis_guidance" => :basis_guidance,
    "discriminating_question" => :discriminating_question,
    "drift_signal" => :drift_signal,
    "drift_conditions" => :drift_conditions,
    "voi_quadrant" => :voi_quadrant,
    "voi_rationale" => :voi_rationale,
    "evidence_standard" => :evidence_standard,
    "recommended_interval" => :recommended_interval,
    "sample_size_guidance" => :sample_size_guidance,
    "staleness_tolerance" => :staleness_tolerance,
    "nature_strategy" => :nature_strategy,
    "generation_model" => :generation_model,
    "base_hash" => :base_hash
  }

  # Artefact JSON keys → Ash attribute atoms
  @artefact_field_atoms %{
    "title" => :title,
    "artefact_type" => :artefact_type,
    "artefact_class" => :artefact_class,
    "what_it_proves" => :what_it_proves,
    "source" => :source,
    "likelihood_ratio" => :likelihood_ratio,
    "recommended_frequency" => :recommended_frequency,
    "evidence_by_design" => :evidence_by_design
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
    ActivityLog.set_status(:evidence_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/evidence/**"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.EvidenceSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:evidence_subscriber, :ready)
        ActivityLog.record(:evidence_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.EvidenceSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    law_name = parse_key_expr(sample.key_expr)
    ActivityLog.increment(:evidence_subscriber, :received)

    case decode_and_upsert(law_name, sample.payload) do
      {:ok, count} ->
        ActivityLog.increment(:evidence_subscriber, :updated)

        ActivityLog.record(:evidence_subscriber, :updated, %{
          law_name: law_name,
          patterns: count
        })

      {:error, reason} ->
        ActivityLog.increment(:evidence_subscriber, :failed)

        ActivityLog.record(:evidence_subscriber, :error, %{
          law_name: law_name,
          reason: inspect(reason)
        })

        Logger.error(
          "[Zenoh.EvidenceSubscriber] Failed to process #{law_name}: #{inspect(reason)}"
        )
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.EvidenceSubscriber] Unexpected message: #{inspect(msg)}")
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

  # Parse key expression to extract law_name.
  # Evidence: fractalaw/@dev/evidence/UK_uksi_1997_1713
  defp parse_key_expr(key_expr) do
    segments = String.split(key_expr, "/")

    case segments do
      [_, _, "evidence", law_name] -> law_name
      _ -> List.last(segments)
    end
  end

  defp decode_and_upsert(law_name, ipc_bytes) do
    case decode_arrow_ipc(ipc_bytes) do
      {:ok, rows} ->
        results = Enum.map(rows, &upsert_evidence_pattern(&1, law_name))
        ok_count = Enum.count(results, &match?({:ok, _}, &1))

        real_errors =
          Enum.count(results, fn
            {:error, _} -> true
            _ -> false
          end)

        if real_errors > 0 do
          Logger.warning(
            "[Zenoh.EvidenceSubscriber] #{law_name}: #{ok_count} ok, #{real_errors} failed"
          )
        else
          Logger.info(
            "[Zenoh.EvidenceSubscriber] Upserted #{ok_count} evidence patterns for #{law_name}"
          )
        end

        {:ok, ok_count}

      {:error, :empty_payload} ->
        Logger.debug("[Zenoh.EvidenceSubscriber] Empty payload for #{law_name}")
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

  defp upsert_evidence_pattern(row, law_name) do
    attrs = normalize_pattern(row, law_name)

    case Ash.create(EvidencePattern, attrs, action: :upsert_from_fractalaw) do
      {:ok, pattern} ->
        rebuild_artefact_templates(pattern, row)
        {:ok, pattern}

      {:error, reason} ->
        control_id = attrs[:control_id] || "unknown"

        Logger.error(
          "[Zenoh.EvidenceSubscriber] Upsert failed for #{law_name}:#{control_id}: #{inspect(reason)}"
        )

        {:error, {:upsert_failed, control_id, reason}}
    end
  end

  @doc false
  def normalize_pattern(row, law_name) do
    # Map scalar fields via @field_atoms whitelist
    attrs =
      Enum.reduce(@field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case Map.get(row, str_key) do
          nil -> acc
          value -> Map.put(acc, atom_key, value)
        end
      end)

    # Ensure law_name is set (may not be in Arrow payload if implicit from key expression)
    Map.put_new(attrs, :law_name, law_name)
  end

  # Rebuild artefact_templates from the artefacts_json field.
  # Deletes existing templates for this pattern, then creates new ones
  # from the unpacked JSON array.
  defp rebuild_artefact_templates(%EvidencePattern{} = pattern, row) do
    artefacts_json = Map.get(row, "artefacts_json")
    artefacts = parse_artefacts_json(artefacts_json)

    if artefacts == [] do
      :ok
    else
      do_rebuild_artefact_templates(pattern, artefacts)
    end
  end

  defp parse_artefacts_json(nil), do: []
  defp parse_artefacts_json(""), do: []

  defp parse_artefacts_json(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, artefacts} when is_list(artefacts) ->
        artefacts

      {:ok, _} ->
        []

      {:error, reason} ->
        Logger.warning(
          "[Zenoh.EvidenceSubscriber] Failed to parse artefacts_json: #{inspect(reason)}"
        )

        []
    end
  end

  defp parse_artefacts_json(_), do: []

  defp do_rebuild_artefact_templates(pattern, artefacts) do
    # Delete existing templates for this pattern
    case ArtefactTemplate
         |> Ash.Query.filter(evidence_pattern_id == ^pattern.id)
         |> Ash.read() do
      {:ok, existing} ->
        Enum.each(existing, fn template ->
          Ash.destroy!(template)
        end)

      {:error, reason} ->
        Logger.warning(
          "[Zenoh.EvidenceSubscriber] Failed to read existing templates for #{pattern.law_name}:#{pattern.control_id}: #{inspect(reason)}"
        )
    end

    # Create new templates from unpacked artefacts_json
    results =
      Enum.map(artefacts, fn artefact ->
        attrs = normalize_artefact(artefact, pattern.id)

        case Ash.create(ArtefactTemplate, attrs, action: :upsert) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, {:artefact_failed, attrs[:title], reason}}
        end
      end)

    ok_count = Enum.count(results, &(&1 == :ok))
    failed = Enum.count(results, &match?({:error, _}, &1))

    if failed > 0 do
      Logger.warning(
        "[Zenoh.EvidenceSubscriber] Artefacts for #{pattern.law_name}:#{pattern.control_id}: #{ok_count} ok, #{failed} failed"
      )
    end

    :ok
  end

  defp normalize_artefact(artefact_map, evidence_pattern_id) do
    attrs =
      Enum.reduce(@artefact_field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case Map.get(artefact_map, str_key) do
          nil -> acc
          value -> Map.put(acc, atom_key, value)
        end
      end)

    Map.put(attrs, :evidence_pattern_id, evidence_pattern_id)
  end
end

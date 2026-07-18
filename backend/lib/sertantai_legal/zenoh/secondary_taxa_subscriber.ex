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

  alias SertantaiLegal.Legal.SecondarySourceProvision
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
        results = Enum.map(rows, &upsert_provision(&1, now))
        ok_count = Enum.count(results, &match?(:ok, &1))
        not_found = Enum.count(results, &match?({:error, {:not_found, _}}, &1))

        real_errors =
          Enum.count(results, fn
            {:error, {:not_found, _}} -> false
            {:error, _} -> true
            _ -> false
          end)

        skipped = if not_found > 0, do: " (#{not_found} skipped — not in provisions)", else: ""

        if real_errors > 0 do
          Logger.warning(
            "[Zenoh.SecondaryTaxaSubscriber] #{source_id}: #{ok_count} ok, #{real_errors} failed#{skipped}"
          )
        else
          Logger.info(
            "[Zenoh.SecondaryTaxaSubscriber] Updated #{ok_count} provisions for #{source_id}#{skipped}"
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
          case provision
               |> Ash.Changeset.for_update(:update_taxa, taxa)
               |> Ash.update() do
            {:ok, _} -> :ok
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
  - `drrp_types` → `:drrp_types` (direct)
  - `governed_actors` + `government_actors` → merged `:governed_actors`
  - Phase 2 columns (obligation_strength, modal_verb, clause_refined) → ignored

  Public for testing.
  """
  @spec normalize_taxa(map()) :: map()
  def normalize_taxa(row) do
    acc =
      Enum.reduce(@field_atoms, %{}, fn {str_key, atom_key}, acc ->
        case Map.get(row, str_key) do
          nil -> acc
          value when is_list(value) -> Map.put(acc, atom_key, value)
          _ -> acc
        end
      end)

    # Merge government_actors into governed_actors (Phase 1 — single column)
    merge_government_actors(acc, row)
  end

  # Merge government_actors list into governed_actors, deduplicating.
  defp merge_government_actors(acc, row) do
    case Map.get(row, "government_actors") do
      nil ->
        acc

      gov_actors when is_list(gov_actors) and gov_actors != [] ->
        existing = Map.get(acc, :governed_actors, [])
        merged = Enum.uniq(existing ++ gov_actors)
        Map.put(acc, :governed_actors, merged)

      _ ->
        acc
    end
  end
end

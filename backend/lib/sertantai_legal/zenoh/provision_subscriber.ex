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

  alias SertantaiLegal.Legal.LegalArticle
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
    "fitness_polarity" => :fitness_polarity,
    "fitness_person" => :fitness_person,
    "fitness_process" => :fitness_process,
    "fitness_place" => :fitness_place,
    "fitness_plant" => :fitness_plant,
    "fitness_property" => :fitness_property,
    "fitness_sector" => :fitness_sector,
    "extraction_method" => :extraction_method
  }

  # Arrow List<Struct> columns — needs special handling (array of maps, not flat array)
  @struct_atoms %{
    "actors" => :actors
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

        skipped = if not_found > 0, do: " (#{not_found} skipped — not in LAT)", else: ""

        if real_errors > 0 do
          Logger.warning(
            "[Zenoh.ProvisionSubscriber] #{law_name}: #{ok_count} ok, #{real_errors} failed#{skipped}"
          )
        else
          Logger.info(
            "[Zenoh.ProvisionSubscriber] Updated #{ok_count} provisions for #{law_name}#{skipped}"
          )
        end

        {:ok, ok_count}

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

  defp upsert_provision(row, now) do
    section_id = row["section_id"]

    if is_nil(section_id) or section_id == "" do
      {:error, :missing_section_id}
    else
      taxa = normalize_taxa(row) |> Map.put(:taxa_enriched_at, now)

      case find_article(section_id) do
        {:ok, article} ->
          case article
               |> Ash.Changeset.for_update(:update_taxa, taxa)
               |> Ash.update() do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, {:update_failed, section_id, reason}}
          end

        {:error, {:not_found, _}} ->
          # Provision exists in fractalaw but not yet parsed in sertantai — skip silently.
          # Common for jurisdiction-specific IDs (s.23[E+W]) and structural sections (title, pt).
          {:error, {:not_found, section_id}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp find_article(section_id) do
    case Ash.get(LegalArticle, section_id) do
      {:ok, article} -> {:ok, article}
      {:error, _} -> {:error, {:not_found, section_id}}
    end
  end

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

    # Struct columns (List<Struct> → {:array, :map})
    Enum.reduce(@struct_atoms, acc, fn {str_key, atom_key}, acc ->
      case Map.get(row, str_key) do
        nil -> acc
        entries when is_list(entries) -> Map.put(acc, atom_key, entries)
        _ -> acc
      end
    end)
  end
end

defmodule SertantaiLegal.Zenoh.TaxaSubscriber do
  @moduledoc """
  Subscribes to fractalaw taxa enrichment data over Zenoh.

  Fractalaw publishes DRRP (duties, rights, responsibilities, powers) data
  as Arrow IPC streaming payloads. This subscriber decodes them with Explorer
  and upserts the taxa fields into existing UkLrt records.

  Key expression: fractalaw/@{tenant}/taxa/enrichment/{law_name}
  """

  use GenServer
  require Logger

  alias SertantaiLegal.Legal.UkLrt

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/taxa/enrichment/*"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.TaxaSubscriber] Subscribed to #{key_expr}")
        {:noreply, %{state | subscriber_id: subscriber_id}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.TaxaSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    law_name = sample.key_expr |> String.split("/") |> List.last()

    case decode_and_upsert(law_name, sample.payload) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("[Zenoh.TaxaSubscriber] Failed to process #{law_name}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.TaxaSubscriber] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # --- Internal ---

  defp decode_and_upsert(law_name, ipc_bytes) do
    with {:ok, taxa} <- decode_arrow_ipc(ipc_bytes),
         {:ok, record} <- find_record(law_name),
         {:ok, _updated} <- upsert_taxa(record, taxa) do
      Logger.info("[Zenoh.TaxaSubscriber] Updated taxa for #{law_name}")
      :ok
    end
  end

  defp decode_arrow_ipc(ipc_bytes) do
    df = Explorer.DataFrame.load_ipc_stream!(ipc_bytes)
    rows = Explorer.DataFrame.to_rows(df)

    case rows do
      [row | _] -> {:ok, normalize_taxa(row)}
      [] -> {:error, :empty_payload}
    end
  rescue
    e -> {:error, {:decode_failed, Exception.message(e)}}
  end

  defp find_record(law_name) do
    case Ash.read(UkLrt, filter: [name: law_name]) do
      {:ok, [record | _]} -> {:ok, record}
      {:ok, []} -> {:error, {:not_found, law_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp upsert_taxa(record, taxa) do
    Ash.update(record, taxa, action: :update)
  end

  @doc false
  def normalize_taxa(row) do
    # List<Utf8> columns → map with values key (matches existing JSONB format)
    # List<Struct> columns → map with entries key
    %{}
    |> put_holder_map(row, "duty_holder")
    |> put_holder_map(row, "rights_holder")
    |> put_holder_map(row, "responsibility_holder")
    |> put_holder_map(row, "power_holder")
    |> put_holder_map(row, "duty_type")
    |> put_list_field(row, "role")
    |> put_holder_map(row, "role_gvt")
    |> put_entries_map(row, "duties")
    |> put_entries_map(row, "rights")
    |> put_entries_map(row, "responsibilities")
    |> put_entries_map(row, "powers")
  end

  # List<Utf8> → %{values: ["a", "b"]} to match existing JSONB map format
  defp put_holder_map(acc, row, key) do
    case Map.get(row, key) do
      nil -> acc
      values when is_list(values) -> Map.put(acc, String.to_existing_atom(key), %{values: values})
      _ -> acc
    end
  end

  # role is {:array, :string} not :map
  defp put_list_field(acc, row, key) do
    case Map.get(row, key) do
      nil -> acc
      values when is_list(values) -> Map.put(acc, String.to_existing_atom(key), values)
      _ -> acc
    end
  end

  # List<Struct> → %{entries: [%{holder, duty_type, clause, article}]}
  defp put_entries_map(acc, row, key) do
    case Map.get(row, key) do
      nil ->
        acc

      entries when is_list(entries) ->
        Map.put(acc, String.to_existing_atom(key), %{entries: entries})

      _ ->
        acc
    end
  end
end

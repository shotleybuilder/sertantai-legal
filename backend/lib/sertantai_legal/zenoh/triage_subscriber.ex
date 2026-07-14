defmodule SertantaiLegal.Zenoh.TriageSubscriber do
  @moduledoc """
  Subscribes to fractalaw triage results over Zenoh.

  Fractalaw publishes making/not-making classification after triaging
  a law's provisions. This subscriber updates the LegalRegister record
  with the triage result.

  Key expression: fractalaw/@{tenant}/triage/{law_name}

  Updates:
  - `making_classification` — the triage classification (making/not_making/uncertain)
  - `making_confidence` — Bayesian posterior probability
  - `making_detection_tier` — highest signal tier that contributed
  - `making_detection_signals` — full counts breakdown
  - `is_making` — boolean derived from classification
  """

  use GenServer
  require Logger
  require Ash.Query

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Zenoh.ActivityLog

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
    ActivityLog.set_status(:triage_subscriber, :connecting)
    send(self(), :setup)
    {:ok, %{subscriber_id: nil, poll_count: 0, key_expr: nil}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        tenant = Application.get_env(:sertantai_legal, :zenoh)[:tenant] || "dev"
        key_expr = "fractalaw/@#{tenant}/triage/*"

        {:ok, subscriber_id} =
          Zenohex.Session.declare_subscriber(session_id, key_expr, self())

        Logger.info("[Zenoh.TriageSubscriber] Subscribed to #{key_expr}")
        ActivityLog.set_status(:triage_subscriber, :ready)
        ActivityLog.record(:triage_subscriber, :connected, %{key_expr: key_expr})
        {:noreply, %{state | subscriber_id: subscriber_id, key_expr: key_expr}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.TriageSubscriber] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  def handle_info(%Zenohex.Sample{} = sample, state) do
    law_name = sample.key_expr |> String.split("/") |> List.last()
    ActivityLog.increment(:triage_subscriber, :received)

    case process_triage(law_name, sample.payload) do
      :ok ->
        ActivityLog.increment(:triage_subscriber, :updated)
        ActivityLog.record(:triage_subscriber, :updated, %{law_name: law_name})

      {:error, reason} ->
        ActivityLog.increment(:triage_subscriber, :failed)

        ActivityLog.record(:triage_subscriber, :error, %{
          law_name: law_name,
          reason: inspect(reason)
        })

        Logger.error("[Zenoh.TriageSubscriber] Failed to process #{law_name}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_info(msg, state) do
    Logger.debug("[Zenoh.TriageSubscriber] Unexpected message: #{inspect(msg)}")
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

  defp process_triage(law_name, payload) do
    with {:ok, triage} <- decode_payload(payload),
         {:ok, record} <- find_record(law_name),
         {:ok, _updated} <- apply_triage(record, triage) do
      classification = triage["classification"]
      is_making = classification == "making"

      Logger.info(
        "[Zenoh.TriageSubscriber] #{law_name}: #{classification} " <>
          "(confidence=#{triage["confidence"]}, tier=#{triage["tier"]}, is_making=#{is_making})"
      )

      :ok
    end
  end

  defp decode_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:ok, _} -> {:error, :not_a_map}
      {:error, reason} -> {:error, {:decode_failed, reason}}
    end
  end

  defp find_record(law_name) do
    LegalRegister
    |> Ash.Query.filter(name == ^law_name)
    |> Ash.read()
    |> case do
      {:ok, [record | _]} -> {:ok, record}
      {:ok, []} -> {:error, {:not_found, law_name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_triage(record, triage) do
    classification = triage["classification"]
    is_making = classification == "making"

    params = %{
      making_classification: classification,
      making_confidence: triage["confidence"],
      making_detection_tier: triage["tier"],
      making_detection_signals: triage["counts"],
      is_making: is_making
    }

    Ash.update(record, params, action: :update)
  end
end

defmodule SertantaiLegal.Metrics.TelemetryHandler do
  @moduledoc """
  Telemetry handler that records metrics to FileStore.

  Attaches to telemetry events at application startup and records
  measurements to daily NDJSON files for analysis.

  ## Handled Events

  - `[:taxa, :classify, :complete]` - Taxa classification complete
  - `[:staged_parser, :parse, :complete]` - Full parse complete (all 7 stages)
  - `[:staged_parser, :stage, :complete]` - Individual stage complete

  ## Usage

  Automatically attached at application startup. No manual setup required.

  To manually attach (e.g., in tests):

      TelemetryHandler.attach()

  To detach:

      TelemetryHandler.detach()
  """

  alias SertantaiLegal.Metrics.FileStore

  @handler_id "sertantai-legal-metrics-handler"

  @doc """
  Attach the telemetry handler to relevant events.

  Called automatically at application startup.
  """
  @spec attach() :: :ok | {:error, :already_exists}
  def attach do
    events = [
      [:taxa, :classify, :complete],
      [:staged_parser, :parse, :complete],
      [:staged_parser, :stage, :complete]
    ]

    :telemetry.attach_many(
      @handler_id,
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  @doc """
  Detach the telemetry handler.
  """
  @spec detach() :: :ok | {:error, :not_found}
  def detach do
    :telemetry.detach(@handler_id)
  end

  @doc """
  Check if the handler is currently attached.
  """
  @spec attached?() :: boolean()
  def attached? do
    handlers = :telemetry.list_handlers([:taxa, :classify, :complete])
    Enum.any?(handlers, fn %{id: id} -> id == @handler_id end)
  end

  @doc """
  Handle telemetry events.

  Records measurements and metadata to the FileStore.
  """
  def handle_event([:taxa, :classify, :complete], measurements, metadata, _config) do
    FileStore.record(:taxa, measurements, metadata)
  end

  def handle_event([:staged_parser, :parse, :complete], measurements, metadata, _config) do
    FileStore.record(:parse, measurements, metadata)
  end

  def handle_event([:staged_parser, :stage, :complete], measurements, metadata, _config) do
    FileStore.record(:stage, measurements, metadata)
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    :ok
  end
end

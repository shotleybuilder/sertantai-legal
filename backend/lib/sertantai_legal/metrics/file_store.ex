defmodule SertantaiLegal.Metrics.FileStore do
  @moduledoc """
  File-based metrics storage using NDJSON (Newline Delimited JSON).

  Dev/test only - stores metrics in daily log files for before/after comparison.
  Production should use OpenTelemetry export to a proper observability stack.

  ## Storage Format

  Files are stored in `priv/metrics/` with daily rotation:

      priv/metrics/
      ├── taxa_2026-01-28.ndjson
      ├── taxa_2026-01-29.ndjson
      └── ...

  Each line is a JSON object with timestamp, measurements, and metadata.

  ## Usage

      # Record a metric (called by telemetry handler)
      FileStore.record(:taxa, measurements, metadata)

      # Load metrics for a day
      {:ok, events} = FileStore.load("2026-01-28")

      # List available metric files
      FileStore.list_files()
  """

  @metrics_dir "priv/metrics"

  @doc """
  Record a metric event to the daily NDJSON file.
  """
  @spec record(atom(), map(), map()) :: :ok | {:error, term()}
  def record(event_type, measurements, metadata) do
    ensure_metrics_dir()

    entry = %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      event: to_string(event_type),
      measurements: measurements,
      metadata: metadata
    }

    json_line = Jason.encode!(entry) <> "\n"
    file_path = current_file_path(event_type)

    case File.write(file_path, json_line, [:append, :utf8]) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Load all metrics from a specific date.

  ## Examples

      {:ok, events} = FileStore.load("taxa_2026-01-28")
      {:ok, events} = FileStore.load("2026-01-28")  # defaults to taxa
  """
  @spec load(String.t()) :: {:ok, list(map())} | {:error, term()}
  def load(file_or_date) do
    file_path = resolve_file_path(file_or_date)

    case File.read(file_path) do
      {:ok, content} ->
        events =
          content
          |> String.split("\n", trim: true)
          |> Enum.map(&Jason.decode!/1)

        {:ok, events}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Load metrics from a date with optional time filtering.

  ## Examples

      # All events after 2pm
      {:ok, events} = FileStore.load("2026-01-28", after: ~U[2026-01-28 14:00:00Z])

      # Events between times
      {:ok, events} = FileStore.load("2026-01-28",
        after: ~U[2026-01-28 14:00:00Z],
        before: ~U[2026-01-28 15:00:00Z]
      )
  """
  @spec load(String.t(), keyword()) :: {:ok, list(map())} | {:error, term()}
  def load(file_or_date, opts) do
    case load(file_or_date) do
      {:ok, events} ->
        filtered =
          events
          |> maybe_filter_after(opts[:after])
          |> maybe_filter_before(opts[:before])

        {:ok, filtered}

      error ->
        error
    end
  end

  @doc """
  List all available metric files.
  """
  @spec list_files() :: list(String.t())
  def list_files do
    ensure_metrics_dir()

    Path.join(metrics_dir(), "*.ndjson")
    |> Path.wildcard()
    |> Enum.map(&Path.basename(&1, ".ndjson"))
    |> Enum.sort(:desc)
  end

  @doc """
  Clear all metrics for a specific date.
  """
  @spec clear(String.t()) :: :ok
  def clear(file_or_date) do
    file_path = resolve_file_path(file_or_date)
    File.rm(file_path)
    :ok
  end

  @doc """
  Clear all metrics files.
  """
  @spec clear_all() :: :ok
  def clear_all do
    ensure_metrics_dir()

    Path.join(metrics_dir(), "*.ndjson")
    |> Path.wildcard()
    |> Enum.each(&File.rm/1)

    :ok
  end

  @doc """
  Get the metrics directory path.
  """
  @spec metrics_dir() :: String.t()
  def metrics_dir do
    Application.get_env(:sertantai_legal, :metrics_dir, default_metrics_dir())
  end

  # ============================================================================
  # Private
  # ============================================================================

  defp default_metrics_dir do
    case :code.priv_dir(:sertantai_legal) do
      {:error, _} ->
        # Fallback for dev/test when priv_dir doesn't exist yet
        Path.join(File.cwd!(), @metrics_dir)

      priv_path ->
        Path.join(priv_path, "metrics")
    end
  end

  defp ensure_metrics_dir do
    dir = metrics_dir()

    unless File.exists?(dir) do
      File.mkdir_p!(dir)
    end
  end

  defp current_file_path(event_type) do
    date = Date.utc_today() |> Date.to_iso8601()
    Path.join(metrics_dir(), "#{event_type}_#{date}.ndjson")
  end

  defp resolve_file_path(file_or_date) do
    cond do
      # Full filename with extension
      String.ends_with?(file_or_date, ".ndjson") ->
        Path.join(metrics_dir(), file_or_date)

      # Filename without extension (e.g., "taxa_2026-01-28")
      String.contains?(file_or_date, "_") ->
        Path.join(metrics_dir(), "#{file_or_date}.ndjson")

      # Just date - default to taxa
      true ->
        Path.join(metrics_dir(), "taxa_#{file_or_date}.ndjson")
    end
  end

  defp maybe_filter_after(events, nil), do: events

  defp maybe_filter_after(events, after_time) do
    Enum.filter(events, fn event ->
      {:ok, ts, _} = DateTime.from_iso8601(event["timestamp"])
      DateTime.compare(ts, after_time) in [:gt, :eq]
    end)
  end

  defp maybe_filter_before(events, nil), do: events

  defp maybe_filter_before(events, before_time) do
    Enum.filter(events, fn event ->
      {:ok, ts, _} = DateTime.from_iso8601(event["timestamp"])
      DateTime.compare(ts, before_time) in [:lt, :eq]
    end)
  end
end

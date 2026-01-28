defmodule SertantaiLegal.Metrics do
  @moduledoc """
  Convenience module for metrics operations in IEx.

  Dev/test only - provides simple access to metrics summary, comparison, and export.

  ## Quick Start

      # View today's summary
      Metrics.summary()

      # Compare two runs
      Metrics.compare("2026-01-28", "2026-01-27")

      # List available files
      Metrics.list()

      # Export to CSV
      Metrics.export("2026-01-28", format: :csv)

  ## Workflow

  1. Run a parse to collect baseline metrics
  2. Make code changes
  3. Run the same parse again
  4. Compare the two runs to see improvement

  ## Storage

  Metrics are stored in `priv/metrics/` as daily NDJSON files.
  These files are gitignored and persist across server restarts.
  """

  alias SertantaiLegal.Metrics.{FileStore, Reporter}

  @doc """
  Print a summary of metrics for a given date.

  ## Examples

      Metrics.summary()              # Today
      Metrics.summary("2026-01-28")  # Specific date
  """
  defdelegate summary(date \\ nil), to: Reporter

  @doc """
  Compare metrics between two dates.

  Shows percentage change in P50, P95, P99 for total time and each stage.
  Green = faster, Red = slower.

  ## Examples

      Metrics.compare("2026-01-28", "2026-01-27")
  """
  defdelegate compare(date_a, date_b), to: Reporter

  @doc """
  List available metric files.
  """
  defdelegate list(), to: Reporter

  @doc """
  Export metrics to a readable format.

  ## Options

  - `:format` - `:table` (default) or `:csv`

  ## Examples

      Metrics.export("2026-01-28")
      Metrics.export("2026-01-28", format: :csv)
  """
  defdelegate export(date, opts \\ []), to: Reporter

  @doc """
  Load raw metrics for a date.

  Returns the list of metric events for programmatic access.

  ## Examples

      {:ok, events} = Metrics.load("2026-01-28")
  """
  defdelegate load(date), to: FileStore

  @doc """
  Load raw metrics with time filtering.

  ## Examples

      {:ok, events} = Metrics.load("2026-01-28", after: ~U[2026-01-28 14:00:00Z])
  """
  defdelegate load(date, opts), to: FileStore

  @doc """
  Clear metrics for a specific date.
  """
  defdelegate clear(date), to: FileStore

  @doc """
  Clear all metrics files.
  """
  defdelegate clear_all(), to: FileStore
end

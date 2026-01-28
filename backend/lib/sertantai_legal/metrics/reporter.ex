defmodule SertantaiLegal.Metrics.Reporter do
  @moduledoc """
  Metrics reporting and comparison tools for Taxa parsing performance.

  Dev/test only - provides summary statistics and before/after comparison
  for measuring the impact of optimizations.

  ## Usage in IEx

      # Summary of today's metrics
      Metrics.summary()

      # Summary of a specific day
      Metrics.summary("2026-01-28")

      # Compare two days
      Metrics.compare("2026-01-28", "2026-01-27")

      # List available metric files
      Metrics.list()
  """

  alias SertantaiLegal.Metrics.FileStore

  @doc """
  Print a summary of metrics for a given date.

  Shows count, P50, P95, P99, and per-stage breakdowns.

  ## Examples

      Reporter.summary()              # Today
      Reporter.summary("2026-01-28")  # Specific date
  """
  @spec summary(String.t() | nil) :: :ok
  def summary(date \\ nil) do
    date = date || Date.utc_today() |> Date.to_iso8601()

    case FileStore.load(date) do
      {:ok, []} ->
        IO.puts("No metrics found for #{date}")

      {:ok, events} ->
        print_summary(date, events)

      {:error, reason} ->
        IO.puts("Error loading metrics: #{inspect(reason)}")
    end
  end

  @doc """
  Compare metrics between two dates.

  Shows percentage change in P50, P95, P99 for total time and each stage.

  ## Examples

      Reporter.compare("2026-01-28", "2026-01-27")
      Reporter.compare("after-optimization", "before-optimization")
  """
  @spec compare(String.t(), String.t()) :: :ok
  def compare(date_a, date_b) do
    with {:ok, events_a} <- FileStore.load(date_a),
         {:ok, events_b} <- FileStore.load(date_b) do
      if events_a == [] or events_b == [] do
        IO.puts("Insufficient data for comparison")
        IO.puts("  #{date_a}: #{length(events_a)} events")
        IO.puts("  #{date_b}: #{length(events_b)} events")
      else
        print_comparison(date_a, events_a, date_b, events_b)
      end
    else
      {:error, reason} ->
        IO.puts("Error loading metrics: #{inspect(reason)}")
    end
  end

  @doc """
  List available metric files.
  """
  @spec list() :: :ok
  def list do
    files = FileStore.list_files()

    if files == [] do
      IO.puts("No metric files found")
    else
      IO.puts("Available metric files:")

      Enum.each(files, fn file ->
        {:ok, events} = FileStore.load(file)
        IO.puts("  #{file} (#{length(events)} events)")
      end)
    end
  end

  @doc """
  Export metrics to a readable format.
  """
  @spec export(String.t(), keyword()) :: :ok
  def export(date, opts \\ []) do
    format = Keyword.get(opts, :format, :table)

    case FileStore.load(date) do
      {:ok, []} ->
        IO.puts("No metrics found for #{date}")

      {:ok, events} ->
        case format do
          :table -> print_table(events)
          :csv -> print_csv(events)
          _ -> IO.puts("Unknown format: #{format}")
        end

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  # ============================================================================
  # Summary Printing
  # ============================================================================

  defp print_summary(date, events) do
    durations = extract_durations(events)

    IO.puts("")
    IO.puts("=== Taxa Metrics Summary: #{date} ===")
    IO.puts("")
    IO.puts("Total events: #{length(events)}")
    IO.puts("")

    print_duration_stats("Total Duration", durations.total)
    print_duration_stats("Actor Stage", durations.actor)
    print_duration_stats("DutyType Stage", durations.duty_type)
    print_duration_stats("Popimar Stage", durations.popimar)
    print_duration_stats("Purpose Stage", durations.purpose)

    IO.puts("")
    print_text_length_stats(events)
    print_popimar_skip_stats(events)
  end

  defp print_duration_stats(label, values) when values == [] do
    IO.puts("#{String.pad_trailing(label, 20)} No data")
  end

  defp print_duration_stats(label, values) do
    stats = calculate_percentiles(values)

    IO.puts(
      "#{String.pad_trailing(label, 20)} " <>
        "P50: #{format_duration(stats.p50)} | " <>
        "P95: #{format_duration(stats.p95)} | " <>
        "P99: #{format_duration(stats.p99)} | " <>
        "Min: #{format_duration(stats.min)} | " <>
        "Max: #{format_duration(stats.max)}"
    )
  end

  defp print_text_length_stats(events) do
    lengths =
      events
      |> Enum.map(& &1["measurements"]["text_length"])
      |> Enum.reject(&is_nil/1)

    if lengths != [] do
      stats = calculate_percentiles(lengths)

      IO.puts("Text Length Stats:")

      IO.puts(
        "  P50: #{format_number(stats.p50)} chars | " <>
          "P95: #{format_number(stats.p95)} chars | " <>
          "Max: #{format_number(stats.max)} chars"
      )
    end
  end

  defp print_popimar_skip_stats(events) do
    total = length(events)

    skipped =
      events
      |> Enum.count(& &1["metadata"]["popimar_skipped"])

    if total > 0 do
      pct = Float.round(skipped / total * 100, 1)
      IO.puts("POPIMAR skipped: #{skipped}/#{total} (#{pct}%)")
    end
  end

  # ============================================================================
  # Comparison Printing
  # ============================================================================

  defp print_comparison(date_a, events_a, date_b, events_b) do
    durations_a = extract_durations(events_a)
    durations_b = extract_durations(events_b)

    IO.puts("")
    IO.puts("=== Taxa Metrics Comparison ===")
    IO.puts("")
    IO.puts("  A: #{date_a} (#{length(events_a)} events)")
    IO.puts("  B: #{date_b} (#{length(events_b)} events)")
    IO.puts("")

    IO.puts(
      "                      #{String.pad_trailing("A (P50)", 12)} #{String.pad_trailing("B (P50)", 12)} Change"
    )

    IO.puts("  " <> String.duplicate("-", 55))

    print_comparison_row("Total Duration", durations_a.total, durations_b.total)
    print_comparison_row("Actor Stage", durations_a.actor, durations_b.actor)
    print_comparison_row("DutyType Stage", durations_a.duty_type, durations_b.duty_type)
    print_comparison_row("Popimar Stage", durations_a.popimar, durations_b.popimar)
    print_comparison_row("Purpose Stage", durations_a.purpose, durations_b.purpose)

    IO.puts("")
  end

  defp print_comparison_row(label, values_a, values_b) do
    stats_a = calculate_percentiles(values_a)
    stats_b = calculate_percentiles(values_b)

    p50_a = stats_a.p50 || 0
    p50_b = stats_b.p50 || 0

    change =
      if p50_b > 0 do
        pct = (p50_a - p50_b) / p50_b * 100
        format_change(pct)
      else
        "N/A"
      end

    IO.puts(
      "  #{String.pad_trailing(label, 18)} " <>
        "#{String.pad_trailing(format_duration(p50_a), 12)} " <>
        "#{String.pad_trailing(format_duration(p50_b), 12)} " <>
        "#{change}"
    )
  end

  defp format_change(pct) when pct < 0 do
    # Negative = improvement (faster)
    "\e[32m#{Float.round(pct, 1)}%\e[0m"
  end

  defp format_change(pct) when pct > 0 do
    # Positive = regression (slower)
    "\e[31m+#{Float.round(pct, 1)}%\e[0m"
  end

  defp format_change(_pct), do: "0%"

  # ============================================================================
  # Table/CSV Export
  # ============================================================================

  defp print_table(events) do
    IO.puts("")

    IO.puts(
      "#{String.pad_trailing("Timestamp", 25)} " <>
        "#{String.pad_trailing("Total", 10)} " <>
        "#{String.pad_trailing("Actor", 10)} " <>
        "#{String.pad_trailing("DutyType", 10)} " <>
        "#{String.pad_trailing("Popimar", 10)} " <>
        "#{String.pad_trailing("Purpose", 10)} " <>
        "Chars"
    )

    IO.puts(String.duplicate("-", 90))

    Enum.each(events, fn event ->
      m = event["measurements"]

      IO.puts(
        "#{String.pad_trailing(String.slice(event["timestamp"], 0, 24), 25)} " <>
          "#{String.pad_trailing(format_duration(m["duration_us"]), 10)} " <>
          "#{String.pad_trailing(format_duration(m["actor_duration_us"]), 10)} " <>
          "#{String.pad_trailing(format_duration(m["duty_type_duration_us"]), 10)} " <>
          "#{String.pad_trailing(format_duration(m["popimar_duration_us"]), 10)} " <>
          "#{String.pad_trailing(format_duration(m["purpose_duration_us"]), 10)} " <>
          "#{m["text_length"]}"
      )
    end)
  end

  defp print_csv(events) do
    IO.puts(
      "timestamp,total_ms,actor_ms,duty_type_ms,popimar_ms,purpose_ms,text_length,popimar_skipped"
    )

    Enum.each(events, fn event ->
      m = event["measurements"]
      meta = event["metadata"]

      IO.puts(
        "#{event["timestamp"]}," <>
          "#{div(m["duration_us"] || 0, 1000)}," <>
          "#{div(m["actor_duration_us"] || 0, 1000)}," <>
          "#{div(m["duty_type_duration_us"] || 0, 1000)}," <>
          "#{div(m["popimar_duration_us"] || 0, 1000)}," <>
          "#{div(m["purpose_duration_us"] || 0, 1000)}," <>
          "#{m["text_length"]}," <>
          "#{meta["popimar_skipped"]}"
      )
    end)
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp extract_durations(events) do
    %{
      total: Enum.map(events, & &1["measurements"]["duration_us"]) |> Enum.reject(&is_nil/1),
      actor:
        Enum.map(events, & &1["measurements"]["actor_duration_us"]) |> Enum.reject(&is_nil/1),
      duty_type:
        Enum.map(events, & &1["measurements"]["duty_type_duration_us"]) |> Enum.reject(&is_nil/1),
      popimar:
        Enum.map(events, & &1["measurements"]["popimar_duration_us"]) |> Enum.reject(&is_nil/1),
      purpose:
        Enum.map(events, & &1["measurements"]["purpose_duration_us"]) |> Enum.reject(&is_nil/1)
    }
  end

  defp calculate_percentiles([]), do: %{p50: nil, p95: nil, p99: nil, min: nil, max: nil}

  defp calculate_percentiles(values) do
    sorted = Enum.sort(values)
    count = length(sorted)

    %{
      p50: percentile(sorted, count, 50),
      p95: percentile(sorted, count, 95),
      p99: percentile(sorted, count, 99),
      min: List.first(sorted),
      max: List.last(sorted)
    }
  end

  defp percentile(sorted, count, p) do
    index = trunc(p / 100 * (count - 1))
    Enum.at(sorted, index)
  end

  defp format_duration(nil), do: "-"

  defp format_duration(us) when us < 1000, do: "#{us}µs"
  defp format_duration(us) when us < 1_000_000, do: "#{Float.round(us / 1000, 1)}ms"
  defp format_duration(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  defp format_number(nil), do: "-"
  defp format_number(n) when n < 1000, do: "#{n}"
  defp format_number(n) when n < 1_000_000, do: "#{Float.round(n / 1000, 1)}K"
  defp format_number(n), do: "#{Float.round(n / 1_000_000, 2)}M"
end

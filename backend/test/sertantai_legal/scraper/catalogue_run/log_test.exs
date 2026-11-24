defmodule SertantaiLegal.Scraper.CatalogueRun.LogTest do
  @moduledoc "The catalogue runs' log: one JSON line a run, and the run's sampled peak memory."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CatalogueRun
  alias SertantaiLegal.Scraper.CatalogueRun.Log

  @tag :tmp_dir
  test "append adds one JSON line a run", %{tmp_dir: dir} do
    path = Path.join(dir, "catalogue-runs.jsonl")

    run =
      CatalogueRun.new(
        catalogue: "order_patterns",
        scope: "all",
        started_at: ~U[2026-11-21 12:00:00Z],
        commit: "abc1234",
        caches: %{},
        wall_s: 1.0,
        serial_s: 0.5,
        workers: 1,
        peak_mb: 10
      )

    Log.append(run, path)
    Log.append(run, path)

    lines = path |> File.read!() |> String.split("\n", trim: true)
    assert length(lines) == 2
    assert %{"catalogue" => "order_patterns", "kind" => "uncached"} = Jason.decode!(hd(lines))
  end

  @tag :tmp_dir
  test "record runs the work, tallies each cache and appends the run", %{tmp_dir: dir} do
    path = Path.join(dir, "runs.jsonl")

    {value, run} =
      Log.record([catalogue: "feed_patterns", scope: "all", workers: 2, log: path], fn ->
        {:done, %{"law" => [:hit, :hit, :read]}, 250_000}
      end)

    assert value == :done
    assert run.caches == %{"law" => %{hits: 2, read: 1}}
    assert run.serial_s == 0.3
    assert CatalogueRun.kind(run) == :mixed
    assert [_] = path |> File.read!() |> String.split("\n", trim: true)
  end

  # the peak sees what the call holds: 64 MB held through it shows well above
  # the memory at its start (a margin, since other processes free memory too)
  test "the function's result, with a sampled peak that sees what the call holds" do
    start = div(:erlang.memory(:total), 1_048_576)

    {result, peak} =
      Log.sample_peak(fn ->
        held = :binary.copy(<<0>>, 64 * 1_048_576)
        Process.sleep(600)
        byte_size(held)
      end)

    assert result == 64 * 1_048_576
    assert peak >= start + 32
  end
end

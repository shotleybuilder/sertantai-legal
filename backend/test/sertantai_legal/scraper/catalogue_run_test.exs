defmodule SertantaiLegal.Scraper.CatalogueRunTest do
  @moduledoc """
  A catalogue run's record (Catalogues Across the Workflow, 2026-11-21: the
  step sessions recorded the catalogues' times only now and then, in prose,
  never cold, warm and serial side by side).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CatalogueRun

  defp run(caches),
    do:
      CatalogueRun.new(
        catalogue: "commencement_patterns",
        scope: "all",
        started_at: ~U[2026-11-21 12:00:00Z],
        commit: "abc1234",
        caches: caches,
        wall_s: 93.2,
        serial_s: 70.1,
        workers: 4,
        peak_mb: 820
      )

  test "cold, warm, mixed, and uncached by its caches' hits and reads" do
    assert CatalogueRun.kind(run(%{"law" => %{hits: 0, read: 10}})) == :cold
    assert CatalogueRun.kind(run(%{"law" => %{hits: 10, read: 0}})) == :warm
    assert CatalogueRun.kind(run(%{"law" => %{hits: 6, read: 4}})) == :mixed
    assert CatalogueRun.kind(run(%{})) == :uncached
  end

  test "two caches: warm only when both are" do
    assert CatalogueRun.kind(
             run(%{"law" => %{hits: 10, read: 0}, "merge" => %{hits: 0, read: 3}})
           ) ==
             :mixed

    assert CatalogueRun.kind(
             run(%{"law" => %{hits: 10, read: 0}, "merge" => %{hits: 3, read: 0}})
           ) ==
             :warm
  end

  test "a run's scope from its options" do
    assert CatalogueRun.scope([]) == "all"
    assert CatalogueRun.scope(laws: "UK_a,UK_b,") == "laws:2"
    assert CatalogueRun.scope(family: "Fire") == "family:Fire"
    assert CatalogueRun.scope(orders: "UK_uksi_1_1") == "orders:1"
  end

  test "a cache's tally from each law's :hit | :read" do
    assert CatalogueRun.tally([:hit, :read, :hit]) == %{hits: 2, read: 1}
    assert CatalogueRun.tally([]) == %{hits: 0, read: 0}
  end

  test "the line a run prints" do
    assert CatalogueRun.line(run(%{"law" => %{hits: 3804, read: 0}})) ==
             "run: warm, law: 3804 hits 0 read, 93.2 s (serial 70.1 s), 820 MB, 4 workers"
  end

  test "as JSON, every field" do
    json = run(%{"law" => %{hits: 1, read: 2}}) |> CatalogueRun.to_json()

    assert %{
             "catalogue" => "commencement_patterns",
             "kind" => "mixed",
             "scope" => "all",
             "started_at" => "2026-11-21T12:00:00Z",
             "commit" => "abc1234",
             "caches" => %{"law" => %{"hits" => 1, "read" => 2}},
             "wall_s" => 93.2,
             "serial_s" => 70.1,
             "workers" => 4,
             "peak_mb" => 820
           } = json
  end
end

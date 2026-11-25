defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.FeedYardstickTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.FeedYardstick

  defp group(rows, by_law),
    do: %{rows: rows, laws: map_size(by_law), by_law: by_law, examples: []}

  defp groups,
    do: [
      {"inserted | feed_only | ours undated: appointed",
       group(617, %{"UK_a" => 600, "UK_b" => 17})},
      {"differ | own dated by clause_date | own earlier",
       group(26, %{"UK_c" => 6, "UK_d" => 20})},
      {"feed_only | ours undated", group(5, %{"UK_e" => 5})}
    ]

  @reviewed %{
    "inserted | feed_only | ours undated: appointed" => "known: the feed alone dates it",
    "differ | own dated by clause_date | own earlier @ UK_c" => %{
      "status" => "fix: a misread",
      "owner" => "Commencement reader"
    },
    "differ | own dated by clause_date | own earlier @ UK_d" => "known: a one-law wording"
  }

  test "the record holds the counts, the proven feed errors and the groups by status and row kind" do
    r =
      FeedYardstick.record(%{
        family: "F",
        at: ~U[2026-11-23 10:00:00Z],
        fresh: false,
        yardstick: [agree: 10, differ: 3, feed_error: 2, own_only: 7],
        groups: groups(),
        reviewed: @reviewed
      })

    assert r.counts == %{
             "agree" => 10,
             "differ" => 3,
             "feed_error" => 2,
             "feed_only" => 0,
             "feed_partial_only" => 0,
             "own_only" => 7,
             "neither" => 0
           }

    assert r.feed_errors_proven == 2
    assert r.groups == 3

    assert r.by_status == %{
             "known" => %{"rows" => 637, "groups" => 2},
             "fix" => %{"rows" => 6, "groups" => 1},
             "no status" => %{"rows" => 5, "groups" => 1}
           }

    assert r.by_row == %{
             "inserted provision" => %{"rows" => 617, "groups" => 1},
             "own provision" => %{"rows" => 31, "groups" => 2}
           }

    assert r.by_owner == %{
             "Commencement reader" => %{"rows" => 6, "groups" => 1},
             "no owner" => %{"rows" => 642, "groups" => 3}
           }
  end

  test "lines print the standard table with the record's date and whether it follows the last build" do
    r =
      FeedYardstick.record(%{
        family: "F",
        at: ~U[2026-11-23 10:00:00Z],
        fresh: true,
        yardstick: [agree: 3, differ: 1],
        groups: [],
        reviewed: %{}
      })

    lines = FeedYardstick.lines(r, ~U[2026-11-23 09:00:00Z])
    text = Enum.join(lines, "\n")
    assert text =~ "Commencement against the feed"
    assert text =~ "2026-11-23 10:00:00Z, --fresh, after the last build"
    assert text =~ ~r/\s+3\s+75\.0%\s+agree/
    assert text =~ ~r/\s+0\s+0\.0%\s+feed_only/

    stale = FeedYardstick.lines(r, ~U[2026-11-23 11:00:00Z]) |> Enum.join("\n")
    assert stale =~ "BEFORE the last build"
  end

  test "no record says how to make one" do
    assert [line] = FeedYardstick.lines(nil, nil)
    assert line =~ "mix lat.commencement_check --family F --all"
  end

  test "a record round-trips through its file" do
    path = Path.join(System.tmp_dir!(), "yardstick-#{System.unique_integer([:positive])}.json")

    r =
      FeedYardstick.record(%{
        family: "F",
        at: ~U[2026-11-23 10:00:00Z],
        fresh: false,
        yardstick: [agree: 1],
        groups: groups(),
        reviewed: @reviewed
      })

    FeedYardstick.write(r, path)
    assert FeedYardstick.read(path) == r
    assert FeedYardstick.read(path <> ".none") == nil
    File.rm!(path)
  end

  # RULES `feed-differences-are-patterns-by-feed-coverage`: the check's laws
  # by whether the feed holds their commencement (`FeedCoverage.of/1`)
  test "the record holds the check's laws by feed coverage, and its lines print them" do
    r =
      FeedYardstick.record(%{
        family: "F",
        at: ~U[2026-11-25 10:00:00Z],
        fresh: false,
        yardstick: [agree: 1],
        groups: [],
        reviewed: %{},
        coverage: %{covered: 3, none: 5}
      })

    assert r.coverage == %{"covered" => 3, "none" => 5}

    assert "  laws by feed coverage: the feed holds 3, silent 5" in FeedYardstick.lines(r, nil)
  end

  test "a record from before the coverage split reads back with none" do
    r =
      FeedYardstick.record(%{
        family: "F",
        at: ~U[2026-11-25 10:00:00Z],
        fresh: false,
        yardstick: [],
        groups: [],
        reviewed: %{}
      })

    assert r.coverage == nil
    refute Enum.any?(FeedYardstick.lines(r, nil), &(&1 =~ "feed coverage"))
  end

  test "the path is per family" do
    assert FeedYardstick.path("Waste, Water and Climate") ==
             "data/reports/commencement-reader/yardstick/waste-water-and-climate.json"
  end
end

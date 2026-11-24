defmodule SertantaiLegal.Scraper.Commencement.FeedCoverageTest do
  @moduledoc "Whether the feed holds a law's commencement (Decision 1 (a), Jason 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.FeedCoverage
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(type, date),
    do: %Effect{type: type, affecting: "UK_uksi_2009_359", in_force_date: date}

  describe "of/1" do
    test "a dated coming-into-force record covers the law" do
      effects = [
        effect("coming into force", ~D[2009-04-01]),
        effect("words substituted", ~D[2010-01-01])
      ]

      assert FeedCoverage.of(effects) == %{covered: true, records: 1}
    end

    test "\"coming into operation\" is coming into force too" do
      assert %{covered: true} = FeedCoverage.of([effect("coming into operation", ~D[1975-01-01])])
    end

    # a law wholly in force on one day has no coming-into-force record,
    # though the feed holds every amendment of it (413 UK SIs from 2002)
    test "amendments alone don't cover it" do
      effects = [effect("inserted", ~D[2015-01-01]), effect("words repealed", ~D[2016-01-01])]
      assert FeedCoverage.of(effects) == %{covered: false, records: 0}
    end

    test "a prospective record with no date gives no date" do
      assert FeedCoverage.of([effect("coming into force", nil)]) == %{covered: false, records: 0}
    end
  end

  test "band/1: before 2002, and 2002 on" do
    assert FeedCoverage.band(2001) == "before 2002"
    assert FeedCoverage.band(2002) == "2002 on"
  end

  test "tally/1 and lines/1: each family's laws by band, covered or not, then all" do
    laws = [
      %{family: "F", year: 1990, covered: false},
      %{family: "F", year: 2010, covered: true},
      %{family: "F", year: 2011, covered: false},
      %{family: "G", year: 2012, covered: true}
    ]

    tally = FeedCoverage.tally(laws)
    assert tally["F"]["2002 on"] == %{covered: 1, none: 1}
    assert tally["F"]["before 2002"] == %{covered: 0, none: 1}

    assert FeedCoverage.lines(tally) == [
             "feed coverage (laws whose feed holds a commencement record):",
             "  F: covered 1, none 2 (before 2002: 0 / 1; 2002 on: 1 / 1)",
             "  G: covered 1, none 0 (before 2002: 0 / 0; 2002 on: 1 / 0)",
             "  all: covered 2, none 2 (before 2002: 0 / 1; 2002 on: 2 / 1)"
           ]
  end

  test "row_share/1: a law's rows with a feed record (partly covered laws show)" do
    rows = [
      %{law: "A", feed: {~D[2009-01-01], ~D[2009-01-01]}},
      %{law: "A", feed: nil},
      %{law: "B", feed: nil}
    ]

    assert FeedCoverage.row_share(rows) == %{"A" => {1, 2}, "B" => {0, 1}}
  end
end

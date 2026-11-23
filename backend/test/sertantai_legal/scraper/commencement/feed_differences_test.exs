defmodule SertantaiLegal.Scraper.Commencement.FeedDifferencesTest do
  @moduledoc """
  The two-way feed gate (LAT Change Pipeline, step Commencement reader;
  Jason 2026-11-21, Decision 5): every row where the commencement reader's
  reading and the Feed reader's differ, or where only the feed dates it,
  grouped by the shape of its cause, so each group is named (ours, the
  Feed reader's, legislation.gov.uk's, or a yardstick difference).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.FeedDifferences
  alias SertantaiLegal.Scraper.Commencement.Rule

  defp rule(treatment, w \\ {:date, ~D[2020-01-01]}),
    do:
      Rule.new(
        commences: "UK_x",
        scope: :all,
        when: w,
        source: %{law: "UK_x"},
        treatment: treatment
      )

  defp row(attrs) do
    Map.merge(
      %{
        law: "UK_x",
        id: "reg.2",
        outcome: :dated,
        full_from: ~D[2020-01-01],
        partial_from: nil,
        feed: {~D[2020-02-01], ~D[2020-02-01]},
        yardstick: :differ,
        result: %{entries: [%{date: ~D[2020-01-01], rule: rule(:provision_dated)}], undated: []}
      },
      attrs
    )
  end

  test "rows agreeing, or with no feed, are no difference" do
    assert FeedDifferences.shape(row(%{yardstick: :agree})) == nil
    assert FeedDifferences.shape(row(%{yardstick: :own_only, feed: nil})) == nil
    assert FeedDifferences.shape(row(%{yardstick: :neither, feed: nil})) == nil
  end

  test "a differ row's shape names our outcome, the rule that dates it and which side is earlier" do
    assert FeedDifferences.shape(row(%{})) ==
             "differ | own dated by provision_dated | own earlier"

    later = row(%{full_from: ~D[2020-03-01]})
    assert FeedDifferences.shape(later) =~ "own later"
  end

  # a provision another law inserted takes that law's day (the Amending-law
  # reader's): its feed record dates the insertion, never the law's own
  # commencement (NISI 1978/1049 reg.29A, inserted 2012, feed 2012-04-01)
  # (Decision 7 C, Jason 2026-11-21: judged by its inserting law instead,
  # `Check.inserted/3`, never by the host law's own clause)
  test "an inserted provision is left out of the own-clause gate" do
    r = row(%{inserted: true, full_from: ~D[1978-06-01], feed: {~D[2012-04-01], ~D[2012-04-01]}})
    assert FeedDifferences.shape(r) == nil
  end

  test "a feed-only row's shape names what our reader left it as" do
    r =
      row(%{
        yardstick: :feed_only,
        outcome: :by_order,
        full_from: nil,
        result: %{entries: [], undated: [rule(:provision_by_order, {:appointed, "by order"})]}
      })

    assert FeedDifferences.shape(r) ==
             "feed_only | own by_order by provision_by_order | feed full"
  end

  test "a feed record partial only, beside our full date" do
    r = row(%{yardstick: :feed_partial_only, feed: {~D[2020-01-01], nil}})

    assert FeedDifferences.shape(r) ==
             "feed_partial_only | own dated by provision_dated | first agrees"
  end

  test "groups count rows and laws, keep three examples from different laws, rank by rows" do
    rows =
      for {law, n} <- [{"UK_a", 3}, {"UK_b", 1}], i <- 1..n, do: row(%{law: law, id: "reg.#{i}"})

    [{shape, g}] = FeedDifferences.groups(rows)
    assert shape =~ "differ"
    assert g.rows == 4 and g.laws == 2
    assert Enum.map(g.examples, & &1.law) == ["UK_a", "UK_b"]
  end

  test "a group lists every law in it with its rows (the step's work list: every instance)" do
    rows =
      for {law, n} <- [{"UK_a", 3}, {"UK_b", 1}], i <- 1..n, do: row(%{law: law, id: "reg.#{i}"})

    [{_shape, g}] = FeedDifferences.groups(rows)
    assert g.by_law == %{"UK_a" => 3, "UK_b" => 1}
  end

  test "the summary lists each group's status and counts those with none" do
    groups = FeedDifferences.groups([row(%{})])
    [shape] = Enum.map(groups, &elem(&1, 0))

    assert List.last(FeedDifferences.summary(groups, %{})) =~ "with no status: 1"

    assert List.last(FeedDifferences.summary(groups, %{shape => "known: x"})) =~
             "with no status: 0"
  end

  test "a status keyed by law (\"<shape> @ <law>\") is that law's, and wins over the shape's own" do
    rows = [row(%{law: "UK_a"}), row(%{law: "UK_b", id: "reg.2"})]
    [{shape, _}] = groups = FeedDifferences.groups(rows)

    assert FeedDifferences.status(%{shape => "known: all"}, shape, "UK_a") == "known: all"

    assert FeedDifferences.status(
             %{shape => "known: all", "#{shape} @ UK_a" => "fix: a"},
             shape,
             "UK_a"
           ) == "fix: a"

    assert FeedDifferences.status(%{}, shape, "UK_a") == nil

    # one law statused, the other not: the group still counts as unstatused
    lines = FeedDifferences.summary(groups, %{"#{shape} @ UK_a" => "known: a"})
    assert List.last(lines) =~ "with no status: 1"
    assert Enum.any?(lines, &(&1 =~ "UK_a" and &1 =~ "known: a"))
    assert Enum.any?(lines, &(&1 =~ "UK_b" and &1 =~ "no status"))

    both = %{"#{shape} @ UK_a" => "known: a", "#{shape} @ UK_b" => "fix: b"}
    assert List.last(FeedDifferences.summary(groups, both)) =~ "with no status: 0"
  end

  test "a status may name its owning step: {status, owner}; a plain string is a status with no owner" do
    shape = "differ | own dated by clause_date | own earlier"

    reviewed = %{
      shape => %{"status" => "known: a wording", "owner" => "Commencement reader"},
      "#{shape} @ UK_b" => "fix: fetch"
    }

    assert FeedDifferences.status(reviewed, shape, "UK_a") == "known: a wording"
    assert FeedDifferences.owner(reviewed, shape, "UK_a") == "Commencement reader"
    assert FeedDifferences.status(reviewed, shape, "UK_b") == "fix: fetch"
    assert FeedDifferences.owner(reviewed, shape, "UK_b") == nil
    assert FeedDifferences.owner(%{}, shape, "UK_a") == nil
  end
end

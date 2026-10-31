defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelPeriodsTest do
  @moduledoc """
  The label fold's periods in the timeline's shape (CV-05): what compliance
  reads (`lat_label_timeline`), built from the merged changes.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence, LabelPeriods}

  @law "UK_uksi_1999_3242"
  @sid "UK_uksi_1999_3242:reg.3(1)"

  defp change(key, date) do
    %Change{
      key: key,
      target: "reg.3(1)",
      resolved: %Evidence.Resolved{
        operation: :substituted,
        level: :words,
        territory: nil,
        date: date,
        by: "UK_uksi_2006_438",
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }
  end

  defp period(from, status, opts \\ []) do
    %{
      valid_from: from,
      valid_to: Keyword.get(opts, :to),
      status: status,
      in_force_from: Keyword.get(opts, :in_force_from),
      changed_by: Keyword.get(opts, :changed_by, []),
      commenced_by: Keyword.get(opts, :commenced_by, []),
      territory: Keyword.get(opts, :territory, "E+W+S"),
      tiers: %{}
    }
  end

  test "each period becomes a timeline row for the stored section id" do
    [row] =
      LabelPeriods.periods(
        @law,
        @sid,
        [period(~D[1999-12-29], :in_force, in_force_from: ~D[1999-12-29])],
        []
      )

    assert row == %{
             law_name: @law,
             section_id: @sid,
             valid_from: ~D[1999-12-29],
             valid_to: nil,
             status: "in_force",
             in_force_from: ~D[1999-12-29],
             changed_by: nil,
             changed_by_all: [],
             commenced_by: [],
             territory: "E+W+S",
             change_ids: []
           }
  end

  test "changed_by keeps one law, the last the fold lists; every law and the commencer kept apart" do
    [row] =
      LabelPeriods.periods(
        @law,
        @sid,
        [
          period(~D[2006-10-01], :in_force,
            changed_by: ["UK_uksi_2006_438", "UK_uksi_2006_1000"],
            commenced_by: ["UK_uksi_2006_9"]
          )
        ],
        []
      )

    assert row.changed_by == "UK_uksi_2006_1000"
    assert row.changed_by_all == ["UK_uksi_2006_438", "UK_uksi_2006_1000"]
    assert row.commenced_by == ["UK_uksi_2006_9"]
  end

  test "changed_by, with no law making the text, is the law that commenced it" do
    [row] =
      LabelPeriods.periods(
        @law,
        @sid,
        [period(~D[2008-04-06], :in_force, commenced_by: ["UK_uksi_2008_401"])],
        []
      )

    assert {row.changed_by, row.changed_by_all} == {"UK_uksi_2008_401", []}
  end

  test "change_ids: the reaching changes dated on the period's first day" do
    reaching = [
      change("b", ~D[2006-10-01]),
      change("a", ~D[2006-10-01]),
      change("c", ~D[2001-01-01])
    ]

    [first, second] =
      LabelPeriods.periods(
        @law,
        @sid,
        [
          period(~D[2001-01-01], :in_force, to: ~D[2006-10-01]),
          period(~D[2006-10-01], :in_force)
        ],
        reaching
      )

    assert first.change_ids == ["c"]
    assert second.change_ids == ["a", "b"]
  end

  test "a repeal as the table records it: in force from its day, territory empty" do
    [repealed, saved, revived] =
      LabelPeriods.periods(
        @law,
        @sid,
        [
          period(~D[2001-01-01], :repealed, to: ~D[2002-01-01], territory: "nowhere"),
          period(~D[2002-01-01], :repealed_saved, to: ~D[2003-01-01], territory: "NI"),
          period(~D[2003-01-01], :in_force, territory: "nowhere")
        ],
        []
      )

    assert {repealed.in_force_from, repealed.territory} == {~D[2001-01-01], nil}
    assert {saved.in_force_from, saved.territory} == {~D[2002-01-01], nil}
    assert revived.territory == "nowhere"
  end

  test "no period from the placeholder start of a law with none" do
    rows =
      LabelPeriods.periods(
        @law,
        @sid,
        [
          period(LabelPeriods.undated_start(), :in_force, to: ~D[2020-12-31]),
          period(~D[2020-12-31], :in_force, in_force_from: ~D[2020-12-31])
        ],
        []
      )

    assert Enum.map(rows, & &1.valid_from) == [~D[2020-12-31]]
  end

  describe "violations/1: the table's rules" do
    defp row(sid, from, to, status \\ "in_force"),
      do: %{section_id: sid, valid_from: from, valid_to: to, status: status}

    test "consecutive periods, one open at the end, break nothing" do
      assert LabelPeriods.violations([
               row("a", ~D[2000-01-01], ~D[2001-01-01]),
               row("a", ~D[2001-01-01], nil),
               row("b", ~D[2000-01-01], nil)
             ]) == []
    end

    test "an overlap, an open period before another, an empty period, an unknown status" do
      assert LabelPeriods.violations([
               row("a", ~D[2000-01-01], ~D[2001-06-01]),
               row("a", ~D[2001-01-01], nil),
               row("b", ~D[2000-01-01], nil),
               row("b", ~D[2002-01-01], nil),
               row("c", ~D[2000-01-01], ~D[2000-01-01]),
               row("d", ~D[2000-01-01], nil, "unknown")
             ]) == [{"a", :overlap}, {"b", :overlap}, {"c", :empty}, {"d", :status}]
    end
  end
end

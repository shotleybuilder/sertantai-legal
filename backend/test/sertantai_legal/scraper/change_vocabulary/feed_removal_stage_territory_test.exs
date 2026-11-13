defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedRemovalStageTerritoryTest do
  @moduledoc """
  Each stage of a whole removal brought in by stages carries what its
  qualification names, as read: the territory it is for (`in_force_for`),
  the one it excepts (`in_force_except`) and its classes (`qualification`),
  as a commencement's stages do. What the territory means for a label is
  the label fold's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @id "key-" <> String.duplicate("b", 4)

  defp stage(date, qualification, order),
    do: %{date: date, qualification: qualification, prospective: false, commencing: order}

  defp effect(type, in_force),
    do: %Effect{
      effect_id: @id,
      type: type,
      affected_provisions: "Sch. 8 para. 8(5)",
      affected_refs: ["schedule-8-paragraph-8-5"],
      affecting: "UK_ukpga_2003_26",
      in_force: in_force,
      in_force_date: hd(in_force).date
    }

  # key → {operation, in_force_for, in_force_except, qualification}
  defp read(e) do
    for {key, _target, claims} <- Feed.read([e], "UK_ukpga_1995_25"), into: %{} do
      facts = Map.new(claims, &{&1.attribute, &1.value})

      {key,
       {facts[:operation], facts[:in_force_for], facts[:in_force_except], facts[:qualification]}}
    end
  end

  test "repealed for E. then for W.: each stage its territory (EA 1995 Sch. 8 para. 8(5))" do
    e =
      effect("repealed", [
        stage(~D[2003-11-18], "for E.", "UK_uksi_2003_2938"),
        stage(~D[2003-11-27], "for W.", "UK_wsi_2003_3034")
      ])

    assert read(e) == %{
             @id => {:repealed_in_part, "E", nil, "territory"},
             "#{@id}@2003-11-27" => {:repealed_in_part, "W", nil, "territory"}
           }
  end

  test "omitted except in relation to W. and for W. on one day: the excepted and the named territory" do
    e =
      effect("omitted", [
        stage(~D[2023-10-01], "except in relation to W.", "UK_uksi_2023_362"),
        stage(~D[2023-10-01], "for W.", "UK_wsi_2023_914")
      ])

    assert read(e) == %{
             @id => {:repealed_in_part, nil, "W", "territory + except"},
             "#{@id}@2023-10-01" => {:repealed_in_part, "W", nil, "territory"}
           }
  end

  # complete for W. only: a removal in part, never the whole removal
  # (Decision 3: `feed_territorial_completion_test`)
  test "the completing stage carries its territory too (for W. in so far as not already in force)" do
    e =
      effect("repealed", [
        stage(~D[2003-11-18], "for E.", "UK_uksi_2003_2938"),
        stage(~D[2005-01-01], "for W. in so far as not already in force", "UK_wsi_2004_3000")
      ])

    assert read(e) == %{
             @id => {:repealed_in_part, "E", nil, "territory"},
             "#{@id}@2005-01-01" => {:repealed_in_part, "W", nil, "complete + territory"}
           }
  end

  test "a stage naming no territory carries none (for specified purposes, then fully)" do
    e =
      effect("omitted", [
        stage(~D[2013-04-25], "for specified purposes", nil),
        stage(~D[2013-10-01], "in so far as not already in force", nil)
      ])

    assert read(e) == %{
             @id => {:repealed, nil, nil, "complete"},
             "#{@id}@2013-04-25" => {:repealed_in_part, nil, nil, "purposes"}
           }
  end

  test "one dated stage whose qualification is an Other text: its territory (EPA 1990 ss. 1-28 by SSI 2015/74)" do
    e =
      effect("repealed", [stage(~D[2015-04-01], "for S. for the repeal of ss. 1-19, 22-28", nil)])

    assert read(e) == %{@id => {:repealed_in_part, "S", nil, "territory + provisions"}}
  end
end

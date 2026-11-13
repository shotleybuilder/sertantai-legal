defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedTerritorialCompletionTest do
  @moduledoc """
  A completing stage that names a territory ("for W. in so far as not
  already in force") completes the change in that territory only: a
  partial stage, never the whole removal (Decision 3, Fire and OH&S: Feed
  reader; School Standards and Framework Act 1998 by the Education Act
  2002, 1975 c. 71 Sch. 9 by ERRA 2013).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @id "key-" <> String.duplicate("d", 4)

  defp entry(date, qualification, order),
    do: %{date: date, qualification: qualification, prospective: false, commencing: order}

  defp effect(type, refs, by, in_force),
    do: %Effect{
      effect_id: @id,
      type: type,
      affected_provisions: "s. 54",
      affected_refs: refs,
      affecting: by,
      in_force: in_force,
      in_force_date: hd(in_force).date
    }

  # key → {operation, date, partial, in_force_for, qualification}
  defp read(e, law) do
    for {key, _target, claims} <- Feed.read([e], law), into: %{} do
      f = Map.new(claims, &{&1.attribute, &1.value})
      {key, {f[:operation], f[:date], f[:partial], f[:in_force_for], f[:qualification]}}
    end
  end

  test "repealed for E. wholly, then for W.: no stage is the whole removal (1998 c. 31 s. 54)" do
    e =
      effect("repealed", ["section-54"], "UK_ukpga_2002_32", [
        entry(~D[2002-10-01], "for E. for specified purposes", "UK_uksi_2002_2439"),
        entry(~D[2003-09-01], "for E. In so far as not already in force", "UK_uksi_2003_1667"),
        entry(~D[2006-04-01], "for W.", "UK_wsi_2006_879")
      ])

    assert read(e, "UK_ukpga_1998_31") == %{
             @id => {:repealed_in_part, ~D[2002-10-01], true, "E", "territory + purposes"},
             "#{@id}@2003-09-01" =>
               {:repealed_in_part, ~D[2003-09-01], true, "E", "complete + territory"},
             "#{@id}@2006-04-01" => {:repealed_in_part, ~D[2006-04-01], true, "W", "territory"}
           }
  end

  test "a completing stage for E. for a purpose is partial (1975 c. 71 Sch. 9 by ERRA 2013)" do
    e =
      effect("repealed", ["schedule-9"], "UK_ukpga_2013_24", [
        entry(
          ~D[2013-06-25],
          "for the purpose of the repeal of Sch. 9 Pt. 1 and para. 6 of Pt. 2",
          "UK_uksi_2013_1455"
        ),
        entry(
          ~D[2013-10-01],
          "for E. for the purpose of the repeal of Sch. 9 Pt. 2 so far as not already in force",
          "UK_uksi_2013_1455"
        )
      ])

    assert read(e, "UK_ukpga_1975_71") == %{
             @id => {:repealed_in_part, ~D[2013-06-25], true, nil, "purposes"},
             "#{@id}@2013-10-01" =>
               {:repealed_in_part, ~D[2013-10-01], true, "E", "complete + territory + purposes"}
           }
  end

  test "a completing stage naming no territory is still the whole removal" do
    e =
      effect("repealed", ["section-54"], "UK_ukpga_2002_32", [
        entry(~D[2013-04-25], "for specified purposes", nil),
        entry(~D[2013-10-01], "in so far as not already in force", nil)
      ])

    assert read(e, "UK_ukpga_1998_31") == %{
             @id => {:repealed, ~D[2013-10-01], nil, nil, "complete"},
             "#{@id}@2013-04-25" => {:repealed_in_part, ~D[2013-04-25], true, nil, "purposes"}
           }
  end

  test "a commencement wholly for W.: partial, carried with what it says" do
    e =
      effect("coming into force", ["section-54"], "UK_ukpga_2002_32", [
        entry(~D[2004-01-01], "for E.", "UK_uksi_2003_1667"),
        entry(~D[2005-01-01], "for W. in so far as not already in force", "UK_wsi_2004_3000")
      ])

    assert read(e, "UK_ukpga_1998_31") == %{
             "#{@id}@2004-01-01" => {:commenced, ~D[2004-01-01], true, "E", "territory"},
             "#{@id}@2005-01-01" =>
               {:commenced, ~D[2005-01-01], true, "W", "complete + territory"}
           }
  end
end

defmodule SertantaiLegal.Scraper.AmendingLaw.LocatorTest do
  @moduledoc "A pointer's provision ref → the amending law's held element ids (LR-08; CV-06a)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator}

  defp doc(ids),
    do: %Doc{law_name: "UK_uksi_1976_2004", type: "uksi", elements: Map.new(ids, &{&1, nil})}

  test "a numbered Schedule and its paragraph" do
    d = doc(["schedule-3", "schedule-3-paragraph-2"])
    assert Locator.ids(d, {:schedule, "3", nil, nil, []}) == ["schedule-3"]
    assert Locator.ids(d, {:schedule, "3", nil, "2", []}) == ["schedule-3-paragraph-2"]
  end

  # SI 2010/675 Sch.26: each Part numbers its paragraphs from 1, and the ids
  # carry the Part (amending Schedules, 2026-11-27)
  test "a Schedule numbered by Part: \"Sch. 26 Pt. 2 para. 10(2)\" is schedule-26-part-2-paragraph-10-2" do
    d =
      doc([
        "schedule-26-part-1-paragraph-10",
        "schedule-26-part-2-paragraph-10",
        "schedule-26-part-2-paragraph-10-2"
      ])

    assert Locator.ids(d, {:schedule, "26", "2", "10", ["2"]}) == [
             "schedule-26-part-2-paragraph-10-2"
           ]

    assert Locator.ids(d, {:schedule, "26", "2", "10", []}) == ["schedule-26-part-2-paragraph-10"]
  end

  # SI 2016/1154 Sch.29: `id="schedule-29-part-1-paragraph-3"
  # shortId="schedule-29-paragraph-3"`; a pointer without the Part (a
  # note's "Sch. 29 para. 3(b)") finds it by the shortId
  test "a Part-less pointer to a Part-numbered paragraph: by its shortId" do
    d = %{
      doc(["schedule-29-part-1-paragraph-3", "schedule-29-part-1-paragraph-3-b"])
      | short: %{"schedule-29-paragraph-3" => "schedule-29-part-1-paragraph-3"}
    }

    assert Locator.ids(d, {:schedule, "29", nil, "3", ["b"]}) == [
             "schedule-29-part-1-paragraph-3-b"
           ]
  end

  test "a Doc holds each shortId's id" do
    xml =
      ~S|<Legislation><Primary><Schedules><Schedule id="schedule-29"><ScheduleBody><Part id="schedule-29-part-1"><P1 id="schedule-29-part-1-paragraph-3" shortId="schedule-29-paragraph-3"><P1para><Text>x</Text></P1para></P1></Part></ScheduleBody></Schedule></Schedules></Primary></Legislation>|

    assert Doc.new("UK_uksi_2016_1154", [xml]).short == %{
             "schedule-29-paragraph-3" => "schedule-29-part-1-paragraph-3"
           }
  end

  # SI 2016/1154 Sch.29 Pt.1 para.2: the paragraph's id carries the Part,
  # its sub-paragraphs' do not (`schedule-29-paragraph-2-2`)
  test "a Part paragraph whose sub-paragraphs carry no Part: the sub-paragraph, never the paragraph" do
    d = doc(["schedule-29-part-1-paragraph-2", "schedule-29-paragraph-2-2"])

    assert Locator.ids(d, {:schedule, "29", "1", "2", ["2"]}) == ["schedule-29-paragraph-2-2"]
  end

  test "a Part named over paragraphs numbered through the Schedule: the Part-less id (\"Sch. 6 Pt. II para. 33\")" do
    d = doc(["schedule-6-part-II", "schedule-6-paragraph-33"])
    assert Locator.ids(d, {:schedule, "6", "II", "33", []}) == ["schedule-6-paragraph-33"]
  end

  test "a law's only Schedule, unnumbered (\"S.I. 1976/2004, Sch.\")" do
    d = doc(["schedule", "schedule-paragraph-8"])
    assert Locator.ids(d, {:schedule, nil, nil, nil, []}) == ["schedule"]
    assert Locator.ids(d, {:schedule, nil, nil, "8", []}) == ["schedule-paragraph-8"]
    assert Locator.ids(doc(["schedule-1"]), {:schedule, nil, nil, nil, []}) == []
  end
end

defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.OwnParagraphTest do
  @moduledoc """
  A Schedule paragraph's own extent: the forms CV-S05f adds, on SOCPA 2005
  Sch.7's wording (paras 47, 49, 54, 56), beside round 11's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.OwnParagraph
  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp p2s(id, subs),
    do:
      ~s(<P1 id="#{id}">) <>
        Enum.map_join(subs, fn {n, text} ->
          ~s(<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{text}</Text></P2para></P2>)
        end) <> "</P1>"

  test "round 11's forms stay" do
    assert OwnParagraph.list(
             "This paragraph does not extend to Northern Ireland.",
             "sch.8.para.27"
           ) ==
             {:not, "NI", ["sch.8.para.27"]}

    assert OwnParagraph.list("This paragraph extends only to England and Wales.", "sch.8.para.2") ==
             {:only, "E+W", ["sch.8.para.2"]}
  end

  test "the whole of the United Kingdom (para 47(5))" do
    assert OwnParagraph.list(
             "This paragraph extends to the whole of the United Kingdom.",
             "sch.7.para.47"
           ) ==
             {:named, "E+W+S+NI", ["sch.7.para.47"]}
  end

  test "places with a bracket saying the same (para 49(4))" do
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to Northern Ireland (but not to Scotland).",
             "sch.7.para.49"
           ) == {:named, "E+W+NI", ["sch.7.para.49"]}

    # (a bracket contradicting the places: never read)
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to Scotland (but not to Scotland).",
             "sch.7.para.49"
           ) == nil
  end

  test "also (para 56)" do
    assert OwnParagraph.list("This paragraph extends also to Scotland.", "sch.7.para.56") ==
             {:also, "S", ["sch.7.para.56"]}
  end

  test "the same extent as the Act it amends (para 54)" do
    assert OwnParagraph.list("This paragraph has the same extent as that Act.", "sch.7.para.54") ==
             {:same, nil, ["sch.7.para.54"]}

    assert OwnParagraph.list(
             "This paragraph has the same extent as the provision amended.",
             "sch.7.para.54"
           ) == {:same, nil, ["sch.7.para.54"]}
  end

  test "never more after its places" do
    assert OwnParagraph.list(
             "This paragraph extends to England and Wales and to the territorial waters adjacent to England and Wales.",
             "sch.7.para.1"
           ) == nil
  end

  describe "a Schedule paragraph's own extent, read whole" do
    defp sch_para(sch, para, text),
      do:
        ~s(<Schedule id="schedule-#{sch}"><Pnumber>#{sch}</Pnumber><ScheduleBody>) <>
          ~s(<P1 id="schedule-#{sch}-paragraph-#{para}"><Pnumber>#{para}</Pnumber><P1para><Text>#{text}</Text></P1para></P1>) <>
          "</ScheduleBody></Schedule>"

    test "\"This paragraph does not extend to Northern Ireland\", \"… extends only to England and Wales\" (ukpga 2003/39 Sch.8)" do
      e =
        read(
          "UK_ukpga_2003_39",
          p1("section-1", "This Act extends to England and Wales, Scotland and Northern Ireland.") <>
            sch_para(8, 27, "This paragraph does not extend to Northern Ireland.") <>
            sch_para(9, 13, "This paragraph extends only to England and Wales.")
        )

      assert {:not, "NI", ["sch.8.para.27"]} in e.lists
      assert {:only, "E+W", ["sch.9.para.13"]} in e.lists
      assert Extent.of(e, "sch.8.para.27") == "E+W+S"
    end

    test "never with more after the places (ukpga 2006/16 Sch.11 para 97)" do
      e =
        read(
          "UK_ukpga_2006_16",
          sch_para(
            11,
            97,
            "This paragraph extends only to England and Wales and to the territorial waters adjacent to England and Wales."
          )
        )

      refute Enum.any?(e.lists, &match?({_, _, ["sch.11.para.97"]}, &1))
    end
  end

  test "\"Sub-paragraph (1) does not extend to Northern Ireland\" in a Schedule paragraph (ukpga 2003/39 Sch.8 para 70)" do
    e =
      read(
        "UK_ukpga_2003_39",
        ~s(<Schedule id="schedule-8">#{p2s("schedule-8-paragraph-70", [{"1", "Words."}, {"2", "Sub-paragraph (1) does not extend to Northern Ireland."}])}</Schedule>)
      )

    assert {"NI", ["sch.8.para.70(1)"]} in rows(e, :not)
  end
end

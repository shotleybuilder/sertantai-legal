defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.UnreadTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lookup, Unread}

  # a law of sections 1–9 and Schedules 1–3 (paragraphs 1–3 each), with
  # the sentence under test as `id`'s own words
  defp doc(id, text) do
    sections =
      for n <- 1..9, "section-#{n}" != id, into: "", do: ExtentDoc.p1("section-#{n}", "Words.")

    schedules =
      for s <- 1..3, into: "" do
        paras =
          for p <- 1..3, into: "" do
            pid = "schedule-#{s}-paragraph-#{p}"

            ~s(<P1 id="#{pid}"><P1para><Text>#{if pid == id, do: text, else: "Words."}</Text></P1para></P1>)
          end

        ~s(<Schedule id="schedule-#{s}"><ScheduleBody>#{paras}</ScheduleBody></Schedule>)
      end

    own = if String.starts_with?(id, "section-"), do: ExtentDoc.p1(id, text), else: ""

    Doc.new("UK_ukpga_2000_1", [
      "<Legislation><Primary><Body>#{own}#{sections}</Body>#{schedules}</Primary></Legislation>"
    ])
  end

  defp subject(id, ref, text), do: Unread.subject(text, ref, doc(id, text))

  test "named provisions: subsections, sections, Schedules, this section" do
    assert subject(
             "section-5",
             "s.5",
             "Subsections (5) to (7) above shall not extend to Scotland."
           ) ==
             ["s.5(5)", "s.5(6)", "s.5(7)"]

    assert subject(
             "section-8",
             "s.8",
             "Section 1(2) and Schedule 1 extend to Northern Ireland so far as they amend— (a) the House of Commons Disqualification Act 1975, (b) the Judicial Pensions Act 1981."
           ) == ["s.1(2)", "sch.1"]

    assert subject(
             "section-8",
             "s.8",
             "This section, section 3 and section 4 so far as relating to regulations under section 3 extend also to Scotland."
           ) == ["s.8", "s.3", "s.4"]
  end

  test "a following list's items, never a repeals table's rows" do
    assert subject(
             "section-8",
             "s.8",
             "The following provisions extend to England and Wales and Northern Ireland (but not to Scotland)— (a) section 2, so far as relating to paragraph 2 of Schedule 1; (b) sections 3 and 4."
           ) == ["s.2", "sch.1.para.2", "s.3", "s.4"]

    assert subject(
             "schedule-3-paragraph-2",
             "sch.3.para.2",
             "The repeal of section 4 of the Law of Libel Amendment Act 1888 do not extend to Northern Ireland. Short title and chapter Extent of repeal— (a) Schedule 2, paragraph 1."
           ) == ["sch.3.para.2"]
  end

  test "\"In Schedule N— (a) paragraph …\": that Schedule's paragraphs" do
    assert subject(
             "section-8",
             "s.8",
             "In Schedule 2— (a) the amendments made by paragraphs 1 and 3 extend to Scotland only; and (b) the amendments made by paragraph 2 extend to England and Wales only."
           ) == ["sch.2.para.1", "sch.2.para.3", "sch.2.para.2"]

    # never the lead-in's number run on into a paragraph's (SI 2019/758:
    # "In Schedule 11— (a) paragraph 2" had read as Schedules 11 and 2)
    assert subject(
             "section-8",
             "s.8",
             "In Schedule 3— (a) paragraph 2 extends to England and Wales and Scotland; (b) paragraph 1 extends to Northern Ireland."
           ) == ["sch.3.para.2", "sch.3.para.1"]
  end

  test "a Schedule paragraph's own statement: the paragraph; \"this Part of this Schedule\": the Schedule" do
    assert subject(
             "schedule-2-paragraph-3",
             "sch.2.para.3",
             "The repeal of section 4(8) extends also to Scotland."
           ) ==
             ["sch.2.para.3"]

    assert subject(
             "schedule-2-paragraph-3",
             "sch.2.para.3",
             "This paragraph extends only to England and Wales."
           ) ==
             ["sch.2.para.3"]

    assert subject(
             "schedule-2-paragraph-3",
             "sch.2.para.3",
             "This Part of this Schedule shall extend to Scotland only."
           ) ==
             ["sch.2"]
  end

  test "the law or its amendments: every provision no list names" do
    for text <- [
          "To the extent that these Regulations concern the importation of pyrotechnics into the United Kingdom, they shall extend to Northern Ireland.",
          "Subject to subsection (4), any provision of this Act which amends or repeals an enactment has the same extent as the enactment amended or repealed.",
          "Apart from the amendments made by sections 1 and 4, the amendments made by this Act have the same extent as the enactments amended.",
          # an item's pronoun is the lead-in's subject (ukpga 2007/27 s.93)
          "Any amendment or repeal by this Act has the same extent as the enactment amended, except that— (a) it does not extend to Scotland."
        ] do
      assert subject("section-8", "s.8", text) == ["*"], text
    end
  end

  test "none of the law's own: another law's, a mention, an idiom" do
    assert subject(
             "section-8",
             "s.8",
             "Any provision of section 3 has the same extent as the enactment amended by it, except that— (a) it does not extend to Scotland; and (b) paragraph 2 of Schedule 1 does not extend to Northern Ireland."
           ) == ["s.3", "sch.1.para.2"]

    for text <- [
          "The amendments made to the Marine and Coastal Access Act 2009 by sections 77 to 80 of the Environment (Wales) Act 2016 (anaw 3) extend to Scotland and Northern Ireland (as well as England and Wales).",
          "In the application of section 3 to Acts passed after the commencement of this Act which extend to Northern Ireland, “statutory instrument” includes statutory rule.",
          "A copy of a document shall be admissible in any legal proceedings to the same extent as the document itself.",
          "In this section “legislation” means— (a) an Act of Parliament if, or to the extent that, it extends to England and Wales."
        ] do
      assert subject("section-8", "s.8", text) == [], text
    end
  end

  test "words the law inserts elsewhere state nothing" do
    text = "Section 6B and this section extend to England and Wales and Northern Ireland."

    xml =
      ~s|<P1 id="section-8"><P1para><Text>For subsection (5) there shall be substituted—</Text><BlockAmendment><P2><P2para><Text>#{text}</Text></P2para></P2></BlockAmendment></P1para></P1>|

    doc =
      Doc.new("UK_ukpga_2000_1", [
        "<Legislation><Primary><Body>#{xml}</Body></Primary></Legislation>"
      ])

    assert Unread.subject(text, "s.8", doc) == []
  end

  test "lists: one per statement of the unread classes, none for a statement read" do
    d = doc("section-5", "Subsections (5) to (7) above shall not extend to Scotland.")

    classes = [
      {"s.5", "Subsections (5) to (7) above shall not extend to Scotland.", "unread:not_read"},
      {"s.5", "Subsections (5) to (7) above shall not extend to Scotland.", "part_not:S"},
      {"s.5", "Subsections (5) to (7) above shall not extend to Scotland.", "unread:application"}
    ]

    assert Unread.lists(classes, d) == [{:unread, nil, ["s.5(5)", "s.5(6)", "s.5(7)"]}]
  end

  test "an unread statement withholds the default from its provisions, and only theirs" do
    e = %Extent{default: "E+W+S", lists: [{:unread, nil, ["s.5(5)"]}]}
    assert Lookup.of(e, "s.5(5)") == nil
    assert Lookup.of(e, "s.6") == "E+W+S"

    # every amendment: unread before the same extent ("*" both)
    e = %Extent{default: "E+W", lists: [{:same, nil, ["*"]}, {:unread, nil, ["*"]}]}
    assert Lookup.of(e, "s.6") == nil

    # a statement read for the provision outranks the one unread
    e = %Extent{
      default: "E+W",
      lists: [{:unread, nil, ["sch.2"]}, {:only, "S", ["sch.2.para.1"]}]
    }

    assert Lookup.of(e, "sch.2.para.1") == "S"
    assert Lookup.of(e, "sch.2.para.2") == nil

    # stating none but an unread statement: its powers don't decide either
    e = %Extent{lists: [{:unread, nil, ["*"]}], powers: "E+W+S"}
    assert Lookup.of(e, "reg.4") == nil
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupListEndTest do
  @moduledoc """
  Where a note's list of amending pieces ends (Waste, Water and Climate:
  Markup reader, `unmarked-note-lists-with-piece` and
  `note-words-run-into-other-law`): the pieces after the amending Citation,
  up to the first words that open another reference — "(with …)",
  "(subject to …)", "(as inserted by …)", another Citation — whether the
  pieces are marked up with no Operative mark or read from the note's
  words.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.ListEnd

  defp cite(id, path, text),
    do: ~s|<Citation id="#{id}" URI="http://www.legislation.gov.uk/id/#{path}">#{text}</Citation>|

  defp sub(citation, section_ref, text, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="#{citation}" SectionRef="#{section_ref}"#{mark}>#{text}</CitationSubRef>|
  end

  defp affecting(text) do
    """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para><Text>Some <Addition ChangeId="d30p100" CommentaryRef="c1">words</Addition></Text></P1para></P1>
    </Body><Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>
    </Legislation>
    """
    |> Markup.read("UK_ukpga_1990_43")
    |> Enum.flat_map(fn {_, _, claims} ->
      for c <- claims, c.attribute == :affecting, do: c.value
    end)
  end

  describe "marked-up pieces with no Operative mark" do
    # the Capital Allowances Act 2001 s.220(A1)(b)
    test "(with Sch. 2): the savings piece is not an amending one" do
      text =
        "Words in s. 220(A1)(b) substituted (1.4.2010) (with effect in accordance with " <>
          "s. 1184(1) of the amending Act) by " <>
          cite("x1", "ukpga/2010/4", "Corporation Tax Act 2010 (c. 4)") <>
          ", " <>
          sub("x1", "section-1184-1", "s. 1184(1)") <>
          ", " <>
          sub("x1", "schedule-1-paragraph-344-2-b-ii", "Sch. 1 para. 344(2)(b)(ii)") <>
          " (with " <> sub("x1", "schedule-2", "Sch. 2") <> ")"

      assert affecting(text) == [["s.1184(1)", "sch.1.para.344(2)(b)(ii)"]]
    end

    # the Planning (Hazardous Substances) Act 1990 s.31(3): a copied note
    # (`CopiedNotePieces`), its "(with s. 111)" piece listed with the rest
    test "(with s. 111) in a copied note" do
      text =
        "Words in s. 31(3) substituted (6.8.2004 for specified purposes) by " <>
          cite("d31e4n1", "ukpga/2004/5", "Planning and Compulsory Purchase Act 2004 (c. 5)") <>
          ", " <>
          sub("d31e4", "schedule-3-paragraph-8-2", "Sch. 3 para. 8(3)") <>
          " (with " <>
          sub("d31e4", "section-111", "s. 111") <>
          "); " <>
          cite("d31e16n1", "uksi/2004/2097", "S.I. 2004/2097") <>
          ", " <> sub("d31e16", "article-2", "art. 2", true)

      assert affecting(text) == [["sch.3.para.8(3)"]]
    end

    # the Electricity (Northern Ireland) Order 1992 art.3
    test "(subject to Sch. 4), and (with savings in …)" do
      text =
        "Definitions substituted (3.7.2007) by " <>
          cite("x1", "nisi/2003/419", "Energy (Northern Ireland) Order 2003") <>
          " (S.I. 2003/419 (N.I. 6)), " <>
          sub("x1", "article-65", "arts. 65") <>
          ", " <>
          sub("x1", "schedule-3-paragraph-1-1", "Sch. 3 para. 1(1)") <>
          " (subject to " <> sub("x1", "schedule-4", "Sch. 4") <> ")"

      assert affecting(text) == [["reg.65", "sch.3.para.1(1)"]]

      savings =
        "S. 58A(2)(b) substituted (30.12.2005) by " <>
          cite("x1", "ukpga/2002/38", "2002 c. 38") <>
          ", " <>
          sub("x1", "section-139", "ss. 139") <>
          ", " <>
          sub("x1", "schedule-3-paragraph-80", "Sch. 3 para. 80") <>
          " (with savings in " <> sub("x1", "schedule-4-paragraph-6", "Sch. 4 paras. 6-8") <> ")"

      assert affecting(savings) == [["s.139", "sch.3.para.80"]]
    end

    # SI 2019/270 reg.1: legislation.gov.uk links the law's own "see reg.
    # 1(2)" to the Act the bracket cites
    test "the list ends at any other words: \"), see reg. 1(2)\"" do
      text =
        "Reg. 1 in force at 31.12.2020 on IP completion day (in accordance with " <>
          cite("x1", "ukpga/2020/1", "2020 c. 1") <>
          ", " <>
          sub("x1", "schedule-5-paragraph-1-1", "Sch. 5 para. 1(1)") <>
          "), see " <> sub("x1", "regulation-1-2", "reg. 1(2)")

      assert affecting(text) == [["sch.5.para.1(1)"]]
    end

    test "nothing but a (with …) piece: no amending piece is named" do
      text =
        "Words inserted by " <>
          cite("x1", "uksi/2000/123", "S.I. 2000/123") <>
          " (with " <> sub("x1", "regulation-7", "reg. 7") <> ")"

      assert affecting(text) == []
    end

    test "a list with no other words is read whole, joined by commas, \"and\" or nothing" do
      text =
        "Words inserted by " <>
          cite("x1", "ukpga/2004/5", "2004 c. 5") <>
          ", " <>
          sub("x1", "section-118", "ss. 118") <>
          ", " <>
          sub("x1", "section-120", "120") <>
          sub("x1", "schedule-6-paragraph-3", "Sch. 6 para. 3") <>
          " and " <>
          sub("x1", "schedule-9", "Sch. 9") <>
          "; " <>
          cite("x2", "uksi/2004/2097", "S.I. 2004/2097") <>
          ", " <> sub("x2", "article-2", "art. 2")

      assert affecting(text) == [["s.118", "s.120", "sch.6.para.3", "sch.9"]]
    end

    # the Police and Criminal Evidence Act 1984 s.63(6)
    test "a piece written in words beside the marked-up ones does not end the list" do
      text =
        "S. 63(6)(7) substituted (7.3.2011) by " <>
          cite("x1", "ukpga/2010/17", "Crime and Security Act 2010 (c. 17)") <>
          ", ss. 4(7), " <>
          sub("x1", "section-59-1", "59(1)") <>
          "; " <>
          cite("x2", "uksi/2011/414", "S.I. 2011/414") <>
          ", " <> sub("x2", "article-2-b", "art. 2(b)")

      assert affecting(text) == [["s.59(1)"]]
    end

    # the Social Security Contributions and Benefits Act 1992 s.39C(1A): a
    # half-copied note, one piece under the id before the copy (its joined
    # SectionRef two provisions: `JoinedSectionRef`)
    test "a piece marked up under another Citation's id does not end the list" do
      text =
        "S. 39C(1A)(2) substituted for s. 39C(2) by " <>
          cite("d9e4n", "ukpga/2007/22", "Pensions Act 2007 (c. 22)") <>
          ", " <>
          sub("d9e4", "section-6-6-a", "ss. 6(6)(a)", true) <>
          ", " <>
          sub("d9e4n", "section-30-1-a-3", "30(1)(a)(3)") <>
          " (with " <> sub("d9e4n", "section-6-7", "6(7)") <> ")"

      assert affecting(text) == [["s.30(1)(a)", "s.30(3)"]]
    end

    test "a piece written before the Citation is kept (\"s. 106(6) of that Act\")" do
      text =
        "Section 338(3) has been amended by " <>
          sub("x1", "section-106-6", "s. 106(6)") <>
          " of the " <>
          cite("x1", "ukpga/2005/15", "Serious Organised Crime and Police Act 2005 (c. 15)") <>
          ", and " <> cite("x2", "uksi/2007/3398", "S.I. 2007/3398")

      assert affecting(text) == [["s.106(6)"]]
    end

    # the marks are legislation.gov.uk's: read as given, as before
    test "an Operative mark is read as given, the list's end or no" do
      text =
        "Words substituted by virtue of " <>
          cite("x1", "ukpga/1995/36", "1995 c. 36") <>
          ", " <>
          sub("x1", "section-105-4", "s. 105(4)") <>
          ", " <>
          sub("x1", "schedule-4-paragraph-8", "Sch. 4 para. 8", true) <>
          " (with " <> sub("x1", "section-103-1", "s. 103(1)") <> ")"

      assert affecting(text) == [["sch.4.para.8"]]
    end
  end

  describe "pieces read from the note's words" do
    # the Clean Air Act 1956 s.16A (c710440): the commencement order's
    # article is marked up under its own Citation
    test "another Citation ends the list: \"s. 162(1), Sch. 15 para.6, S.I. 1991/1042, art.2\"" do
      text =
        "S. 16A inserted (1.4.1991) by " <>
          cite("x1", "ukpga/1990/43", "Environmental Protection Act 1990 (c. 43, SIF 46:4)") <>
          " s. 162(1), Sch. 15 para.6, " <>
          cite("x2", "uksi/1991/1042", "S.I. 1991/1042") <>
          ", " <> sub("x2", "article-2", "art.2", true)

      assert affecting(text) == [["s.162(1)", "sch.15.para.6"]]
    end

    # the Mines and Quarries Act 1954 s.182(1) (c651264): the articles are
    # the later instruments', which the note cites in words only
    test "another instrument's number ends the list: \"(1957 I, p. 1439), 1969/1498, arts. 2(1), 5(6)\"" do
      text =
        "Words substituted by virtue of " <>
          cite("x1", "uksi/1957/48", "S.I. 1957/48") <>
          " (1957 I, p. 1439), 1969/1498, arts. 2(1), 5(6), and 1970/1537, arts. 2(2), 7(4)"

      assert affecting(text) == []
    end

    test "the instrument's own number bracket is no end: \"S.I. 1994/426 (N.I. 1) arts. 1(2), 71(4), Sch. 10 (with art. 16)\"" do
      text =
        "S. 60(5) repealed (24.4.1994) by " <>
          cite("x1", "nisi/1994/426", "S.I. 1994/426") <>
          " (N.I. 1) arts. 1(2), 71(4), Sch. 10 (with art. 16)"

      assert affecting(text) == [["reg.1(2)", "reg.71(4)", "sch.10"]]
    end

    # the Human Medicines Regulations 2012 reg.61(13)
    test "the instrument cited again in brackets as its number is no other Citation" do
      text =
        "Words in reg. 61(13) inserted (31.12.2020) by " <>
          cite(
            "x1",
            "uksi/2019/775",
            "The Human Medicines (Amendment etc.) (EU Exit) Regulations 2019 (S.I. 2019/775)"
          ) <>
          " (" <>
          cite("x2", "uksi/2019/775", "S.I. 2019/775") <>
          "), reg. 68(5) (as amended by " <>
          cite("x3", "uksi/2020/1488", "S.I. 2020/1488") <>
          ", " <> sub("x3", "regulation-1", "reg. 1") <> ")"

      assert affecting(text) == [["reg.68(5)"]]
    end

    # the Bankruptcy and Diligence etc. (Scotland) Act 2007 s.152(2)
    test "{art. 2(c)} (with transitional modifications in art. 4)" do
      text =
        "S. 152(2) inserted (22.4.2009) by The Bankruptcy and Diligence etc. (Scotland) Act " <>
          "2007 (Inhibition) Order (" <>
          cite("x1", "ssi/2009/219", "S.S.I. 2009/219") <>
          "), {art. 2(c)} (with transitional modifications in art. 4)"

      assert affecting(text) == [["reg.2(c)"]]
    end

    # the Taxes Management Act 1970 Pt. 6
    # the provision applied was inserted by the 2020 Regulations: the
    # change is theirs (`NoteCitation`), their list ending where the
    # bracket closes
    test "(as inserted by …): the inserting instrument's pieces, to the bracket's close" do
      text =
        "Pt. 6 applied (with modifications) (6.4.2021) by " <>
          cite("x1", "uksi/2003/2682", "S.I. 2003/2682") <>
          " reg. 97LH (as inserted by " <>
          cite(
            "x2",
            "uksi/2020/1150",
            "The Income Tax (Pay As You Earn) (Amendment No. 3) Regulations 2020"
          ) <>
          " (S.I. 2020/1150), regs. 1, 3)"

      assert affecting(text) == [["reg.1", "reg.3"]]
    end

    # the Road Traffic Regulation Act 1967 s.76(2); the National Health
    # Service Act 1977 s.126(4)
    test ~s|legislation.gov.uk's slips are still the list: "ss. 4. 6(2) Sch. 2", "{ss. 6(3)(c}, 42(3)"| do
      stop =
        "Words in s. 76(2) substituted (27.5.1997) by " <>
          cite("x1", "ukpga/1997/11", "1997 c. 11") <> " ss. 4. 6(2) Sch. 2 para. 15(4)(b)"

      assert affecting(stop) == [["s.4", "sch.2.para.15(4)(b)"]]

      brace =
        "Words in s. 126(4) substituted (10.10.2002 for W.) by " <>
          cite("x1", "ukpga/2002/17", "2002 c. 17") <>
          ", {ss. 6(3)(c}, 42(3); " <> cite("x2", "uksi/2002/2532", "S.I. 2002/2532")

      assert affecting(brace) == [["s.6(3)", "s.42(3)"]]
    end

    # the Employment Rights Act 1996 s.235(1)
    test "an empty Citation: the law's name and its list are read from the words after it" do
      text =
        "Words in s. 235(1) substituted (8.12.2002) by " <>
          cite("x1", "ukpga/2002/22", "") <>
          "Employment Act 2002 (c. 22), s. 55(2), 53, Sch. 7 para. 48(3); " <>
          cite(
            "x2",
            "uksi/2002/2866",
            "The Employment Act 2002 (Commencement No. 3) Order 2002 (S.I. 2002/2866)"
          ) <>
          ", " <> sub("x2", "article-2-2", "art. 2(2)")

      assert affecting(text) == [["s.55(2)", "s.53", "sch.7.para.48(3)"]]
    end

    test "a list marked up inside the Citation itself is read" do
      text =
        "Words substituted by " <>
          cite("x1", "ukpga/2002/22", "Employment Act 2002 (c. 22), s. 55(2), Sch. 7 para. 48(3)") <>
          " (with s. 53)"

      assert affecting(text) == [["s.55(2)", "sch.7.para.48(3)"]]
    end

    test "a sentence's stop ends the list: \"Sch.8 para.18. Development Land Tax Act 1976 repealed by …\"" do
      text =
        "S. 86A added by " <>
          cite("x1", "ukpga/1976/24", "Development Land Tax Act 1976 (c. 24)") <>
          " Sch.8 para.21. S. 86A repealed by Finance Act 1985, s.98(6), Sch.27 Part X."

      assert affecting(text) == [["sch.8.para.21"]]
    end

    test "a list with no other words is read whole, to the \";\"" do
      text =
        "Words substituted (25.7.2003) by " <>
          cite("x1", "ukpga/2003/21", "Communications Act 2003 (c. 21)") <>
          " , ss. 406, 411(2)(3), {Sch. 17 para. 127(2)}; " <>
          cite("x2", "uksi/2003/1900", "S.I. 2003/1900") <> ", art. 2(1)"

      assert affecting(text) == [["s.406", "s.411(2)", "s.411(3)", "sch.17.para.127(2)"]]
    end
  end

  describe "ListEnd.words/2" do
    test "the words after the Citation, up to the list's end" do
      {doc, _} =
        ("<Commentary id=\"c1\"><Para><Text>S. 5 repealed by " <>
           cite("x1", "ukpga/1999/23", "1999 c. 23") <>
           ", s. 67, Sch. 6 (with Sch. 7 paras. 3(3), 5(2)); S.I. 2002/1739, art. 2(g)" <>
           "</Text></Para></Commentary>")
        |> String.to_charlist()
        |> :xmerl_scan.string()

      assert ListEnd.words(doc, "x1") == {"1999 c. 23", "s. 67, Sch. 6 "}
      assert ListEnd.words(doc, "x9") == nil
    end
  end
end

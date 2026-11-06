defmodule SertantaiLegal.Scraper.Amendment.Reader.InstructionPlacesTest do
  @moduledoc """
  Where an instruction's change lands: a Schedule's paragraph never the
  law's regulation of that number, the law a holding provision names, a
  subsection set out elsewhere, one law among many listed, each as the
  real words the reader once misread.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}

  @regs Reader.law_ref("UK_nisr_1997_193", "The Lifts Regulations (Northern Ireland)", "reg")
  @clean_air Reader.law_ref("UK_ukpga_1993_11", "Clean Air Act", "s")

  defp doc(body, law \\ "UK_nisr_2015_265"),
    do: Doc.new(law, [~s|<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>|])

  defp p1(id, text), do: ~s|<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>|

  defp read(d, id, law, terms \\ %{}), do: Reader.instruction(d, id, terms, [law])

  describe "a Schedule's paragraph is never the law's regulation of that number" do
    test "the instruction's own words place it in a Schedule (NISR 2015/265 reg.5(2))" do
      d =
        doc(
          p1(
            "regulation-5",
            "The Lifts Regulations (Northern Ireland) 1997 are amended as follows."
          ) <>
            ~s|<P1 id="regulation-5-2"><P1para><Text>In Schedule 2, for paragraph 10 substitute—</Text><BlockAmendment><P1><Pnumber>10</Pnumber><P1para><Text>new</Text></P1para></P1></BlockAmendment></P1para></P1>|
        )

      assert read(d, "regulation-5-2", @regs) == []
    end

    test "\"Omit Schedule 5.\" (NISR 2020/330 reg.9(6))" do
      d =
        doc(
          p1("regulation-9", "In the Lifts Regulations (Northern Ireland) 1997, omit Schedule 5.")
        )

      assert read(d, "regulation-9", @regs) == []
    end

    test "a holding provision with a non-breaking space, and a law's title once \"(Northern Ireland)\" goes (NISR 2005/45)" do
      d =
        doc(
          ~s|<P1 id="regulation-5"><P1para><Text>In the Lifts Regulations (Northern Ireland) 1997 –</Text><P2 id="regulation-5-c"><P2para><Text>in Schedule 1 –</Text><P3 id="regulation-5-c-i"><P3para><Text>in paragraph 1(1) the following definition shall be inserted –</Text><BlockAmendment><P3><P3para><Text>“x” means y;</Text></P3para></P3></BlockAmendment></P3para></P3></P2para></P2></P1para></P1>|
        )

      assert read(d, "regulation-5-c-i", @regs) == []
    end

    test "the amending law's own Schedule is not a place in the amended law (2021/30 Sch.12 para 14(5))" do
      d =
        doc(
          ~s|<P1 id="section-14"><P1para><Text>Section 20 of the Clean Air Act 1993 is amended as follows.</Text><P2 id="section-14-5"><P2para><Text>If at the time of the coming into force of this paragraph Part 2 of this Schedule is not in force, in subsection (6)—</Text><P3 id="section-14-5-a"><P3para><Text>omit “Except as provided by subsection (5ZA),”;</Text></P3para></P3></P2para></P2></P1para></P1>|,
          "UK_ukpga_2021_30"
        )

      assert [%Rule{operation: :repealed, level: :words}] = read(d, "section-14-5-a", @clean_air)
    end

    test "a section named beside a Schedule is still read (asp 2003/8 Sch.6 para 9)" do
      hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

      d =
        doc(
          p1(
            "section-9",
            "In the Health and Safety at Work etc. Act 1974, section 75 and Schedule 7 are repealed."
          ),
          "UK_asp_2003_8"
        )

      assert [%Rule{targets: ["s.75"], operation: :repealed}] = read(d, "section-9", hswa)
    end
  end

  test "a holding provision's caption doesn't hide \"Schedule 2 … is amended\" (2013 c.32 Sch.12 para 15(13))" do
    hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

    d =
      doc(
        ~s|<P1 id="schedule-12-paragraph-15"><P1para><Text>Schedule 2 (constitution etc. of the Health and Safety Executive) to the Health and Safety at Work etc. Act 1974 is amended as follows.</Text><P2 id="schedule-12-paragraph-15-13"><P2para><Text>After that sub-paragraph insert—</Text><BlockAmendment><P3><Pnumber>4</Pnumber><P3para><Text>new</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|,
        "UK_ukpga_2013_32"
      )

    assert read(d, "schedule-12-paragraph-15-13", hswa) == []
  end

  test "the subsection \"set out in sub-paragraph (2)\" is the one inserted (2005 c.14 Sch.3 para 3)" do
    hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

    d =
      doc(
        ~s|<P1 id="schedule-3-paragraph-3"><P1para><P2 id="schedule-3-paragraph-3-1"><P2para><Text>In section 11 of the Health and Safety at Work etc. Act 1974—</Text><P3 id="schedule-3-paragraph-3-1-b"><P3para><Text>after subsection (2) insert the subsection set out in sub-paragraph (2).</Text></P3para></P3></P2para></P2><P2 id="schedule-3-paragraph-3-2"><P2para><Text>The subsection is—</Text><BlockAmendment><P2><Pnumber>2A</Pnumber><P2para><Text>new</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|,
        "UK_ukpga_2005_14"
      )

    assert [%Rule{operation: :inserted, targets: ["s.11(2A)"]}] =
             read(d, "schedule-3-paragraph-3-1-b", hswa)
  end

  test "a list of many laws' provisions is no one law's instruction (Sentencing Act 2020 Sch.24 para 443)" do
    hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

    d =
      doc(
        p1(
          "section-443",
          "In the following provisions, for “section 154(1) of the Criminal Justice Act 2003” substitute “paragraph 24(2) of Schedule 22 to the Sentencing Act 2020”— section 1A(8) of the Prevention of Crime Act 1953; sections 1(10) and 4(13) of the Nuclear Installations Act 1965; paragraph 2(2) of Schedule 3A to the Health and Safety at Work etc. Act 1974;"
        ),
        "UK_ukpga_2020_17"
      )

    assert read(d, "section-443", hswa) == []
  end

  test "listed sections each keep their own brackets, and a Schedule entry beside them is no target (SI 1974/1941 reg.5(1))" do
    emas = Reader.law_ref("UK_ukpga_1972_28", "Employment Medical Advisory Service Act", "s")

    d =
      doc(
        p1(
          "regulation-5-1",
          "In the Employment Medical Advisory Service Act 1972, (“the 1972 Act”) sections 7, 8(2) and the entry in Schedule 2 relating to section 124(2) of the 1961 Act are hereby repealed."
        ),
        "UK_uksi_1974_1941"
      )

    assert [%Rule{targets: ["s.7", "s.8(2)"], operation: :repealed, level: :provision}] =
             read(d, "regulation-5-1", emas)
  end

  describe "Maritime Safety: Amending-law reader (2026-11-06)" do
    @msa Reader.law_ref("UK_ukpga_1995_21", "Merchant Shipping Act", "s")
    @load_line Reader.law_ref(
                 "UK_uksi_1998_2241",
                 "Merchant Shipping (Load Line) Regulations",
                 "reg"
               )
    @fees Reader.law_ref("UK_uksi_2004_1495", "Merchant Shipping (Fees) Regulations", "reg")

    test "a lead-in naming the amended law's Schedule's text keeps its items in the Schedule (SI 2016/1061 art.3(a))" do
      d =
        doc(
          p1("article-2", "The Merchant Shipping Act 1995 is amended as follows.") <>
            ~s|<P1 id="article-3"><P1para><Text>The text of the Convention as set out in Part 1 of Schedule 7 is amended as follows—</Text><P3 id="article-3-a"><P3para><Text>for paragraph 1 of Article 6 (the general limits) substitute—</Text><BlockAmendment><P3><Pnumber>1</Pnumber><P3para><Text>The limits of liability</Text></P3para></P3></BlockAmendment></P3para></P3></P1para></P1>|,
          "UK_uksi_2016_1061"
        )

      assert read(d, "article-3-a", @msa) == []
    end

    test "a quote substituting a whole regulation from its paragraphs, without its own number, is that regulation's (SI 2000/1335 reg.16)" do
      d =
        doc(
          p1(
            "regulation-1",
            "The Merchant Shipping (Load Line) Regulations 1998 are amended as follows."
          ) <>
            ~s|<P1 id="regulation-16"><P1para><Text>For regulation 10 there shall be substituted—</Text><BlockAmendment><P2><Pnumber>1</Pnumber><P2para><Text>Subject to paragraphs (2)</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><P3><Pnumber>a</Pnumber><P3para><Text>When</Text></P3para></P3></P2para></P2></BlockAmendment></P1para></P1>|,
          "UK_uksi_2000_1335"
        )

      rules = read(d, "regulation-16", @load_line)
      targets = rules |> Enum.flat_map(& &1.targets) |> Enum.uniq() |> Enum.sort()

      assert "reg.10" in targets
      assert "reg.10(1)" in targets and "reg.10(2)(a)" in targets
      refute "reg.1" in targets or "reg.2" in targets
    end

    test "a law's year in a Citation is part of its words: never another law named before (2026 c.18 s.148(1)(a))" do
      d =
        doc(
          p1("section-147", "In section 85 of the Merchant Shipping Act 1995, omit “x”.") <>
            ~s|<P1 id="section-148"><P1para><P2 id="section-148-1"><P2para><Text>In the Smoking, Health and Social Care (Scotland) Act <Citation URI="http://www.legislation.gov.uk/id/asp/2005/13" id="c00073" Year="2005" Number="13" Class="ScottishAct">2005 (asp 13)</Citation>—</Text><P3 id="section-148-1-a"><P3para><Text>in section 4 (meaning of “no-smoking premises” etc), for subsections (2) to (9) substitute—</Text><BlockAmendment><P2><Pnumber>2</Pnumber><P2para><Text>x</Text></P2para></P2></BlockAmendment></P3para></P3></P2para></P2></P1para></P1>|,
          "UK_ukpga_2026_18"
        )

      assert read(d, "section-148-1-a", @msa) == []
    end

    test "a quote numbering its own regulation is still read as it (For regulation 10 substitute— 10.)" do
      d =
        doc(
          p1(
            "regulation-1",
            "The Merchant Shipping (Load Line) Regulations 1998 are amended as follows."
          ) <>
            ~s|<P1 id="regulation-16"><P1para><Text>For regulation 10 there shall be substituted—</Text><BlockAmendment><P1><Pnumber>10</Pnumber><P1para><Text>Duration</Text></P1para></P1></BlockAmendment></P1para></P1>|,
          "UK_uksi_2000_1335"
        )

      assert "reg.10" in (d |> read("regulation-16", @load_line) |> Enum.flat_map(& &1.targets))
    end

    test "a list of places across regulations keeps each its own regulation (SI 2005/1434 reg.2(3))" do
      d =
        doc(
          p1(
            "regulation-2",
            "The Merchant Shipping (Fees) Regulations 2004 are amended as follows."
          ) <>
            p1(
              "regulation-2-3",
              "In regulations 6(6), 8(9), 12(2) and 15(1), in paragraph (a), for “level 5 on the standard scale” there shall be substituted “the statutory maximum”."
            ),
          "UK_uksi_2005_1434"
        )

      targets = d |> read("regulation-2-3", @fees) |> Enum.flat_map(& &1.targets)

      assert "reg.8(9)(a)" in targets and "reg.15(1)(a)" in targets
      refute "reg.6(1)" in targets or "reg.6(9)" in targets
    end

    test "a list of places keeps a range of bare numbers whole (asp 2004/6 Sch.7 para 4)" do
      wca = Reader.law_ref("UK_ukpga_1981_69", "Wildlife and Countryside Act", "s")

      d =
        doc(
          p1(
            "section-4",
            "Sections 28 to 34, 41, 50, 51 and 74(5A) of the Wildlife and Countryside Act 1981 are repealed."
          ),
          "UK_asp_2004_6"
        )

      assert [%Rule{targets: targets}] = read(d, "section-4", wca)
      assert Enum.sort(targets) == Enum.sort(~w[s.28..s.34 s.41 s.50 s.51 s.74(5A)])
    end

    test "a bracket alone in a list takes the item before's place above its level (asp 2014/3 Sch.3 para 29(2)(a)(i))" do
      d =
        doc(
          p1(
            "section-1",
            "In section 21(1) of the Merchant Shipping Act 1995, paragraph (a)(i), (iii) and (iv) are repealed."
          ),
          "UK_asp_2014_3"
        )

      [%Rule{targets: targets}] = read(d, "section-1", @msa)
      assert "s.21(1)(a)(iii)" in targets and "s.21(1)(a)(iv)" in targets
      refute "s.21(1)(a)(i)(iii)" in targets
    end

    test "a bracket item with brackets of its own keeps the item before's higher place (2007 c.28 on s.94: \"(1)(a) and (b)(iii)\")" do
      d =
        doc(
          p1(
            "section-1",
            "In section 94(1) of the Merchant Shipping Act 1995, in subsections (1)(a) and (b)(iii) for “best value authority” substitute “x”."
          ),
          "UK_ukpga_2007_28"
        )

      targets = d |> read("section-1", @msa) |> Enum.flat_map(& &1.targets)
      assert "s.94(1)(b)(iii)" in targets and "s.94(1)(a)" in targets
    end

    test "whole provisions omitted with a sentence beside them stay whole (SI 2019/270 reg.3(19))" do
      d =
        doc(
          p1(
            "section-1",
            "In section 4 of the Merchant Shipping Act 1995, omit subsections (2) to (4) and the final sentence following subsection (4)."
          ),
          "UK_uksi_2019_270"
        )

      assert [%Rule{level: :provision}] = read(d, "section-1", @msa)
    end

    test "a numbered list of a Schedule's paragraphs is never the Act's sections (SI 2008/948 Sch.1 para 100(a))" do
      ia = Reader.law_ref("UK_ukpga_1986_45", "Insolvency Act", "s")

      d =
        doc(
          p1(
            "paragraph-100",
            "In Schedule B1 to the Insolvency Act 1986, in paragraphs 49(3)(b) and 73(2)(c) for “section 425 of the Companies Act” substitute “Part 26 of the Companies Act 2006”."
          ),
          "UK_uksi_2008_948"
        )

      refute Enum.any?(read(d, "paragraph-100", ia), &("s.49(3)(b)" in &1.targets))
    end

    test "a quote substituting a range of sections keeps its own numbers (1989 c.15 Sch.23 para 4)" do
      copa = Reader.law_ref("UK_ukpga_1974_40", "Control of Pollution Act", "s")

      d =
        doc(
          p1("section-1", "The Control of Pollution Act 1974 is amended as follows.") <>
            ~s|<P1 id="section-2"><P1para><Text>For sections 31 to 42 there shall be substituted the following sections—</Text><BlockAmendment><P1><Pnumber>30A</Pnumber><P1para><Text>new</Text></P1para></P1></BlockAmendment></P1para></P1>|,
          "UK_ukpga_1989_15"
        )

      targets = d |> read("section-2", copa) |> Enum.flat_map(& &1.targets)
      assert "s.30A" in targets
      refute Enum.any?(targets, &String.starts_with?(&1, "s.31(30A)"))
    end

    test "the second sentence, and the rest of a paragraph, are words (SI 2009/1941 Sch.1 para.152(2); SI 2017/879 reg.8(b))" do
      d =
        doc(
          p1(
            "regulation-1",
            "In section 143(6) of the Merchant Shipping Act 1995 (prosecutions), for the second sentence substitute <InlineAmendment>“The rest.”</InlineAmendment>."
          ) <>
            p1(
              "regulation-2",
              "In section 144(4) of the Merchant Shipping Act 1995, omit the rest of paragraph (4)."
            ),
          "UK_uksi_2009_1941"
        )

      assert [%Rule{level: :words}] = read(d, "regulation-1", @msa)
      assert [%Rule{level: :words}] = read(d, "regulation-2", @msa)
    end
  end
end

defmodule SertantaiLegal.Scraper.Amendment.ReaderS06Test do
  @moduledoc """
  CV-S06: the amendment reader's misreads found by the amending provisions'
  catalogue and the census of the family's disagreements (B1–B7), each as
  the real words that were misread.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw

  @regs Reader.law_ref("UK_nisr_1997_193", "The Lifts Regulations (Northern Ireland)", "reg")
  @clean_air Reader.law_ref("UK_ukpga_1993_11", "Clean Air Act", "s")

  defp doc(body, law \\ "UK_nisr_2015_265"),
    do: Doc.new(law, [~s|<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>|])

  defp p1(id, text), do: ~s|<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>|

  defp read(d, id, law, terms \\ %{}), do: Reader.instruction(d, id, terms, [law])

  describe "B1: a Schedule's paragraph is never the law's regulation of that number" do
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

  test "B1: a holding provision's caption doesn't hide \"Schedule 2 … is amended\" (2013 c.32 Sch.12 para 15(13))" do
    hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

    d =
      doc(
        ~s|<P1 id="schedule-12-paragraph-15"><P1para><Text>Schedule 2 (constitution etc. of the Health and Safety Executive) to the Health and Safety at Work etc. Act 1974 is amended as follows.</Text><P2 id="schedule-12-paragraph-15-13"><P2para><Text>After that sub-paragraph insert—</Text><BlockAmendment><P3><Pnumber>4</Pnumber><P3para><Text>new</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|,
        "UK_ukpga_2013_32"
      )

    assert read(d, "schedule-12-paragraph-15-13", hswa) == []
  end

  test "B4: the subsection \"set out in sub-paragraph (2)\" is the one inserted (2005 c.14 Sch.3 para 3)" do
    hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

    d =
      doc(
        ~s|<P1 id="schedule-3-paragraph-3"><P1para><P2 id="schedule-3-paragraph-3-1"><P2para><Text>In section 11 of the Health and Safety at Work etc. Act 1974—</Text><P3 id="schedule-3-paragraph-3-1-b"><P3para><Text>after subsection (2) insert the subsection set out in sub-paragraph (2).</Text></P3para></P3></P2para></P2><P2 id="schedule-3-paragraph-3-2"><P2para><Text>The subsection is—</Text><BlockAmendment><P2><Pnumber>2A</Pnumber><P2para><Text>new</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|,
        "UK_ukpga_2005_14"
      )

    assert [%Rule{operation: :inserted, targets: ["s.11(2A)"]}] =
             read(d, "schedule-3-paragraph-3-1-b", hswa)
  end

  test "B2: a list of many laws' provisions is no one law's instruction (Sentencing Act 2020 Sch.24 para 443)" do
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

  describe "B3, B6: the level" do
    test "a heading or a mark itself changed is words; a provision going with its heading is whole" do
      d =
        doc(
          ~s|<P1 id="regulation-6"><P1para><Text>In regulation 6 of the Lifts Regulations (Northern Ireland) 1997—</Text><P2 id="regulation-6-a"><P2para><Text>for the heading substitute “New heading”;</Text></P2para></P2><P2 id="regulation-6-b"><P2para><Text>for the full stop at the end of paragraph (2) substitute a comma; and</Text></P2para></P2></P1para></P1>| <>
            p1(
              "regulation-7",
              "In the Lifts Regulations (Northern Ireland) 1997, omit regulation 27A and the heading preceding it."
            )
        )

      assert [%Rule{level: :words, targets: ["reg.6"]}] = read(d, "regulation-6-a", @regs)
      assert [%Rule{level: :words}] = read(d, "regulation-6-b", @regs)
      assert [%Rule{level: :provision, targets: ["reg.27A"]}] = read(d, "regulation-7", @regs)
    end

    test "a provision omitted with the word joining it goes whole (SI 2018/816 reg.23(1)(b))" do
      d =
        doc(
          p1(
            "regulation-11",
            "In regulation 23 of the Lifts Regulations (Northern Ireland) 1997, in paragraph (1) omit sub-paragraph (b) and the “or” which precedes it."
          )
        )

      assert [%Rule{level: :provision, operation: :repealed}] = read(d, "regulation-11", @regs)
    end
  end

  test "B7: a quote numbering provisions makes them whole (NISR 2011/365 reg.4(5))" do
    d =
      doc(
        ~s|<P1 id="regulation-4"><P1para><Text>In regulation 3 of the Lifts Regulations (Northern Ireland) 1997—</Text><P2 id="regulation-4-5"><P2para><Text>In paragraph (l), at the end, for “.” substitute—</Text><BlockAmendment><P3><Pnumber>m</Pnumber><P3para><Text>new m;</Text></P3para></P3><P3><Pnumber>n</Pnumber><P3para><Text>new n.</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|,
        "UK_nisr_2011_365"
      )

    rules = read(d, "regulation-4-5", @regs)

    assert %Rule{level: :provision, treatment: :quoted} =
             Enum.find(rules, &("reg.3(m)" in &1.targets))
  end

  describe "B5: the change vocabulary's targets" do
    defp rule(targets, treatment, level \\ :provision),
      do:
        Rule.new(
          amends: "UK_ukpga_1974_37",
          targets: targets,
          operation: :repealed,
          level: level,
          source: %{law: "UK_ukpga_2008_20", ref: "schedule-3-paragraph-2-1", text: nil},
          treatment: treatment
        )

    defp targets(rules, known),
      do: for({_key, t, _claims} <- AmendingLaw.read(rules, %{}, known), do: t)

    test "a named place is its deepest held reading: \"subsection (6)(e) is omitted\" is s.15(6)(e), never s.15(6)" do
      r = rule(["s.15(6)", "s.15(e)", "s.15(6)(e)"], :instruction)
      assert targets([r], ["s.15", "s.15(6)", "s.15(6)(e)"]) == ["s.15(6)(e)"]
    end

    test "a reading the law doesn't hold falls back to the place it does" do
      r = rule(["s.15(6)", "s.15(e)", "s.15(6)(e)"], :instruction)
      assert targets([r], ["s.15", "s.15(6)"]) == ["s.15(6)"]
    end

    test "siblings named stay apart: \"subsections (5) and (6)\"" do
      r = rule(["s.47(5)", "s.47(6)"], :instruction)
      assert Enum.sort(targets([r], ["s.47(5)", "s.47(6)"])) == ["s.47(5)", "s.47(6)"]
    end

    test "a quote's provisions follow its top: an inserted s.51A is s.51A" do
      r = rule(["s.51A", "s.51A(1)", "s.51A(2)"], :quoted)
      assert targets([r], ["s.51A", "s.51A(1)", "s.51A(2)"]) == ["s.51A"]
    end
  end
end

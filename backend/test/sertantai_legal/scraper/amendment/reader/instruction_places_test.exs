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
end

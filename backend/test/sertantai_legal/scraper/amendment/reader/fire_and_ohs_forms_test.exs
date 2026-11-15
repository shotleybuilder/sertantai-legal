defmodule SertantaiLegal.Scraper.Amendment.Reader.FireAndOhsFormsTest do
  @moduledoc """
  Amending wordings read for Fire and OH&S: Amending-law reader (2026-11-15,
  Decision 1): a law or provision named in an aside or a describing clause
  is never the law amended or a target, each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader

  @frsa Reader.law_ref("UK_ukpga_2004_21", "Fire and Rescue Services Act", "s")

  defp doc(amending, body),
    do:
      Doc.new(amending, [~s(<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>)])

  defp targets(rules), do: rules |> Enum.flat_map(& &1.targets) |> Enum.uniq() |> Enum.sort()
  defp amended(rules), do: rules |> Enum.map(& &1.amends) |> Enum.uniq() |> Enum.sort()

  describe "an aside's law or provision is never the amended place" do
    test "a caption with brackets inside brackets names neither the law nor regulations (SI 2019/696 Sch.31 para.9)" do
      itoer =
        Reader.law_ref(
          "UK_nisr_2013_48",
          "Identification and Traceability of Explosives Regulations (Northern Ireland)",
          "reg"
        )

      explosives =
        Reader.law_ref("UK_nisr_2016_366", "Explosives Regulations (Northern Ireland)", "reg")

      d =
        doc(
          "UK_uksi_2019_696",
          ~S|<P1 id="schedule-31-paragraph-1"><P1para><Text>The Explosives Regulations (Northern Ireland) 2016 are amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-31-paragraph-9"><P1para><Text>In regulation 10 (traceability of certain civil explosives excluded from the scope of regulations 4, 5 and 6 of the Identification and Traceability of Explosives Regulations (Northern Ireland) 2013 (ITOER (NI) 2013)) for paragraph (4) substitute—</Text><BlockAmendment><P2><Pnumber>4</Pnumber><P2para><Text>For a civil explosive that is to be made available on the market in Northern Ireland the contact details referred to in paragraph (1) must be provided in English.</Text></P2para></P2></BlockAmendment></P1para></P1>|
        )

      rules = Reader.instruction(d, "schedule-31-paragraph-9", %{}, [itoer, explosives])

      assert amended(rules) == ["UK_nisr_2016_366"]
      assert targets(rules) == ["reg.10(4)"]
    end

    test "\"(as continued in force by order under section 36 of the … Act 2004)\" after the law amended names no law (2017 c.3 s.8(5)(a))" do
      fsa = Reader.law_ref("UK_ukpga_1947_41", "Fire Services Act", "s")

      d =
        doc(
          "UK_ukpga_2017_3",
          ~S|<P1 id="section-8"><P1para><P2 id="section-8-5"><P2para><Text>In section 26 of the Fire Services Act 1947 (firefighters' pension scheme) (as continued in force by order under section 36 of the Fire and Rescue Services Act 2004) in subsection (5A) (as inserted by paragraph 14 of Schedule 1)—</Text><P3 id="section-8-5-a"><P3para><Text>omit the “or” at the end of paragraph (a), and</Text></P3para></P3></P2para></P2></P1para></P1>|
        )

      rules = Reader.instruction(d, "section-8-5-a", %{}, [fsa, @frsa])

      assert amended(rules) == ["UK_ukpga_1947_41"]
      assert "s.26(5A)(a)" in targets(rules)
      refute Enum.any?(targets(rules), &String.starts_with?(&1, "s.36"))
    end

    test "\"In section 5B (boundaries of power under section 5A) after subsection (5) insert— 5A … 5B\": the section's subsections (2017 c.3 Sch.2 para.113)" do
      d =
        doc(
          "UK_ukpga_2017_3",
          ~S|<P1 id="schedule-2-paragraph-112"><P1para><Text>The Fire and Rescue Services Act 2004 is amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-2-paragraph-113"><P1para><Text>In section 5B (boundaries of power under section 5A) after subsection (5) insert—</Text><BlockAmendment><P2><Pnumber>5A</Pnumber><P2para><Text>Section 5A(1) does not authorise the London Fire Commissioner to enter into a contract to which this subsection applies without the consent of the Mayor of London.</Text></P2para></P2><P2><Pnumber>5B</Pnumber><P2para><Text>Subsection (5A) applies to a contract if—</Text><P3><Pnumber>a</Pnumber><P3para><Text>the Mayor of London has notified the London Fire Commissioner, and</Text></P3para></P3><P3><Pnumber>b</Pnumber><P3para><Text>the contract is of that kind.</Text></P3para></P3></P2para></P2></BlockAmendment></P1para></P1>|
        )

      rules = Reader.instruction(d, "schedule-2-paragraph-113", %{}, [@frsa])

      assert targets(rules) == ["s.5B(5A)", "s.5B(5B)", "s.5B(5B)(a)", "s.5B(5B)(b)"]
    end

    test "a section grown from the one named is still a section where the quote follows a section (\"After section 5B insert— 5C\")" do
      d =
        doc(
          "UK_ukpga_2017_3",
          ~S|<P1 id="schedule-2-paragraph-112"><P1para><Text>The Fire and Rescue Services Act 2004 is amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-2-paragraph-114"><P1para><Text>After section 5B (boundaries of power under section 5A) insert—</Text><BlockAmendment><P1><Pnumber>5C</Pnumber><P1para><Text>New section.</Text></P1para></P1></BlockAmendment></P1para></P1>|
        )

      assert targets(Reader.instruction(d, "schedule-2-paragraph-114", %{}, [@frsa])) == ["s.5C"]
    end

    test "an entry's description names neither the law nor a place (2017 c.3 Sch.1 para.85)" do
      d =
        doc(
          "UK_ukpga_2017_3",
          ~S|<P1 id="schedule-1-paragraph-85"><P1para><Text>In Part 1 of Schedule 19 to the Equality Act 2010 (public authorities) after the entry relating to a fire and rescue authority constituted by a scheme under section 2 of the Fire and Rescue Services Act 2004 or a scheme to which section 4 of that Act applies insert—</Text><BlockAmendment><P3para><Text>A fire and rescue authority created by an order under section 4A of that Act.</Text></P3para></BlockAmendment></P1para></P1>|
        )

      assert Reader.instruction(d, "schedule-1-paragraph-85", %{}, [@frsa]) == []
    end

    test "\"(which enables Orders in Council under section 11 of the Petroleum Act 1998 (c. 17) …)\" names no law: never a fall-back (2004 c.20 s.87(5))" do
      petroleum = Reader.law_ref("UK_ukpga_1998_17", "Petroleum Act", "s")

      d =
        doc(
          "UK_ukpga_2004_20",
          ~S|<P1 id="section-87"><P1para><P2 id="section-87-5"><P2para><Text>In section 410(3) of the Communications Act 2003 (c. 21) (which enables Orders in Council under section 11 of the Petroleum Act 1998 (c. 17) to extend certain communications legislation to offshore installations), after “1998” insert “or section 87 of the Energy Act 2004”.</Text></P2para></P2></P1para></P1>|
        )

      assert Reader.instruction(d, "section-87-5", %{}, [petroleum]) == []

      communications = Reader.law_ref("UK_ukpga_2003_21", "Communications Act", "s")
      rules = Reader.instruction(d, "section-87-5", %{}, [petroleum, communications])
      assert amended(rules) == ["UK_ukpga_2003_21"]
      assert "s.410(3)" in targets(rules)
      refute "s.11" in targets(rules)
    end

    test "\"has the meaning assigned to it in section 108 of that Act\" names no target (SI 1996/2089 reg.34(1))" do
      explosives = Reader.law_ref("UK_ukpga_1875_17", "Explosives Act", "s")

      d =
        doc(
          "UK_uksi_1996_2089",
          ~S|<P1 id="regulation-34"><P1para><P2 id="regulation-34-1"><P2para><Text>Section 35 of the Explosives Act 1875 is hereby repealed to the extent that it imposes a duty upon every railway company over whose railway any explosives are carried and in this paragraph the expression “railway company” has the meaning assigned to it in section 108 of that Act.</Text></P2para></P2></P1para></P1>|
        )

      assert targets(Reader.instruction(d, "regulation-34-1", %{}, [explosives])) == ["s.35"]
    end

    test "an item whose only verb sat in its caption takes its parent's, \"The following provisions are repealed—\" (2011 c.20 s.47(b))" do
      cca = Reader.law_ref("UK_ukpga_2008_27", "Climate Change Act", "s")

      d =
        doc(
          "UK_ukpga_2011_20",
          ~S|<P1 id="section-47"><P1para><Text>The following provisions are repealed—</Text><P3 id="section-47-a"><P3para><Text>section 71(1) of, and Schedule 5 to, the Climate Change Act 2008 (which amend the Environmental Protection Act 1990 to enable waste collection authorities to make waste reduction schemes, but which have never been in force), and</Text></P3para></P3><P3 id="section-47-b"><P3para><Text>sections 71(2) and (3) and 72 to 75 of that Act (which provide for the provisions mentioned in paragraph (a) to be piloted and then either brought into force, with or without amendments, or repealed).</Text></P3para></P3></P1para></P1>|
        )

      rules = Reader.instruction(d, "section-47-b", %{}, [cca])

      assert amended(rules) == ["UK_ukpga_2008_27"]
      assert targets(rules) == ["s.71(2)", "s.71(3)", "s.72..s.75"]
      assert Enum.all?(rules, &(&1.operation == :repealed))
    end
  end

  describe "a Schedule's instruction is never placed on a body provision" do
    test "\"Omit Schedules 1 and 2.\" takes no place from the sibling before, Omit sections 119 to 121 (SR 2006/425 Sch.6 para.1(15))" do
      explosives = Reader.law_ref("UK_ukpga_1875_17", "Explosives Act", "s")
      terms = %{"the 1875 act" => %{law: "UK_ukpga_1875_17", title: nil}}

      d =
        doc(
          "UK_nisr_2006_425",
          ~S|<P1 id="schedule-6-paragraph-1"><P1para><P2 id="schedule-6-paragraph-1-1"><P2para><Text>The 1875 Act is amended as follows.</Text></P2para></P2><P2 id="schedule-6-paragraph-1-14"><P2para><Text>Omit sections 119 to 121.</Text></P2para></P2><P2 id="schedule-6-paragraph-1-15"><P2para><Text>Omit Schedules 1 and 2.</Text></P2para></P2></P1para></P1>|
        )

      assert targets(Reader.instruction(d, "schedule-6-paragraph-1-14", terms, [explosives])) ==
               ["s.119..s.121"]

      assert Reader.instruction(d, "schedule-6-paragraph-1-15", terms, [explosives]) == []
    end

    test "\"Paragraph 9 is amended as follows.\" is a Schedule's lead-in: its sub-paragraphs give no rule (2016 c.20 Sch.1 para.38)" do
      petroleum = Reader.law_ref("UK_ukpga_1998_17", "Petroleum Act", "s")

      d =
        doc(
          "UK_ukpga_2016_20",
          ~S|<P1 id="schedule-1-paragraph-6"><P1para><Text>The Petroleum Act 1998 is amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-1-paragraph-32"><P1para><P2 id="schedule-1-paragraph-32-1"><P2para><Text>Schedule 2 (authorisations) is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-32-2"><P2para><Text>Omit paragraph 1(2).</Text></P2para></P2></P1para></P1>| <>
            ~S|<P1 id="schedule-1-paragraph-38"><P1para><P2 id="schedule-1-paragraph-38-1"><P2para><Text>Paragraph 9 is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-38-2"><P2para><Text>In sub-paragraph (1), for “Secretary of State” substitute “OGA”.</Text></P2para></P2><P2 id="schedule-1-paragraph-38-3"><P2para><Text>In sub-paragraph (2), for “Secretary of State” (in each place) substitute “OGA”.</Text></P2para></P2><P2 id="schedule-1-paragraph-38-4"><P2para><Text>For sub-paragraph (3) substitute—</Text><BlockAmendment><P2><Pnumber>3</Pnumber><P2para><Text>The OGA shall publish a copy of the notice in such manner as it considers appropriate.</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
        )

      for id <- ~w(schedule-1-paragraph-38-2 schedule-1-paragraph-38-3 schedule-1-paragraph-38-4) do
        assert Reader.instruction(d, id, %{}, [petroleum]) == []
      end
    end

    test "a section's lead-in after the Schedule paragraph's is still the section's (\"Section 4 is amended as follows.\")" do
      petroleum = Reader.law_ref("UK_ukpga_1998_17", "Petroleum Act", "s")

      d =
        doc(
          "UK_ukpga_2016_20",
          ~S|<P1 id="schedule-1-paragraph-6"><P1para><Text>The Petroleum Act 1998 is amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="schedule-1-paragraph-32"><P1para><P2 id="schedule-1-paragraph-32-1"><P2para><Text>Schedule 2 (authorisations) is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-32-2"><P2para><Text>Omit paragraph 1(2).</Text></P2para></P2></P1para></P1>| <>
            ~S|<P1 id="schedule-1-paragraph-38"><P1para><P2 id="schedule-1-paragraph-38-1"><P2para><Text>Paragraph 9 is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-38-2"><P2para><Text>Section 4 is amended as follows.</Text></P2para></P2><P2 id="schedule-1-paragraph-38-3"><P2para><Text>For subsection (3) substitute—</Text><BlockAmendment><P2><Pnumber>3</Pnumber><P2para><Text>New.</Text></P2para></P2></BlockAmendment></P2para></P2></P1para></P1>|
        )

      assert targets(Reader.instruction(d, "schedule-1-paragraph-38-3", %{}, [petroleum])) ==
               ["s.4(3)"]
    end
  end

  describe "a list of provisions, each with its own brackets, is read provision by provision" do
    test "\"In each of regulation 46(2)(a) (…) and regulation 60(b)(i) (…)\": each regulation at its own path (SI 2017/879 reg.5)" do
      registration =
        Reader.law_ref(
          "UK_uksi_1993_3138",
          "Merchant Shipping (Registration of Ships) Regulations",
          "reg"
        )

      d =
        doc(
          "UK_uksi_2017_879",
          ~S|<P1 id="regulation-2"><P1para><Text>The Merchant Shipping (Registration of Ships) Regulations 1993 are amended as follows.</Text></P1para></P1>| <>
            ~S|<P1 id="regulation-5"><P1para><Text>In each of regulation 46(2)(a) (evidence of title on transmission of a registered ship) and regulation 60(b)(i) (evidence on transmission of mortgage), for “an office copy”, substitute “a copy”.</Text></P1para></P1>|
        )

      rules = Reader.instruction(d, "regulation-5", %{}, [registration])

      assert targets(rules) ==
               ~w[reg.46(2) reg.46(2)(a) reg.46(a) reg.60(b) reg.60(b)(i) reg.60(i)]
    end

    test "\"In each of the following provisions … –section 78A(7)(b)(i), section 78C(10)(b), …\": each listed section as named (SSI 2005/658 reg.2(2))" do
      epa = Reader.law_ref("UK_ukpga_1990_43", "Environmental Protection Act", "s")

      items =
        [
          "section 78A(7)(b)(i),",
          "section 78C(10)(b),",
          "section 78E(4)(b),",
          "section 78G(4),",
          "section 78H(4),",
          "section 78J(2),",
          "section 78J(3) (where the expression appears for the second time),",
          "section 78N(3)(a),",
          "section 78YB(2A)(a),",
          "section 78YB(2B)(a),",
          "section 78YC."
        ]
        |> Enum.map_join(&"<ListItem><Para><Text>#{&1}</Text></Para></ListItem>")

      d =
        doc(
          "UK_ssi_2005_658",
          ~S|<P1 id="regulation-2"><P1para><P2 id="regulation-2-1"><P2para><Text>The Environmental Protection Act 1990 is amended as follows.</Text></P2para></P2>| <>
            ~S|<P2 id="regulation-2-2"><P2para><Text>In each of the following provisions, for “controlled waters” wherever the expression occurs substitute “the water environment”–</Text><UnorderedList Decoration="none">| <>
            items <> ~S|</UnorderedList></P2para></P2></P1para></P1>|
        )

      rules = Reader.instruction(d, "regulation-2-2", %{}, [epa])

      assert targets(rules) ==
               Enum.sort(
                 ~w[s.78A(7) s.78A(b) s.78A(i) s.78A(7)(b) s.78A(7)(i) s.78A(b)(i) s.78A(7)(b)(i)] ++
                   ~w[s.78C(10) s.78C(b) s.78C(10)(b) s.78E(4) s.78E(b) s.78E(4)(b)] ++
                   ~w[s.78G(4) s.78H(4) s.78J(2) s.78J(3) s.78N(3) s.78N(a) s.78N(3)(a)] ++
                   ~w[s.78YB(2A) s.78YB(a) s.78YB(2A)(a) s.78YB(2B) s.78YB(2B)(a) s.78YC]
               )
    end

    test "a title's year before the provision's word is never a list item (\"… Regulations 2001, regulation 6(3) (groups)\": SI 2009/1890 art.4(1)(a))" do
      levy =
        Reader.law_ref(
          "UK_uksi_2001_7",
          "Climate Change Levy (Registration and Miscellaneous Provisions) Regulations",
          "reg"
        )

      d =
        doc(
          "UK_uksi_2009_1890",
          ~S|<P1 id="article-4"><P1para><P2 id="article-4-1"><P2para><Text>In the following enactments, substitute “1159 of and Schedule 6 to” for “736 of”, and substitute “2006” for “1985”:—</Text>| <>
            ~S|<P3 id="article-4-1-a"><P3para><Text>the Climate Change Levy (Registration and Miscellaneous Provisions) Regulations 2001, regulation 6(3) (groups), and in this regulation also substitute “those provisions” for “that section”;</Text></P3para></P3></P2para></P2></P1para></P1>|
        )

      assert targets(Reader.instruction(d, "article-4-1-a", %{}, [levy])) == ["reg.6(3)"]
    end
  end
end

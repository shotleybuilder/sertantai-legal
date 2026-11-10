defmodule SertantaiLegal.Scraper.Amendment.Reader.ParkedFormsTest do
  @moduledoc """
  Amending wordings parked on the Amending-law reader and fixed in
  Amending-law reader: parked bugs (2026-11-10), each on its law's real
  wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader

  defp doc(amending, body),
    do:
      Doc.new(amending, [
        ~s(<Legislation><Primary><Schedules><Schedule id="schedule-1">#{body}</Schedule></Schedules></Primary></Legislation>)
      ])

  # SI 2011/2616 Sch.1 para.2, as legislation.gov.uk marks it up: items
  # (c)–(e) nested, without ids, in the list quoting (b)'s words
  @para2 ~S|<P1 id="schedule-1-paragraph-1"><P1para><Text>The Merchant Shipping (Vessel Traffic Monitoring and Reporting Requirements) Regulations 2004 are amended as follows.</Text></P1para></P1><P1 id="schedule-1-paragraph-2"><P1para><Text>In regulation 2 (interpretation), in paragraph (1)—</Text><P3 id="schedule-1-paragraph-2-a"><P3para><Text>delete the definition of “the BC Code”;</Text></P3para></P3><P3 id="schedule-1-paragraph-2-b"><P3para><Text>at the end of the definition of “the Directive” add—</Text></P3para></P3><UnorderedList Decoration="none" Class="Definition"><ListItem><Para><Text>“, as amended by Directive 2009/17/EC;”;</Text><OrderedList Decoration="parens" Type="alpha" Start="3"><ListItem><Para><Text>in the definition of “the IBC Code” for “1998” substitute “2007”;</Text></Para></ListItem><ListItem><Para><Text>in the definition of “IMDG Code” for “2002” substitute “2010/11”;</Text></Para></ListItem><ListItem><Para><Text>for the definition of the “ISM Code” substitute—</Text></Para></ListItem></OrderedList></Para></ListItem></UnorderedList></P1para></P1>|

  test "an id-less list of instructions under a provision: each item its own provision, numbered from Start (SI 2011/2616 Sch.1 para.2(c)–(e))" do
    d = doc("UK_uksi_2011_2616", @para2)

    assert "schedule-1-paragraph-2-c" in d.ids
    assert "schedule-1-paragraph-2-e" in d.ids

    assert %Text{instruction: "in the definition of “the IBC Code” for “1998” substitute “2007”;"} =
             Text.of(d, "schedule-1-paragraph-2-c")

    # the parent's own words no longer hold its items' instructions
    refute Text.of(d, "schedule-1-paragraph-2").instruction =~ "IBC"
  end

  test "each item is read on its own (reg.2(1) words substituted, from para.2(c) and (d) apart)" do
    d = doc("UK_uksi_2011_2616", @para2)

    vtm =
      Reader.law_ref(
        "UK_uksi_2004_2110",
        "Merchant Shipping (Vessel Traffic Monitoring and Reporting Requirements) Regulations",
        "reg"
      )

    for id <- ["schedule-1-paragraph-2-c", "schedule-1-paragraph-2-d"] do
      assert [%{operation: :substituted, level: :words, targets: targets}] =
               Reader.instruction(d, id, %{}, [vtm])

      assert "reg.2(1)" in targets
    end
  end

  test "a list of places, not instructions, stays its provision's words (\"in the following provisions— (a) section 1; (b) …\")" do
    d =
      doc(
        "UK_ukpga_2000_1",
        ~S|<P1 id="schedule-1-paragraph-3"><P1para><Text>In the following provisions of the Health and Safety at Work etc. Act 1974, for “the Commission” substitute “the Executive”—</Text><OrderedList Decoration="parens" Type="alpha"><ListItem><Para><Text>section 1;</Text></Para></ListItem><ListItem><Para><Text>section 11.</Text></Para></ListItem></OrderedList></P1para></P1>|
      )

    refute "schedule-1-paragraph-3-a" in d.ids
  end

  test "\"the definition of “X” shall be deleted and replaced with the following definition—\" is one substitution of words (SI 1997/2776 reg.2(a); SI 1996/1592 Sch.9 para.3)" do
    cs = Reader.law_ref("UK_uksi_1997_1713", "Confined Spaces Regulations", "reg")

    d =
      Doc.new("UK_uksi_1997_2776", [
        ~S|<Legislation><Primary><Body><P1 id="regulation-2"><P1para><Text>In the Confined Spaces Regulations 1997—</Text><P3 id="regulation-2-a"><P3para><Text>in regulation 1(2), the definition of “diving operation” shall be deleted and replaced with the following definition—</Text><BlockAmendment><Para><Text>““diving project” has the same meaning as in the Diving at Work Regulations 1997;”</Text></Para></BlockAmendment></P3para></P3></P1para></P1></Body></Primary></Legislation>|
      ])

    assert [%{operation: :substituted, level: :words, targets: ["reg.1(2)"]}] =
             Reader.instruction(d, "regulation-2-a", %{}, [cs])
  end

  defp body_doc(amending, body),
    do:
      Doc.new(amending, [~s(<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>)])

  defp targets(rules), do: rules |> Enum.flat_map(& &1.targets) |> Enum.uniq() |> Enum.sort()

  test "a container whose verb follows its items of words: words repealed, never the section whole (LGSA 1994 Sch.13 para.119(10) on the Water (Scotland) Act 1980 s.17)" do
    wsa = Reader.law_ref("UK_ukpga_1980_45", "Water (Scotland) Act", "s")

    d =
      body_doc(
        "UK_ukpga_1994_39",
        ~S|<P1 id="section-1"><P1para><Text>The Water (Scotland) Act 1980 is amended as follows.</Text><P2 id="section-1-10"><P2para><Text>In section 17 (acquisition of water rights)—</Text><P3 id="section-1-10-a"><P3para><Text>in subsection (1), the words “or water development board”;</Text></P3para></P3><P3 id="section-1-10-b"><P3para><Text>in subsection (2), the words “or board”;</Text></P3para></P3><Text>shall cease to have effect.</Text></P2para></P2></P1para></P1>|
      )

    rules = Reader.instruction(d, "section-1-10", %{}, [wsa])
    assert rules != []
    assert Enum.all?(rules, &(&1.level == :words))
  end

  test "a range of brackets is every bracket between: \"in paragraphs (1)(b)(i) to (iii)\" (SI 2019/696 Sch.12 para 8(a) on SI 2008/1597 reg.12)" do
    smr = Reader.law_ref("UK_uksi_2008_1597", "Supply of Machinery (Safety) Regulations", "reg")

    d =
      body_doc(
        "UK_uksi_2019_696",
        ~S|<P1 id="regulation-8"><P1para><Text>In regulation 12 (Annex IV machinery) of the Supply of Machinery (Safety) Regulations 2008—</Text><P3 id="regulation-8-a"><P3para><Text>in the heading and in paragraphs (1)(b)(i) to (iii) for “published harmonised” substitute “designated”;</Text></P3para></P3></P1para></P1>|
      )

    ts = targets(Reader.instruction(d, "regulation-8-a", %{}, [smr]))
    assert "reg.12(1)(b)(ii)" in ts
    assert "reg.12(1)(b)(i)" in ts and "reg.12(1)(b)(iii)" in ts
  end

  test "\"In the provisions mentioned in sub-paragraph (6)\": the amending law's own sub-paragraph, never a place in the amended law (SSI 2005/383 Sch.1 para 7(5))" do
    cgsa = Reader.law_ref("UK_ukpga_1982_45", "Civic Government (Scotland) Act", "s")

    d =
      body_doc(
        "UK_ssi_2005_383",
        ~S|<P1 id="regulation-7"><P1para><Text>The Civic Government (Scotland) Act 1982 is amended as follows.</Text><P2 id="regulation-7-5"><P2para><Text>In the provisions mentioned in sub-paragraph (6), for “the fire authority” substitute “an employee of the appropriate authority”.</Text></P2para></P2></P1para></P1>|
      )

    refute "s.5(6)" in targets(Reader.instruction(d, "regulation-7-5", %{}, [cgsa]))
  end

  describe "a quote as the body of the provision named: only that number, starting at (1) or (a)" do
    @regs Reader.law_ref(
            "UK_uksi_2000_1335",
            "Merchant Shipping (Safe Manning) Regulations",
            "reg"
          )

    defp body_rules(words, quote) do
      d =
        body_doc(
          "UK_uksi_2005_1",
          ~s|<P1 id="regulation-2"><P1para><Text>The Merchant Shipping (Safe Manning) Regulations 2000 are amended as follows.</Text><P2 id="regulation-2-1"><P2para><Text>#{words}</Text><BlockAmendment>#{quote}</BlockAmendment></P2para></P2></P1para></P1>|
        )

      targets(Reader.instruction(d, "regulation-2-1", %{}, [@regs]))
    end

    test "\"For regulation 10 substitute— (1) … (2)\" is reg.10's body (SI 2000/1335 reg.16, kept)" do
      ts =
        body_rules(
          "For regulation 10 there shall be substituted—",
          ~S|<P2><Pnumber>1</Pnumber><P2para><Text>one</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>two</Text></P2para></P2>|
        )

      assert "reg.10(1)" in ts and "reg.10(2)" in ts
    end

    test "\"for regulation 45 and its chapeau, substitute— 80 …\": never reg.45(80)" do
      ts =
        body_rules(
          "for regulation 45 and its chapeau, substitute—",
          ~S|<P1><Pnumber>80</Pnumber><P1para><Text>eighty</Text></P1para></P1>|
        )

      refute "reg.45(80)" in ts
    end

    test "\"For regulation 15a substitute— (1) (2)\": never reg.15(1)" do
      ts =
        body_rules(
          "For regulation 15a substitute—",
          ~S|<P2><Pnumber>1</Pnumber><P2para><Text>one</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>two</Text></P2para></P2>|
        )

      refute "reg.15(1)" in ts
    end
  end

  test "an aside \"as it has effect before section 5(8) of the Housing and Planning Act 2016 comes into force\" names neither the law nor a place (asc 2023/3 Sch.13 para 72 on TCPA 1990 s.70(3))" do
    tcpa = Reader.law_ref("UK_ukpga_1990_8", "Town and Country Planning Act", "s")
    hpa = Reader.law_ref("UK_ukpga_2016_22", "Housing and Planning Act", "s")

    d =
      body_doc(
        "UK_asc_2023_3",
        ~S|<P1 id="section-72"><P1para><P2 id="section-72-1"><P2para><Text>The Town and Country Planning Act 1990 is amended as follows.</Text></P2para></P2><P2 id="section-72-2"><P2para><Text>In section 70(3), as it has effect before section 5(8) of the Housing and Planning Act 2016 (c. 22) comes into force, after “Planning (Listed Buildings and Conservation Areas) Act 1990” insert “, to section 160 of the Historic Environment (Wales) Act 2023”.</Text></P2para></P2></P1para></P1>|
      )

    rules = Reader.instruction(d, "section-72-2", %{}, [tcpa, hpa])
    assert [%{amends: "UK_ukpga_1990_8", targets: ts}] = rules
    assert "s.70(3)" in ts
    refute Enum.any?(ts, &String.starts_with?(&1, "s.5"))
  end
end

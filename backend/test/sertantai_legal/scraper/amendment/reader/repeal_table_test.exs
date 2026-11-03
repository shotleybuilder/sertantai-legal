defmodule SertantaiLegal.Scraper.Amendment.Reader.RepealTableTest do
  @moduledoc "Repeals tables read into rules (decomposed from Amendment.Reader, run time 2026-10-25); the reader delegates."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.RepealTable

  test "AR-06: a repeals-table line quoting words or naming a definition or entry is words; naming a provision beside a quote is the provision (1991 c.34 Sch 19)" do
    d =
      Doc.new("UK_ukpga_1991_34", [
        ~S"""
        <Legislation><Primary><Schedules><Schedule id="schedule-19"><Tabular><table><tbody>
        <tr><th>Chapter</th><th>Short title</th><th>Extent of repeal</th></tr>
        <tr><td>1982 c. 16</td><td>Civic Government (Scotland) Act 1982</td><td><Para><Text>In section 53(1)(a) “114”.</Text></Para><Para><Text>In section 63(6), the definition of “statutory provision”.</Text></Para><Para><Text>In section 86, the entry relating to the expression “licensing authority”.</Text></Para><Para><Text>In section 33(3)(a), sub-paragraph (ii) and the preceding “and”.</Text></Para><Para><Text>Section 40.</Text></Para><Para><Text>In section 130, in subsection (1) “, in place of the Commission”.</Text></Para><Para><Text>In section 10, in subsection (1), the words “or water development board”.</Text></Para><Para><Text>In section 31, in subsection (1), the words “, other than a district council,” and, in subsection (2), the words “or a council”.</Text></Para><Para><Text>In section 109, in subsection (1) the definitions of “bridge authority” and “street”; and subsection (2).</Text></Para></td></tr>
        </tbody></table></Tabular></Schedule></Schedules></Primary></Legislation>
        """
      ])

    law = Reader.law_ref("UK_ukpga_1982_16", "Civic Government (Scotland) Act", "s")
    rules = RepealTable.repeal_table(d, "schedule-19", [law])
    level = fn target -> for r <- rules, target in r.targets, do: r.level end

    assert level.("s.53(1)(a)") == [:words]
    assert level.("s.63(6)") == [:words]
    assert level.("s.86") == [:words]
    assert level.("s.33(3)(a)(ii)") == [:provision]
    assert level.("s.40") == [:provision]
    # "in subsection (1)" is where the words are: words, on that subsection
    assert level.("s.130(1)") == [:words]
    assert level.("s.10(1)") == [:words]
    # two places: a target each, never one path s.31(1)(2)
    assert level.("s.31(1)") == [:words]
    assert level.("s.31(2)") == [:words]
    # a definition beside a provision named: the provision stays repealed
    assert level.("s.109(2)") == [:provision]
  end

  test "repeal_table?/2: a Schedule of repeals is a table; a provision is not" do
    d =
      Doc.new("UK_ukpga_1991_34", [
        ~S|<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>x</Text></P1para></P1></Body><Schedules><Schedule id="schedule-19"><Tabular><table><tbody><tr><th>Chapter</th><th>Short title</th><th>Extent of repeal</th></tr><tr><td>1982 c. 16</td><td>Civic Government (Scotland) Act 1982</td><td>Section 40.</td></tr></tbody></table></Tabular></Schedule></Schedules></Primary></Legislation>|
      ])

    assert RepealTable.repeal_table?(d, "schedule-19")
    refute RepealTable.repeal_table?(d, "section-1")
    assert Reader.repeal_table?(d, "schedule-19")
  end

  describe "repeals tables the header test missed" do
    defp table(law, id, title, rows) do
      cells = fn row -> Enum.map_join(row, "", &"<td>#{&1}</td>") end

      Doc.new(law, [
        ~s(<Legislation><Secondary><Schedules><Schedule id="#{id}"><Title>#{title}</Title><Tabular><table><tbody>) <>
          Enum.map_join(rows, "", &"<tr>#{cells.(&1)}</tr>") <>
          ~s(</tbody></table></Tabular></Schedule></Schedules></Secondary></Legislation>)
      ])
    end

    defp targets(rules, level),
      do: rules |> Enum.filter(&(&1.level == level)) |> Enum.flat_map(& &1.targets) |> Enum.sort()

    @factories Reader.law_ref("UK_ukpga_1961_34", "Factories Act", "s")
    @mines Reader.law_ref("UK_ukpga_1954_70", "Mines and Quarries Act", "s")

    test "a column-numbering row above the header (SI 1992/2932 Sch. 1)" do
      d =
        table("UK_uksi_1992_2932", "schedule-1", "SCHEDULE 1 REPEALS", [
          ["(1)", "(2)", "(3)"],
          ["Chapter", "Short title", "Extent of repeal"],
          ["1961 c. 34 .", "The Factories Act 1961.", "Sections 12 to 16."]
        ])

      assert RepealTable.repeal_table?(d, "schedule-1")

      assert targets(RepealTable.repeal_table(d, "schedule-1", [@factories]), :provision) == [
               "s.12..s.16"
             ]
    end

    test "\"Column 1 | Column 2\" above a one-law table (SI 1988/1657 Sch. 8)" do
      d =
        table(
          "UK_uksi_1988_1657",
          "schedule-8",
          "SCHEDULE 8 REPEALS PART I repeals of the provisions of the mines and quarries act 1954",
          [
            ["Column 1", "Column 2"],
            ["Provision", "Extent of repeal"],
            ["Section 112.", "The whole section."]
          ]
        )

      assert targets(RepealTable.repeal_table(d, "schedule-8", [@factories, @mines]), :provision) ==
               ["s.112"]
    end

    test "one law's provisions, the law in the schedule's title (SI 1974/1941, 1975/1012, 1976/2005)" do
      d =
        table("UK_uksi_1974_1941", "schedule-1", "SCHEDULE 1 REPEALS—THE FACTORIES ACT 1961", [
          ["Provision", "Extent of repeal"],
          ["Section 1.", "Subsection (5)."],
          ["Section 9 and 10.", "The whole section in each case."],
          ["Sections 40 to 52.", "The whole section in each case."],
          [
            "Section 42.",
            "Subsections (11) and (12). Subsection (13) except in relation to offences committed before 1st January 1977."
          ],
          ["Section 53.", "The whole section, so far as still in operation."],
          [
            "Section 125.",
            "In subsection (2), paragraph (h) and the words in paragraph (j) “and the provisions”."
          ],
          ["Section 119", "The words “ (notwithstanding that a certificate)”."]
        ])

      rules = RepealTable.repeal_table(d, "schedule-1", [@mines, @factories])
      assert Enum.all?(rules, &(&1.amends == "UK_ukpga_1961_34"))

      assert targets(rules, :provision) ==
               Enum.sort([
                 "s.1(5)",
                 "s.9",
                 "s.10",
                 "s.40..s.52",
                 "s.42(11)",
                 "s.42(12)",
                 "s.42(13)",
                 "s.53",
                 "s.125(2)(h)"
               ])

      assert targets(rules, :words) == ["s.119", "s.125(2)(j)"]
    end

    test "one law's provisions, no law named and several laws: nothing read" do
      d =
        table("UK_uksi_1974_1941", "schedule-1", "SCHEDULE 1 REPEALS", [
          ["Provision", "Extent of repeal"],
          ["Section 1.", "Subsection (5)."]
        ])

      assert RepealTable.repeal_table(d, "schedule-1", [@mines, @factories]) == []

      assert targets(RepealTable.repeal_table(d, "schedule-1", [@factories]), :provision) == [
               "s.1(5)"
             ]
    end

    test "a header \"Provision\" over rows naming laws is a law-column table (Sentencing Act 2020 Sch. 29)" do
      d =
        table("UK_ukpga_2020_17", "schedule-29", "SCHEDULE 29 Repeals and revocations", [
          ["Provision", "Extent of repeal or revocation"],
          ["Factories Act 1961 (c. 34)", "Section 37."],
          ["Mines and Quarries Act 1954 (c. 70)", "Section 1."]
        ])

      rules = RepealTable.repeal_table(d, "schedule-29", [@factories, @mines])

      assert for(r <- rules, do: {r.amends, r.targets}) |> Enum.sort() ==
               [{"UK_ukpga_1954_70", ["s.1"]}, {"UK_ukpga_1961_34", ["s.37"]}]
    end

    test "the law in a Schedule's TitleBlock (SI 1974/1941 Sch. 1, as legislation.gov.uk marks it up)" do
      d =
        Doc.new("UK_uksi_1974_1941", [
          ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>REPEALS—THE FACTORIES ACT 1961</Title></TitleBlock><ScheduleBody><Tabular><table><tbody>| <>
            ~S|<tr><th>Provision</th><th>Extent of repeal</th></tr><tr><td>Section 1.</td><td>Subsection (5).</td></tr>| <>
            ~S|</tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|
        ])

      assert targets(RepealTable.repeal_table(d, "schedule-1", [@mines, @factories]), :provision) ==
               ["s.1(5)"]
    end

    test "a list of sections is each section; a qualification's brackets name nothing (SI 1989/2169, 1992/2932, 1992/2793)" do
      d =
        table("UK_uksi_1989_2169", "schedule-6", "SCHEDULE 6", [
          ["Chapter", "Short title", "Extent of repeal"],
          [
            "1961 c. 34.",
            "The Factories Act 1961.",
            "Sections 32, 33, 35 and 36.<br/>Sections 12 to 16, 17 and 19.<br/>Sections 125(2)(a), 127(2)(c).<br/>Section 72 except insofar as the prohibition applies to any person (4)."
          ]
        ])

      assert targets(RepealTable.repeal_table(d, "schedule-6", [@factories]), :provision) ==
               Enum.sort(
                 ["s.12..s.16", "s.17", "s.19", "s.32", "s.33", "s.35", "s.36", "s.72"] ++
                   ["s.125(2)", "s.125(2)(a)", "s.125(a)", "s.127(2)", "s.127(2)(c)", "s.127(c)"]
               )
    end

    test "a range of brackets and those after it (\"Section 146(2) to (5) and (7).\")" do
      d =
        table("UK_ukpga_2009_23", "schedule-22", "SCHEDULE 22 Repeals", [
          ["Chapter", "Short title", "Extent of repeal"],
          ["1961 c. 34.", "The Factories Act 1961.", "Section 146(2) to (5) and (7)."]
        ])

      assert targets(RepealTable.repeal_table(d, "schedule-22", [@factories]), :provision) ==
               ["s.146(2)..s.146(5)", "s.146(7)"]
    end

    test "header-less rows in a Schedule of repeals are law, title, extent (Electricity Act 1989 Sch. 18)" do
      d =
        table("UK_ukpga_1989_29", "schedule-18", "SCHEDULE 18 Repeals", [
          ["1961 c. 34.", "The Factories Act 1961.", "Section 90(2)."]
        ])

      assert targets(RepealTable.repeal_table(d, "schedule-18", [@factories]), :provision) ==
               ["s.90(2)"]

      no_title =
        table("UK_ukpga_1989_29", "schedule-1", "SCHEDULE 1", [
          ["1961 c. 34.", "x", "Section 90(2)."]
        ])

      assert RepealTable.repeal_table(no_title, "schedule-1", [@factories]) == []
    end
  end
end

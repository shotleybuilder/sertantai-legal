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
end

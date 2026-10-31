defmodule SertantaiLegal.Scraper.Amendment.Reader.SavingsTest do
  @moduledoc "A repeal the amending law's own text saves (CV-06 round 1, R2)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.{RepealTable, Savings}

  test "a table line's own saving; a limit of what is repealed saves nothing" do
    assert Savings.line?("The whole section except for the purposes of section 135.")

    assert Savings.line?(
             "Section 161(1)(a) except in relation to offences committed before 1st January 1975."
           )

    assert Savings.line?(
             "The whole section except in so far as it enables orders to be made otherwise than by statutory instrument."
           )

    refute Savings.line?("Sections 73 to 75, so far as not repealed by Schedule 28.")
    refute Savings.line?("The whole section, so far as still in operation.")
    refute Savings.line?("Section 37.")
  end

  test "the provision giving the Schedule effect saves the law named, not another" do
    intro =
      "27 (1) The enactments mentioned in column 2 of Part I of Schedule 2 are repealed. (2) Nothing in this regulation shall affect the operation of any provision of the Offices, Shops and Railway Premises Act 1963 as that provision has effect by virtue of section 90(4) of that Act."

    assert Savings.intro?(intro, "Offices, Shops and Railway Premises Act", "1963")
    refute Savings.intro?(intro, "Factories Act", "1961")
    refute Savings.intro?(nil, "Factories Act", "1961")
  end

  test "repeal rules carry it (SI 1992/3004 Sch. 2 by reg.27)" do
    d =
      Doc.new("UK_uksi_1992_3004", [
        ~S|<Legislation><Secondary><Body><P1group><P1 id="regulation-27"><P1para><Text>(1) The enactments mentioned in Part I of Schedule 2 are repealed. (2) Nothing in this regulation shall affect the operation of any provision of the Offices, Shops and Railway Premises Act 1963 as that provision has effect by virtue of section 90(4) of that Act.</Text></P1para></P1></P1group></Body><Schedules><Schedule id="schedule-2"><Number>SCHEDULE 2</Number><Reference>Regulation 27</Reference><TitleBlock><Title>REPEALS</Title></TitleBlock><Tabular><table><tbody><tr><th>Chapter</th><th>Short title</th><th>Extent of repeal</th></tr><tr><td>1961 c. 34.</td><td>The Factories Act 1961.</td><td>Section 1.</td></tr><tr><td>1963 c. 41.</td><td>The Offices, Shops and Railway Premises Act 1963.</td><td>Section 5.</td></tr></tbody></table></Tabular></Schedule></Schedules></Secondary></Legislation>|
      ])

    rules =
      RepealTable.repeal_table(d, "schedule-2", [
        Reader.law_ref("UK_ukpga_1961_34", "Factories Act", "s"),
        Reader.law_ref("UK_ukpga_1963_41", "Offices, Shops and Railway Premises Act", "s")
      ])

    assert for(r <- rules, into: %{}, do: {r.amends, r.saved}) ==
             %{"UK_ukpga_1961_34" => false, "UK_ukpga_1963_41" => true}
  end

  test "a one-law table's saving stays on its line; a bracket range before a saving is still a range (SI 1974/1941)" do
    alias SertantaiLegal.Scraper.Amendment.Reader.ProvisionTable

    assert ProvisionTable.lines(
             "Section 168.",
             "The whole section except for the purposes of section 135."
           ) ==
             ["Section 168 except for the purposes of section 135."]

    assert ProvisionTable.lines("Section 120.", "The whole section.") == ["Section 120."]
    assert Savings.line?("Section 168 except for the purposes of section 135.")

    d =
      Doc.new("UK_uksi_1974_1941", [
        ~S|<Legislation><Secondary><Schedules><Schedule id="schedule-1"><TitleBlock><Title>REPEALS—THE FACTORIES ACT 1961</Title></TitleBlock><Tabular><table><tbody><tr><th>Provision</th><th>Extent of repeal</th></tr><tr><td>Section 146.</td><td>Subsections (1) to (4) except for the purposes of section 148.</td></tr></tbody></table></Tabular></Schedule></Schedules></Secondary></Legislation>|
      ])

    [rule] =
      RepealTable.repeal_table(d, "schedule-1", [
        Reader.law_ref("UK_ukpga_1961_34", "Factories Act", "s")
      ])

    assert {rule.targets, rule.saved} == {["s.146(1)..s.146(4)"], true}
  end
end

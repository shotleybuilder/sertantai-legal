defmodule SertantaiLegal.Scraper.Commencement.OwnClauseThatProvisionTest do
  @moduledoc """
  A law's own commencement clause (LAT Change Pipeline, step Commencement
  reader; Waste, Water and Climate round): a provision named by "of that
  section / regulation" is the section or regulation last named, never the
  clause's own; a qualifier written before its item is that item's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.ThatProvision

  defp rows(specs) do
    for spec <- specs do
      {sid, text} =
        case spec do
          {sid, text} -> {sid, text}
          sid -> {sid, ""}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
    end
  end

  defp rules(specs, made, type, ref) do
    for r <- OwnClause.read("UK_x", %{type_code: type, rows: rows(specs), made: made}).rules,
        r.source.ref == ref,
        do: {r.treatment, r.scope}
  end

  test "\"paragraph (3) of that regulation\" after its qualifier (SI 2017/1312 reg.1(3))" do
    specs = [
      "reg.1",
      {"reg.1(2)",
       "Except as provided in paragraphs (3) and (4), these Regulations come into force 21 days after the day on which they are made."},
      {"reg.1(3)",
       "Paragraph (2) of regulation 3 and, so far as it relates to that paragraph, paragraph (3) of that regulation, and regulation 4, come into force 6 months after the day on which these Regulations are made."},
      "reg.2",
      "reg.3",
      "reg.3(1)",
      "reg.3(2)",
      "reg.3(3)",
      "reg.4"
    ]

    assert rules(specs, ~D[2017-12-19], "uksi", "reg.1(3)") == [
             {:provision_dated, ["reg.3(2)", "reg.4"]},
             {:provision_qualified, ["reg.3(3)"]}
           ]
  end

  test "\"subsection (2) of that section\" is the section last named (1988 c.33 s.171(6))" do
    specs = [
      "s.44",
      "s.160",
      "s.161",
      "s.170",
      "s.170(1)",
      "s.170(2)",
      "s.171",
      {"s.171(1)",
       "Subject to the following provisions of this section, this Act shall come into force on such day as the Secretary of State may by order made by statutory instrument appoint."},
      {"s.171(2)", "An order under this section may make such transitional provision."},
      {"s.171(6)",
       "The following provisions— section 44; sections 160 and 161; subsection (1) of section 170, so far as relating to the Sexual Offences (Amendment) Act 1976, the Protection of Children Act 1978 and section 6(5) of the Magistrates’ Courts Act 1980; subsection (2) of that section, so far as relating to the following— the Prevention of Corruption Act 1916; Schedule 3 to the Criminal Justice Act 1967; section 24(2)(e) of the Police and Criminal Evidence Act 1984, shall come into force at the end of the period of two months beginning with the day this Act is passed."}
    ]

    got = rules(specs, ~D[1988-07-29], "ukpga", "s.171(6)")
    assert {:provision_qualified, ["s.170(1)", "s.170(2)"]} in got
    refute Enum.any?(got, fn {_, scope} -> "s.171(2)" in scope end)
  end

  describe "ThatProvision.name/1" do
    test "the section last named outwards, never another Act's" do
      assert ThatProvision.name(
               "subsection (1) of section 170, so far as relating to section 6(5) of the Magistrates’ Courts Act 1980; subsection (2) of that section"
             ) =~ ~r/; section 170\(2\)$/
    end

    test "nothing named before: left as written" do
      s = "subsection (2) of that section comes into force on 1st May 2004"
      assert ThatProvision.name(s) == s
    end
  end
end

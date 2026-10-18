defmodule SertantaiLegal.Scraper.ChangeCollector.CommencementTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector.{Commencement, Record}

  test "one law-level record: the treatment, its date, the clause as evidence" do
    input = %{
      type_code: "nisr",
      rows: [
        %{
          section_id: "UK_x:reg.1",
          text: "These Regulations shall come into operation on 17th April 1995."
        }
      ]
    }

    assert [
             %Record{
               section_id: nil,
               source: "law",
               operation: "commenced",
               effect_type: "clause_date",
               effective_from: ~D[1995-04-17],
               evidence: "UK_x:reg.1",
               affecting_law: "UK_x",
               dated_by_law: "UK_x",
               via: ["instrument"]
             }
           ] = Commencement.records("UK_x", input)
  end

  test "a known limit: the treatment, no date" do
    assert [
             %Record{
               effect_type: "eu_directive",
               effective_from: nil,
               in_force: [],
               dated_by_law: nil
             }
           ] =
             Commencement.records("UK_eudr_1989_391", %{type_code: "eudr", rows: []})
  end

  defp rows(specs),
    do:
      for({sid, text} <- specs, do: %{section_id: "UK_x:" <> sid, text: text, extent_code: "GB"})

  defp provisions(input),
    do:
      for(
        r <- Commencement.records("UK_x", input),
        r.section_id != nil,
        do:
          {r.section_id, r.effect_type, r.effective_from,
           Enum.map(r.in_force, & &1["qualification"])}
      )

  test "CR-06: provision records from the evaluator — a dated provision; a qualified one partly first, fully with the law" do
    input = %{
      type_code: "uksi",
      made: ~D[2006-01-10],
      rows:
        rows([
          {"reg.1(1)", "These Regulations may be cited as the Quarries Regulations."},
          {"reg.1(2)",
           "Subject to paragraphs (3) and (4), these Regulations shall come into force on 1st April 2007."},
          {"reg.1(3)", "Regulation 12 shall come into force on 31st May 2007."},
          {"reg.1(4)",
           "Regulation 26 shall come into force on 1st April 2006 with respect to any tip which was a classified tip."},
          {"reg.12", "Duty."},
          {"reg.26", "Tips."},
          {"reg.30", "Other."}
        ])
    }

    assert [
             {"UK_x:reg.12", "provision_dated", ~D[2007-05-31], [nil]},
             {"UK_x:reg.26", "provision_dated", ~D[2007-04-01], ["for certain purposes", nil]}
           ] = provisions(input)
  end

  test "CR-06: a law commenced wholly by order leaves every row to orders" do
    input = %{
      type_code: "ukpga",
      made: ~D[2000-07-28],
      rows:
        rows([
          {"s.1", "Duty."},
          {"s.110",
           "This Act shall come into force on such day as the Secretary of State may by order appoint."}
        ])
    }

    assert [
             {"UK_x:s.1", "provision_by_order", nil, []},
             {"UK_x:s.110", "provision_by_order", nil, []}
           ] =
             provisions(input)
  end

  test "CR-06: a provision's own words date it (\"This section shall come into force on the passing of this Act\")" do
    input = %{
      type_code: "ukpga",
      made: ~D[2000-07-28],
      rows:
        rows([
          {"s.1", "Duty."},
          {"s.68(2)", "This section shall come into force on the passing of this Act."},
          {"s.110",
           "This Act (apart from this section and section 68) shall come into force on such day as the Secretary of State may by order appoint."}
        ])
    }

    assert {"UK_x:s.68(2)", "provision_dated", ~D[2000-07-28], [nil]} in provisions(input)
  end
end

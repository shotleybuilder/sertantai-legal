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
end

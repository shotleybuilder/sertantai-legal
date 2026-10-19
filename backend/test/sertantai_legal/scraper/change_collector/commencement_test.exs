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

  test "CR-06: a law with no law-level rule (no clause) — rows only a provision rule reaches" do
    input = %{
      type_code: "wsi",
      rows:
        rows([
          {"reg.1", "Duty."},
          {"reg.2(1)", "This regulation comes into force on 1st April 2024."}
        ])
    }

    assert [{"UK_x:reg.2(1)", "provision_dated", ~D[2024-04-01], [nil]}] = provisions(input)
  end

  test "CR-06: partly in on a date, the rest left to orders: by order (J6), the partial entry kept" do
    input = %{
      type_code: "ukpga",
      made: ~D[1990-11-01],
      rows:
        rows([
          {"s.164(2)",
           "Section 158 in so far as it relates to Scotland shall come into force on 1st January 1991."},
          {"s.164(3)",
           "The remainder of this Act shall come into force on such day as the Secretary of State may by order appoint."},
          {"s.158", "Duty."}
        ])
    }

    assert {"UK_x:s.158", "provision_by_order", nil, ["for certain purposes"]} in provisions(
             input
           )
  end

  test "CR-07: the law's own commencement order dates a by-order row; the feed first where it dates the row" do
    alias SertantaiLegal.Scraper.Commencement.Rule

    input = %{
      type_code: "ukpga",
      made: ~D[1981-10-30],
      rows:
        rows([
          {"s.1", "Duty."},
          {"s.2", "Duty."},
          {"s.74",
           "This Act shall come into force on such day as the Secretary of State may by order appoint."}
        ])
    }

    order =
      Rule.new(
        commences: "UK_x",
        scope: ["s.1", "s.2"],
        when: {:date, ~D[1982-09-28]},
        source: %{law: "UK_uksi_1982_1217", ref: "reg.2", text: "… section 1 …"},
        treatment: :order_date
      )

    recs =
      Commencement.records("UK_x", input, orders: [order], feed_dated: MapSet.new(["UK_x:s.2"]))

    s1 = Enum.find(recs, &(&1.section_id == "UK_x:s.1"))
    s2 = Enum.find(recs, &(&1.section_id == "UK_x:s.2"))

    assert %{
             effect_type: "provision_dated",
             effective_from: ~D[1982-09-28],
             dated_by_law: "UK_uksi_1982_1217",
             evidence: "UK_uksi_1982_1217:reg.2"
           } = s1

    assert %{effect_type: "provision_by_order", effective_from: nil} = s2
  end
end

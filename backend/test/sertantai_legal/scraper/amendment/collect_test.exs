defmodule SertantaiLegal.Scraper.Amendment.CollectTest do
  @moduledoc """
  AR-03/AR-04: the ruleset collector gives the records the row-driven
  collector gave (`ChangeCollector.AmendingLaw`, deleted at AR-04: its
  records pinned) on the LR-08 fixtures (Utilities Act 2000 on the
  Electricity Act 1989), from the document and from the read pass's store.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Collect, Reader}

  @dir "test/fixtures/amending_law"
  @law "UK_ukpga_1989_29"

  defp docs do
    doc =
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

    fn
      "UK_ukpga_2000_27" -> doc
      _ -> nil
    end
  end

  defp note(code, text, sids),
    do: %{
      code: code,
      text: text,
      citation_law: "UK_ukpga_2000_27",
      affected_sections: Enum.map(sids, &"#{@law}:#{&1}")
    }

  defp key(recs),
    do:
      recs |> Enum.map(&{&1.section_id, &1.evidence, &1.operation, &1.effect_type}) |> Enum.sort()

  # the row-driven collector's records on these fixtures (AR-03 gate)
  @pinned [
    {"UK_ukpga_1989_29:s.25(5A)", "ukpga/2000/27/section/60/5", "inserted", "inserted"},
    {"UK_ukpga_1989_29:s.36", "ukpga/2000/27/schedule/8", "repealed", "repealed"},
    {"UK_ukpga_1989_29:s.40(2)", "ukpga/2000/27/schedule/6/paragraph/33/c", "substituted",
     "words substituted"}
  ]

  test "the row-driven collector's records on the LR-08 fixtures, from the document and the store" do
    rows = ["s.25", "s.25(5)", "s.25(5A)", "s.36", "s.40", "s.40(2)"]
    sids = Enum.map(rows, &"#{@law}:#{&1}")

    notes = [
      note(
        "F1",
        "S. 25(5A) inserted (1.10.2001) by 2000 c. 27, s. 60(5); S.I. 2001/3266, art. 2",
        ["s.25(5A)"]
      ),
      note(
        "F2",
        "Words in s. 40(2) substituted by 2000 c. 27, s. 108, Sch. 6 Pt. II para. 33(c)",
        ["s.40(2)"]
      ),
      note("F3", "S. 36 repealed by 2000 c. 27, s. 108, Sch. 8", ["s.36"])
    ]

    sources = fn l -> (d = docs().(l)) && Collect.doc_source(d) end
    new = Collect.records(@law, "Electricity Act", sids, notes, MapSet.new(sids), sources)
    Collect.clear()

    assert key(new) == @pinned

    # the read pass's store gives the same records with no document at collection
    doc = docs().("UK_ukpga_2000_27")
    law = Reader.law_ref(@law, "Electricity Act", "s")
    stored = Enum.flat_map(doc.ids, &Collect.read(doc, &1, [law]))

    index = %{
      "elements" => Map.keys(doc.elements),
      "references" => Reader.references(doc)
    }

    from_store = fn
      "UK_ukpga_2000_27" -> Collect.stored_source("UK_ukpga_2000_27", index, stored)
      _ -> nil
    end

    assert key(
             Collect.records(@law, "Electricity Act", sids, notes, MapSet.new(sids), from_store)
           ) == @pinned
  end
end

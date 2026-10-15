defmodule SertantaiLegal.Scraper.ChangeCollector.AmendingLawTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ChangeCollector.{AmendingLaw, Record}

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

  defp run(notes, rows \\ ["s.25", "s.25(5)", "s.25(5A)", "s.36", "s.40", "s.40(2)"]) do
    sids = Enum.map(rows, &"#{@law}:#{&1}")
    AmendingLaw.records(@law, "Electricity Act", sids, notes, MapSet.new(sids), docs())
  end

  test "an inserted subsection: a law record from s. 60(5), dated by order → no date (hop 2)" do
    [r] =
      run([
        note(
          "F1",
          "S. 25(5A) inserted (1.10.2001) by 2000 c. 27, s. 60(5); S.I. 2001/3266, art. 2",
          ["s.25(5A)"]
        )
      ])

    assert %Record{
             law_name: @law,
             section_id: "UK_ukpga_1989_29:s.25(5A)",
             source: "law",
             evidence: "ukpga/2000/27/section/60/5",
             affecting_law: "UK_ukpga_2000_27",
             affecting_ref: "section-60-5",
             operation: "inserted",
             effect_type: "inserted",
             effective_from: nil,
             pointer: "F1",
             via: ["law_pointer"]
           } = r
  end

  test "a Schedule paragraph under the law's Part: a words substitution on s. 40(2)" do
    [r] =
      run([
        note(
          "F2",
          "Words in s. 40(2) substituted by 2000 c. 27, s. 108, Sch. 6 Pt. II para. 33(c)",
          ["s.40(2)"]
        )
      ])

    assert %Record{
             section_id: "UK_ukpga_1989_29:s.40(2)",
             effect_type: "words substituted",
             evidence: "ukpga/2000/27/schedule/6/paragraph/33/c"
           } = r
  end

  test "a repeals table: the section's repeal on its own row" do
    [r] = run([note("F3", "S. 36 repealed by 2000 c. 27, s. 108, Sch. 8", ["s.36"])])

    assert %Record{
             section_id: "UK_ukpga_1989_29:s.36",
             operation: "repealed",
             effect_type: "repealed",
             evidence: "ukpga/2000/27/schedule/8"
           } = r
  end

  test "the note points at a provision whose text doesn't name the row: no record" do
    assert run([note("F4", "S. 40(2) substituted by 2000 c. 27, s. 60(5)", ["s.40(2)"])]) == []
  end

  test "only rows asked for; the amending law not held; no law named: no record" do
    sids = ["#{@law}:s.25(5A)"]
    n = note("F1", "S. 25(5A) inserted by 2000 c. 27, s. 60(5)", ["s.25(5A)"])
    assert AmendingLaw.records(@law, "Electricity Act", sids, [n], MapSet.new(), docs()) == []

    assert AmendingLaw.records(
             @law,
             "Electricity Act",
             sids,
             [%{n | citation_law: "UK_ukpga_2001_1"}],
             MapSet.new(sids),
             docs()
           ) == []

    assert AmendingLaw.records(
             @law,
             "Electricity Act",
             sids,
             [%{n | citation_law: nil}],
             MapSet.new(sids),
             docs()
           ) == []
  end

  test "a whole Schedule that isn't a repeals table is never read as one instruction" do
    assert run([note("F5", "S. 40(2) inserted by 2000 c. 27, Sch. 6", ["s.40(2)"])]) == []
  end

  test "ChangeCollector.dated?/3: undated rows are false (gaps mode asks them), dated rows true" do
    dated = MapSet.new([{"#{@law}:s.25", "UK_ukpga_2000_27"}])

    assert SertantaiLegal.Scraper.ChangeCollector.dated?(
             dated,
             "#{@law}:s.25(5A)",
             "UK_ukpga_2000_27"
           )

    refute SertantaiLegal.Scraper.ChangeCollector.dated?(
             dated,
             "#{@law}:s.15A",
             "UK_ukpga_2000_27"
           )

    refute SertantaiLegal.Scraper.ChangeCollector.dated?(dated, "#{@law}:s.25", "UK_ukpga_1999_1")
  end

  test "hop 2: an undated record is dated by the commencing order the note names" do
    order = Doc.new("UK_uksi_2001_3266", [File.read!("#{@dir}/uksi_2001_3266.xml")])

    act =
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

    docs = fn
      "UK_ukpga_2000_27" -> act
      "UK_uksi_2001_3266" -> order
      _ -> nil
    end

    titles = fn
      "UK_ukpga_2000_27" -> "Utilities Act"
      _ -> nil
    end

    sids = ["#{@law}:s.25(5A)"]

    n =
      note(
        "F1",
        "S. 25(5A) inserted (1.10.2001) by 2000 c. 27, s. 60(5); S.I. 2001/3266, art. 2, Sch.",
        ["s.25(5A)"]
      )

    assert [
             %Record{
               effective_from: ~D[2001-10-01],
               dated_by_law: "UK_uksi_2001_3266",
               dated_by_ref: "schedule"
             } = r
           ] =
             AmendingLaw.records(
               @law,
               "Electricity Act",
               sids,
               [n],
               MapSet.new(sids),
               docs,
               titles
             )

    assert [%{"date" => "2001-10-01", "qualification" => nil}] = r.in_force
  end

  test "records/7 leaves no ETS tables behind (memory across a corpus run, LR-25)" do
    # only this process's tables: async tests create their own in parallel
    owned = fn -> Enum.count(:ets.all(), &(:ets.info(&1, :owner) == self())) end
    before = owned.()

    run([
      note(
        "F1",
        "S. 25(5A) inserted (1.10.2001) by 2000 c. 27, s. 60(5); S.I. 2001/3266, art. 2",
        ["s.25(5A)"]
      )
    ])

    assert owned.() == before
  end
end

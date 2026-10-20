defmodule SertantaiLegal.Scraper.Amendment.CollectRecordsTest do
  @moduledoc """
  The amending-law collector's records (LR-08, CR-06, CR-08), on the
  amendment ruleset since AR-04 (`Amendment.Collect` over a document
  source; the row-driven `ChangeCollector.AmendingLaw` is deleted).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Collect
  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.Commencement.Order

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

  # the collector over each amending law's document
  defp records(law, title, sids, notes, ask, docs, opts \\ []) do
    sources = fn l -> (d = docs.(l)) && Collect.doc_source(d) end
    Collect.records(law, title, sids, notes, ask, sources, opts)
  after
    Collect.clear()
  end

  defp run(notes, rows \\ ["s.25", "s.25(5)", "s.25(5A)", "s.36", "s.40", "s.40(2)"]) do
    sids = Enum.map(rows, &"#{@law}:#{&1}")
    records(@law, "Electricity Act", sids, notes, MapSet.new(sids), docs())
  end

  test "an inserted subsection: a law record from s. 60(5), no rules → no date" do
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
    assert records(@law, "Electricity Act", sids, [n], MapSet.new(), docs()) == []

    assert records(
             @law,
             "Electricity Act",
             sids,
             [%{n | citation_law: "UK_ukpga_2001_1"}],
             MapSet.new(sids),
             docs()
           ) == []

    assert records(
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

  test "ChangeCollector.asked_notes/3: a row asked about is read for every note on it (AR-04: the feed's own record may not date the row)" do
    alias SertantaiLegal.Scraper.ChangeCollector

    a = "#{@law}:s.51A(1)(a)"

    # the feed dates 2022 c.30 on (a) only with an "excluded" effect, no text change
    feed = [
      %Record{
        law_name: @law,
        section_id: a,
        source: "feed",
        evidence: "key-x",
        affecting_law: "UK_ukpga_2022_30",
        operation: "other",
        effect_type: "excluded",
        effective_from: ~D[2022-09-01]
      }
    ]

    on = fn code, law -> %{note(code, "x", []) | citation_law: law, affected_sections: [a]} end
    notes = [on.("F1", "UK_uksi_1996_1905"), on.("F2", "UK_ukpga_2022_30")]

    assert [%{code: "F1"}, %{code: "F2"}] = ChangeCollector.asked_notes(notes, feed, :gaps)
    assert [] = ChangeCollector.asked_notes([on.("F2", "UK_ukpga_2022_30")], feed, :gaps)
  end

  test "dated by the evaluator over the amending law's rules: the commencing order's (CR-06)" do
    order = Doc.new("UK_uksi_2001_3266", [File.read!("#{@dir}/uksi_2001_3266.xml")])
    rules = Order.rules(order, %{law: "UK_ukpga_2000_27", title: "Utilities Act", year: "2000"})
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
               dated_by_law: "UK_uksi_2001_3266"
             } = r
           ] =
             records(@law, "Electricity Act", sids, [n], MapSet.new(sids), docs(),
               rules: fn
                 "UK_ukpga_2000_27" -> rules
                 _ -> []
               end,
               extents: %{"#{@law}:s.25(5A)" => "E+W+S"}
             )

    assert [%{"date" => "2001-10-01", "qualification" => nil}] = r.in_force
  end

  test "ChangeCollector.with_doc_cache/1 leaves no memoised reads behind (memory across a corpus run, LR-25)" do
    sources = fn l -> (d = docs().(l)) && Collect.doc_source(d) end
    sids = ["#{@law}:s.25(5A)"]
    n = note("F1", "S. 25(5A) inserted by 2000 c. 27, s. 60(5)", ["s.25(5A)"])

    SertantaiLegal.Scraper.ChangeCollector.with_doc_cache(fn ->
      Collect.records(@law, "Electricity Act", sids, [n], MapSet.new(sids), sources)
    end)

    assert Enum.filter(Process.get_keys(), &match?({Collect, _}, &1)) == []
  end

  test "CR-06: a row the quoted text makes is inserted, not the sentence's earlier repeal (1991 c.40 s.9(1))" do
    rta = "UK_ukpga_1988_52"

    doc =
      Doc.new("UK_ukpga_1991_40", [
        ~S|<Legislation><Primary><Body><P1 id="section-9"><P1para><P2 id="section-9-1"><P2para><Text>Section 68(1) and (2) of the Road Traffic Act 1988 shall cease to have effect, and after section 66 of that Act there shall be inserted—</Text><BlockAmendment><P1group><Title>Appointment of examiners</Title><P1><Pnumber>66A</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>The Secretary of State shall appoint such examiners as he considers necessary.</Text></P2para></P2></P1para></P1></P1group></BlockAmendment></P2para></P2></P1para></P1></Body></Primary></Legislation>|
      ])

    n = %{
      code: "F1",
      text:
        "S. 66A inserted (1.7.1992) by Road Traffic Act 1991 (c. 40), s. 9(1); S.I. 1992/1286, art. 2, Sch.",
      citation_law: "UK_ukpga_1991_40",
      affected_sections: ["#{rta}:s.66A(1)"]
    }

    sids = ["#{rta}:s.66A(1)"]

    assert [%Record{operation: "inserted"}] =
             records(rta, "Road Traffic Act", sids, [n], MapSet.new(sids), fn
               "UK_ukpga_1991_40" -> doc
               _ -> nil
             end)
  end

  test "AR-04: a change to the provision named lands on the note's row inside it, words-level — never on the provision (Electricity Act s.42(1)(b); Jason option c)" do
    doc =
      Doc.new("UK_ukpga_2000_27", [
        ~S|<Legislation><Primary><Body><P1 id="section-57"><P1para><P2 id="section-57-2"><P2para><Text>In section 42(1) of the Electricity Act 1989, omit the word “and” where it last occurs.</Text></P2para></P2></P1para></P1></Body></Primary></Legislation>|
      ])

    sids = ["#{@law}:s.42(1)", "#{@law}:s.42(1)(b)"]

    n =
      note(
        "F1",
        "S. 42(1)(c) and the word “and” immediately preceding it repealed by 2000 c. 27, s. 57(2)",
        ["s.42(1)(b)"]
      )

    recs =
      records(@law, "Electricity Act", sids, [n], MapSet.new(sids), fn
        "UK_ukpga_2000_27" -> doc
        _ -> nil
      end)

    assert recs |> Enum.map(&{&1.section_id, &1.effect_type}) |> Enum.sort() == [
             {"#{@law}:s.42(1)(b)", "words repealed"}
           ]
  end

  test "AR-04: a repeal reaching the note's row only through its ancestor is words on that row; the row it names is repealed (2000 c.27 s.57(2): (c) and the \"and\" before it)" do
    doc =
      Doc.new("UK_ukpga_2000_27", [
        ~S|<Legislation><Primary><Body><P1 id="section-57"><P1para><Text>Section 42 of the Electricity Act 1989 is amended as follows.</Text><P2 id="section-57-2"><P2para><Text>In subsection (1), paragraph (c) (and the word “and” preceding it) shall cease to have effect.</Text></P2para></P2></P1para></P1></Body></Primary></Legislation>|
      ])

    sids = ["#{@law}:s.42(1)", "#{@law}:s.42(1)(b)", "#{@law}:s.42(1)(c)"]

    n =
      note(
        "F1",
        "S. 42(1)(c) and the word “and” immediately preceding it repealed by 2000 c. 27, s. 57(2)",
        ["s.42(1)(b)"]
      )

    on_c = %{n | code: "F2", affected_sections: ["#{@law}:s.42(1)(c)"]}

    recs =
      records(@law, "Electricity Act", sids, [n, on_c], MapSet.new(sids), fn
        "UK_ukpga_2000_27" -> doc
        _ -> nil
      end)

    assert recs |> Enum.map(&{&1.section_id, &1.effect_type}) |> Enum.sort() == [
             {"#{@law}:s.42(1)(b)", "words repealed"},
             {"#{@law}:s.42(1)(c)", "repealed"}
           ]
  end

  test "CR-08: a repeals table is dated by its own entry before the section introducing it (1994 c.19 Sch. 18 / s.66(8))" do
    alias SertantaiLegal.Scraper.Commencement.Rule

    rule = fn scope, w, src ->
      Rule.new(
        commences: "UK_ukpga_2000_27",
        scope: scope,
        when: w,
        source: %{law: "UK_ukpga_2000_27", ref: src, text: nil},
        treatment: :provision_dated
      )
    end

    # the introducing section on passing; the Schedule left to orders
    rules = [
      rule.(["s.108"], {:date, ~D[2000-07-28]}, "s.110(1)"),
      rule.(["sch.8"], {:appointed, "by order"}, "s.110(2)")
    ]

    sids = ["#{@law}:s.36"]

    [r] =
      records(
        @law,
        "Electricity Act",
        sids,
        [note("F3", "S. 36 repealed by 2000 c. 27, s. 108, Sch. 8", ["s.36"])],
        MapSet.new(sids),
        docs(),
        rules: fn _ -> rules end
      )

    assert %Record{effective_from: nil, in_force: []} = r
  end
end

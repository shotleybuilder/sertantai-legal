defmodule SertantaiLegal.Scraper.AmendingLaw.ReadersTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc, Operation, Text}
  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Reader}

  # AR-04: the row matchers (`Target`, `RepealTable`) are gone; their cases
  # run on the reader's rules and the evaluator, in the matchers' shape —
  # `{:ok, row reached}` | `:no_match` (a table: `{:ok, row, type}` |
  # `:no_match` | `:not_a_table`)
  defp row(sid, title), do: %{section_id: sid, title: title}

  defp law(%{section_id: sid, title: title}) do
    [name, _] = String.split(sid, ":", parts: 2)
    [_, prefix] = Regex.run(~r/:(s|reg|art|rule)\./, sid)
    Reader.law_ref(name, title, prefix)
  end

  defp match(%Text{} = text, title, terms, row) do
    text
    |> Reader.of_text(title, terms, [law(row)], %{
      law: "UK_test",
      ref: text.id,
      text: text.instruction
    })
    |> Enum.find_value(:no_match, &reached(&1, row))
  end

  defp table(doc, id, row) do
    if Reader.repeal_table?(doc, id) do
      doc
      |> Reader.repeal_table(id, [law(row)])
      |> Enum.find_value(:no_match, fn rule ->
        with {:ok, t} <- reached(rule, row),
             do: {:ok, t, if(rule.level == :words, do: "words repealed", else: "repealed")}
      end)
    else
      :not_a_table
    end
  end

  defp reached(rule, row) do
    case Evaluator.reach(rule, row.section_id) do
      {:ok, t} -> {:ok, t}
      :no_match -> nil
    end
  end

  @dir "test/fixtures/amending_law"
  defp doc,
    do:
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

  defp electricity(sid), do: row("UK_ukpga_1989_29:" <> sid, "Electricity Act")
  defp gas(sid), do: row("UK_ukpga_1986_44:" <> sid, "Gas Act")

  test "DefinedTerms: a term's law from its definition's Citation, else its title" do
    terms = DefinedTerms.of(doc())
    assert terms["the 1989 act"] == %{law: "UK_ukpga_1989_29", title: "Electricity Act 1989"}
    assert terms["the 1986 act"] == %{law: nil, title: "Gas Act 1986"}
  end

  test "LR-41: omitting definitions or entries is words-level (SI 2009/2861 reg. 12(a))" do
    assert Operation.of(%Text{id: "x", instruction: "omit the following definitions—"}) ==
             {"repealed", "words repealed"}

    assert Operation.of(%Text{
             id: "x",
             instruction: "the entry relating to the 1963 Act is omitted."
           }) ==
             {"repealed", "words repealed"}
  end

  test "Operation: the drafting verb, words-level when words are quoted or named" do
    op = fn s -> Operation.of(%Text{id: "x", instruction: s}) end

    assert op.("After subsection (5) of that section there is inserted—") ==
             {"inserted", "inserted"}

    assert op.("In subsection (2) for “public electricity supplier” there is substituted .") ==
             {"substituted", "words substituted"}

    assert op.(
             "In subsection (5) of that section, paragraphs (b) and (c) shall cease to have effect."
           ) == {"repealed", "repealed"}

    assert op.("In section 3, omit the words “the public”.") == {"repealed", "words repealed"}
    assert op.("For section 4 substitute—") == {"substituted", "substituted"}
    assert op.("The 1989 Act is amended as follows.") == nil
  end

  test "Target: the text names the row's law and provision — else no match" do
    d = doc()
    terms = DefinedTerms.of(d)
    t = fn id, row -> match(Text.of(d, id), Doc.title(d, id), terms, row) end

    # "The 1989 Act is amended" (context) + "subsection (5) of that section" (section 25) + inserted (5A)
    assert t.("section-60-5", electricity("s.25(5A)")) == {:ok, "UK_ukpga_1989_29:s.25(5A)"}
    assert t.("section-60-4", electricity("s.25(5)(b)")) == {:ok, "UK_ukpga_1989_29:s.25(5)(b)"}
    # the same instruction doesn't name section 26, nor the Gas Act
    assert t.("section-60-5", electricity("s.26(5A)")) == :no_match
    assert t.("section-60-5", gas("s.25(5A)")) == :no_match
    # a Schedule paragraph under a Part titled with the law
    assert t.("schedule-6-paragraph-33-c", electricity("s.40(2)")) ==
             {:ok, "UK_ukpga_1989_29:s.40(2)"}

    assert t.("schedule-6-paragraph-33-c", electricity("s.40(3)")) == :no_match
    # an instruction naming another law (the 1986 Act) never matches the 1989 Act
    assert t.("section-68", electricity("s.3")) == :no_match
    assert t.("section-68", gas("s.3")) == {:ok, "UK_ukpga_1986_44:s.3"}
  end

  test "RepealTable: a row of a repeals Schedule naming the row's law and provision" do
    d = doc()

    assert table(d, "schedule-8", electricity("s.36")) ==
             {:ok, "UK_ukpga_1989_29:s.36", "repealed"}

    assert table(d, "schedule-8", electricity("s.42")) ==
             {:ok, "UK_ukpga_1989_29:s.42", "repealed"}

    assert table(d, "schedule-8", electricity("s.40")) ==
             {:ok, "UK_ukpga_1989_29:s.40", "words repealed"}

    assert table(d, "schedule-8", electricity("s.37")) == :no_match
    assert table(d, "schedule-8", gas("s.36")) == :no_match
    assert table(d, "schedule-6", electricity("s.36")) == :not_a_table
    assert Reader.reference(d, "schedule-8") == "section-108"
  end

  test "RepealTable, modern form: Reference / Extent of repeal or revocation, entries per line" do
    d = Doc.new("UK_ukpga_2002_40", [File.read!("#{@dir}/ukpga_2002_40_schedules.xml")])
    row = fn sid, title -> row(sid, title) end

    assert table(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.56C(7)", "Electricity Act")
           ) ==
             {:ok, "UK_ukpga_1989_29:s.56C(7)", "repealed"}

    assert table(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.56C(6)", "Electricity Act")
           ) == :no_match

    assert table(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.57(1)", "Electricity Act")
           ) ==
             {:ok, "UK_ukpga_1989_29:s.57(1)", "words repealed"}

    assert table(
             d,
             "schedule-26",
             row.("UK_ukpga_1949_88:s.11A(1)(b)", "Registered Designs Act")
           ) ==
             {:ok, "UK_ukpga_1949_88:s.11A(1)(b)", "repealed"}

    assert table(
             d,
             "schedule-26",
             row.("UK_ukpga_1968_29:s.28(5A)", "Trade Descriptions Act")
           ) ==
             {:ok, "UK_ukpga_1968_29:s.28(5A)", "repealed"}

    assert Reader.reference(d, "schedule-26") == "section-278"
  end

  describe "LR-41: defined terms name a law only when their definition does" do
    defp tx(instruction, opts \\ []),
      do:
        struct!(
          SertantaiLegal.Scraper.AmendingLaw.Text,
          [id: "x", instruction: instruction, quoted: "", context: []] ++ opts
        )

    defp terms_of(text),
      do:
        DefinedTerms.of(
          Doc.new("UK_ukpga_1988_45", [
            ~s(<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>#{text}</Text></P1para></P1></Body></Primary></Legislation>)
          ])
        )

    test "a term defined by apposition to a law's title means that law (1988/45: “the principal Act”)" do
      terms =
        terms_of(
          ~s(Section 5 of the Firearms Act 1968 \(in this Act referred to as “<Term id="t1">the principal Act</Term>”\) shall have effect)
        )

      assert terms["the principal act"] == %{law: nil, title: "Firearms Act 1968"}

      # PCA 1991 s.1: "(referred to in this Act as …)"
      assert terms_of(
               ~s(In the Town and Country Planning Act 1990 \(referred to in this Act as “<Term id="t1">the principal Act</Term>”\) in Part VII)
             )["the principal act"] == %{law: nil, title: "Town and Country Planning Act 1990"}
    end

    test "a term whose definition names no law is not a law term (1994/39 “a”, “authority”)" do
      assert terms_of(~s(“<Term id="t1">authority</Term>” means a local authority;)) == %{}
    end

    test "only a law term stops the search, and only as whole words" do
      row = row("UK_ukpga_1991_22:s.148(3)", "New Roads and Street Works Act")
      text = tx("for subsection (3) substitute—.", context: ["In section 148 (sewers)—"])
      title = "The New Roads and Street Works Act 1991 (c.22)"

      assert match(text, title, %{"a" => %{law: nil, title: nil}}, row) ==
               {:ok, "UK_ukpga_1991_22:s.148(3)"}

      # "the 1986 act" inside "of the 1986 Actions" is not the term
      gas = %{"the 1986 act" => %{law: nil, title: "Gas Act 1986"}}

      assert match(
               tx("In section 148 of the 1986 Actions, for subsection (3) substitute—."),
               title,
               gas,
               row
             ) ==
               {:ok, "UK_ukpga_1991_22:s.148(3)"}
    end
  end

  describe "LR-41: the law named before the instruction" do
    defp pipelines(sid), do: row("UK_ukpga_1962_58:" <> sid, "Pipe-lines Act")

    test "a Schedule paragraph amends the law the body says the Schedule amends (SI 2000/1937)" do
      d =
        Doc.new("UK_uksi_2000_1937", [
          ~S|<Legislation><Secondary><Body><P1 id="regulation-2"><P1para><Text>The Pipe-lines Act 1962 is amended as set out in Schedule 1 to these Regulations.</Text></P1para></P1></Body><Schedules><Schedule id="schedule-1"><Number>Schedule 1</Number><ScheduleBody><P1 id="schedule-1-paragraph-3"><P1para><Text>In section 10(1), for the words “x” there shall be substituted “y”.</Text></P1para></P1></ScheduleBody></Schedule><Schedule id="schedule-2"><Number>Schedule 2</Number><ScheduleBody><P1 id="schedule-2-paragraph-1"><P1para><Text>In section 10(1), for the words “x” there shall be substituted “y”.</Text></P1para></P1></ScheduleBody></Schedule></Schedules></Secondary></Legislation>|
        ])

      row = pipelines("s.10(1)")

      assert match(Text.of(d, "schedule-1-paragraph-3"), nil, %{}, row) ==
               {:ok, row.section_id}

      # Schedule 2: nothing names its law
      assert match(Text.of(d, "schedule-2-paragraph-1"), nil, %{}, row) == :no_match
    end

    test "\"that Act\": the law an earlier provision names; a nearer other law stops the search (EReA 1999 s.8)" do
      d =
        Doc.new("UK_ukpga_1999_26", [
          ~S|<Legislation><Primary><Body><P1 id="section-7"><P1para><Text>Part VIII of the Pipe-lines Act 1962 is amended.</Text></P1para></P1><P1 id="section-8"><P1para><Text>In section 10 of that Act, for subsection (1) substitute “y”.</Text></P1para></P1><P1 id="section-9"><P1para><Text>The Gas Act 1986 is amended.</Text></P1para></P1><P1 id="section-10"><P1para><Text>In section 10 of that Act, for subsection (1) substitute “y”.</Text></P1para></P1></Body></Primary></Legislation>|
        ])

      row = pipelines("s.10(1)")
      assert match(Text.of(d, "section-8"), nil, %{}, row) == {:ok, row.section_id}
      assert match(Text.of(d, "section-10"), nil, %{}, row) == :no_match
    end
  end

  test "LR-41: inserting subsections into a section doesn't insert the section (PIDA 1998 s.15(2), ERA 1996 s.235)" do
    text =
      tx("In section 235 of the Employment Rights Act 1996, after subsection (2) insert—.",
        inserted: [["2A"], ["2B"]]
      )

    era = &row("UK_ukpga_1996_18:" <> &1, "Employment Rights Act")
    assert match(text, nil, %{}, era.("s.235")) == :no_match
    assert match(text, nil, %{}, era.("s.235(2A)")) == {:ok, "UK_ukpga_1996_18:s.235(2A)"}
    assert match(text, nil, %{}, era.("s.235(2)")) == :no_match

    # a paragraph added at the end of a subsection, no number in the quote (1980/60 s.20(1)(b))
    added =
      tx("at the end of the subsection there shall be added the following paragraph—",
        context: ["In section 4(3) of the Land Compensation Act 1973—"]
      )

    lca = &row("UK_ukpga_1973_26:" <> &1, "Land Compensation Act")
    assert match(added, nil, %{}, lca.("s.4")) == :no_match
    assert match(added, nil, %{}, lca.("s.4(3)")) == :no_match

    # a renumbering aside names no target (2008/32 Sch. 1 para. 8)
    renumbered =
      tx(
        "In section 13 of the Land Compensation Act 1973, after the existing provision (which becomes subsection (1)) insert—",
        inserted: [["2"]]
      )

    assert match(renumbered, nil, %{}, lca.("s.13(1)")) == :no_match

    assert match(renumbered, nil, %{}, lca.("s.13(2)")) ==
             {:ok, "UK_ukpga_1973_26:s.13(2)"}

    # "In subsection (1) … insert" is where, not what (1999/1820 → 1984/26 s.9(1))
    into_sub =
      tx(
        "In section 9 of the Land Compensation Act 1973, in subsection (1), after paragraph (b) insert—",
        inserted: [["c"]]
      )

    assert match(into_sub, nil, %{}, lca.("s.9(1)")) == :no_match

    assert match(
             tx(
               "In subsection (1) of section 9 of the Land Compensation Act 1973 there shall be added the following paragraph—"
             ),
             nil,
             %{},
             lca.("s.9(1)")
           ) == :no_match

    # the subsection named as what is inserted, quote unnumbered
    named_new =
      tx(
        "In section 9 of the Land Compensation Act 1973 there shall be inserted the following subsection (5A)—"
      )

    assert match(named_new, nil, %{}, lca.("s.9(5A)")) == {:ok, "UK_ukpga_1973_26:s.9(5A)"}

    # words inserted into a section still reach it
    words = tx("In section 4 of the Land Compensation Act 1973, after “x” insert “y”.")
    assert match(words, nil, %{}, lca.("s.4")) == {:ok, "UK_ukpga_1973_26:s.4"}
  end

  describe "LR-43: a block instruction reaches the rows inside it" do
    test "a quoted block's provisions, with no provision number named (\"For Part 13, Sub-Part C substitute—\": SI 2019/696)" do
      text =
        tx("For Part 13, Sub-Part C substitute—.",
          inserted: [["69"], ["69", "1"], ["69", "1", "a"], ["76"], ["76", "1"]],
          context: ["The Electricity Safety Regulations 2014 are amended as follows."]
        )

      m = fn sid ->
        match(
          text,
          nil,
          %{},
          row("UK_uksi_2014_1638:" <> sid, "Electricity Safety Regulations")
        )
      end

      assert m.("reg.69(1)(a)") == {:ok, "UK_uksi_2014_1638:reg.69(1)(a)"}
      assert m.("reg.76(1)") == {:ok, "UK_uksi_2014_1638:reg.76(1)"}
      assert m.("reg.80") == :no_match
    end

    test "a substituted subsection's paragraphs, the quote numbered from the subsection (\"for subsection (3) substitute—\": NRSWA 1991 s.148)" do
      text =
        tx(
          "In section 148 of the New Roads and Street Works Act 1991, for subsection (3) substitute—.",
          inserted: [["3"], ["3", "a"], ["3", "b"]]
        )

      m = fn sid ->
        match(
          text,
          nil,
          %{},
          row("UK_ukpga_1991_22:" <> sid, "New Roads and Street Works Act")
        )
      end

      assert m.("s.148(3)(a)") == {:ok, "UK_ukpga_1991_22:s.148(3)(a)"}
      assert m.("s.148(3)") == {:ok, "UK_ukpga_1991_22:s.148(3)"}
      assert m.("s.148(4)") == :no_match
    end

    test "words substituted in a subsection land on the subsection, not its paragraphs" do
      text =
        tx("In section 148(3) of the New Roads and Street Works Act 1991, for “x” substitute .",
          quoted: "y"
        )

      assert match(
               text,
               nil,
               %{},
               row("UK_ukpga_1991_22:s.148(3)(a)", "New Roads and Street Works Act")
             ) == {:ok, "UK_ukpga_1991_22:s.148(3)"}
    end
  end

  describe "Target truth guards (benchmark review)" do
    test "inserted words beginning 'a' are not an inserted paragraph (a) (1990/43 s.6(2)(a))" do
      text =
        tx(
          "In section 6 of the Environmental Protection Act 1990, in subsection (2) after the words “shall be accompanied by” there shall be inserted—.",
          quoted: "a fee and a charge"
        )

      # the note on (a) lands on s.6(2), the provision named (AR-04, Jason
      # 2026-10-20 "Parent"), never on an inserted (a)
      row = row("UK_ukpga_1990_43:s.6(2)(a)", "Environmental Protection Act")
      assert match(text, nil, %{}, row) == {:ok, "UK_ukpga_1990_43:s.6(2)"}

      assert match(
               text,
               nil,
               %{},
               row("UK_ukpga_1990_43:s.6(2)", "Environmental Protection Act")
             ) == {:ok, "UK_ukpga_1990_43:s.6(2)"}
    end

    test "an inserted provision's own number counts (Pnumber in the quote)" do
      text =
        tx("In section 98(2) after paragraph (c) insert—.",
          inserted: [["ca"]],
          context: ["In the Water Industry Act 1991—"]
        )

      assert match(
               text,
               nil,
               %{},
               row("UK_ukpga_1991_56:s.98(2)(ca)", "Water Industry Act")
             ) == {:ok, "UK_ukpga_1991_56:s.98(2)(ca)"}
    end

    test "a law named only in quoted old words doesn't count; the nearest law-naming text decides" do
      row = row("UK_ukpga_1990_43:s.142(7)", "Environmental Protection Act")
      quoted_old = tx("In section 142(7), for “Explosive Substances Act 1875” substitute .")

      assert match(quoted_old, "Environmental Protection Act 1990", %{}, row) ==
               {:ok, "UK_ukpga_1990_43:s.142(7)"}

      other = tx("In section 142(7) of the Gas Act 1986, for “x” substitute .")
      assert match(other, "Environmental Protection Act 1990", %{}, row) == :no_match
    end
  end

  test "an inserted provision matches by its full path in the quote, not by numbers found anywhere in it" do
    xml =
      ~s(<Legislation><Primary><Body><P1 id="section-35"><P1para><Text>After section 11 of the Electricity Act 1989 there is inserted—</Text><BlockAmendment><P1group><P1><Pnumber>11A</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><P3><Pnumber>b</Pnumber></P3></P2para></P2><P2><Pnumber>7</Pnumber><P2para><Text>text</Text></P2para></P2></P1para></P1></P1group></BlockAmendment></P1para></P1></Body></Primary></Legislation>)

    d = Doc.new("UK_ukpga_2000_27", [xml])
    t = Text.of(d, "section-35")
    assert t.inserted == [["11A"], ["11A", "1"], ["11A", "1", "b"], ["11A", "7"]]

    m = fn sid ->
      match(t, nil, %{}, row("UK_ukpga_1989_29:" <> sid, "Electricity Act"))
    end

    assert m.("s.11A(1)(b)") == {:ok, "UK_ukpga_1989_29:s.11A(1)(b)"}
    assert m.("s.11A(7)") == {:ok, "UK_ukpga_1989_29:s.11A(7)"}
    # (7)(b) isn't in the inserted text: added later by another law
    # (AR-04: a row inside an inserted provision lands on the provision —
    # Jason 2026-10-20 "Parent" — never on the row itself)
    assert m.("s.11A(7)(b)") == {:ok, "UK_ukpga_1989_29:s.11A(7)"}
  end
end

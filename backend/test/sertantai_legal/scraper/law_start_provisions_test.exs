defmodule SertantaiLegal.Scraper.LawStartProvisionsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Provisions

  defp rows(specs),
    do:
      for(
        spec <- specs,
        do:
          case spec do
            {sid, text, part, chapter} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: chapter}

            {sid, text, part} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part}

            {sid, text} ->
              %{section_id: "UK_x:" <> sid, text: text, part: nil}

            sid ->
              %{section_id: "UK_x:" <> sid, text: "", part: nil}
          end
      )

  # the provision records the commencement collector writes (CR-06: the
  # evaluator over the clause's rules), grouped as {treatment, date, rows}
  defp assign(specs, opts \\ []) do
    rs = rows(specs)

    input = %{
      type_code: Keyword.get(opts, :type, "uksi"),
      rows: rs,
      made: Keyword.get(opts, :made)
    }

    "UK_x"
    |> SertantaiLegal.Scraper.ChangeCollector.Commencement.records(input)
    |> Enum.filter(&String.starts_with?(&1.effect_type, "provision_"))
    |> Enum.group_by(&{&1.effect_type, &1.effective_from, &1.section_id == nil, &1.evidence})
    |> Map.values()
    |> Enum.map(fn [r | _] = rs ->
      {String.to_atom(r.effect_type), r.effective_from,
       for(x <- rs, x.section_id != nil, do: String.replace(x.section_id, "UK_x:", ""))}
    end)
  end

  test "the catalogue lists each provision treatment once" do
    ids = Enum.map(LawStart.provision_catalogue(), &elem(&1, 0))

    assert ids ==
             ~w(provision_dated provision_by_order provision_qualified provision_unread schedule_effect)a
  end

  test "named exceptions with a made-relative date (uksi 2015/1947 art. 1(3))" do
    got =
      assign(
        [
          {"reg.1(2)",
           "Subject to paragraph (3), this Order comes into force on the first day of the month following that in which it is made."},
          {"reg.1(3)",
           "Articles 45(4)(d) and (5)(a) and 48 come into force on the first day of the second month following that in which this Order is made."},
          "reg.45",
          "reg.45(4)",
          "reg.45(4)(d)",
          "reg.45(5)(a)",
          "reg.45(6)",
          "reg.48",
          "reg.48(1)"
        ],
        made: ~D[2015-11-26]
      )

    assert got == [
             {:provision_dated, ~D[2016-01-01], ~w[reg.45(4)(d) reg.45(5)(a) reg.48 reg.48(1)]}
           ]
  end

  test "named on Royal Assent, the other provisions by order; the clause's own section keeps the law's start (asp 2024/14-like)" do
    got =
      assign(
        [
          "s.1",
          "s.62",
          "s.63",
          {"s.64(1)",
           "This section and sections 62 and 63 come into force on the day after Royal Assent."},
          {"s.64(2)",
           "The other provisions of this Act come into force on such day as the Scottish Ministers may by regulations appoint."}
        ],
        type: "asp",
        made: ~D[2024-11-12]
      )

    assert {:provision_dated, ~D[2024-11-13], ~w[s.62 s.63 s.64(1) s.64(2)]} in got
    assert {:provision_by_order, nil, ~w[s.1]} in got
  end

  test "a range of regulations" do
    got =
      assign([
        {"reg.1", "These Regulations come into force on 1st October 2025."},
        {"reg.1(2)", "Regulations 17 to 19 come into force on 15th September 2025."},
        "reg.16",
        "reg.17",
        "reg.18",
        "reg.18(1)",
        "reg.19",
        "reg.20"
      ])

    assert got == [{:provision_dated, ~D[2025-09-15], ~w[reg.17 reg.18 reg.18(1) reg.19]}]
  end

  test "\", and\" separates a list's items (SI 2004/3386 reg.1, CV-S08 round 1)" do
    got =
      assign([
        {"reg.1",
         "These Regulations come into force on 17th January 2005, except for regulations 2(a), (c) and (h), and 4(b), which shall come into force on 6th April 2005."},
        "reg.2",
        "reg.2(a)",
        "reg.2(b)",
        "reg.2(c)",
        "reg.2(h)",
        "reg.4",
        "reg.4(a)",
        "reg.4(b)"
      ])

    assert {:provision_dated, ~D[2005-04-06], ~w[reg.2(a) reg.2(c) reg.2(h) reg.4(b)]} in got
  end

  test "\"except …\" is subtracted from the remaining provisions (asp 2003/8)" do
    got =
      assign(
        [
          "s.1",
          "s.54",
          "s.57",
          {"s.60",
           "The provisions of this Act, except sections 54 and 57 and this section, come into force on such day as the Scottish Ministers may by order appoint."}
        ],
        type: "asp"
      )

    assert got == [{:provision_by_order, nil, ~w[s.1]}]
  end

  test "a Part, in Roman or Arabic" do
    got =
      assign([
        {"reg.1(2)",
         "These Regulations shall, except as provided by paragraph (3) below, come into force on 3rd August 1994."},
        {"reg.1(3)", "Part II of these Regulations shall come into force on 1st January 1995."},
        {"reg.2", "", "I"},
        {"reg.5", "", "II"},
        {"reg.5(1)", "", "II"}
      ])

    assert got == [{:provision_dated, ~D[1995-01-01], ~w[reg.5 reg.5(1)]}]
  end

  test "a qualified commencement is a partial rule: fully in force once the general one has started too (CR-03, replaces LR-34 D2)" do
    got =
      assign([
        {"reg.1(1)",
         "These Regulations may be cited as the Quarries Regulations (Northern Ireland) 2006 and, subject to paragraphs (2) and (3), shall come into operation on 1st August 2006."},
        {"reg.1(2)",
         "Regulation 26, with the exception of paragraph (4), shall come into operation on 1st August 2007 with respect to any tip which was not a classified tip."},
        "reg.26",
        "reg.26(4)"
      ])

    assert got == [{:provision_dated, ~D[2007-08-01], ~w[reg.26]}]
  end

  test "a law commenced wholly by order: every row (D1 b)" do
    got =
      assign(
        [
          {"art.1(2)",
           "This Order shall come into operation on such day or days as the Department may by order appoint."},
          "art.2"
        ],
        type: "nisi"
      )

    assert got == [{:provision_by_order, nil, ~w[art.1(2) art.2]}]
  end

  test "a list read item by item; inline after \"namely—\"; a qualified item partly in force, the rest by order: J6 (EPA 1990 s.164)" do
    got =
      assign(
        [
          "s.79",
          "s.80",
          "s.97",
          "s.105",
          "s.150",
          {"s.164(2)",
           "The following provisions of the Act shall come into force at the end of the period of two months beginning with the day on which it is passed, namely— sections 79 to 80; section 97; section 105 in so far as it relates to paragraphs 7 and 13 of Schedule 5;"},
          {"s.164(3)",
           "The remainder of this Act (except this section) shall come into force on such day as the Secretary of State may by order appoint."}
        ],
        type: "ukpga",
        made: ~D[1990-11-01]
      )

    assert {:provision_dated, ~D[1991-01-01], ~w[s.79 s.80 s.97]} in got
    assert {:provision_by_order, nil, ~w[s.105]} in got
    assert {:provision_by_order, nil, ~w[s.150]} in got
  end

  test "\"This Part\", \"on the passing of this Act\", \"The preceding provisions\" (ukpga 2003/20-like)" do
    got =
      assign(
        [
          {"s.1", "", "1"},
          {"s.104", "", "5"},
          {"s.120(1)",
           "Subject to subsections (5) to (8), the preceding provisions of this Act shall come into force in accordance with provision made by the Secretary of State by order.",
           "6"},
          {"s.120(5)", "Section 104 shall come into force on the passing of this Act.", "6"},
          {"s.121", "", "6"}
        ],
        type: "ukpga",
        made: ~D[2003-07-10]
      )

    assert {:provision_dated, ~D[2003-07-10], ~w[s.104]} in got
    # s.121 comes after the clause: not a preceding provision (CV-S04)
    assert {:provision_by_order, nil, ~w[s.1]} in got

    got =
      assign(
        [
          {"s.1", "", "1"},
          {"s.92(1)",
           "This Part comes into force on the day after the day on which this Act receives Royal Assent.",
           "4"},
          {"s.90", "", "4"}
        ],
        type: "asc",
        made: ~D[2025-09-11]
      )

    assert {:provision_dated, ~D[2025-09-12], ~w[s.92(1) s.90]} in got
  end

  test "an inline list after a colon (asp 2024/13)" do
    got =
      assign(
        [
          "s.26",
          "s.27",
          "s.28",
          "s.1",
          {"s.27(1)",
           "The following provisions come into force on the day after Royal Assent: this section and sections 26 and 28."}
        ],
        type: "asp",
        made: ~D[2024-08-08]
      )

    assert {:provision_dated, ~D[2024-08-09], ~w[s.26 s.27 s.28 s.27(1)]} in got
  end

  test "another law's provisions are never this law's rows (wsi 2024/207, a commencement order)" do
    got =
      assign([
        {"reg.1", "These Regulations come into force on 1st April 2024."},
        {"reg.1(2)", "Section 3 of the 2022 Act comes into force on 6 April 2024."},
        "reg.3"
      ])

    assert [{:provision_unread, nil, []}] = got
  end

  test "a Chapter of a Part, an item's own except, a named regulation over its Part (wsi 2026/103)" do
    got =
      assign(
        [
          {"reg.1(2)",
           "Except as provided in paragraphs (3) and (4), these Regulations come into force on 1 October 2027.",
           "1"},
          {"reg.1(3)",
           "The following provisions come into force on the day after the day on which these Regulations are made—",
           "1"},
          {"reg.1(3)(a)", "this Part;", "1"},
          {"reg.1(3)(b)", "Chapter 1 of Part 6 (items subject to overseas schemes);", "1"},
          {"reg.1(3)(c)", "Part 7 (the scheme administrator), except regulation 73;", "1"},
          {"reg.1(4)",
           "Regulation 73 (reuse of returned refund items) comes into force on 1 October 2030.",
           "1"},
          {"reg.50", "", "6", "1"},
          {"reg.60", "", "6", "2"},
          {"reg.70", "", "7"},
          {"reg.73", "", "7"}
        ],
        made: ~D[2026-03-25]
      )

    assert {:provision_dated, ~D[2026-03-26],
            ~w[reg.1(2) reg.1(3) reg.1(3)(a) reg.1(3)(b) reg.1(3)(c) reg.1(4) reg.50 reg.70]} in got

    assert {:provision_dated, ~D[2030-10-01], ~w[reg.73]} in got
    refute Enum.any?(got, fn {_, _, ids} -> "reg.60" in ids end)
  end

  test "a Schedule's commencement is read (its rule: `sch.3`), though no LAT row holds it (CV-S04)" do
    got =
      assign([
        {"reg.1(1)", "These Regulations come into force on 1st June 2015."},
        {"reg.1(2)", "Schedule 3 comes into force on 1st June 2016."}
      ])

    assert got == []

    rules =
      SertantaiLegal.Scraper.Commencement.OwnClause.rules("UK_x", %{
        type_code: "uksi",
        rows: [
          %{
            section_id: "UK_x:reg.1(1)",
            text: "These Regulations come into force on 1st June 2015.",
            part: nil,
            chapter: nil
          },
          %{
            section_id: "UK_x:reg.1(2)",
            text: "Schedule 3 comes into force on 1st June 2016.",
            part: nil,
            chapter: nil
          }
        ]
      })

    assert Enum.any?(rules, &(&1.scope == ["sch.3"] and &1.when == {:date, ~D[2016-06-01]}))
  end

  test "provisions the reader can't resolve: listed for the law" do
    got =
      assign([
        {"reg.1(1)", "These Regulations come into force on 1st June 2015."},
        {"reg.1(2)", "The provisions mentioned below come into force on 1st June 2016."}
      ])

    assert [{:provision_unread, nil, []}] = got
  end

  test "a place inside a parenthesis doesn't qualify the sentence (uksi 2017/1200 reg.2(2))" do
    got =
      assign([
        {"reg.2(1)",
         "These Regulations (except Parts 2 and 3) come into force on 1st January 2018."},
        {"reg.2(2)",
         "Parts 2 and 3 (which are about civil enforcement except in Scotland and the Scottish offshore area) come into force on 1st April 2018."},
        {"reg.7", "", "2"},
        {"reg.20", "", "3"}
      ])

    assert got == [{:provision_dated, ~D[2018-04-01], ~w[reg.7 reg.20]}]
  end

  test "\"comes into force in Wales on …\" is partial: fully in force once the law's general date has started too" do
    got =
      assign([
        {"reg.1(1)", "These Regulations come into force on 1st April 2020."},
        {"reg.1(2)", "Regulation 5 comes into force in Wales on 1st October 2020."},
        "reg.5"
      ])

    assert got == [{:provision_dated, ~D[2020-10-01], ~w[reg.5]}]
  end

  test "CR-06: a power's condition or description names no provision (2020/7 s.87(4))" do
    got =
      assign(
        [
          {"s.87(1)",
           "This Act comes into force on the day on which this Act is passed, subject to subsection (2)."},
          {"s.87(2)",
           "The following provisions of this Act come into force on such day as a Minister of the Crown may by regulations appoint— section 8;"},
          {"s.87(4)",
           "If the condition in subsection (5) is met, the Welsh Ministers may by regulations provide that a provision of this Act to which subsection (2) applies comes into force, so far as it extends to England and Wales and applies in relation to Wales, on a day appointed by the regulations."},
          "s.87(5)",
          "s.8"
        ],
        type: "ukpga",
        made: ~D[2020-03-25]
      )

    refute Enum.any?(got, fn {_, _, rows} -> "s.87(2)" in rows or "s.87(5)" in rows end)
  end

  test "CR-06: a qualifier covers only the items after it (uksi 1988/819 reg.1(2); asp 2005/13 s.33)" do
    got =
      assign([
        {"reg.1(1)", "These Regulations may be cited as the Regulations."},
        {"reg.1(2)",
         "This regulation, regulations 2, 5, 10 and 11, and, so far as they relate to the provisions of sections 12 to 14, regulations 3, 6 and 7, shall come into force on 6th June 1988."},
        {"reg.1(3)",
         "The remainder of these regulations shall come into force on 3rd October 1988."},
        "reg.2",
        "reg.3",
        "reg.10",
        "reg.12"
      ])

    # "This regulation" and regs 2, 10 fully on 6 June; reg.3 partly then, fully with the rest
    assert {:provision_dated, ~D[1988-06-06], ~w[reg.1(1) reg.1(2) reg.1(3) reg.2 reg.10]} in got
    assert {:provision_dated, ~D[1988-10-03], ~w[reg.3 reg.12]} in got

    asp =
      assign(
        [
          {"s.60(1)",
           "Except as provided in subsection (2), this Act comes into force on 1st April 2006."},
          {"s.60(2)",
           "Sections 33, 34, 41 and (in so far as it relates to section 41) 42 come into force on 5th August 2005."},
          "s.33",
          "s.42"
        ],
        type: "asp",
        made: ~D[2005-06-01]
      )

    assert {:provision_dated, ~D[2005-08-05], ~w[s.33]} in asp
  end

  describe "groups/3: the sentences with their references unexpanded (commencement-rules CR-03)" do
    defp groups(specs, opts \\ []) do
      rs = rows(specs)
      made = Keyword.get(opts, :made)
      law = LawStart.resolve(%{type_code: Keyword.get(opts, :type, "uksi"), rows: rs, made: made})

      for g <- Provisions.groups(rs, made, law),
          do:
            {g.kind, g.treatment, g.date || g.qualified_date,
             Enum.map(g.refs, &String.replace(&1, "UK_x:", "")),
             Enum.map(g.excluded, &String.replace(&1, "UK_x:", ""))}
    end

    test "a Part by the law's own numeral, not its rows" do
      got =
        groups([
          {"reg.1(2)",
           "These Regulations shall, except as provided by paragraph (3) below, come into force on 3rd August 1994."},
          {"reg.1(3)", "Part II of these Regulations shall come into force on 1st January 1995."},
          {"reg.2", "", "I"},
          {"reg.5", "", "II"},
          {"reg.5(1)", "", "II"}
        ])

      assert got == [{:named, :provision_dated, ~D[1995-01-01], ["pt.II"], []}]
    end

    test "this Part, a Chapter of a Part, a Part with an item's except, a named regulation (wsi 2026/103)" do
      got =
        groups(
          [
            {"reg.1(2)",
             "Except as provided in paragraphs (3) and (4), these Regulations come into force on 1 October 2027.",
             "1"},
            {"reg.1(3)",
             "The following provisions come into force on the day after the day on which these Regulations are made—",
             "1"},
            {"reg.1(3)(a)", "this Part;", "1"},
            {"reg.1(3)(b)", "Chapter 1 of Part 6 (items subject to overseas schemes);", "1"},
            {"reg.1(3)(c)", "Part 7 (the scheme administrator), except regulation 73;", "1"},
            {"reg.1(4)",
             "Regulation 73 (reuse of returned refund items) comes into force on 1 October 2030.",
             "1"},
            {"reg.50", "", "6", "1"},
            {"reg.60", "", "6", "2"},
            {"reg.70", "", "7"},
            {"reg.73", "", "7"}
          ],
          made: ~D[2026-03-25]
        )

      assert {:named, :provision_dated, ~D[2026-03-26], ["pt.1", "pt.6.ch.1", "pt.7"], ["reg.73"]} in got
      assert {:named, :provision_dated, ~D[2030-10-01], ["reg.73"], []} in got
    end

    test "remaining provisions and a qualified sentence keep their dates" do
      got =
        groups([
          {"reg.1(1)",
           "These Regulations may be cited as the Quarries Regulations (Northern Ireland) 2006 and, subject to paragraphs (2) and (3), shall come into operation on 1st August 2006."},
          {"reg.1(2)",
           "Regulation 26, with the exception of paragraph (4), shall come into operation on 1st August 2007 with respect to any tip which was not a classified tip."},
          "reg.26",
          "reg.26(4)"
        ])

      assert got == [{:named, :provision_qualified, ~D[2007-08-01], ["reg.26"], ["reg.26(4)"]}]
    end
  end

  test "V1-02: a staged clause's items date their provisions (wsi 2026/60; SI 2005/894 \"the remainder\")" do
    got =
      assign([
        {"reg.1(2)", "These Regulations come into force on the following dates—"},
        {"reg.1(2)(a)", "this regulation and regulations 2 and 5 on 1 July 2026;"},
        {"reg.1(2)(b)", "regulation 3 on 4 March 2027;"},
        {"reg.1(2)(c)", "the remainder, on 1 September 2026."},
        "reg.2",
        "reg.3",
        "reg.3(1)",
        "reg.4",
        "reg.5"
      ])

    assert {:provision_dated, ~D[2027-03-04], ~w[reg.3 reg.3(1)]} in got
    assert {:provision_dated, ~D[2026-09-01], ~w[reg.4]} in got

    assert Enum.any?(got, fn {t, d, rows} ->
             t == :provision_dated and d == ~D[2026-07-01] and "reg.2" in rows
           end)
  end
end

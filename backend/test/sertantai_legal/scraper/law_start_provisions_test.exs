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

  defp assign(specs, opts \\ []) do
    rs = rows(specs)
    made = Keyword.get(opts, :made)
    law = LawStart.resolve(%{type_code: Keyword.get(opts, :type, "uksi"), rows: rs, made: made})

    Provisions.assign(rs, made, law)
    |> Enum.map(
      &{&1.treatment, &1.date,
       Enum.map(&1.section_ids, fn s -> String.replace(s, "UK_x:", "") end)}
    )
  end

  test "the catalogue lists each provision treatment once" do
    ids = Enum.map(LawStart.provision_catalogue(), &elem(&1, 0))
    assert ids == ~w(provision_dated provision_by_order provision_qualified provision_unread)a
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

  test "qualified commencements are listed and start nothing (D2)" do
    got =
      assign([
        {"reg.1(1)",
         "These Regulations may be cited as the Quarries Regulations (Northern Ireland) 2006 and, subject to paragraphs (2) and (3), shall come into operation on 1st August 2006."},
        {"reg.1(2)",
         "Regulation 26, with the exception of paragraph (4), shall come into operation on 1st August 2007 with respect to any tip which was not a classified tip."},
        "reg.26",
        "reg.26(4)"
      ])

    assert got == [{:provision_qualified, nil, ~w[reg.26]}]
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

  test "a list read item by item; inline after \"namely—\"; qualified items listed apart (EPA 1990 s.164)" do
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
    assert {:provision_qualified, nil, ~w[s.105]} in got
    assert {:provision_by_order, nil, ~w[s.105 s.150]} in got
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
    assert {:provision_by_order, nil, ~w[s.1 s.121]} in got

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

  test "provisions the reader can't resolve: listed for the law" do
    got =
      assign([
        {"reg.1(1)", "These Regulations come into force on 1st June 2015."},
        {"reg.1(2)", "Schedule 3 comes into force on 1st June 2016."}
      ])

    assert [{:provision_unread, nil, []}] = got
  end
end

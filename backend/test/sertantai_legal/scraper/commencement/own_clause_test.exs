defmodule SertantaiLegal.Scraper.Commencement.OwnClauseTest do
  @moduledoc """
  CR-03: a law's own commencement clause as rules — the law-level start
  (`LawStart`'s treatment) and the provision-level sentences
  (`LawStart.Provisions.groups/3`) — and the evaluator dating rows from them.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Evaluator, OwnClause, Rule}

  defp rows(specs),
    do:
      for(
        spec <- specs,
        do:
          case spec do
            {sid, text, part, chapter} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: chapter}

            {sid, text, part} ->
              %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil}

            {sid, text} ->
              %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}

            sid ->
              %{section_id: "UK_x:" <> sid, text: "", part: nil, chapter: nil}
          end
      )

  defp read(specs, opts \\ []) do
    rs = rows(specs)

    rules =
      OwnClause.rules("UK_x", %{
        type_code: Keyword.get(opts, :type, "uksi"),
        rows: rs,
        made: opts[:made],
        clml_head: opts[:head],
        lrt_date: opts[:lrt_date]
      })

    {rules, rs}
  end

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_x") |> hd()))

  defp date_of(rules, rows, sid) do
    rules
    |> Evaluator.evaluate(sid, OwnClause.context(rows))
    |> Map.fetch!(:full_from)
  end

  test "one date for the whole law" do
    {rules, _} =
      read([{"reg.1", "These Regulations come into force on 1st April 2020."}, "reg.2"])

    assert lines(rules) == ["all — 2020-04-01 — everywhere, fully — clause_date"]
    assert [%Rule{source: %{law: "UK_x", ref: "reg.1"}}] = rules
  end

  test "an Act left to orders: all appointed by order" do
    {rules, rs} =
      read(
        [
          {"s.30(2)",
           "This Act comes into force on such day as the Secretary of State may by order appoint."},
          "s.1"
        ],
        type: "ukpga"
      )

    assert lines(rules) == ["all — appointed (by order) — everywhere, fully — by_order"]
    assert date_of(rules, rs, "UK_x:s.1") == nil
  end

  describe "provision-level sentences (wsi 2026/103)" do
    @specs [
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
       "Regulation 73 (reuse of returned refund items) comes into force on 1 October 2030.", "1"},
      {"reg.2", "", "1"},
      {"reg.50", "", "6", "1"},
      {"reg.60", "", "6", "2"},
      {"reg.70", "", "7"},
      {"reg.73", "", "7"}
    ]

    test "the rules, one readable line each" do
      {rules, _} = read(@specs, made: ~D[2026-03-25])

      assert lines(rules) == [
               "all — 2027-10-01 — everywhere, fully — clause_date",
               "pt.1, pt.6.ch.1, pt.7 except reg.73 — 2026-03-26 — everywhere, fully — provision_dated",
               "reg.73 — 2030-10-01 — everywhere, fully — provision_dated"
             ]
    end

    test "each row's date from the evaluator" do
      {rules, rs} = read(@specs, made: ~D[2026-03-25])
      on = &date_of(rules, rs, "UK_x:" <> &1)

      assert on.("reg.2") == ~D[2026-03-26]
      assert on.("reg.50") == ~D[2026-03-26]
      assert on.("reg.60") == ~D[2027-10-01]
      assert on.("reg.70") == ~D[2026-03-26]
      assert on.("reg.73") == ~D[2030-10-01]
    end
  end

  test "named provisions, the remaining ones by order; the clause itself commences with them" do
    {rules, rs} =
      read(
        [
          {"s.40(1)", "Sections 1 and 2 come into force on 1st January 2025."},
          {"s.40(2)",
           "The remaining provisions of this Act come into force on such day as the Scottish Ministers may by order appoint."},
          "s.1",
          "s.2",
          "s.3"
        ],
        type: "asp"
      )

    assert "rest except s.40 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
             rules
           )

    on = &date_of(rules, rs, "UK_x:" <> &1)
    assert on.("s.1") == ~D[2025-01-01]
    assert on.("s.3") == nil
  end

  describe "qualified sentences: partial entries" do
    test "for some purposes — in_relation_to, with the exception subtracted" do
      {rules, rs} =
        read([
          {"reg.1(1)",
           "These Regulations may be cited as the Quarries Regulations (Northern Ireland) 2006 and, subject to paragraphs (2) and (3), shall come into operation on 1st August 2006."},
          {"reg.1(2)",
           "Regulation 26, with the exception of paragraph (4), shall come into operation on 1st August 2007 with respect to any tip which was not a classified tip."},
          "reg.26",
          "reg.26(4)"
        ])

      assert "reg.26 except reg.26(4) — 2007-08-01 — everywhere, in relation to — provision_qualified" in lines(
               rules
             )

      # in force for classified tips with the Regulations, fully once the rest is added
      r = Evaluator.evaluate(rules, "UK_x:reg.26", OwnClause.context(rs))
      assert %{partial_from: ~D[2006-08-01], full_from: ~D[2007-08-01]} = r
    end

    test "in relation to a territory — the territory, not purposes" do
      {rules, _} =
        read([
          {"reg.1(1)", "These Regulations come into force on 1st April 2020."},
          {"reg.1(2)", "Regulation 5 comes into force in relation to Wales on 1st October 2020."},
          "reg.5"
        ])

      assert "reg.5 — 2020-10-01 — W, fully — provision_qualified" in lines(rules)
    end

    test "\"in Wales on …\" is qualified too" do
      {rules, _} =
        read([
          {"reg.1(1)", "These Regulations come into force on 1st April 2020."},
          {"reg.1(2)", "Regulation 5 comes into force in Wales on 1st October 2020."},
          "reg.5"
        ])

      assert "reg.5 — 2020-10-01 — W, fully — provision_qualified" in lines(rules)
    end

    test "for the purpose of making regulations" do
      {rules, _} =
        read(
          [
            {"s.20(1)", "This Act comes into force on 1st April 2020."},
            {"s.20(2)",
             "Section 5 comes into force on 1st January 2020 for the purpose of making regulations."},
            "s.5"
          ],
          type: "ukpga"
        )

      assert "s.5 — 2020-01-01 — everywhere, for making secondary legislation — provision_qualified" in lines(
               rules
             )
    end
  end

  test "uksi 2017/469: \"the day after the day on which the Order is made\"; otherwise 8 May" do
    {rules, rs} =
      read(
        [
          {"reg.1(1)", "This Order may be cited as the X Order 2017."},
          {"reg.1(2)",
           "This article, article 2 and article 11 come into force on the day after the day on which the Order is made."},
          {"reg.1(3)", "Otherwise this Order comes into force on 8th May 2017."},
          "reg.2",
          "reg.5",
          "reg.11"
        ],
        made: ~D[2017-03-24]
      )

    on = &date_of(rules, rs, "UK_x:" <> &1)
    assert on.("reg.1(2)") == ~D[2017-03-25]
    assert on.("reg.11") == ~D[2017-03-25]
    assert on.("reg.5") == ~D[2017-05-08]
  end

  test "no clause, an EU directive: no rule (unknown stays unknown)" do
    {rules, _} = read(["reg.1", "reg.2"])
    assert rules == []
  end

  describe "CV-S04: an Act whose start is its Royal Assent still has its clause's rules" do
    @assent ~s(<ukm:EnactmentDate Date="1974-07-31"/>)

    test "a whole Act left to orders: appointed by order, not Royal Assent (HSWA 1974 s.85(2))" do
      {rules, rs} =
        read(
          [
            "s.1",
            {"s.85(2)",
             "This Act shall come into operation on such day as the Secretary of State may by order made by statutory instrument appoint, and different days may be appointed under this subsection for different purposes."}
          ],
          type: "ukpga",
          head: @assent
        )

      assert lines(rules) == ["all — appointed (by order) — everywhere, fully — by_order"]
      assert date_of(rules, rs, "UK_x:s.1") == nil
    end

    test "the preceding provisions left to orders; the clause and those after it on Royal Assent (CMCHA 2007 s.27(1))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.26",
            {"s.27(1)",
             "The preceding provisions of this Act come into force in accordance with provision made by order by the Secretary of State (subject to subsection (1A))."},
            "s.28",
            "s.29"
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2007-07-26"/>)
        )

      assert date_of(rules, rs, "UK_x:s.1") == nil
      assert date_of(rules, rs, "UK_x:s.26") == nil
      assert date_of(rules, rs, "UK_x:s.27") == ~D[2007-07-26]
      assert date_of(rules, rs, "UK_x:s.29") == ~D[2007-07-26]
    end
  end

  describe "CV-S04: the law's text is primary for its provisions" do
    test "the clause's date over the register's (NISR 1997/455 reg.1: the register holds reg.1(2)'s earlier date)" do
      {rules, rs} =
        read(
          [
            {"reg.1(1)",
             "These Regulations may be cited as the Reporting of Injuries, Diseases and Dangerous Occurrences Regulations (Northern Ireland) 1997 and, subject to paragraph (2), shall come into operation on 1st April 1998."},
            {"reg.1(2)",
             "Regulations 14 and 15(3) and Schedule 9 shall come into operation on 1st December 1997."},
            "reg.2",
            "reg.14"
          ],
          type: "nisr",
          lrt_date: ~D[1997-12-01]
        )

      assert date_of(rules, rs, "UK_x:reg.2") == ~D[1998-04-01]
      assert date_of(rules, rs, "UK_x:reg.14") == ~D[1997-12-01]
    end

    test "the general sentence's own exception, dated (NISR 2007/31 reg.1)" do
      {rules, rs} =
        read(
          [
            {"reg.1",
             "These Regulations may be cited as the Control of Asbestos Regulations (Northern Ireland) 2007 and shall come into operation on 1st March 2007, except regulation 20(4) which shall come into operation on 6th April 2007."},
            "reg.20",
            "reg.20(4)"
          ],
          type: "nisr",
          lrt_date: ~D[2007-03-01]
        )

      assert date_of(rules, rs, "UK_x:reg.20(4)") == ~D[2007-04-06]
      assert date_of(rules, rs, "UK_x:reg.20") == ~D[2007-03-01]
    end

    test "\"shall not come into operation … until\": partly from the start, fully from that date (NISR 2006/1 reg.1)" do
      {rules, rs} =
        read(
          [
            {"reg.1",
             "These Regulations may be cited as the Control of Noise at Work Regulations (Northern Ireland) 2006 and shall come into operation on 6th April 2006, except that—"},
            {"reg.1(a)",
             "for the music and entertainment sectors only they shall not come into operation until 6th April 2008; and"},
            {"reg.1(b)",
             "subject to regulation 3(4), regulation 6(4) shall not come into operation in relation to the master and crew of a seagoing ship until 6th April 2011."},
            "reg.2",
            "reg.6(4)"
          ],
          type: "nisr",
          lrt_date: ~D[2006-04-06]
        )

      at = &Evaluator.evaluate(rules, &1, OwnClause.context(rs))

      assert %{partial_from: ~D[2006-04-06], full_from: ~D[2008-04-06]} = at.("UK_x:reg.2")
      assert %{partial_from: ~D[2006-04-06], full_from: ~D[2011-04-06]} = at.("UK_x:reg.6(4)")
    end
  end

  describe "CV-S04: items in a sentence" do
    test "a bracketed qualifier is only its item's (SI 2015/21 reg.1(2))" do
      {rules, rs} =
        read([
          {"reg.1(2)",
           "This regulation, regulation 2 (insofar as it relates to regulation 22) and regulation 22 come into force on 31st May 2015."},
          {"reg.1(3)", "The remainder of these Regulations come into force on 1st June 2015."},
          "reg.2",
          "reg.3",
          "reg.22"
        ])

      at = &Evaluator.evaluate(rules, &1, OwnClause.context(rs))
      assert %{full_from: ~D[2015-05-31], partial_from: nil} = at.("UK_x:reg.22")
      assert %{full_from: ~D[2015-05-31]} = at.("UK_x:reg.1")
      assert %{partial_from: ~D[2015-05-31], full_from: ~D[2015-06-01]} = at.("UK_x:reg.2")
      assert %{full_from: ~D[2015-06-01]} = at.("UK_x:reg.3")
    end

    test "\"… and the Schedules\": every Schedule (SI 1992/3004 reg.1(3))" do
      {rules, rs} =
        read(
          [
            {"reg.1(2)",
             "Subject to paragraph (3), these Regulations shall come into force on 1st January 1993."},
            {"reg.1(3)",
             "Regulations 5 to 27 and the Schedules shall come into force on 1st January 1996."},
            "reg.5",
            "reg.27"
          ],
          lrt_date: ~D[1993-01-01]
        )

      at = &Evaluator.evaluate(rules, &1, OwnClause.context(rs)).full_from
      assert at.("UK_x:sch.2.para.1") == ~D[1996-01-01]
      assert at.("UK_x:reg.5") == ~D[1996-01-01]
    end
  end

  describe "CV-S04 catalogue: forms the reader missed" do
    test "a statement in another provision, read in its own (Access to Justice Act 1999 s.7(3)-like)" do
      {rules, rs} =
        read(
          [
            {"s.30(2)", "This Act comes into force on the day on which it is passed."},
            "s.6",
            {"s.7(3)",
             "Section 6 shall not come into force until such day as the Secretary of State may appoint by order made by statutory instrument."}
          ],
          type: "ukpga",
          made: ~D[1999-07-27],
          head: ~s(<ukm:EnactmentDate Date="1999-07-27"/>)
        )

      assert date_of(rules, rs, "UK_x:s.6") == nil
      assert Enum.any?(rules, &(&1.scope == ["s.6"] and match?({:appointed, _}, &1.when)))
    end

    test "\"Except so far as relating to … of another Act, subsection (1) … shall not come into force until\": dated, partly from the start (Health Authorities Act 1995 s.5(2))" do
      {rules, rs} =
        read(
          [
            {"s.8", "This Act comes into force on the day on which it is passed."},
            {"s.5(1)", "The enactments mentioned in Schedule 3 are repealed."},
            {"s.5(2)",
             "Except so far as relating to the repeal in section 18(3) of the National Health Service Act 1977, subsection (1) (and Schedule 3) shall not come into force until 1st April 1996."}
          ],
          type: "ukpga",
          made: ~D[1995-06-28],
          head: ~s(<ukm:EnactmentDate Date="1995-06-28"/>)
        )

      assert date_of(rules, rs, "UK_x:s.5(1)") == ~D[1996-04-01]
      refute Enum.any?(rules, &(is_list(&1.scope) and "s.18(3)" in &1.scope))
    end

    test "Schedules and Parts named, a lead-in, \"is to come into force\" (LGRA 1997 s.34)" do
      {rules, rs} =
        read(
          [
            {"s.20", "", "II"},
            {"s.33", "", "IV"},
            {"s.34(1)",
             "Subject to subsections (2) and (3), this Act is to come into force on such day as the Secretary of State may by order made by statutory instrument appoint.",
             "IV"},
            {"s.34(2)",
             "Part II and paragraphs 4 to 10 and 21 of Schedule 3 are to come into force at the end of the period of two months beginning with the day on which this Act is passed.",
             "IV"},
            {"s.34(3)",
             "This Part (except section 33) is to come into force on the passing of this Act.",
             "IV"}
          ],
          type: "ukpga",
          made: ~D[1997-03-19],
          head: ~s(<ukm:EnactmentDate Date="1997-03-19"/>)
        )

      assert date_of(rules, rs, "UK_x:s.20") == ~D[1997-05-19]
      assert date_of(rules, rs, "UK_x:sch.3.para.5") == ~D[1997-05-19]
      assert date_of(rules, rs, "UK_x:s.34") == ~D[1997-03-19]
      assert date_of(rules, rs, "UK_x:s.33") == nil
    end

    test "\"Parts 1 to 3\" by order; \"This Part\" on passing (DRA 2014 s.50)" do
      {rules, rs} =
        read(
          [
            {"s.1", "", "1"},
            {"s.30", "", "3"},
            {"s.50(1)",
             "Parts 1 to 3 come into force on such day or days as the Secretary of State may by order made by statutory instrument appoint.",
             "4"},
            {"s.50(9)", "This Part comes into force on the day on which this Act is passed.", "4"}
          ],
          type: "ukpga",
          made: ~D[2014-05-14],
          head: ~s(<ukm:EnactmentDate Date="2014-05-14"/>)
        )

      assert date_of(rules, rs, "UK_x:s.30") == nil
      assert Enum.any?(rules, &(&1.scope == ["pt.1", "pt.3"]))
      assert date_of(rules, rs, "UK_x:s.50") == ~D[2014-05-14]
    end

    test "another general sentence in a staged clause dates the rest (SSI 2025/417 reg.1(2))" do
      {rules, rs} =
        read([
          {"reg.1(1)",
           "These Regulations may be cited as the Energy Performance Regulations 2025 and come into force in accordance with paragraphs (2) and (3)."},
          {"reg.1(2)",
           "Other than those regulations specified in paragraph (3) these Regulations come into force on 31 October 2026."},
          {"reg.1(3)", "This regulation and regulation 2 come into force on 1 January 2026."},
          "reg.2",
          "reg.10"
        ])

      assert date_of(rules, rs, "UK_x:reg.10") == ~D[2026-10-31]
      assert date_of(rules, rs, "UK_x:reg.2") == ~D[2026-01-01]
    end

    test "each country its own date (SI 2007/764 reg.1)" do
      {rules, rs} =
        read(
          [
            {"reg.1(1)", "These Regulations may be cited as the X Regulations 2007."},
            {"reg.1(2)",
             "These Regulations come into force in England on 1st July 2007 and in Wales on 2nd April 2007."},
            "reg.2"
          ],
          lrt_date: ~D[2007-04-02]
        )

      # as the readers evaluate: a staged clause's start is the law's, not a
      # provision's
      provisions = Enum.reject(rules, &(&1.treatment == :clause_staged))
      at = &Evaluator.evaluate(provisions, &1, Map.put(OwnClause.context(rs), :extent, "E+W"))
      assert %{partial_from: ~D[2007-04-02], full_from: ~D[2007-07-01]} = at.("UK_x:reg.2")
    end

    test "made-relative wordings and the title clause" do
      for {text, date} <- [
            {"This Act comes into operation on the day after receiving Royal Assent.",
             ~D[2021-03-11]},
            {"This Act comes into force on the day after that on which it is passed.",
             ~D[2021-03-11]},
            {"This Act shall come into operation on the expiration of one month beginning with the date of the passing thereof.",
             ~D[2021-04-10]}
          ] do
        {rules, rs} =
          read([{"s.6(1)", text}, "s.1"],
            type: "ukpga",
            made: ~D[2021-03-10],
            head: ~s(<ukm:EnactmentDate Date="2021-03-10"/>)
          )

        assert date_of(rules, rs, "UK_x:s.1") == date, text
      end

      {rules, rs} =
        read([
          {"reg.1(1)",
           "The title of this Order is the Beavers (Wales) Order 2026 and it comes into force on 4 March 2026."},
          "reg.2"
        ])

      assert date_of(rules, rs, "UK_x:reg.2") == ~D[2026-03-04]
    end

    test "a list head: each item dates the head's provisions (UK_ukpga_2021_24 s.4(2))" do
      {rules, _rs} =
        read(
          [
            "s.1",
            {"s.4(2)", "Section 1 comes into force—"},
            {"s.4(2)(a)",
             "in relation to premises in England, on such day as the Secretary of State may by regulations appoint;"},
            {"s.4(2)(b)",
             "in relation to premises in Wales, on such day as the Welsh Ministers may by regulations appoint."},
            {"s.4(6)", "This section comes into force on the day on which this Act is passed."}
          ],
          type: "ukpga",
          made: ~D[2021-04-29],
          head: ~s(<ukm:EnactmentDate Date="2021-04-29"/>)
        )

      assert rules
             |> Enum.filter(&(&1.scope == ["s.1"]))
             |> Enum.map(& &1.territory)
             |> Enum.sort() == ["E", "W"]
    end
  end

  describe "CV-S04 catalogue run 2: more forms" do
    test "lead-ins: \"Except as mentioned in …\", a bracket before the clause (EA 1995 s.125(3))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.74",
            {"s.125(3)",
             "Except as provided in subsection (2) above and except for this section, section 74 above and paragraphs 76(8)(a) and 135 of Schedule 22 to this Act (which come into force on the passing of this Act) and the repeal of sub-paragraph (1) of paragraph 22 of Schedule 10 to this Act (which comes into force in accordance with sub-paragraph (7) of that paragraph) this Act shall come into force on such day as the Secretary of State may specify by order made by statutory instrument."}
          ],
          type: "ukpga",
          made: ~D[1995-07-19],
          head: ~s(<ukm:EnactmentDate Date="1995-07-19"/>)
        )

      assert date_of(rules, rs, "UK_x:s.1") == nil
      assert date_of(rules, rs, "UK_x:s.74") == ~D[1995-07-19]
      assert date_of(rules, rs, "UK_x:sch.22.para.135") == ~D[1995-07-19]

      {rules, _} =
        read(
          [
            "s.1",
            {"s.186(6)",
             "Except as mentioned in subsections (1) to (5), this Act comes into force on such day as the Secretary of State may by regulations appoint."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2022-04-28"/>)
        )

      assert [%{scope: :all, when: {:appointed, _}}] = Enum.filter(rules, &(&1.scope == :all))
    end

    test "\"does not apply to section 195 which shall come into force when this Act is passed\"; \"The rest of this Act …\"" do
      {rules, rs} =
        read(
          [
            {"s.211(1)",
             "This Act shall come into force on such day as the Secretary of State may by order appoint."},
            {"s.211(2)",
             "Subsection (1) above does not apply to section 195 which shall come into force when this Act is passed."},
            "s.195"
          ],
          type: "ukpga",
          made: ~D[1986-11-07],
          head: ~s(<ukm:EnactmentDate Date="1986-11-07"/>)
        )

      assert date_of(rules, rs, "UK_x:s.195") == ~D[1986-11-07]

      {rules, _} =
        read(
          [
            {"s.14(1)", "This section comes into force on the day on which this Act is passed."},
            {"s.14(2)",
             "The rest of this Act comes into force on such day as the Secretary of State may by regulations appoint."},
            "s.1"
          ],
          type: "ukpga",
          made: ~D[2023-05-02],
          head: ~s(<ukm:EnactmentDate Date="2023-05-02"/>)
        )

      assert Enum.any?(rules, &(&1.scope == :rest and match?({:appointed, _}, &1.when)))
    end

    test "\"The provisions mentioned in subsection (3)\", \"in Schedule 4, paragraphs …\", \"5(1) to (4)\" (Petroleum Act 1998 s.52)" do
      {rules, rs} =
        read(
          [
            "s.5(1)",
            "s.5(2)",
            "s.5(3)",
            "s.5(4)",
            "s.5(5)",
            {"s.52(1)",
             "Section 5(1) to (4) and this section shall come into force on the passing of this Act."},
            {"s.52(2)",
             "The provisions mentioned in subsection (3) shall come into force on such day as the Secretary of State may by order appoint."},
            {"s.52(3)",
             "The provisions referred to in subsection (2) are— in Schedule 4, paragraphs 8, 10 and 11;"},
            {"s.52(4)",
             "Subject to subsections (1) and (2), this Act shall come into force on such day as the Secretary of State may by order appoint."}
          ],
          type: "ukpga",
          made: ~D[1998-06-11],
          head: ~s(<ukm:EnactmentDate Date="1998-06-11"/>)
        )

      assert date_of(rules, rs, "UK_x:s.5(3)") == ~D[1998-06-11]
      assert date_of(rules, rs, "UK_x:s.5(5)") == nil
      assert Enum.any?(rules, &(&1.scope == ["sch.4.para.8", "sch.4.para.10", "sch.4.para.11"]))
    end

    test "a statement elsewhere names provisions first, never something under one (Building Societies Act 1986 s.186(1))" do
      {rules, _} =
        read(
          [
            {"s.211(1)",
             "This Act shall come into force on such day as the Secretary of State may by order appoint."},
            "s.183",
            {"s.186(1)",
             "The Secretary of State may vary a partial restriction notice served under section 183 above by a notice which shall come into force on such day as he may appoint."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1986-07-25"/>)
        )

      refute Enum.any?(rules, &(&1.scope == ["s.183"]))
    end

    test "general clauses: \"apply … and come into force\", \"may be cited as … which shall come into force\"" do
      for text <- [
            "These Regulations apply in relation to Wales and come into force on 1 October 2011.",
            "These Regulations may be cited as the X Regulations 2011 which shall come into force on 1st October 2011."
          ] do
        {rules, rs} = read([{"reg.1", text}, "reg.2"])
        assert date_of(rules, rs, "UK_x:reg.2") == ~D[2011-10-01], text
      end
    end
  end

  describe "CV-S04 catalogue run 3: general clauses with exceptions" do
    @act ~s(<ukm:EnactmentDate Date="2003-07-17"/>)

    test "a bracketed exception with its own date (Communications Act 2003 s.411(2))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.405",
            {"s.411(2)",
             "This Act (except the provisions listed in subsection (3), which come into force on the passing of this Act) shall come into force on such day as the Secretary of State may by order appoint."},
            {"s.411(3)", "Those provisions are section 405 and this section."}
          ],
          type: "ukpga",
          made: ~D[2003-07-17],
          head: @act
        )

      assert date_of(rules, rs, "UK_x:s.1") == nil
      assert date_of(rules, rs, "UK_x:s.405") == ~D[2003-07-17]
    end

    test "a list between commas; \"does not come into force until\"" do
      for text <- [
            "This Act, except section 120 above, this section and section 122 below, shall come into operation on such day as the Secretary of State may by order appoint.",
            "Apart from— this Act does not come into force until such date as the Secretary of State may appoint by order made by statutory instrument."
          ] do
        {rules, _} = read([{"s.17(3)", text}, "s.1"], type: "ukpga", head: @act)
        assert [%{when: {:appointed, _}}] = Enum.filter(rules, &(&1.scope == :all)), text
      end
    end

    test "a mention is never a statement; a statement's \"on the day on which this Act is passed\" stays one" do
      alias SertantaiLegal.Scraper.LawStart.Clause

      assert Clause.mention?(
               "When an order under this section provides by virtue of subsection (2) above that section 60 above shall come into force in an area, it may make provision."
             )

      assert Clause.mention?(
               "The “relevant date” is the date on which this section comes into force."
             )

      refute Clause.mention?("Section 2 comes into force on the day on which this Act is passed.")
    end
  end

  describe "CV-S04 agent round 2: clauses" do
    test "N4: an Act's own commencement words unread leave it unread, never Royal Assent" do
      {rules, _} =
        read(
          [
            "s.1",
            {"s.18(2)", "This Act shall come into force in the manner the Minister thinks fit."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1995-11-08"/>)
        )

      assert [%{when: :unread}] = Enum.filter(rules, &(&1.scope == :all))
    end

    test "an except list below an Act's clause: the Act by order, the excepted on Royal Assent, a provision's own sentence first (Gas Act 1995 s.18)" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.12",
            "s.13",
            {"s.18(2)",
             "This Act, except— shall come into force on the appointed day, that is to say, such day as the Secretary of State may by order made by statutory instrument appoint."},
            {"s.18(2)(a)", "this section;"},
            {"s.18(2)(b)", "sections 12 and 13;"},
            {"s.18(4)",
             "Section 12 above shall come into force on such day as the Secretary of State may by order made by statutory instrument under this subsection appoint."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1995-11-08"/>)
        )

      assert date_of(rules, rs, "UK_x:s.1") == nil
      assert date_of(rules, rs, "UK_x:s.13") == ~D[1995-11-08]
      assert date_of(rules, rs, "UK_x:s.12") == nil
    end

    test "N5: \"may be cited as … and subject to paragraphs (2) and (3) shall come into force on …\" (Quarries Regulations 1999)" do
      {rules, rs} =
        read([
          {"reg.1(1)",
           "These Regulations may be cited as the Quarries Regulations 1999 and subject to paragraphs (2) and (3) shall come into force on 1st January 2000."},
          "reg.47"
        ])

      assert date_of(rules, rs, "UK_x:reg.47") == ~D[2000-01-01]
    end

    test "N3: \"the Schedule entitled Schedule 1C\" is that Schedule, not every one; \"(and the Schedule)\" is the Act's" do
      {rules, _} =
        read(
          [
            {"s.18(1)",
             "Sections 1 to 2 (and the Schedule) do not come into force until a day appointed by order made by the Secretary of State."},
            "s.1",
            "s.2"
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2003-07-10"/>)
        )

      assert Enum.any?(rules, &("sch" in List.wrap(&1.scope)))
    end
  end

  describe "CV-S04 agent round 3: clauses" do
    test "an except list at the front; \"Except as otherwise expressly provided\"; \"which extend to Great Britain\"" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.26",
            {"s.27(1)",
             "Except for section 26 and this section the provisions of this Act shall not come into force until such day as the Secretary of State may appoint by an order made by statutory instrument."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1988-11-15"/>)
        )

      assert date_of(rules, rs, "UK_x:s.1") == nil
      assert date_of(rules, rs, "UK_x:s.26") == ~D[1988-11-15]

      {rules, rs} =
        read(
          [
            {"s.30(2)",
             "Except as otherwise expressly provided, this Act shall come into force on 1st April 1968 and have effect for the financial year."},
            "s.1"
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1968-03-27"/>)
        )

      assert date_of(rules, rs, "UK_x:s.1") == ~D[1968-04-01]

      {rules, rs} =
        read([
          {"reg.1",
           "These Regulations, which extend to Great Britain, may be cited as the X Regulations 1996 and shall come into force on 1st October 1996."},
          "reg.2"
        ])

      assert date_of(rules, rs, "UK_x:reg.2") == ~D[1996-10-01]
    end
  end
end

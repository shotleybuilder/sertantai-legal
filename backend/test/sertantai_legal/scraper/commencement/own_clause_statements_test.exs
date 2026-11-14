defmodule SertantaiLegal.Scraper.Commencement.OwnClauseStatementsTest do
  @moduledoc """
  A law's own commencement clause, the forms of the Fire and OH&S round
  (LAT Change Pipeline, step Commencement reader): several statements in
  one sentence, numbers in words, a commencement territory by territory,
  one tied to another provision, lists and their items' qualifiers.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}

  defp rows(specs) do
    for spec <- specs do
      {sid, text, part, chapter} =
        case spec do
          {sid, text, part, chapter} -> {sid, text, part, chapter}
          {sid, text, part} -> {sid, text, part, nil}
          {sid, text} -> {sid, text, nil, nil}
          sid -> {sid, "", nil, nil}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: chapter}
    end
  end

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

  defp outcome(rules, rows, id),
    do: rules |> OwnCommencement.outcome("UK_x", id, OwnClause.context(rows)) |> elem(0)

  @assent ~s(<ukm:EnactmentDate Date="1969-03-27"/>)

  describe "several statements in one sentence" do
    test "each dated statement after a comma or \"and\" (SI 1989/1401 reg.1(3))" do
      {rules, _} =
        read([
          {"reg.1(2)",
           "These Regulations, with the exception of the provisions specified in paragraph (3) below, shall come into force on 18th September 1989."},
          {"reg.1(3)",
           "Regulations 6(3) and 7(1) and (2) shall come into force on 1st January 1990, regulations 5(4) and (5) and 6(4), (6) and (8) shall come into force on 1st January 1991 and regulation 8(3) shall come into force on 1st January 1996."},
          "reg.5(4)",
          "reg.5(5)",
          "reg.6(3)",
          "reg.6(4)",
          "reg.6(6)",
          "reg.6(8)",
          "reg.7(1)",
          "reg.7(2)",
          "reg.8(3)"
        ])

      assert "reg.6(3), reg.7(1), reg.7(2) — 1990-01-01 — everywhere, fully — provision_dated" in lines(
               rules
             )

      assert "reg.5(4), reg.5(5), reg.6(4), reg.6(6), reg.6(8) — 1991-01-01 — everywhere, fully — provision_dated" in lines(
               rules
             )

      assert "reg.8(3) — 1996-01-01 — everywhere, fully — provision_dated" in lines(rules)
    end

    test "a section in words on the passing, and the remainder by Order in Council (1962 c.58 s.70(3))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.41",
            {"s.70(3)",
             "Section forty-one of this Act shall come into operation on the passing of this Act, and the remainder of this Act shall come into operation on such day as Her Majesty may by Order in Council appoint."}
          ],
          type: "ukpga",
          made: ~D[1962-08-01],
          head: ~s(<ukm:EnactmentDate Date="1962-08-01"/>)
        )

      assert "s.41 — 1962-08-01 — everywhere, fully — provision_dated" in lines(rules)

      assert "rest except s.70 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert outcome(rules, rs, "s.1") == :by_order
      assert outcome(rules, rs, "s.41") == :dated
    end

    test "sections in words a general clause excepts (1954 c.70 s.194)" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.172",
            "s.190",
            {"s.194",
             "This Act, except sections one hundred and seventy-two and one hundred and ninety thereof, shall come into operation on such day as the Minister may by order appoint, and those sections shall come into operation on the passing of this Act; and for the purposes of this Act and of the application thereto of section 13 of the Interpretation Act 1978 (which relates to the exercise of statutory powers between the passing and the commencement of an Act references to the commencement of this Act shall, notwithstanding the provisions of section 4 of the said Act of 1978 with respect to the construction of the expression “commencement”, be construed as references to the time at which this Act, except the said sections one hundred and seventy-two and one hundred and ninety, comes into operation."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1954-11-25"/>)
        )

      assert "all except s.172, s.190 — appointed (by order) — everywhere, fully — by_order" in lines(
               rules
             )

      assert "s.172, s.190 — 1954-11-25 — everywhere, fully — act_enactment" in lines(rules)
      assert outcome(rules, rs, "s.1") == :by_order
      assert outcome(rules, rs, "s.190") == :dated
    end
  end

  describe "a commencement territory by territory" do
    test "a Part by order in its application to each country (1969 c.10 s.38(3))" do
      {rules, rs} =
        read(
          [
            {"s.1", "", "I"},
            {"s.11", "", "II"},
            {"s.37", "", "III"},
            {"s.38(3)",
             "Part I of this Act shall come into operation on such day as the Minister of Power may by order made by statutory instrument appoint and Part II of this Act, in its application to England and Wales, shall come into operation on such day as the Minister of Housing and Local Government and the Secretary of State for Wales may by order made by statutory instrument jointly appoint, and in its application to Scotland on such day as the Secretary of State for Scotland may by order so made appoint.",
             "III"}
          ],
          type: "ukpga",
          head: @assent
        )

      assert "pt.I — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert "pt.II — appointed (by order) — E+W, fully — provision_by_order" in lines(rules)
      assert "pt.II — appointed (by order) — S, fully — provision_by_order" in lines(rules)

      # left to orders in each country: never partly in force on Royal Assent
      assert outcome(rules, rs, "s.11") == :by_order
      assert outcome(rules, rs, "s.1") == :by_order
      assert outcome(rules, rs, "s.37") == :dated
    end

    test "a by-order clause qualified only by a territory (CNEA 2005 s.108(1))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.2",
            "s.3",
            {"s.108(1)", "The provisions specified in subsection (2) come into force—"},
            {"s.108(1)(a)",
             "in relation to England, in accordance with provision made by order by the Secretary of State; and"},
            {"s.108(1)(b)",
             "in relation to Wales, in accordance with provision so made by the National Assembly for Wales."},
            {"s.108(2)", "The provisions referred to in subsection (1) are—"},
            {"s.108(2)(a)", "section 2;"}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2005-04-07"/>)
        )

      assert "s.2 — appointed (by order) — E, fully — provision_by_order" in lines(rules)
      assert "s.2 — appointed (by order) — W, fully — provision_by_order" in lines(rules)
      assert outcome(rules, rs, "s.2") == :by_order
      assert outcome(rules, rs, "s.3") == :dated
    end

    test "left to an order for one country alone, the general rule stands elsewhere (2017 c.29 s.124(3), (5))" do
      {rules, _} =
        read(
          [
            "s.1",
            "s.89(4)",
            {"s.124(3)",
             "Section 89(4) comes into force, in relation to Wales, on such day as the Welsh Ministers may by regulations made by statutory instrument appoint."},
            {"s.124(5)",
             "The remaining provisions of this Act come into force on such day as the Secretary of State may by regulations made by statutory instrument appoint."}
          ],
          type: "ukpga",
          head: @assent
        )

      assert "s.89(4) — appointed (by order) — W, fully — provision_by_order" in lines(rules)

      assert "rest except s.124 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )
    end

    test "a purpose beside the territory stays a partial commencement" do
      {rules, _} =
        read(
          [
            "s.2",
            {"s.9(1)",
             "Section 2 comes into force in relation to Wales, for the purpose of making regulations, on such day as the Welsh Ministers may by order appoint."}
          ],
          type: "ukpga",
          head: @assent
        )

      assert "s.2 — appointed (by order) — W, fully — provision_qualified" in lines(rules)
    end
  end

  describe "a provision tied to another's commencement" do
    test "an event day, undated: never Royal Assent's (2021 c.24 s.4(5))" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.2",
            "s.3",
            {"s.4(2)", "Section 1 comes into force—"},
            {"s.4(2)(a)",
             "in relation to premises in England, on such day as the Secretary of State may by regulations made by statutory instrument appoint;"},
            {"s.4(2)(b)",
             "in relation to premises in Wales, on such day as the Welsh Ministers may by regulations made by statutory instrument appoint."},
            {"s.4(5)",
             "Section 3 comes into force at the same time as section 1 comes fully into force in relation to premises in England."},
            {"s.4(6)", "This section comes into force on the day on which this Act is passed."}
          ],
          type: "ukpga",
          made: ~D[2021-04-29],
          head: ~s(<ukm:EnactmentDate Date="2021-04-29"/>)
        )

      assert "s.3 — appointed (with another provision) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert "s.1 — appointed (by order) — E, fully — provision_by_order" in lines(rules)
      assert outcome(rules, rs, "s.3") == :by_order
      assert outcome(rules, rs, "s.1") == :by_order
      assert outcome(rules, rs, "s.4") == :dated
    end
  end

  describe "a list's items with their own verb" do
    test "the rest less an exception, and an item's own qualifier (SI 1994/232 reg.1)" do
      {rules, rs} =
        read([
          {"reg.1",
           "These Regulations, which extend to Great Britain, may be cited as the Batteries and Accumulators (Containing Dangerous Substances) Regulations 1994 and shall come into force as follows:"},
          {"reg.1(a)",
           "except for regulation 4 and regulation 6 to the extent that it applies to regulation 4, they shall come into force on 1st March 1994; and"},
          {"reg.1(b)",
           "regulation 4 and regulation 6 to the extent that it applies to regulation 4 shall come into force on 1st August 1994."},
          "reg.2",
          "reg.4",
          "reg.6"
        ])

      assert "rest except reg.1, reg.4 — 1994-03-01 — everywhere, fully — provision_dated" in lines(
               rules
             )

      assert "reg.4 — 1994-08-01 — everywhere, fully — provision_dated" in lines(rules)

      assert "reg.6 — 1994-08-01 — everywhere, in relation to — provision_qualified" in lines(
               rules
             )

      assert outcome(rules, rs, "reg.2") == :dated
      assert outcome(rules, rs, "reg.4") == :dated
      assert outcome(rules, rs, "reg.6") == :staged
    end
  end

  describe "a date legislation.gov.uk runs together" do
    test "\"6th July2017\", with an exception left to an event (SI 2017/720 art.1(2))" do
      {rules, _} =
        read([
          {"reg.1(2)",
           "This Order comes into force on 6th July2017 except for article 2(2) which comes into force as provided for in article 2(3)."},
          "reg.2(2)",
          {"reg.2(3)",
           "Paragraph (2) comes into force when the installation concerned arrives at its station."}
        ])

      assert lines(rules) == [
               "all except reg.2(2) — 2017-07-06 — everywhere, fully — clause_date",
               "reg.2(2) — unread — everywhere, fully — provision_unread"
             ]
    end
  end

  describe "containers in a list" do
    test "\"Chapters II and III of Part I\": each Chapter, never the whole Part (CROW 2000 s.103(2))" do
      {rules, _} =
        read(
          [
            {"s.1", "", "I", "I"},
            {"s.21", "", "I", "II"},
            {"s.34", "", "I", "III"},
            {"s.40", "", "I", "IV"},
            {"s.103(2)",
             "The following provisions of this Act come into force at the end of the period of two months beginning with the day on which this Act is passed— section 1, Chapters II and III of Part I, and section 40.",
             "V"}
          ],
          type: "ukpga",
          made: ~D[2000-11-30],
          head: ~s(<ukm:EnactmentDate Date="2000-11-30"/>)
        )

      assert "s.1, pt.I.ch.II, pt.I.ch.III, s.40 — 2001-01-30 — everywhere, fully — provision_dated" in lines(
               rules
             )
    end

    test "a Schedule's Parts after \"in Schedule 15,\" (AJA 1999 s.108(3)(f))" do
      {rules, _} =
        read(
          [
            "s.1",
            "s.107",
            {"s.108(3)",
             "The following provisions shall come into force at the end of the period of two months beginning with the day on which this Act is passed—"},
            {"s.108(3)(e)", "Schedule 14,"},
            {"s.108(3)(f)",
             "in Schedule 15, Part III and Part V(1) and (5), apart from the provisions specified in subsection (4), and"},
            {"s.108(3)(g)", "section 107."},
            {"s.108(4)",
             "The provisions excepted from subsection (3)(f) are the repeal of section 67(8) of the Magistrates’ Courts Act 1980 (and that in Schedule 11 to the Children Act 1989) contained in Part V(1) of Schedule 15."}
          ],
          type: "ukpga",
          made: ~D[1999-07-27],
          head: ~s(<ukm:EnactmentDate Date="1999-07-27"/>)
        )

      assert "sch.14, sch.15.pt.III, sch.15.pt.V, s.107 — 1999-09-27 — everywhere, fully — provision_dated" in lines(
               rules
             )
    end
  end

  describe "left to orders" do
    test "\"Apart from …, the preceding provisions … in accordance with orders made by the Treasury\" (2002 c.21 s.61)" do
      {rules, rs} =
        read(
          [
            "s.1",
            "s.54(1)",
            "s.54(2)",
            {"s.61",
             "Apart from section 54(1) and (2), the preceding provisions of this Act come into force in accordance with orders made by the Treasury."},
            "s.62"
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2002-07-08"/>)
        )

      assert "rest except s.61, s.54(1), s.54(2), s.62 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert outcome(rules, rs, "s.1") == :by_order
      assert outcome(rules, rs, "s.54(1)") == :dated
    end

    test "a “namely—” list on a day the Act names: “the transfer date” (1986 c.44 s.68(3))" do
      {rules, _} =
        read(
          [
            {"s.3", "", "I"},
            {"s.49", "", "II"},
            "s.67(3)",
            "s.67(4)",
            {"s.68(3)",
             "The following provisions of this Act, namely— Part II; Part II of Schedule 8 and section 67(3) so far as relating to that Part; and Part II of Schedule 9 and section 67(4) so far as relating to that Part, shall come into force on the transfer date.",
             "III"}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1986-07-25"/>)
        )

      assert "pt.II, sch.8.pt.II, sch.9.pt.II — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert "s.67(3), s.67(4) — appointed (by order) — everywhere, in relation to — provision_qualified" in lines(
               rules
             )
    end
  end

  describe "the same provisions in two statements" do
    test "each statement keeps its rule (1984 c.12 s.110(2), (3))" do
      {rules, _} =
        read(
          [
            "s.109(4)",
            {"s.110(2)",
             "The following provisions of this Act, namely— section 106; Part I of Schedule 5 and section 109(4) so far as relating to that Part, shall come into force on the appointed day."},
            {"s.110(3)",
             "The following provisions of this Act, namely— Part II of Schedule 5 and section 109(4) so far as relating to that Part, shall come into force on the transfer date."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1984-04-12"/>)
        )

      assert ["s.110(2)", "s.110(3)"] ==
               for(%Rule{scope: ["s.109(4)"], source: %{ref: ref}} <- rules, do: ref)
    end
  end

  describe "a list item's own exception and qualifier" do
    test "a qualified item's \"except …\" excepts, never names (1981 c.69 s.74(2))" do
      {rules, _} =
        read(
          [
            {"s.28", "", "II"},
            {"s.29", "", "II"},
            {"s.59", "", "III"},
            {"s.67", "", "IV"},
            {"s.72(4)", "", "IV"},
            {"s.72(6)", "", "IV"},
            {"s.72(14)", "", "IV"},
            {"s.73(1)", "", "IV"},
            {"s.74(2)",
             "The following provisions of this Act, namely— Part II, except sections 29 to 32, 41 and 46 to 48 and Schedule 13; sections 59 to 62 and 65 and 66; and Part IV, except section 72(4), (6) and (14) and section 73(1) so far as relating to Part II of Schedule 17, shall come into force on the expiration of the period of one month beginning with the passing of this Act.",
             "IV"}
          ],
          type: "ukpga",
          made: ~D[1981-10-30],
          head: ~s(<ukm:EnactmentDate Date="1981-10-30"/>)
        )

      assert "pt.II, s.59, pt.IV except s.29, sch.13, s.72(4), s.72(6), s.72(14), s.73(1) — 1981-11-30 — everywhere, fully — provision_dated" in lines(
               rules
             )

      # excepted only so far as relating to that Part: partly in with Part IV
      assert "s.73(1) — 1981-11-30 — everywhere, in relation to — provision_qualified" in lines(
               rules
             )
    end

    test "a list with no \";\": each item's qualifier its own (1996 c.56 s.583(3))" do
      {rules, _} =
        read(
          [
            "s.8",
            "s.317(6)",
            "s.348",
            "s.528",
            "s.582(1)",
            "s.582(2)",
            {"s.583(3)",
             "The following provisions— section 8, section 317(6), section 348, section 528, Part II of Schedule 37 and section 582(1) so far as relating thereto, and Part II of Schedule 38 and section 582(2) so far as relating thereto, shall come into force on such day as the Secretary of State may by order appoint; and different days may be appointed for different provisions and for different purposes."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1996-07-24"/>)
        )

      assert "s.8, s.317(6), s.348, s.528, sch.37.pt.II, sch.38.pt.II — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert "s.582(1), s.582(2) — appointed (by order) — everywhere, in relation to — provision_qualified" in lines(
               rules
             )
    end

    test "an item's exception in brackets, with \"that Schedule\" (CROW 2000 s.103(2))" do
      {rules, _} =
        read(
          [
            "s.64",
            {"s.68", "", "III"},
            {"s.81(2)", "", "III"},
            {"s.81(3)", "", "III"},
            "s.94",
            {"s.103(2)",
             "The following provisions of this Act come into force at the end of the period of two months beginning with the day on which this Act is passed— section 64 and Schedule 7 (apart from paragraphs 6 and 7 of that Schedule), Part III (apart from section 81(2) and (3)), and Schedules 8 and 9 and Parts III and IV of Schedule 16, and section 94."}
          ],
          type: "ukpga",
          made: ~D[2000-11-30],
          head: ~s(<ukm:EnactmentDate Date="2000-11-30"/>)
        )

      assert [line] = Enum.filter(lines(rules), &(&1 =~ "provision_dated"))
      [scope, except] = line |> String.split(" — ") |> hd() |> String.split(" except ")

      assert Enum.sort(String.split(scope, ", ")) ==
               Enum.sort(~w(s.64 sch.7 pt.III sch.8 sch.9 sch.16.pt.III sch.16.pt.IV s.94))

      assert Enum.sort(String.split(except, ", ")) ==
               Enum.sort(~w[sch.7.para.6 sch.7.para.7 s.81(2) s.81(3)])
    end
  end

  describe "a staged clause's items" do
    test "\"the rest of these Regulations\" on exit day, beside an application item (SI 2019/145 reg.1(2))" do
      {rules, _} =
        read(
          [
            {"reg.1(2)", "These Regulations come into force as follows—"},
            {"reg.1(2)(a)",
             "this regulation and Schedule 1 come into force on the seventh day after the day on which these Regulations are made;"},
            {"reg.1(2)(b)",
             "the provisions to which regulation 2 applies have effect in relation to financial years beginning on or after IP completion day;"},
            {"reg.1(2)(c)", "the rest of these Regulations come into force on exit day ."},
            "reg.2",
            "reg.3"
          ],
          made: ~D[2019-01-30]
        )

      assert "reg.1, sch.1 — 2019-02-06 — everywhere, fully — provision_dated" in lines(rules)

      assert "rest except reg.1 — 2020-12-31 — everywhere, fully — provision_dated" in lines(
               rules
             )
    end
  end

  describe "the review's edges" do
    test "\", and all other provisions …\" is its own statement (SI 2006/641 reg.1)" do
      {rules, _} =
        read([
          {"reg.1",
           "Regulation 15 shall come into force on the date on which section 7(3) of the Water Act 2003 comes into force, and all other provisions of these Regulations shall come into force on 1st April 2006."},
          "reg.2",
          "reg.15"
        ])

      assert "reg.15 — appointed (with another provision) — everywhere, fully — provision_by_order" in lines(
               rules
             )

      assert "rest except reg.1 — 2006-04-01 — everywhere, fully — provision_dated" in lines(
               rules
             )
    end

    test "\"immediately after … the other regulations\" is the law's own day (SI 2013/1471 reg.1(3))" do
      {rules, rs} =
        read([
          {"reg.1(2)",
           "Subject to paragraph (3), these Regulations come into force on 1st October 2013."},
          {"reg.1(3)",
           "Regulation 18(2) comes into force immediately after the coming into force of the other regulations."},
          "reg.18(2)"
        ])

      assert lines(rules) == ["all — 2013-10-01 — everywhere, fully — clause_date"]
      assert outcome(rules, rs, "reg.18(2)") == :dated
    end

    test "a deeming is no tied commencement (2011 c.19 s.29(5))" do
      {rules, _} =
        read(
          [
            "s.1",
            {"s.29(3)", "In section 5 omit subsection (2)."},
            {"s.29(5)",
             "The amendments made by subsections (3) and (4) are to be regarded as having come into force at the same time as section 99 of the Pensions Act 2008."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2011-11-03"/>)
        )

      assert lines(rules) == ["all — 2011-11-03 — everywhere, fully — act_enactment"]
    end

    test "provisions named stay named when left to an order for one country (FWMA 2010 s.49(3))" do
      {rules, _} =
        read(
          [
            {"s.1", "", "1"},
            {"s.30", "", "2"},
            {"s.49(3)", "The other provisions of this Act come into force—", "4"},
            {"s.49(3)(a)",
             "other provisions of Parts 1 and 2 come into force in relation to England in accordance with provision made by order of the Secretary of State,",
             "4"}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="2010-04-08"/>)
        )

      assert "pt.1, pt.2 — appointed (by order) — E, fully — provision_by_order" in lines(rules)
    end

    test "a bracketed \"(and section 59 so far as relating to them)\" alone is partly in (2006 c.49 s.61)" do
      {rules, _} =
        read(
          [
            "s.51",
            "s.58",
            "s.59",
            "s.60",
            {"s.61(2)",
             "Sections 51, 58 and 60, and the repeals contained in Schedule 7 under the heading “Spent enactments” (and section 59 so far as relating to them), come into force on the day on which this Act is passed; but—"}
          ],
          type: "ukpga",
          made: ~D[2006-11-08],
          head: ~s(<ukm:EnactmentDate Date="2006-11-08"/>)
        )

      assert "s.51, s.58, s.60 — 2006-11-08 — everywhere, fully — provision_dated" in lines(rules)

      assert "s.59 — 2006-11-08 — everywhere, in relation to — provision_qualified" in lines(
               rules
             )
    end
  end

  describe "the review of the held moves" do
    test "the unqualified items of an unread day stay, unread (1984 c.12 s.110(4))" do
      {rules, _} =
        read(
          [
            "s.109(6)",
            {"s.110(4)",
             "Part III of Schedule 7 and section 109(6) so far as relating to that Part shall come into force on the dissolution of British Telecommunications."}
          ],
          type: "ukpga",
          head: ~s(<ukm:EnactmentDate Date="1984-04-12"/>)
        )

      assert "sch.7.pt.III — unread — everywhere, fully — provision_unread" in lines(rules)

      assert "s.109(6) — unread — everywhere, in relation to — provision_qualified" in lines(
               rules
             )
    end

    test "… and in a list (1986 c.63 s.57(1))" do
      {rules, _} =
        read(
          [
            "s.21",
            "s.24(1)(j)",
            "s.24(3)",
            {"s.57(1)",
             "The following provisions of this Act come into force on the day this Act is passed— section 21 (effect of resolutions relating to housing action area or general improvement area); section 24(1)(j), paragraphs 10 to 13 of Schedule 5, the repeals specified in the first part of Part I of Schedule 12 and section 24(3) so far as relating to those repeals (miscellaneous corrections)."}
          ],
          type: "ukpga"
        )

      assert [plain] = Enum.filter(lines(rules), &(&1 =~ "provision_unread"))
      assert plain =~ "s.24(1)(j)"
      assert plain =~ "sch.5.para.10..sch.5.para.13"
      assert plain =~ "sch.12.pt.I"
      assert plain =~ "— unread — everywhere, fully"

      assert Enum.any?(
               lines(rules),
               &(&1 =~ ~r/^s\.24\(3\) — unread — .* — provision_qualified$/)
             )
    end
  end
end

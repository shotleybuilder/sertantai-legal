defmodule SertantaiLegal.Scraper.Commencement.OwnClausePurposeStagesAndNamedFormsTest do
  @moduledoc """
  A law's own commencement clause, forms of the Waste, Water and Climate
  round (LAT Change Pipeline, step Commencement reader): the whole law
  staged by purpose; a Part less a leading exception; a "not until" whose
  provisions follow "that is to say"; heads conditional on the making day
  and "at the end of" a date; a sub-paragraph named outwards ("Sub-paragraph
  (a) of paragraph (1) of regulation 9"); provisions described, not named.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}

  defp rows(specs) do
    for spec <- specs do
      {sid, text, part} =
        case spec do
          {sid, text, part} -> {sid, text, part}
          {sid, text} -> {sid, text, nil}
          sid -> {sid, "", nil}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: part, chapter: nil}
    end
  end

  defp read(specs, made, type \\ "uksi"),
    do: OwnClause.read("UK_x", %{type_code: type, rows: rows(specs), made: made})

  defp full_from(specs, id, made, type \\ "uksi") do
    rules = read(specs, made, type).rules
    {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, OwnClause.context(rows(specs)))
    {outcome, result && result.full_from}
  end

  defp partly(specs, made) do
    for r <- read(specs, made).rules, r.treatment == :provision_qualified, do: {r.scope, r.when}
  end

  # Jason 2026-11-21 (replacing 2026-11-20's "the whole law partly in
  # force"): a narrow purpose naming the law's own provisions is a list of
  # them. They are fully in force on the first day and every other
  # provision on the last; none is partly in force. "18(1) is full in force
  # one month after made and everything else 5th October. The Order overall
  # would be partly in force until the 5th" (a read-through of its
  # provisions' labels, the Label fold's).
  describe "the whole law staged by purpose" do
    test "items under \"comes into force—\" (SI 2015/776 art.1(c))" do
      specs = [
        {"reg.1", "This Order—"},
        {"reg.1(a)", "may be cited as the Single Use Carrier Bags Charges (England) Order 2015;"},
        {"reg.1(c)", "comes into force—"},
        {"reg.1(c)(i)",
         "for the purposes of article 18(1), one month after the day on which it is made;"},
        {"reg.1(c)(ii)", "for all other purposes, on 5th October 2015;"},
        "reg.2",
        "reg.18",
        "reg.18(1)"
      ]

      made = ~D[2015-03-19]
      assert partly(specs, made) == []
      assert full_from(specs, "reg.2", made) == {:dated, ~D[2015-10-05]}
      assert full_from(specs, "reg.18(1)", made) == {:dated, ~D[2015-04-19]}
    end

    test "\"for the purposes of making appointments under regulation 5 or 11 (approved bodies)\" names both (SI 2020/1095 reg.1(2))" do
      specs = [
        {"reg.1(2)", "These Regulations come into force—"},
        {"reg.1(2)(a)",
         "for the purposes of making appointments under regulation 5 or 11 (approved bodies), on the day after the day on which they are made;"},
        {"reg.1(2)(b)", "for all other purposes, on 1st May 2021."},
        "reg.2",
        "reg.5",
        "reg.11",
        "reg.11(1)"
      ]

      made = ~D[2020-10-07]
      assert partly(specs, made) == []
      assert full_from(specs, "reg.2", made) == {:dated, ~D[2021-05-01]}
      assert full_from(specs, "reg.5", made) == {:dated, ~D[2020-10-08]}
      assert full_from(specs, "reg.11(1)", made) == {:dated, ~D[2020-10-08]}
    end

    test "the purposes of several provisions, the later day a named day (SI 2018/1221 reg.2)" do
      specs = [
        {"reg.2", "These Regulations come into force—"},
        {"reg.2(a)",
         "for the purposes of regulations 1, 2 and 3 on the 22nd day after the day on which these Regulations are laid, and"},
        {"reg.2(b)", "for all other purposes, on exit day."},
        "reg.1",
        "reg.3",
        "reg.3(1)",
        "reg.4"
      ]

      # laid 28th November 2018 (the CLML's `ukm:Laid`): regulations 1, 2
      # and 3 fully in force on the 22nd day after, the rest on exit day
      # (IP completion day, the instrument being made before exit day),
      # nothing partly
      input = %{type_code: "uksi", rows: rows(specs), made: ~D[2018-11-22], laid: ~D[2018-11-28]}
      rules = OwnClause.read("UK_x", input).rules
      context = OwnClause.context(rows(specs))

      full = fn id ->
        {outcome, result} = OwnCommencement.outcome(rules, "UK_x", id, context)
        {outcome, result && result.full_from}
      end

      assert [] == for(r <- rules, r.treatment == :provision_qualified, do: r)

      for id <- ["reg.1", "reg.2", "reg.3", "reg.3(1)"],
          do: assert(full.(id) == {:dated, ~D[2018-12-20]})

      assert full.("reg.4") == {:dated, ~D[2020-12-31]}

      # no laid day held: (a) is unread, never dropped; the rest keeps its day
      made = ~D[2018-11-22]
      assert partly(specs, made) == []

      assert [%{scope: ["reg.1", "reg.2", "reg.3"], when: :unread}] =
               Enum.filter(read(specs, made).rules, &(&1.treatment == :provision_unread))

      assert full_from(specs, "reg.4", made) == {:dated, ~D[2020-12-31]}
    end

    # the clause's own paragraph (2) sits beside the dash's items, the
    # clause holding no (1): it is no item of the list
    test "a numbered paragraph after the list is no item of it (SI 2019/74 reg.2)" do
      specs = [
        {"reg.1",
         "These Regulations may be cited as the Air Quality (Amendment of Domestic Regulations) (EU Exit) Regulations 2019."},
        {"reg.2", "These Regulations come into force—"},
        {"reg.2(a)",
         "for the purposes of regulations 1, 2, and 3, 21 days after the day on which the Regulations are made, and"},
        {"reg.2(b)", "for all other purposes, on 1st March 2019."},
        {"reg.2(2)",
         "Any provision of these Regulations amending a provision in an enactment has the same extent as the provision being amended."},
        "reg.3",
        {"reg.3(1)", "The Air Quality Standards Regulations 2010 are amended as follows."},
        "reg.4"
      ]

      made = ~D[2019-01-01]
      assert partly(specs, made) == []
      assert full_from(specs, "reg.3(1)", made) == {:dated, ~D[2019-01-22]}
      assert full_from(specs, "reg.4", made) == {:dated, ~D[2019-03-01]}
      assert read(specs, made).unread == []
    end

    test "a narrow purpose naming no provision keeps the whole law partly in force first" do
      specs = [
        {"reg.1", "These Regulations come into force—"},
        {"reg.1(a)", "for the purpose of enabling directions to be given, on 1st April 2020;"},
        {"reg.1(b)", "for all other purposes, on 1st October 2020."},
        "reg.2"
      ]

      made = ~D[2020-03-01]
      assert partly(specs, made) == [{:rest, {:date, ~D[2020-04-01]}}]
      assert full_from(specs, "reg.2", made) == {:staged, ~D[2020-10-01]}
    end

    test "in one sentence, after the citation (SI 1991/346 reg.1(1))" do
      specs = [
        "reg.1",
        {"reg.1(1)",
         "These Regulations may he cited as the Control of Pollution (Silage, Slurry and Agricultural Fuel Oil) (Scotland) Regulations 1991 and shall come into force, for the purpose of regulation 10(2), on 20th March 1991 and for all other purposes on 1st September 1991."},
        "reg.2",
        "reg.10",
        "reg.10(2)"
      ]

      made = ~D[1991-02-20]
      assert read(specs, made).law.date == ~D[1991-03-20]
      assert partly(specs, made) == []
      assert full_from(specs, "reg.2", made) == {:dated, ~D[1991-09-01]}
      assert full_from(specs, "reg.10(2)", made) == {:dated, ~D[1991-03-20]}
    end

    # "all other purposes" first: every provision is wholly in force from
    # that day but the provisions the waiting purpose names, partly in
    # force until the purpose's day (Jason 2026-11-20)
    test "the named purpose the later stage: only its provisions wait (SI 2004/1261 reg.1)" do
      specs = [
        {"reg.1",
         "These Regulations may be cited as the Competition Act 1998 and other enactments (Amendment) Regulations 2004 and shall come into force—"},
        {"reg.1(a)",
         "for the purposes of regulation 4 as it gives effect to paragraphs 50(a) and 54(8) of Schedule 1, on 1st May 2007; and"},
        {"reg.1(b)", "for all other purposes, on 1st May 2004."},
        "reg.2",
        "reg.4",
        "sch.1.para.49",
        "sch.1.para.50",
        "sch.1.para.50(a)",
        "sch.1.para.54(8)"
      ]

      made = ~D[2004-04-29]
      named = ["reg.4", "sch.1.para.50(a)", "sch.1.para.54(8)"]
      assert read(specs, made).law.date == ~D[2004-05-01]
      assert partly(specs, made) == [{named, {:date, ~D[2004-05-01]}}]
      assert full_from(specs, "reg.2", made) == {:dated, ~D[2004-05-01]}
      assert full_from(specs, "sch.1.para.49", made) == {:dated, ~D[2004-05-01]}
      assert full_from(specs, "reg.4", made) == {:staged, ~D[2007-05-01]}
      assert full_from(specs, "sch.1.para.50(a)", made) == {:staged, ~D[2007-05-01]}
      assert full_from(specs, "sch.1.para.54(8)", made) == {:staged, ~D[2007-05-01]}
    end

    test "the same in one sentence: the named purpose the later day" do
      specs = [
        "reg.1",
        {"reg.1(1)",
         "These Regulations shall come into force, for the purposes of regulation 4, on 1st May 2007 and for all other purposes on 1st May 2004."},
        "reg.2",
        "reg.4"
      ]

      made = ~D[2004-04-29]
      assert read(specs, made).law.date == ~D[2004-05-01]
      assert partly(specs, made) == [{["reg.4"], {:date, ~D[2004-05-01]}}]
      assert full_from(specs, "reg.2", made) == {:dated, ~D[2004-05-01]}
      assert full_from(specs, "reg.4", made) == {:staged, ~D[2007-05-01]}
    end

    test "a waiting purpose naming no provision keeps the whole law partly in force" do
      specs = [
        {"reg.1", "These Regulations shall come into force—"},
        {"reg.1(a)", "for the purposes of making applications, on 1st May 2007; and"},
        {"reg.1(b)", "for all other purposes, on 1st May 2004."},
        "reg.2"
      ]

      made = ~D[2004-04-29]
      assert partly(specs, made) == [{:rest, {:date, ~D[2004-05-01]}}]
      assert full_from(specs, "reg.2", made) == {:staged, ~D[2007-05-01]}
    end

    test "a named provision for a purpose is that provision's, as before" do
      specs = [
        "reg.1",
        {"reg.1(1)", "These Regulations come into force on 1st May 2004."},
        {"reg.1(2)",
         "Regulation 4 comes into force on 1st March 2004 for the purposes of making regulations."},
        "reg.2",
        "reg.4"
      ]

      assert partly(specs, ~D[2004-02-01]) == [{["reg.4"], {:date, ~D[2004-03-01]}}]
    end
  end

  test "\"Except section 53 (and schedule 4), this Part comes into force …\" (asp 2013/5 s.56(1))" do
    specs = [
      {"s.1", "", "1"},
      {"s.53", "", "8"},
      {"s.54", "", "8"},
      {"s.56", "", "8"},
      {"s.56(1)",
       "Except section 53 (and schedule 4), this Part comes into force on the day after Royal Assent.",
       "8"},
      {"s.56(2)",
       "The other provisions of this Act (including that section (and schedule)) come into force on such day as the Scottish Ministers may by order appoint.",
       "8"},
      "sch.4"
    ]

    made = ~D[2013-04-09]
    assert read(specs, made, "asp").unread == []
    assert full_from(specs, "s.54", made, "asp") == {:dated, ~D[2013-04-10]}
    assert {:by_order, _} = full_from(specs, "s.53", made, "asp")
    assert {:by_order, _} = full_from(specs, "sch.4", made, "asp")
    assert {:by_order, _} = full_from(specs, "s.1", made, "asp")
  end

  test "\"shall not come into force until …, that is to say, Parts II, III …\" (1963 c.33 s.94(2))" do
    specs = [
      {"s.1", "", "I"},
      {"s.9", "", "II"},
      {"s.17", "", "II"},
      {"s.17(6)", "", "II"},
      {"s.23", "", "III"},
      {"s.30", "", "IV"},
      {"s.40", "", "V"},
      {"s.45", "", "VI"},
      {"s.50", "", "VII"},
      {"s.66", "", "VIII"},
      {"s.68", "", "VIII"},
      {"s.94", "", "IX"},
      {"s.94(1)", "This Act may be cited as the London Government Act 1963.", "IX"},
      {"s.94(2)",
       "The following provisions of this Act shall not come into force until 1st April 1965, that is to say, Parts II, III, and V to VIII other than sections 17(6), 48(2), 62(4), 66, 69, and 70.",
       "IX"}
    ]

    made = ~D[1963-07-31]

    dated =
      for r <- read(specs, made, "ukpga").rules,
          r.when == {:date, ~D[1965-04-01]},
          r.treatment == :provision_dated,
          do: r

    assert [%{scope: ["pt.II", "pt.III", "pt.V", "pt.VI", "pt.VII", "pt.VIII"], except: except}] =
             dated

    assert "s.17(6)" in except and "s.66" in except
    assert {_, ~D[1965-04-01]} = full_from(specs, "s.9", made, "ukpga")
    # the rest of the Act is not the list's
    refute match?({_, ~D[1965-04-01]}, full_from(specs, "s.30", made, "ukpga"))
    refute match?({_, ~D[1965-04-01]}, full_from(specs, "s.66", made, "ukpga"))
  end

  describe "heads conditional on the making day (SI 2024/1366 art.2)" do
    @specs [
      {"reg.1", "", "1"},
      {"reg.2", "", "1"},
      {"reg.2(1)",
       "The following provisions come into force on the day after the date on which this Order is made—",
       "1"},
      {"reg.2(1)(a)", "this Part;", "1"},
      {"reg.2(1)(b)", "article 4;", "1"},
      {"reg.2(2)", "If this Order is made on or before 30th December 2024—", "1"},
      {"reg.2(2)(a)", "articles 44 and 45 come into force at the end of 31st December 2024;",
       "1"},
      {"reg.2(2)(b)",
       "except as provided in paragraph (1), the rest of this Order comes into force on 1st January 2025.",
       "1"},
      {"reg.2(3)", "If this Order is made on or after 31st December 2024—", "1"},
      {"reg.2(3)(a)",
       "articles 44 and 45 come into force at the end of the day before the relevant commencement day;",
       "1"},
      {"reg.2(3)(b)",
       "except as provided in paragraph (1), the rest of this Order comes into force on the relevant commencement day.",
       "1"},
      {"reg.4", "", "2"},
      {"reg.5", "", "2"},
      {"reg.44", "", "3"},
      {"reg.45", "", "3"}
    ]

    test "the condition that holds is read, \"at the end of\" a date as the next day" do
      made = ~D[2024-12-18]
      read = read(@specs, made)

      assert [%{source: %{ref: "reg.2(2)(a)"}, when: {:date, ~D[2025-01-01]}}] =
               Enum.filter(read.rules, &(&1.scope == ["reg.44", "reg.45"]))

      # the head whose condition fails states nothing
      assert read.unread == []
      assert full_from(@specs, "reg.44", made) == {:dated, ~D[2025-01-01]}
      assert full_from(@specs, "reg.5", made) == {:dated, ~D[2025-01-01]}
      assert full_from(@specs, "reg.4", made) == {:dated, ~D[2024-12-19]}
    end

    test "no words are left: the day used, the failed head's statements not stated" do
      read = read(@specs, ~D[2024-12-18])

      left =
        for %{row: row, leftovers: [_ | _] = l} <- Leftovers.sentences(rows(@specs), read),
            do: {row, l}

      assert left == []
    end

    test "the other head when the making day is later" do
      read = read(@specs, ~D[2025-01-10])
      refute Enum.any?(read.rules, &(&1.source.ref in ["reg.2(2)(a)", "reg.2(2)(b)"]))
      assert Enum.any?(read.unread, &(&1.evidence == "UK_x:reg.2(3)(a)"))
    end

    test "no making day held: neither head is dropped" do
      read = read(@specs, nil)
      assert Enum.any?(read.rules, &(&1.source.ref == "reg.2(2)(a)"))
      assert Enum.any?(read.unread, &(&1.evidence == "UK_x:reg.2(3)(a)"))
    end
  end

  test "an item's purpose in its middle limits only what follows it (WSI 2005/1806 reg.1(2)(i))" do
    specs = [
      {"reg.1(1)",
       "The title of these Regulations is the Hazardous Waste (Wales) Regulations 2005."},
      {"reg.1(2)", "These Regulations come into force as follows—"},
      {"reg.1(2)(i)",
       "Parts 1, 2, paragraph 1 of Part 1 of Schedule 12 and, for the purposes of that paragraph only, in Part 5, regulation 59(3) and Schedule 9 and regulation 74 on 6 July 2005; and"},
      {"reg.1(2)(ii)", "the remainder, on 16 July 2005."},
      {"reg.2", "", "1"},
      {"reg.59", "", "5"},
      {"reg.59(3)", "", "5"},
      {"reg.60", "", "5"},
      {"reg.74", "", "11"}
    ]

    made = ~D[2005-06-28]
    assert full_from(specs, "reg.2", made) == {:dated, ~D[2005-07-06]}
    assert full_from(specs, "reg.59(3)", made) == {:staged, ~D[2005-07-16]}
    assert full_from(specs, "reg.60", made) == {:dated, ~D[2005-07-16]}
  end

  test "\"paragraphs (4) and (5) of regulation 29\" are those paragraphs (NISR 2002/331 reg.1(4))" do
    specs = [
      {"reg.1(2)",
       "Regulation 1, 2, 25, 27, 28 and 36 shall come into operation on 28th November 2002."},
      {"reg.1(4)",
       "Regulations 4 and 17 to 24, paragraphs (4) and (5) of regulation 29, and paragraph (1) of regulation 38, shall come into operation on 25th December 2003."},
      {"reg.1(5)",
       "All other provisions of these Regulations shall come into operation on 1st January 2004."},
      "reg.29",
      "reg.29(1)",
      "reg.29(4)",
      "reg.29(4)(a)",
      "reg.29(5)",
      "reg.38",
      "reg.38(1)"
    ]

    made = ~D[2002-10-01]
    assert full_from(specs, "reg.29(1)", made) == {:dated, ~D[2004-01-01]}
    assert full_from(specs, "reg.29(4)(a)", made) == {:dated, ~D[2003-12-25]}
    assert full_from(specs, "reg.29(5)", made) == {:dated, ~D[2003-12-25]}
    assert full_from(specs, "reg.38(1)", made) == {:dated, ~D[2003-12-25]}
  end

  test "\"Sub-paragraph (a) of paragraph (1) of regulation 9\" is that sub-paragraph (NISR 2008/231 reg.1(6))" do
    specs = [
      "reg.1",
      {"reg.1(1)",
       "These Regulations may be cited as the Quality of Bathing Water Regulations (Northern Ireland) 2008 and come into operation in accordance with paragraphs (2) to (6)."},
      {"reg.1(4)",
       "Subject to paragraph (6), regulations 8 to10, 11(1) (a) and (5), 13, 15 to 18 and 20 come into operation on 24th March 2012."},
      {"reg.1(6)",
       "Sub-paragraph (a) of paragraph (1) of regulation 9, regulation 10 insofar as it relates to that sub-paragraph and regulation 21 come into operation on 30th September 2015."},
      "reg.8",
      "reg.9",
      "reg.9(1)",
      "reg.9(1)(a)",
      "reg.9(1)(b)",
      "reg.10",
      "reg.21"
    ]

    made = ~D[2008-06-01]
    rules = read(specs, made).rules

    assert [%{scope: ["reg.9(1)(a)", "reg.21"]}] =
             Enum.filter(
               rules,
               &(&1.when == {:date, ~D[2015-09-30]} and &1.treatment == :provision_dated)
             )

    assert full_from(specs, "reg.9(1)(a)", made) == {:dated, ~D[2015-09-30]}
    assert full_from(specs, "reg.9(1)(b)", made) == {:dated, ~D[2012-03-24]}
    assert full_from(specs, "reg.21", made) == {:dated, ~D[2015-09-30]}
  end

  test "provisions described, not named, stay unread though qualified (SI 2010/231 art.1(3))" do
    specs = [
      "reg.1",
      {"reg.1(1)", "This Order may be cited as the Pharmacy Order 2010."},
      {"reg.1(3)",
       "Except as provided for by paragraph (2), the provisions of this Order which confer powers enabling rules or orders to be made, or which enable standards or requirements to be set by the Council, come into force on the making of this Order, but for the purpose only of the exercise of those powers."},
      "reg.2"
    ]

    read = read(specs, ~D[2010-02-10])
    assert [%{evidence: "UK_x:reg.1(3)", refs: []}] = read.unread
    # (the law-level rule apart) no rule dates a provision from it
    assert Enum.reject(read.rules, &(&1.scope == :all)) == []
  end
end

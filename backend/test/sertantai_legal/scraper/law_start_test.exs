defmodule SertantaiLegal.Scraper.LawStartTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Clause

  defp rows(texts), do: for({sid, text} <- texts, do: %{section_id: "UK_x:" <> sid, text: text})

  defp start(type, texts, opts \\ []),
    do: LawStart.resolve(Map.merge(%{type_code: type, rows: rows(texts)}, Map.new(opts)))

  describe "the catalogue" do
    test "every treatment is listed once, with its rule and decision" do
      ids = Enum.map(LawStart.catalogue(), &elem(&1, 0))
      assert ids == Enum.uniq(ids)
      assert List.last(ids) == :no_clause

      for {_, dates?, rule, decided} <- LawStart.catalogue(),
          do: assert(is_boolean(dates?) and rule != "" and decided != "")
    end

    test "known limits never carry a date" do
      refute LawStart.dates?(:by_order)
      refute LawStart.dates?(:eu_directive)
      assert LawStart.dates?(:clause_made_relative)
    end
  end

  describe "metadata treatments come first (unchanged from LR-24)" do
    test "the register's date wins" do
      s =
        start("uksi", [{"reg.1", "These Regulations come into force on 1st June 2015."}],
          lrt_date: ~D[2015-06-02]
        )

      assert %LawStart{treatment: :lrt_metadata, date: ~D[2015-06-02]} = s
    end

    test "CLML ComingIntoForce, the earliest; an Act's Royal Assent; an SI never by enactment" do
      si =
        ~s(<ukm:ComingIntoForce><ukm:DateTime Date="1995-11-01"/><ukm:DateTime Date="1995-10-09"/></ukm:ComingIntoForce>)

      assert %{treatment: :clml_coming_into_force, date: ~D[1995-10-09]} =
               start("nisr", [], clml_head: si)

      act = ~s(<ukm:EnactmentDate Date="1974-07-31"/>)

      assert %{treatment: :act_enactment, date: ~D[1974-07-31]} =
               start("ukpga", [], clml_head: act)

      assert %{treatment: :no_clause} = start("uksi", [], clml_head: act)
    end
  end

  describe "the law's commencement clause (P1)" do
    test "a stated date (nisr 1995/87)" do
      s =
        start("nisr", [
          {"reg.1",
           "These Regulations may be cited as the Explosives in Harbour Areas Regulations (Northern Ireland) 1995 and shall come into operation on 17th April 1995."}
        ])

      assert %LawStart{treatment: :clause_date, date: ~D[1995-04-17], evidence: "UK_x:reg.1"} = s
    end

    test "\"Subject to paragraph (3)\": the general date (uksi 2015/1947)" do
      s =
        start(
          "uksi",
          [
            {"reg.1(1)", "This Order may be cited as the Renewables Obligation Order 2015."},
            {"reg.1(2)",
             "Subject to paragraph (3), this Order comes into force on the first day of the month following that in which it is made."},
            {"reg.1(3)",
             "Articles 45(4)(d) and (5)(a) and 48 come into force on the first day of the second month following that in which this Order is made."}
          ],
          made: ~D[2015-11-26]
        )

      assert %{treatment: :clause_made_relative, date: ~D[2015-12-01], evidence: "UK_x:reg.1(2)"} =
               s
    end

    test "asides and prefixes without a comma (nisr 2015/236, uksi 1994/1768, ssi 2010/60)" do
      for text <- [
            "Except as provided by paragraph (3) these Regulations shall come into operation on 1st June 2015.",
            "These Regulations shall, except as provided by paragraphs (3) and (4) below, come into force on 1st June 2015.",
            "These Regulations may be cited as the Management of Extractive Waste (Scotland) Regulations 2010 and, other than regulation 3(1), come into force on 1st June 2015."
          ] do
        assert %{treatment: :clause_date, date: ~D[2015-06-01]} =
                 start("nisr", [{"reg.1(2)", text}])
      end
    end

    test "only parts commence: the earliest date their provision states (nisi 2006/1254, uksi 1988/819)" do
      s =
        start(
          "nisi",
          [
            {"art.1(2)",
             "This Article and Article 2 shall come into operation on the expiration of seven days from the day on which this Order is made."},
            {"art.1(3)",
             "The remaining provisions of this Order shall come into operation on such day or days as the Department may by order appoint."}
          ],
          made: ~D[2006-06-27]
        )

      assert %{treatment: :clause_staged, date: ~D[2006-07-05], evidence: "UK_x:art.1(2)"} = s

      s =
        start("uksi", [
          {"reg.1(2)",
           "This regulation, regulations 2, 5, 10 and 11 shall come into force on 6th June 1988. The remainder of these regulations shall come into force on 1st October 1988."}
        ])

      assert %{treatment: :clause_staged, date: ~D[1988-06-06]} = s
    end

    test "list items under the clause (uksi 2006/599-like); dates written \"6thApril 2012\"; by territory, the earliest" do
      s =
        start("uksi", [
          {"reg.1",
           "These Regulations may be cited as the Railways (Safety) Regulations 2006 and shall come into force—"},
          {"reg.1(a)", "on 1st October 2006, for the purposes of regulations 1 to 3; and"},
          {"reg.1(b)", "for all other purposes, on 1st April 2007."}
        ])

      assert %{treatment: :clause_staged, date: ~D[2006-10-01]} = s

      assert %{treatment: :clause_date, date: ~D[2012-04-06]} =
               start("uksi", [
                 {"reg.1",
                  "These Regulations may be cited as the Control of Asbestos Regulations 2012 and come into force on 6thApril 2012."}
               ])

      assert %{date: ~D[2007-04-02]} =
               start("uksi", [
                 {"reg.1(2)",
                  "These Regulations come into force in England on 1st July 2007 and in Wales on 2nd April 2007."}
               ])

      assert %{treatment: :clause_date, date: ~D[2006-03-26]} =
               start("ssi", [
                 {"reg.1",
                  "These Regulations shall come into force at 0600 hours on 26th March 2006."}
               ])
    end

    test "higher ordinals; \"the day after the day they are made\"" do
      made = ~D[2019-04-01]

      assert Clause.tail_date("on the fortieth day after the day on which they were made", made) ==
               {:clause_made_relative, ~D[2019-05-11]}

      assert Clause.tail_date("on the day after the day they are made", made) ==
               {:clause_made_relative, ~D[2019-04-02]}
    end

    test "laid-relative: unread (we don't hold the laid date)" do
      s =
        start(
          "uksi",
          [
            {"reg.1",
             "These Regulations come into force 21 days after the day on which they are laid."}
          ],
          made: ~D[2026-01-01]
        )

      assert s.treatment == :clause_unread
    end

    test "another law's provision commencing is not this law's clause (nisr 2012/286)" do
      s =
        start("nisr", [
          {"reg.2",
           "Section 2(1)(d) of the Corporate Manslaughter and Corporate Homicide Act 2007 shall come into force on 3rd September 2012."}
        ])

      assert s.treatment == :no_clause
    end

    test "a clause that only mentions the law coming into force is not its clause" do
      s =
        start("mwa", [
          {"s.12",
           "Regulations under section 54 that are in force immediately before this Part comes into force have effect as if made under this section."}
        ])

      assert s.treatment == :no_clause
    end

    test "staged: the earliest date its paragraphs state (Fire Safety Order 2005-like)" do
      s =
        start(
          "uksi",
          [
            {"art.1(1)",
             "This Order may be cited as the Regulatory Reform (Fire Safety) Order 2005 and shall come into force in accordance with paragraphs (2) and (3)."},
            {"art.1(2)",
             "This article and article 52(1)(a) shall come into force on the day after the day on which this Order is made."},
            {"art.1(3)",
             "All other articles of this Order shall come into force on 1st April 2006."}
          ],
          made: ~D[2005-06-07]
        )

      assert %{treatment: :clause_staged, date: ~D[2005-06-08]} = s
    end

    test "staged with nothing readable: unread, listed" do
      s =
        start("ssi", [
          {"reg.25(1)",
           "These Regulations come into force in accordance with paragraphs (2) and (3)."}
        ])

      assert %{treatment: :clause_unread, date: nil, evidence: "UK_x:reg.25(1)"} = s
    end

    test "made-relative without a made date: unread, never a guess" do
      s =
        start("uksi", [
          {"reg.1",
           "These Regulations come into force on the day after the day on which they are made."}
        ])

      assert %{treatment: :clause_unread, date: nil} = s
    end
  end

  describe "Acts: their own clause before Royal Assent (Interpretation Act 1978 s.4 applies only where no provision is made)" do
    @assent ~s(<ukm:EnactmentDate Date="1990-06-29"/>)

    test "a dated clause wins over Royal Assent (ukpga 1990/11)" do
      s =
        start(
          "ukpga",
          [
            {"s.20(2)",
             "This Act shall come into force at the end of the period of three months beginning with the day on which it is passed."}
          ],
          clml_head: @assent,
          made: ~D[1990-06-29]
        )

      assert %{treatment: :clause_made_relative, date: ~D[1990-09-29]} = s
    end

    test "a clause the reader can't date yields to Royal Assent" do
      s =
        start(
          "ukpga",
          [
            {"s.20(2)",
             "This Act shall come into force on such day as the Secretary of State may by order appoint."}
          ],
          clml_head: @assent
        )

      assert %{treatment: :act_enactment, date: ~D[1990-06-29]} = s
    end

    test "\"on the day this Act is passed\" (no \"on which\"): the earliest part (ukpga 2008/27 s.100)" do
      s =
        start(
          "ukpga",
          [
            {"s.100(1)",
             "Part 1 (carbon target and budgeting), Part 2 (the Committee on Climate Change) and this Part come into force on the day this Act is passed."},
            {"s.100(5)",
             "The other provisions of this Act come into force at the end of two months beginning with the day it is passed."}
          ],
          clml_head: @assent,
          made: ~D[1990-06-29]
        )

      assert %{treatment: :clause_staged, date: ~D[1990-06-29]} = s
    end

    test "parts commencing on Royal Assent (asp 2024/14-like)" do
      s =
        start(
          "asp",
          [
            {"s.70(1)",
             "This section and sections 62, 63 and 65 come into force on the day after Royal Assent."}
          ],
          clml_head: @assent,
          made: ~D[1990-06-29]
        )

      assert %{treatment: :clause_staged, date: ~D[1990-06-30]} = s
    end
  end

  describe "made-relative counting" do
    @made ~D[1987-07-21]

    test "the day on which, the day after, the Nth day after" do
      assert Clause.tail_date("on the day on which it is made", @made) ==
               {:clause_made_relative, @made}

      assert Clause.tail_date("on the day on which this Act is passed—", @made) ==
               {:clause_made_relative, @made}

      assert Clause.tail_date("on the day after the day on which they are made", @made) ==
               {:clause_made_relative, ~D[1987-07-22]}

      assert Clause.tail_date(
               "on the twenty-first day after the day on which they are made",
               @made
             ) == {:clause_made_relative, ~D[1987-08-11]}

      assert Clause.tail_date("six months after the date on which they are made", @made) ==
               {:clause_made_relative, ~D[1988-01-21]}
    end

    test "a period from the day excludes it (+1 day); beginning with the day includes it" do
      assert Clause.tail_date(
               "on the expiration of two months from the day on which it is made",
               @made
             ) ==
               {:clause_made_relative, ~D[1987-09-22]}

      assert Clause.tail_date(
               "at the end of the period of three months beginning with the day on which it is passed",
               @made
             ) ==
               {:clause_made_relative, ~D[1987-10-21]}

      assert Clause.tail_date(
               "on the expiration of 6 months from the day on which it is made",
               @made
             ) ==
               {:clause_made_relative, ~D[1988-01-22]}
    end

    test "the first day of the month following, and of the Nth month following" do
      assert Clause.tail_date(
               "on the first day of the month following that in which it is made",
               @made
             ) ==
               {:clause_made_relative, ~D[1987-08-01]}

      assert Clause.tail_date(
               "on the first day of the second month following that in which this Order is made",
               @made
             ) ==
               {:clause_made_relative, ~D[1987-09-01]}
    end
  end

  test "LR-43: a title with \"etc.\" doesn't end the citation-and-commencement sentence (SI 2019/696)" do
    rows = [
      %{
        section_id: "UK_uksi_2019_696:reg.1",
        text:
          "These Regulations may be cited as the Product Safety and Metrology etc. (Amendment etc.) (EU Exit) Regulations 2019 and come into force on exit day."
      }
    ]

    assert %LawStart{treatment: :clause_named_day, date: ~D[2020-12-31]} =
             Clause.read(rows, ~D[2019-03-27])
  end

  describe "named days (P2)" do
    test "IP completion day, also immediately before / after; exit day" do
      assert Clause.tail_date("on IP completion day", nil) == {:clause_named_day, ~D[2020-12-31]}

      assert Clause.tail_date("immediately before IP completion day", nil) ==
               {:clause_named_day, ~D[2020-12-31]}

      assert Clause.tail_date("on exit day", nil) == {:clause_named_day, ~D[2020-01-31]}
    end

    test "CR-09: \"exit day\" in an instrument made before exit day is IP completion day (EU(WA)A 2020 Sch. 5 para. 1(1)), unless it disapplies that (para. 1(2))" do
      assert Clause.tail_date("on exit day", ~D[2019-03-28]) ==
               {:clause_named_day, ~D[2020-12-31]}

      assert Clause.tail_date("immediately before exit day", ~D[2019-02-11]) ==
               {:clause_named_day, ~D[2020-12-31]}

      # made on or after exit day: exit day as written
      assert Clause.tail_date("on exit day", ~D[2020-01-31]) ==
               {:clause_named_day, ~D[2020-01-31]}

      assert Clause.tail_date(
               "on exit day (and paragraph 1(1) of Schedule 5 to the European Union (Withdrawal Agreement) Act 2020 does not apply)",
               ~D[2020-01-27]
             ) == {:clause_named_day, ~D[2020-01-31]}
    end
  end

  describe "known limits (P4, P5)" do
    test "by order" do
      s =
        start("nisi", [
          {"art.1(2)",
           "This Order shall come into operation on such day or days as the Department may by order appoint."}
        ])

      assert %{treatment: :by_order, date: nil} = s
    end

    test "tied to another law's commencement" do
      s =
        start("uksi", [
          {"reg.1(2)",
           "These Regulations come into force at the same time as section 83 of the 2022 Act comes into force."}
        ])

      assert %{treatment: :tied_to_other_law, date: nil} = s
    end

    test "a defined day the reader doesn't know" do
      s =
        start("uksi", [
          {"reg.1(2)", "These Regulations come into force on the main commencement day."}
        ])

      assert %{treatment: :clause_unread} = s
    end
  end

  describe "EU law (P3)" do
    test "a directive: known limit" do
      assert %{treatment: :eu_directive, date: nil} = start("eudr", [])
    end

    test "a regulation whose metadata is the original act's: EUR-Lex entry into force" do
      head =
        ~s(<ukm:CELEX Value="32007R1497"/><RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE type="date"> <VALUE>2008-01-08</VALUE></RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE>)

      assert %{treatment: :eu_entry_into_force, date: ~D[2008-01-08]} =
               start("eur", [], clml_head: head)
    end

    test "a consolidation's metadata: the date the text states, else publication-relative" do
      head =
        ~s(<ukm:CELEX Value="02006R0561-20200820"/><RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE type="date"> <VALUE>2020-08-20</VALUE></RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE>)

      stated = [
        {"art.29",
         "This Regulation shall enter into force on 11 April 2007, with the exception of Articles 10(5), 26(3) and (4) and 27, which shall enter into force on 1 May 2006."}
      ]

      assert %{treatment: :eu_entry_into_force, date: ~D[2007-04-11]} =
               start("eur", stated, clml_head: head)

      relative = [
        {"art.18",
         "This Regulation shall enter into force on the 20th day after that of its publication in the Official Journal of the European Union."}
      ]

      assert %{treatment: :eu_publication_relative, date: nil} =
               start("eur", relative, clml_head: head)
    end
  end
end

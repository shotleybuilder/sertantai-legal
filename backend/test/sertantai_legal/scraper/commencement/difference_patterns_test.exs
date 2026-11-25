defmodule SertantaiLegal.Scraper.Commencement.Review.DifferencePatternsTest do
  @moduledoc """
  The feed differences' one-law wordings as patterns (RULES
  `feed-differences-are-patterns-by-feed-coverage`): each matches its own
  law's words, and a near form doesn't.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Review.DifferencePatterns, as: P

  defp rows(pairs), do: for({id, text} <- pairs, do: %{id: id, text: text})

  describe "own/1, a law's rows" do
    test "excepted paragraph omitted (NISR 2011/127 reg.1(4))" do
      law =
        rows([
          {"reg.1(1)",
           "These Regulations may be cited as the Waste Regulations (Northern Ireland) 2011 and except as provided in paragraphs (2), (3) and (4) shall come into operation on 8th April 2011."},
          {"reg.1(2)", "Regulation 17 shall come into operation on 8th October 2011."},
          {"reg.1(4)", ". . . . . . . . . . . . . . . ."}
        ])

      assert P.own(law) == [{"excepted-paragraph-omitted", "reg.1(1)"}]
      # every excepted paragraph still in the text: no hit
      assert P.own(Enum.take(law, 2)) == []
    end

    test "whole law in stages by purpose (SI 2016/359 reg.1)" do
      law =
        rows([
          {"reg.1(3)",
           "Subject to paragraphs (4) and (5), these Regulations come into force on 15 March 2016."},
          {"reg.1(4)",
           "Subject to paragraph (5), these Regulations come into force on 15 March 2020 in relation to any container in which oil is being stored on 15 March 2016."}
        ])

      assert P.own(law) == [{"whole-law-purpose-stages", "reg.1"}]
      assert P.own(Enum.take(law, 1)) == []

      # the rest "in so far as not already in force" completes the law (SI 2026/15 reg.1(3))
      completing =
        rows([
          {"reg.1(2)",
           "The following provisions of these Regulations come into force on 18th February 2026—"},
          {"reg.1(3)",
           "In so far as they are not already in force, these Regulations come into force on 6th April 2026."}
        ])

      assert P.own(completing) == []
    end

    test "alternative days, whichever is later (SI 2020/1265 art.2(2))" do
      law =
        rows([
          {"reg.2(2)",
           "Article 25, Schedule 5 and paragraph 4 of Schedule 8 come into force— … whichever is later."}
        ])

      assert P.own(law) == [{"alternative-days-whichever", "reg.2(2)"}]
      assert P.own(rows([{"reg.3", "whichever is later, the Agency must decide."}])) == []

      # a duty counting from the law's day is no commencement (SI 2025/1298 reg.10(4))
      duty =
        "Where a cargo ship … ending immediately before the day on which these Regulations come into force, that ship need not comply until the date of such survey, whichever occurs first."

      assert P.own(rows([{"reg.10(4)", duty}])) == []
    end

    test "tied to another law's provision (SI 2006/641 reg.1(2))" do
      law =
        rows([
          {"reg.1(2)",
           "Regulation 15 shall come into force on the date on which section 7(3) of the Water Act 2003 comes into force, and all other provisions of these Regulations shall come into force on 1st April 2006."}
        ])

      assert P.own(law) == [{"provision-tied-to-another-law", "reg.1(2)"}]
      # the other law's title with "(Scotland)" or "and", short ("the 2022
      # Act"), or a whole other law (SI 2020/1540, 2025/878)
      for text <- [
            "Regulation 4 comes into force on the day on which section 11 of the Fire (Scotland) Act 2005 comes into force.",
            "Regulation 2 comes into force immediately after section 162 of the Health and Care Act 2022 comes into force.",
            "Regulation 3 comes into force at the same time as section 83 of the 2022 Act comes into force.",
            "Regulations 13 and 15, and this regulation, come into force immediately before the coming into force of the Environment and Rural Affairs (Amendment) (EU Exit) Regulations 2019.",
            "Regulations 7(2) and 13(1) come into force immediately after the coming into force of regulations 4 and 17 of the Aviation Safety (Amendment) Regulations 2024."
          ] do
        assert P.own(rows([{"reg.1(2)", text}])) == [
                 {"provision-tied-to-another-law", "reg.1(2)"}
               ],
               text
      end

      # the whole law tied: `LawStart`'s `:tied_to_other_law` reads it
      for text <- [
            "This Order may be cited as the Fire (Additional Function) (Scotland) Order 2005 and shall come into force on the day on which section 11 of the Fire (Scotland) Act 2005 comes into force.",
            "These Regulations come into force on the day on which the Biodiversity Gain Site Register Regulations 2024 come into force."
          ] do
        assert P.own(rows([{"reg.1", text}])) == [], text
      end

      # passed, IP completion day, an agreement: no law tied to
      for text <- [
            "This section comes into force on the day on which this Act is passed.",
            "These Regulations come into force immediately before IP completion day.",
            "It shall come into operation on the date on which the Headquarters Agreement between the Government of the United Kingdom and the Fund enters into force."
          ] do
        assert P.own(rows([{"reg.1", text}])) == [], text
      end

      # tied to the law's own section: not another law
      own =
        rows([
          {"s.4(5)", "Section 3 comes into force at the same time as section 1 of this Act."}
        ])

      assert P.own(own) == []
    end
  end

  describe "order/1, an order's articles and table rows" do
    test "application with an exception (SI 2009/359 art.1(2))" do
      units = [
        %{
          kind: "article",
          id: "article-1",
          text:
            "1 This Order may be cited as … . 2 This Order applies in relation to England only except article 2(d) which extends to Scotland only."
        }
      ]

      assert P.order(units) == [{"application-with-exception", "article-1"}]

      plain = [
        %{
          kind: "article",
          id: "article-1",
          text: "This Order applies in relation to England only."
        }
      ]

      assert P.order(plain) == []
    end

    test "subject to a territorial paragraph (WSI 2004/1488 art.2)" do
      units = [
        %{
          kind: "article",
          id: "article-2",
          text:
            "2 1 Subject to paragraph (2) Sections 4, 5, 9,10, 19 and 35(a) and (c) of the Waste and Emissions Trading Act 2003 come into force on 25 June 2004. 2 Sections 4,5,9,10 and 35(a) are brought into force in relation to Wales ."
        }
      ]

      assert P.order(units) == [{"subject-to-territory-paragraph", "article-2"}]

      dated = [
        %{
          kind: "article",
          id: "article-2",
          text:
            "1 Subject to paragraph (2) section 4 comes into force on 1 May 2004. 2 Section 5 comes into force on 1 June 2004 in relation to Wales."
        }
      ]

      assert P.order(dated) == []
    end

    test "a table row's long exception (NISR 2007/194 Sch.1)" do
      units = [
        %{
          kind: "table",
          id: "schedule-1-part-I-tr-3",
          text:
            "In Article 288, paragraph (1) in so far as it relates to: Article 9(1) and 9(2) of the 1999 Order; Article 9(3) of the 1999 Order in so far as it gives effect to Schedule 1 of that Order, except paragraphs 1(1)(b), 2(1)(b), 2(3)(a) and 3 of that Schedule"
        }
      ]

      assert P.order(units) == [{"table-row-long-exception", "schedule-1-part-I-tr-3"}]

      mid =
        "Section 83(1) (except in so far as it relates to section 24 of the Act), (3) (except as already in operation), (6) and (7) | Application of the Act to the Crown."

      # an item's own bracketed exception with more of the list after it is
      # its own form: held where the feed is silent (1963 c.41), the Reader's
      assert P.order([%{kind: "table", id: "t", text: mid}]) == [
               {"table-row-exception-mid-list", "t"}
             ]

      # NISR 2007/194's own: an exception, then more of the list after a ";"
      more =
        "Article 9(3) of the 1999 Order except paragraphs 1(1)(b), 2(1)(b), 2(3)(a) and 3 of that Schedule; and Articles 10 and 13"

      assert P.order([%{kind: "table", id: "t", text: more}]) == [
               {"table-row-long-exception", "t"}
             ]

      # one exception closing the item, however many numbers it names
      for text <- [
            "Article 13 except 13(1)(b) and (6)",
            "Paragraph 9(2)(i) | except so far as it relates to the substitution of a reference to “section 316(1) to (3)” by a reference to “section 316”",
            "Part IV, section 186, Part VIII (except section 204) or section 250 of the Town and Country Planning Act 1990"
          ] do
        assert P.order([%{kind: "table", id: "t", text: text}]) == [], text
      end
    end
  end

  test "territory_orders/1: an Act commenced by one order per territory (2003 c.33)" do
    titles = %{
      "UK_ukpga_2003_33" => [
        {"UK_uksi_2004_3181",
         "The Waste and Emissions Trading Act 2003 (Commencement No.1) (England) Order 2004"},
        {"UK_wsi_2004_1488",
         "The Waste and Emissions Trading Act 2003 (Commencement) (Wales) Order 2004"}
      ],
      "UK_ukpga_2003_37" => [
        {"UK_uksi_2004_641", "The Water Act 2003 (Commencement No. 1) Order 2004"}
      ]
    }

    assert P.territory_orders(titles) == [
             {"one-order-per-territory", "UK_ukpga_2003_33",
              ["UK_uksi_2004_3181", "UK_wsi_2004_1488"]}
           ]
  end

  test "names/0 and entries/1: every pattern names the feed differences it judges" do
    assert length(P.names()) == 9
    keys = P.names() |> Enum.flat_map(&P.entries/1)
    assert "differ | own dated by clause_made_relative | own earlier @ UK_uksi_2020_1265" in keys
    assert length(keys) == length(Enum.uniq(keys))
  end

  test "verdict/1: held where the feed is silent is the Reader's; else a known limit" do
    assert P.verdict("alternative-days-whichever", %{covered: 3, none: 1}) == :fix
    assert P.verdict("alternative-days-whichever", %{covered: 3, none: 0}) == :known
    # the Reader reads the law right: the difference is the feed's staging
    assert P.verdict("one-order-per-territory", %{covered: 10, none: 2}) == :yardstick
  end

  test "status/4: the verdict's head, with the old status's own words" do
    old =
      "known: a one-law commencement wording (RULES section 11, …; Jason 2026-11-22): art.25's \"…, whichever is later\" after the items"

    new = P.status("alternative-days-whichever", :fix, %{covered: 1, none: 1}, old)

    assert new =~
             ~r/^fix: the pattern alternative-days-whichever is held where the feed holds no commencement \(1 laws; 1 where it does\)/

    assert String.ends_with?(new, ~s{: art.25's "…, whichever is later" after the items})

    assert P.status("whole-law-purpose-stages", :known, %{covered: 2, none: 0}, old) =~
             ~r/^known: the pattern whole-law-purpose-stages is held only where the feed holds the commencement \(2 laws\)/
  end
end

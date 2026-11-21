defmodule SertantaiLegal.Scraper.Commencement.OwnClauseNestedItemsTest do
  @moduledoc """
  The rows nested under a commencement list item that ends on a dash are
  that item's: its provision with the paragraphs they name ("in regulation
  14— (i) paragraph (1) in so far as …; (ii) paragraphs (2) to (5)"), what
  it excepts ("section 159, other than— (i) subsection (4)(b) and (c); …")
  or the matter of its qualifier ("so far as relating to the following—").
  A Schedule's Part named for its repeals in a subsection another statement
  points to ("The provisions specified in subsection (2) …") is partly in.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.ListItems
  alias SertantaiLegal.Scraper.LawStart.NestedItems

  defp rows(law, list),
    do: for({sid, text} <- list, do: %{section_id: "#{law}:#{sid}", text: text, part: nil})

  defp bare(law, sids), do: rows(law, Enum.map(sids, &{&1, "…"}))

  defp rules(law, type, rows, made),
    do:
      OwnClause.rules(law, %{
        type_code: type,
        rows: rows,
        made: made,
        clml_head: nil,
        lrt_date: nil
      })

  defp of(rules, ref), do: Enum.filter(rules, &(&1.source.ref == ref and is_list(&1.scope)))
  defp scope(rules), do: Enum.flat_map(rules, & &1.scope)

  describe "the Bathing Water Regulations 2013 (SI 2013/1675) reg.1(2)" do
    @law "UK_uksi_2013_1675"

    defp bathing do
      provisions =
        ~w[reg.2 reg.9 reg.14 reg.14(1) reg.14(2) reg.14(3) reg.14(4) reg.14(5) reg.14(6)
           reg.15 reg.18 reg.19 reg.19(1) reg.19(2) reg.19(3) reg.19(3)(a) reg.19(3)(b)
           reg.19(3)(c) reg.19(4) reg.19(4)(a) reg.19(4)(b) reg.20 reg.21]

      clause =
        rows(@law, [
          {"reg.1(1)", "These Regulations may be cited as the Bathing Water Regulations 2013."},
          {"reg.1(2)", "The following provisions come into force on 31st July 2013—"},
          {"reg.1(2)(a)", "this regulation and regulations 2 to 9;"},
          {"reg.1(2)(b)", "in regulation 14—"},
          {"reg.1(2)(b)(i)", "paragraph (1) in so far as it relates to paragraphs (2) to (5);"},
          {"reg.1(2)(b)(ii)", "paragraphs (2) to (5);"},
          {"reg.1(2)(c)", "regulations 15 to 18;"},
          {"reg.1(2)(d)", "in regulation 19—"},
          {"reg.1(2)(d)(i)", "paragraph (1);"},
          {"reg.1(2)(d)(ii)", "paragraph 3(b) and (c);"},
          {"reg.1(2)(d)(iii)", "paragraph (4)(b);"},
          {"reg.1(2)(e)", "regulation 20."},
          {"reg.1(3)", "All remaining provisions come into force on 24th March 2015."}
        ])

      rules(@law, "uksi", clause ++ bare(@law, provisions), ~D[2013-07-10]) |> of("reg.1(2)")
    end

    test "regulation 14's paragraphs (2) to (5) are in full, never regulation 14 whole" do
      full = bathing() |> Enum.filter(&is_nil(&1.purposes)) |> scope()

      assert Enum.all?(
               ~w[reg.1 reg.20 reg.19(1) reg.19(3)(b) reg.19(3)(c) reg.19(4)(b)],
               &(&1 in full)
             )

      assert Enum.any?(full, &String.starts_with?(&1, "reg.14(2)"))
      refute "reg.14" in full
      refute "reg.19" in full
      refute "reg.14(1)" in full
    end

    test "the nested paragraphs are regulation 14's and 19's, never regulation 1's own" do
      all = bathing() |> scope()

      refute Enum.any?(all, &String.starts_with?(&1, "reg.1("))
    end

    test "regulation 14(1) is partly in: in so far as it relates to paragraphs (2) to (5)" do
      assert [partly] = bathing() |> Enum.reject(&is_nil(&1.purposes))
      assert partly.scope == ["reg.14(1)"]
      assert partly.when == {:date, ~D[2013-07-31]}
    end
  end

  describe "the Local Government and Elections (Wales) Act 2021 (asc 2021/1) s.175(1)(g)" do
    @law "UK_asc_2021_1"

    defp wales do
      provisions =
        ~w[s.50 s.159 s.159(1) s.159(4) s.159(4)(a) s.159(4)(b) s.159(4)(c) s.159(5) s.160
           s.175(4) s.175(4)(a) s.175(4)(b) s.175(5)]

      clause =
        rows(@law, [
          {"s.175(1)",
           "The following provisions come into force on the day after the day on which this Act receives Royal Assent—"},
          {"s.175(1)(a)", "section 50;"},
          {"s.175(1)(g)", "section 159, other than—"},
          {"s.175(1)(g)(i)", "subsection (4)(b) and (c);"},
          {"s.175(1)(g)(ii)",
           "in table 2 in subsection (5), the entry relating to the Auditor General for Wales' functions under Chapter 1 of Part 6;"},
          {"s.175(1)(g)(iii)",
           "in that table, in the entry relating to the Welsh Ministers' functions under this Act, the words from “, Chapter 1” to “areas)”;"},
          {"s.175(1)(h)", "section 160;"}
        ])

      rules(@law, "asc", clause ++ bare(@law, provisions), ~D[2021-01-20]) |> of("s.175(1)")
    end

    test "section 159 is in, less subsection (4)(b) and (c); section 175's own subsections are not named" do
      assert [full] = wales() |> Enum.filter(&is_nil(&1.purposes))

      assert "s.159" in full.scope
      assert "s.159(4)(b)" in full.except
      assert "s.159(4)(c)" in full.except
      refute Enum.any?(wales() |> scope(), &String.starts_with?(&1, "s.175("))
      refute "pt.6.ch.1" in full.scope
    end

    test "subsection (5), excepted for a table entry only, is partly in" do
      assert [full] = wales() |> Enum.filter(&is_nil(&1.purposes))
      assert [partly] = wales() |> Enum.reject(&is_nil(&1.purposes))

      assert partly.scope == ["s.159(5)"]
      assert "s.159(5)" in full.except
    end
  end

  describe "the Local Government and Elections (Wales) Act 2021 (asc 2021/1) s.175(2)" do
    @law "UK_asc_2021_1"

    defp taken_out do
      provisions =
        ~w[pt.2 pt.7 s.129 s.129(6) s.138 s.138(1) s.138(1)(b) s.138(3) s.139 s.139(2)
           s.139(3) s.141 s.141(1) s.141(1)(a) s.141(3) s.145(7)(b) s.148 s.149 s.175(1)
           s.175(1)(f) s.175(6) s.175(7) sch.1 sch.1.para.1(3) sch.1.para.2(2) sch.1.para.2(4)
           sch.1.para.2(5) sch.1.para.6(2)(a) sch.1.para.12(1)(a) sch.1.para.12(2)
           sch.1.para.12(4)(a) sch.11 sch.11.pt.2 sch.11.para.7(3)(a) sch.11.para.7(3)(c)
           sch.12 sch.12.para.1(1) sch.12.para.7(6)]

      clause =
        rows(@law, [
          {"s.175(2)",
           "Subsection (1)(f) does not apply to the following provisions in Part 7 (which come into force in accordance with subsection (6) or (7) of this section)—"},
          {"s.175(2)(a)", "Chapter 2;"},
          {"s.175(2)(c)", "in section 138—"},
          {"s.175(2)(c)(i)", "subsection (1)(b);"},
          {"s.175(2)(c)(ii)", "subsection (3);"},
          {"s.175(2)(d)", "in section 139—"},
          {"s.175(2)(d)(i)", "subsection (2);"},
          {"s.175(2)(d)(ii)", "in subsection (3), the words “or (2)”;"},
          {"s.175(2)(f)", "in section 141—"},
          {"s.175(2)(f)(i)",
           "in subsection (1)(a), the words “to another principal council (“council B”) or”;"},
          {"s.175(2)(f)(iv)", "subsection (3);"},
          {"s.175(2)(g)", "section 145(7)(b);"},
          {"s.175(2)(h)", "section 148;"},
          {"s.175(2)(i)", "in section 149—"},
          {"s.175(2)(i)(i)",
           "the definitions of “abolition request”, “council under consideration” and “restructuring council”;"},
          {"s.175(2)(k)", "in Schedule 1—"},
          {"s.175(2)(k)(i)", "each reference to “11 or”;"},
          {"s.175(2)(k)(ii)", "in paragraph 1(3), the words “11(3) or”;"},
          {"s.175(2)(k)(iii)", "paragraphs 2(2), 6(2)(a) and 12(1)(a), (2) and (4)(a);"},
          {"s.175(2)(k)(iv)", "paragraph 2(4) and (5);"},
          {"s.175(2)(l)", "in Schedule 11—"},
          {"s.175(2)(l)(i)", "Part 2;"},
          {"s.175(2)(l)(ii)", "in paragraph 7(3)(a), the words “or by virtue of paragraph 4”;"},
          {"s.175(2)(l)(iii)", "paragraph 7(3)(c);"},
          {"s.175(2)(m)", "in Schedule 12—"},
          {"s.175(2)(m)(i)",
           "in paragraph 1(1), the words “or after giving notice as described in section 129(6)”;"},
          {"s.175(2)(m)(ii)",
           "in paragraph 7(6), in the definition of “the relevant date”, paragraph (b)."}
        ])

      # (a row of Chapter 2 of Part 7, as the LAT holds it)
      chapter = [%{section_id: "#{@law}:s.130", text: "…", part: "7", chapter: "2"}]

      rules(@law, "asc", clause ++ bare(@law, provisions) ++ chapter, ~D[2021-01-20])
      |> of("s.175(2)")
    end

    defp whole(rules), do: rules |> Enum.filter(&is_nil(&1.purposes)) |> scope()
    defp partly(rules), do: rules |> Enum.reject(&is_nil(&1.purposes)) |> scope()

    test "a Schedule opened for its parts: the paragraphs and Part named are that Schedule's" do
      whole = whole(taken_out())

      for ref <- ~w[sch.1.para.2(2) sch.1.para.6(2)(a) sch.1.para.12(1)(a) sch.1.para.12(2)
                    sch.1.para.12(4)(a) sch.1.para.2(4) sch.1.para.2(5) sch.11.pt.2
                    sch.11.para.7(3)(c)] do
        assert ref in whole
      end

      refute "pt.2" in whole
    end

    test "words in a paragraph of the Schedule leave that paragraph partly out; quoted words name nothing" do
      rules = taken_out()

      for ref <- ~w[sch.1.para.1(3) sch.11.para.7(3)(a) sch.12.para.1(1) sch.12.para.7(6) sch.1] do
        assert ref in partly(rules)
        refute ref in whole(rules)
      end

      refute Enum.any?(scope(rules), &String.starts_with?(&1, "s.129"))
    end

    test "words in a subsection of a section opened leave that subsection partly out, never the section" do
      rules = taken_out()

      assert "s.139(3)" in partly(rules)
      assert "s.141(1)(a)" in partly(rules)
      assert "s.139(2)" in whole(rules)
      refute "s.139" in scope(rules)
      refute "s.141" in scope(rules)
      # (definitions in the section, no subsection named: the section, partly)
      assert "s.149" in partly(rules)
    end

    test "Chapter 2, a provision in Part 7, is that Part's" do
      assert "pt.7.ch.2" in whole(taken_out())
    end

    test "subsection (1)(f), what the provisions are taken out of, is no provision of the list" do
      refute Enum.any?(scope(taken_out()), &String.starts_with?(&1, "s.175"))
    end
  end

  describe "NestedItems.read/2, a Schedule opened" do
    test "bare paragraphs and Parts are the Schedule's; words in a paragraph leave it partly in" do
      assert [
               %{plain: "Part 2 of Schedule 11", qualified: ""},
               %{plain: "", qualified: "paragraph 7(3)(a) of Schedule 11"},
               %{plain: "paragraph 7(3)(c) of Schedule 11", qualified: ""}
             ] =
               NestedItems.read("in Schedule 11—", [
                 "Part 2;",
                 "in paragraph 7(3)(a), the words “or by virtue of paragraph 4”;",
                 "paragraph 7(3)(c);"
               ])
    end

    test "paragraphs with a qualifier of their own are partly in (SI 2007/2709 reg.3(c)(ii))" do
      assert [%{plain: "", qualified: "paragraphs 11 and 22(3) of Schedule 7"}] =
               NestedItems.read("in Schedule 7—", [
                 "paragraphs 11 and 22(3) to the extent that they relate to the Administrative Justice and Tribunals Council;"
               ])
    end

    test "a row naming no paragraph leaves the Schedule partly in" do
      assert [%{plain: "", qualified: "Schedule 1"}] =
               NestedItems.read("in Schedule 1—", ["each reference to “11 or”;"])
    end
  end

  describe "the Criminal Justice Act 1988 (1988 c.33) s.171(5)" do
    @law "UK_ukpga_1988_33"

    defp justice do
      clause =
        rows(@law, [
          {"s.171(5)",
           "The following provisions shall come into force on the day this Act is passed— section 66; section 103(1), so far as it relates— section 129; section 132, so far as it relates to the Local Government Finance Act 1982; section 141; subsection (1) of section 170, so far as relating to the following— section 112A(1) of the Land Registration Act 1925; the Visiting Forces Act 1952; section 67(6) of the Criminal Justice Act 1967; this section; sections 172 and 173."},
          {"s.171(5)(a)",
           "to the addition of two subsections at the end of section 8 of the Drug Trafficking Offences Act 1986;"},
          {"s.171(5)(b)", "to the insertion of a new subsection in section 24 of that Act; and"}
        ])

      provisions =
        ~w[s.8 s.24 s.66 s.67 s.103 s.103(1) s.112 s.129 s.132 s.141 s.170 s.170(1) s.172 s.173]

      rules(@law, "ukpga", clause ++ bare(@law, provisions), ~D[1988-07-29]) |> of("s.171(5)")
    end

    test "section 129, the item after a qualifier's dash, is in full" do
      full = justice() |> Enum.filter(&is_nil(&1.purposes)) |> scope()

      assert Enum.all?(~w[s.66 s.129 s.141 s.171 s.172 s.173], &(&1 in full))
      refute "s.103(1)" in full
      refute "s.170(1)" in full
    end

    test "sections 103(1), 132 and 170(1) are partly in; the matters listed name no section of this Act" do
      partly = justice() |> Enum.reject(&is_nil(&1.purposes)) |> scope()

      assert Enum.sort(partly) == ["s.103(1)", "s.132", "s.170(1)"]
    end
  end

  describe "NestedItems.fold/1" do
    defp nested(list), do: NestedItems.fold(rows("UK_x", list))

    test "rows under no dash-ended item stay flat" do
      assert {["section 1;", "section 2."], []} =
               nested([{"s.9(1)(a)", "section 1;"}, {"s.9(1)(b)", "section 2."}])
    end

    test "a relative clause's own rows stay flat (the Agriculture Act 2020 s.57(1)(b))" do
      assert {[_, _], []} =
               nested([
                 {"s.57(1)(b)", "any provision of Parts 1 to 7 which—"},
                 {"s.57(1)(b)(i)", "confers a power to make regulations, or"}
               ])
    end

    test "a qualifier's dash: its rows are its matter, and the item is partly in" do
      assert {[], [%{plain: "", qualified: qualified}]} =
               nested([
                 {"s.171(5)(a)",
                  "subsection (1) of section 170, so far as relating to the following—"},
                 {"s.171(5)(a)(i)", "section 112A(1) of the Land Registration Act 1925;"}
               ])

      assert qualified =~ "section 170"
      refute qualified =~ "112A"
    end
  end

  describe "the Clean Neighbourhoods and Environment Act 2005 (2005 c.16) s.108(1) and (2)" do
    @law "UK_ukpga_2005_16"

    defp cnea do
      provisions = ~w[s.2 s.6 s.13 s.15 s.17 s.47 s.48 s.104 sch.4.para.4 s.108(8)]

      schedule =
        for part <- ~w[1 4 10],
            do: %{section_id: "#{@law}:sch.5.pt.#{part}", text: "…", part: nil}

      clause =
        rows(@law, [
          {"s.108(1)", "The provisions specified in subsection (2) come into force—"},
          {"s.108(1)(a)",
           "in relation to England, in accordance with provision made by order by the Secretary of State; and"},
          {"s.108(1)(b)",
           "in relation to Wales, in accordance with provision so made by the National Assembly for Wales."},
          {"s.108(2)", "The provisions referred to in subsection (1) are—"},
          {"s.108(2)(a)", "section 2;"},
          {"s.108(2)(b)",
           "sections 6 to 13 and 15 to 17 and, in Part 1 of Schedule 5, the repeals to the Refuse Disposal (Amenity) Act 1978 (c. 3) and the Road Traffic Regulation Act 1984 (c. 27);"},
          {"s.108(2)(h)",
           "section 47, paragraph 4 of Schedule 4 and, in Part 4 of Schedule 5, the repeals to the Environmental Protection Act 1990, other than the repeal to section 33 of that Act;"},
          {"s.108(2)(i)", "section 48;"},
          {"s.108(2)(r)", "section 104 and Part 10 of Schedule 5."}
        ])

      rules(@law, "ukpga", clause ++ bare(@law, provisions) ++ schedule, ~D[2005-04-07])
    end

    test "the Parts of Schedule 5 named for their repeals are out of the full rule; Part 10, named whole, is in" do
      for ref <- ["s.108(1)(a)", "s.108(1)(b)"] do
        assert [full] = cnea() |> of(ref) |> Enum.filter(&is_nil(&1.purposes))
        assert Enum.all?(~w[s.2 s.47 s.48 s.104 sch.5.pt.10 sch.4.para.4], &(&1 in full.scope))
        refute "sch.5.pt.1" in full.scope
        refute "sch.5.pt.4" in full.scope
      end
    end

    test "they are partly in, country by country, by order" do
      for {ref, place} <- [{"s.108(1)(a)", "E"}, {"s.108(1)(b)", "W"}] do
        assert [partly] = cnea() |> of(ref) |> Enum.reject(&is_nil(&1.purposes))
        assert Enum.sort(partly.scope) == ["sch.5.pt.1", "sch.5.pt.4"]
        assert partly.purposes == :in_relation_to
        assert partly.territory == place
        assert partly.when == {:appointed, "by order"}
      end
    end
  end

  describe "the Coal Industry Act 1994 (1994 c.21) s.68(4) and (6)" do
    @law "UK_ukpga_1994_21"

    defp coal do
      provisions = ~w[s.1 s.7 s.8 s.9 s.54 s.67 s.67(1) s.67(2) s.67(6) s.67(8)]

      schedule = [%{section_id: "#{@law}:sch.11.pt.I", text: "…", part: nil}]

      clause =
        rows(@law, [
          {"s.68(4)",
           "Apart from the provisions to which subsections (2) and (3) above apply and the provisions specified in subsection (6) below (which come into force on the passing of this Act), this Act shall come into force on such day as the Secretary of State may by order made by statutory instrument appoint."},
          {"s.68(6)",
           "The provisions of this Act mentioned in subsection (4) above are this section and—"},
          {"s.68(6)(a)", "sections 7 to 9;"},
          {"s.68(6)(c)", "section 54;"},
          {"s.68(6)(e)", "section 67(2) to (6); and"},
          {"s.68(6)(f)",
           "Part I of Schedule 11 to this Act and subsection (8) of section 67 so far as it relates to that Part of that Schedule."}
        ])

      OwnClause.rules(@law, %{
        type_code: "ukpga",
        rows: clause ++ bare(@law, provisions) ++ schedule,
        made: ~D[1994-07-05],
        clml_head: ~s(<ukm:EnactmentDate Date="1994-07-05"/>)
      })
      |> Enum.filter(&(&1.source.ref == "s.68(4)"))
    end

    test "Part I of Schedule 11 is in full on passing; section 67(8) partly, so far as it relates to that Part" do
      dated = Enum.filter(coal(), &(is_list(&1.scope) and &1.when == {:date, ~D[1994-07-05]}))
      assert [full] = Enum.filter(dated, &is_nil(&1.purposes))
      assert [partly] = Enum.reject(dated, &is_nil(&1.purposes))

      assert Enum.all?(~w[s.7 s.54 sch.11.pt.I], &(&1 in full.scope))
      refute "s.67(8)" in full.scope
      assert partly.scope == ["s.67(8)"]
    end

    test "neither is left to the order: both are excepted from the Act's general rule" do
      assert [general] = Enum.filter(coal(), &(&1.scope == :all))
      assert "sch.11.pt.I" in general.except
      assert "s.67(8)" in general.except
    end
  end

  describe "ListItems.split/3" do
    test "a qualifier's dash ends its item in a list written in one text" do
      assert ["section 103(1), so far as it relates", "section 129"] =
               ListItems.split("", "section 103(1), so far as it relates— section 129", [])
               |> Enum.map(&String.trim/1)
    end
  end
end

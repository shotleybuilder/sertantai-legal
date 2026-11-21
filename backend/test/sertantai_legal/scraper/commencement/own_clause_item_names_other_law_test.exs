defmodule SertantaiLegal.Scraper.Commencement.OwnClauseItemNamesOtherLawTest do
  @moduledoc """
  A list item that names another law only in its bracketed description or
  in its qualifier is still the law's own provision (LAT Change Pipeline,
  step Commencement reader): "regulation 4(c) (amendment of regulation 17A
  of the 2008 Regulations: …)" is regulation 4(c), and "section 32(3) so
  far as relating to section 91ZD of that Act" is section 32(3), partly.
  An item whose own provisions are another law's stays that law's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.ItemSubject

  defp rows(specs),
    do:
      for(
        {sid, text} <- specs,
        do: %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
      )

  defp rules(specs, type \\ "uksi", made \\ ~D[2025-06-10]),
    do: OwnClause.rules("UK_x", %{type_code: type, rows: rows(specs), made: made})

  defp from(rules, ref), do: Enum.filter(rules, &(&1.source.ref == ref and is_list(&1.scope)))
  defp scope(rules), do: rules |> Enum.flat_map(& &1.scope) |> Enum.sort()

  defp blank(ids), do: Enum.map(ids, &{&1, ""})

  test "a description naming another law's regulation is no part of the item (SI 2025/662 reg.1(2))" do
    rules =
      rules(
        [
          {"reg.1", ""},
          {"reg.1(2)", "The following provisions come into force on 1st October 2025—"},
          {"reg.1(2)(a)",
           "regulation 4(c) (amendment of regulation 17A of the 2008 Regulations: new definition of “valid claim”);"},
          {"reg.1(2)(b)",
           "regulation 6(2) (amendment of regulation 17C of the 2008 Regulations: circumstances which may trigger payments);"},
          {"reg.1(2)(c)",
           "regulation 7(2) to (6) and (9) to (11) (amendment of regulation 17D of the 2008 Regulations: validity of claims etc);"},
          {"reg.1(2)(d)",
           "regulation 13(1), in so far as it inserts new regulations 17IA to 17IE of the 2008 Regulations;"},
          {"reg.1(2)(e)",
           "regulation 15(a) (consequential amendment of regulation 17K of the 2008 Regulations);"},
          {"reg.1(2)(f)",
           "regulation 16 (consequential amendment of regulation 17N of the 2008 Regulations);"},
          {"reg.1(2)(g)",
           "regulation 18 (savings: matters arising on or after 2nd July 2025 but before 1st October 2025);"},
          {"reg.1(2)(h)",
           "regulation 20 (transitional provisions: statements of communication methods)."},
          {"reg.1(3)", "Otherwise these Regulations come into force on 2nd July 2025."}
        ] ++
          blank(
            ~w[reg.4 reg.4(c) reg.6 reg.6(2) reg.7 reg.7(2) reg.7(3) reg.7(4) reg.7(5) reg.7(6) reg.7(7) reg.7(9) reg.7(10) reg.7(11) reg.13 reg.13(1) reg.13(2) reg.15 reg.15(a) reg.16 reg.17 reg.18 reg.20]
          )
      )

    [whole] = rules |> from("reg.1(2)") |> Enum.filter(&(&1.purposes == nil))
    assert whole.when == {:date, ~D[2025-10-01]}

    for ref <-
          ~w[reg.4(c) reg.6(2) reg.7(2) reg.7(6) reg.7(9) reg.7(11) reg.15(a) reg.16 reg.18 reg.20],
        do: assert(Enum.any?(whole.scope, &(&1 == ref or String.contains?(&1, ref))), ref)

    # "in so far as it inserts …": regulation 13(1) partly, and never
    # regulation 17 (the 2008 Regulations')
    [partly] = rules |> from("reg.1(2)") |> Enum.reject(&(&1.purposes == nil))
    assert partly.scope == ["reg.13(1)"]
    assert partly.when == {:date, ~D[2025-10-01]}
    refute "reg.17" in scope(from(rules, "reg.1(2)"))
  end

  test "\"so far as relating to section 91ZD of that Act\" leaves the item partly in (2022 c.30 s.170(4)(a))" do
    rules =
      rules(
        [
          {"s.170", ""},
          {"s.170(4)(a)",
           "the following provisions come into force on such day as the Welsh Ministers may by regulations appoint—"},
          {"s.170(4)(a)(i)",
           "section 31 so far as relating to section 120I of the Building Act 1984;"},
          {"s.170(4)(a)(ii)", "section 32(3) so far as relating to section 91ZD of that Act;"},
          {"s.170(4)(a)(iii)",
           "section 42 so far as relating to section 58Z2 and 58Z10 of that Act;"}
        ] ++ blank(~w[s.31 s.32 s.32(3) s.42 s.58 s.91 s.120]),
        "ukpga",
        ~D[2022-04-28]
      )

    assert [partly] = from(rules, "s.170(4)(a)")
    assert Enum.sort(partly.scope) == ["s.31", "s.32(3)", "s.42"]
    assert partly.purposes != nil
    assert partly.when == {:appointed, "by order"}
  end

  test "\"for the purposes of … section 17A of that Act\" on a day unread keeps the item (SI 2012/3039 reg.1(3)(b))" do
    rules =
      rules(
        [
          {"reg.1", ""},
          {"reg.1(3)",
           "The following provisions come into force for the purposes specified on the day after the day on which these Regulations are made—"},
          {"reg.1(3)(a)",
           "regulation 14, for the purposes of the Secretary of State granting consents under section 14(6) of the Animals (Scientific Procedures) Act 1986;"},
          {"reg.1(3)(b)",
           "regulation 18, for the purposes of the Secretary of State granting consents under section 17A of that Act;"}
        ] ++ blank(~w[reg.14 reg.17 reg.18]),
        "uksi",
        nil
      )

    assert scope(from(rules, "reg.1(3)")) == ["reg.14", "reg.18"]
  end

  test "\"so far as relating to the power … under section 43F of the 1996 Act\" (1998 c.23 s.18(4)(a))" do
    rules =
      rules(
        [
          {"s.18", ""},
          {"s.18(4)",
           "The following provisions shall come into force on the passing of this Act—"},
          {"s.18(4)(a)",
           "section 1 so far as relating to the power to make an order under section 43F of the 1996 Act,"},
          {"s.18(4)(c)", "section 17, and"},
          {"s.18(4)(d)", "this section."}
        ] ++ blank(~w[s.1 s.17 s.43]),
        "ukpga",
        ~D[1998-07-02]
      )

    assert [partly] = rules |> from("s.18(4)") |> Enum.reject(&(&1.purposes == nil))
    assert partly.scope == ["s.1"]
    assert partly.when == {:date, ~D[1998-07-02]}
  end

  test "a purpose naming another Act's provisions keeps the item's own (2016 c.12 s.44(1)(d))" do
    rules =
      rules(
        [
          {"s.44", ""},
          {"s.44(1)",
           "The following provisions of this Act come into force on the day on which this Act is passed—"},
          {"s.44(1)(d)",
           "section 33 and Schedule 5 (Sunday working) for the purpose of enabling the exercise of any power to make regulations under any provision of the Employment Rights Act 1996 inserted by that Schedule;"},
          {"s.44(1)(e)", "section 38 (UK Green Investment Bank: transitional provision);"}
        ] ++ blank(~w[s.33 s.38 sch.5 sch.5.para.1]),
        "ukpga",
        ~D[2016-05-04]
      )

    assert [partly] = rules |> from("s.44(1)") |> Enum.reject(&(&1.purposes == nil))
    assert Enum.sort(partly.scope) == ["s.33", "sch.5"]
    assert partly.when == {:date, ~D[2016-05-04]}
  end

  test "\"so far as relating to the entries … in respect of the Matrimonial Causes Act 1973\" (1999 c.30 s.89(2)(d))" do
    rules =
      rules(
        [
          {"s.89", ""},
          {"s.89(2)",
           "The following provisions shall not come into force until such day as the Lord Chancellor may by order appoint—"},
          {"s.89(2)(a)", "sections 19, 21 and 22;"},
          {"s.89(2)(d)",
           "section 88 so far as relating to the entries in Part II of Schedule 13 in respect of the Matrimonial Causes Act 1973, the Matrimonial and Family Proceedings Act 1984 and sections 9(8) and 16 of the Family Law Act 1996."}
        ] ++ blank(~w[s.9 s.16 s.19 s.21 s.22 s.88 sch.13]),
        "ukpga",
        ~D[1999-11-11]
      )

    assert [partly] = rules |> from("s.89(2)") |> Enum.reject(&(&1.purposes == nil))
    assert partly.scope == ["s.88"]
  end

  test "\"to the extent necessary for … section 15 of the 2025 Act\": the items partly, never regulation 15 (SI 2026/15 reg.1(2))" do
    rules =
      rules(
        [
          {"reg.1", ""},
          {"reg.1(2)",
           "The following provisions of these Regulations come into force on 18th February 2026—"},
          {"reg.1(2)(a)", "this regulation and regulations 2 and 3;"},
          {"reg.1(2)(b)",
           "regulations 4 and 5 to the extent necessary for the giving of any notices and evidence under Schedule 2 to the 1999 Regulations by or to an employee who becomes entitled to take parental leave on or after 6th April 2026 as a result of section 15 of the 2025 Act (parental leave: removal of qualifying period of employment) coming fully into force;"},
          {"reg.1(2)(d)",
           "regulations 6 to 8 and 10 to 14, in relation to cases where a child’s mother dies or where a person with whom a child is placed or expected to be placed for adoption dies (see sections 80A(6A) and 80B(6C) of the 1996 Act);"},
          {"reg.1(2)(e)", "regulation 9."},
          {"reg.1(3)",
           "In so far as they are not already in force, these Regulations come into force on 6th April 2026."}
        ] ++
          blank(
            ~w[reg.2 reg.3 reg.4 reg.5 reg.6 reg.7 reg.8 reg.9 reg.10 reg.11 reg.12 reg.13 reg.14 reg.15 reg.16 sch.2]
          ),
        "uksi",
        ~D[2026-01-12]
      )

    [whole] = rules |> from("reg.1(2)") |> Enum.filter(&(&1.purposes == nil))
    assert Enum.sort(whole.scope) == ["reg.1", "reg.2", "reg.3", "reg.9"]

    [partly] = rules |> from("reg.1(2)") |> Enum.reject(&(&1.purposes == nil))
    assert partly.when == {:date, ~D[2026-02-18]}

    assert Enum.sort(partly.scope) ==
             Enum.sort(~w[reg.4 reg.5 reg.6 reg.7 reg.8 reg.10 reg.11 reg.12 reg.13 reg.14])
  end

  test "an item whose own provisions are another law's stays that law's (SI 2017/58 art.2 form)" do
    assert rules([
             {"reg.1", ""},
             {"reg.2", "The following provisions come into force on 6th March 2017—"},
             {"reg.2(a)", "section 3 of the 2014 Act (duty to supply);"},
             {"reg.2(b)", "paragraph 12 of Schedule 1A to that Act so far as relating to Wales."},
             {"reg.3", ""},
             {"reg.12", ""}
           ])
           |> from("reg.2") == []
  end

  describe "ItemSubject.words/1" do
    test "the description in brackets and the qualifier are dropped" do
      assert ItemSubject.words(
               "regulation 4(c) (amendment of regulation 17A of the 2008 Regulations: new definition)"
             ) == "regulation 4(c)"

      assert ItemSubject.words("section 32(3) so far as relating to section 91ZD of that Act;") ==
               "section 32(3)"
    end

    test "the item's own number brackets stay" do
      assert ItemSubject.words("regulation 7(2) to (6) and (9) to (11) (amendment of that)") ==
               "regulation 7(2) to (6) and (9) to (11)"
    end
  end
end

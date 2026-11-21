defmodule SertantaiLegal.Scraper.Commencement.MisreadsTest do
  @moduledoc """
  The misread scan (`Commencement.Misreads`): a rule whose scope or extent
  its statement does not give it, each kind from a real law's words — and
  the forms the reader reads rightly now, which must not flag.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Misreads, Order, OrderMisreads, Rule}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  @day {:date, ~D[2005-04-07]}

  defp rule(scope, opts \\ []),
    do:
      Rule.new(
        [
          commences: "UK_x",
          scope: scope,
          when: Keyword.get(opts, :when, @day),
          source: %{law: "UK_x", ref: "s.1", text: ""},
          treatment: Keyword.get(opts, :treatment, :provision_dated)
        ] ++ Keyword.take(opts, [:except, :territory, :purposes])
      )

  # the reader names refs over the law's rows, from the clause's provision
  defp ctx(ids, opts \\ []) do
    rows = Enum.map(ids, &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil})
    base = "UK_x:" <> Keyword.get(opts, :base, "s.1")
    %{refs: &Provisions.refs_in(&1, rows, base), ids: opts[:check] && MapSet.new(ids)}
  end

  defp kinds(misreads), do: misreads |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()
  defp words(misreads, kind), do: for(%{kind: ^kind, words: w} <- misreads, do: w)

  describe "another law's provisions" do
    test "another Act's sections in a rule's scope flag (1988 c.33 s.171(5))" do
      head = "The following provisions shall come into force on the day this Act is passed—"

      items = [
        "section 66;",
        "subsection (1) of section 170, so far as relating to the following— section 6(1) of the Juries Act 1974; sections 37 and 133 of the Magistrates’ Courts Act 1980; the Criminal Justice Act 1982;"
      ]

      rules = [
        rule(~w[s.66 s.37 s.133]),
        rule(~w[s.170(1)], purposes: :in_relation_to, treatment: :provision_qualified)
      ]

      got =
        Misreads.of(
          %{head: head, items: items},
          rules,
          ctx(~w[s.66 s.170 s.170(1) s.171], base: "s.171")
        )

      assert words(got, :other_law) == [
               "s.37 of the Magistrates’ Courts Act 1980",
               "s.133 of the Magistrates’ Courts Act 1980"
             ]
    end

    test "another Act's Schedule the rules leave out does not (1988 c.33 s.171(6))" do
      head =
        "The following provisions— section 44; section 45; subsection (2) of that section, so far as relating to the following— the Prevention of Corruption Act 1916; Schedule 3 to the Criminal Justice Act 1967; section 28(3) of the Criminal Justice Act 1972, shall come into force at the end of the period of two months beginning with the day this Act is passed."

      rules = [
        rule(~w[s.44 s.45]),
        rule(~w[s.170(1) s.170(2)], purposes: :in_relation_to, treatment: :provision_qualified)
      ]

      assert words(
               Misreads.of(
                 %{head: head, items: []},
                 rules,
                 ctx(~w[s.44 s.45 s.170 s.170(1) s.170(2) s.171], base: "s.171")
               ),
               :other_law
             ) == []
    end

    test "an order's own Act is never another law" do
      head =
        "Section 33 of the Clean Neighbourhoods and Environment Act 2005 shall come into force on 7th June 2005."

      own = %{title: "Clean Neighbourhoods and Environment Act", year: "2005"}
      ctx = %{refs: &Order.refs_in/1, own: own}

      assert Misreads.of(%{head: head, items: []}, [rule(~w[s.33])], ctx) == []

      other =
        String.replace(
          head,
          "Clean Neighbourhoods and Environment Act 2005",
          "Control of Pollution Act 1974"
        )

      assert kinds(Misreads.of(%{head: other, items: []}, [rule(~w[s.33])], ctx)) == [:other_law]
    end
  end

  describe "an order's laws" do
    @rsa %{title: "Road Safety Act", year: "2006"}

    defp from_item(rule, head, item),
      do: %{rule | source: %{rule.source | text: head <> " … " <> item}}

    test "the order commences two Acts: the other's section is not this one's (SI 2024/452 reg.4)" do
      # "the Planning Act 2008 (Commencement No. 8) and Levelling-up and
      # Regeneration Act 2023 (Commencement No. 4 …) Regulations 2024": read
      # for the 2008 Act, the 2023 Act's section 105 is another law's
      head =
        "Section 105 of the 2023 Act (removal of compensation for building preservation notice) comes into force on 25th July 2024."

      statement = %{head: head, items: []}
      ctx = fn own -> %{refs: &Order.refs_in/1, own: own} end

      assert Misreads.of(
               statement,
               [rule(~w[s.105])],
               ctx.(%{title: "Planning Act", year: "2008"})
             ) ==
               [%{kind: :other_law, words: "s.105 of the 2023 Act"}]

      lura = %{title: "Levelling-up and Regeneration Act", year: "2023"}
      assert Misreads.of(statement, [rule(~w[s.105])], ctx.(lura)) == []
    end

    test "\"that Act\" is the law named before it in the item (SI 2007/2472 art.2(h))" do
      head =
        "The following provisions of the Road Safety Act 2006 shall come into force on 24th September 2007"

      item =
        "section 30 in so far as section 3ZA of the Road Traffic Act 1988 has effect for the purposes of sections 3 and 3A of that Act"

      rules = [
        from_item(rule(~w[s.29]), head, "section 29"),
        from_item(rule(~w[s.30 s.3 s.3A], purposes: :in_relation_to), head, item)
      ]

      assert OrderMisreads.order_items(rules, %{refs: &Order.refs_in/1, own: @rsa}) == [
               %{
                 kind: :other_law,
                 words: "s.3 of the Road Traffic Act 1988: a purpose's words, not commenced"
               },
               %{
                 kind: :other_law,
                 words: "s.3A of the Road Traffic Act 1988: a purpose's words, not commenced"
               }
             ]
    end

    test "\"that Act\" with no other law named before it is the order's own" do
      # (words made for the test: the form of SI 2007/2472's list)
      head = "The following provisions of the Road Safety Act 2006 shall come into force"
      rules = [from_item(rule(~w[s.30 s.3]), head, "section 30 and section 3 of that Act")]

      assert OrderMisreads.order_items(rules, %{refs: &Order.refs_in/1, own: @rsa}) == []
    end

    test "another Act's Part named as the purpose, held as the scope (SI 2021/1322 art.3)" do
      head =
        "The provision specified in article 4 comes into force on the day after the day on which this Order is made, for the purposes of the application of Part 1 of the 2006 Act in Wales and Scotland only."

      rules = [rule(~w[pt.1], purposes: :in_relation_to, territory: "W")]
      ctx = %{refs: &Order.refs_in/1, own: %{title: "Equality Act", year: "2010"}}

      assert Misreads.of(%{head: head, items: []}, rules, ctx) == [
               %{
                 kind: :other_law,
                 words: "pt.1 of the 2006 Act: a purpose's words, not commenced"
               }
             ]
    end
  end

  describe "no row" do
    @osrpa %{title: "Offices, Shops and Railway Premises Act", year: "1963"}

    test "a ref the law holds no row for flags; a Schedule not held does not" do
      head = "Sections 3 and 9 and paragraph 2 of Schedule 4 come into force on 7th April 2005."
      rules = [rule(~w[s.3 s.9 sch.4.para.2])]

      got = Misreads.of(%{head: head, items: []}, rules, ctx(~w[s.1 s.2 s.3], check: true))
      assert got == [%{kind: :not_held, words: "s.9"}]
    end

    test "a provision simply not held is counted, never a misread (SI 1964/1045 art.1)" do
      # the Offices, Shops and Railway Premises Act 1963's section 24 is
      # repealed: its subsections' rows are gone
      head =
        "the following provisions (which relate to first aid) of the Act shall come into operation on 1st December 1964, that is to say— sections 24(1) to (3), (7) and (9), 25 and 26"

      rules = [rule(~w[s.24(1)..s.24(3) s.24(7) s.24(9) s.25 s.26])]
      ctx = %{refs: &Order.refs_in/1, ids: MapSet.new(~w[s.24 s.25 s.83]), own: @osrpa}

      got = Misreads.of(%{head: head, items: []}, rules, ctx)
      assert words(got, :no_row) == []
      assert Misreads.not_held(got) == 5
      assert Misreads.without(got, [:not_held]) == []
      assert Misreads.add(%{}, "following|x", "UK_uksi_1964_1045", "article-1", got, 9) == %{}
    end

    test "a ref misnamed flags: a deeper row ends in its last bracket (SI 1992/3253 art.3)" do
      head =
        "The following provisions of the Environmental Protection Act 1990 shall come into force on 1st February 1993— section 118(1)(a), (c), (e) to (l), (m) (in so far as it relates to section 111), (n) and (o),"

      rules = [rule(~w[s.118(1)(a) s.118(1)(c) s.118(n) s.118(o)])]

      ids =
        MapSet.new(~w[s.118 s.118(1) s.118(1)(a) s.118(1)(c) s.118(1)(n) s.118(1)(o) s.118(3)(a)])

      own = %{title: "Environmental Protection Act", year: "1990"}

      got =
        Misreads.of(%{head: head, items: []}, rules, %{refs: &Order.refs_in/1, ids: ids, own: own})

      assert got == [
               %{kind: :no_row, words: "s.118(n): misnamed (s.118(1)(n) held)"},
               %{kind: :no_row, words: "s.118(o): misnamed (s.118(1)(o) held)"}
             ]

      assert Misreads.not_held(got) == 0
    end

    test "a law whose rows are no measure skips both (`without/2`)" do
      got = [%{kind: :no_row, words: "s.1(n): misnamed"}, %{kind: :not_held, words: "s.9"}]
      assert Misreads.without(got, [:no_row]) == []
    end

    test "one extent's version of a provision held is held (1990 c.43 s.164(2))" do
      head = "Sections 79 and 80 come into force on 7th April 2005."
      rules = [rule(["s.79[S]", "s.80[E+W]"])]

      assert Misreads.of(%{head: head, items: []}, rules, ctx(~w[s.1 s.79 s.80], check: true)) ==
               []
    end

    test "no rows given, nothing checked" do
      head = "Section 9 comes into force on 7th April 2005."
      assert Misreads.of(%{head: head, items: []}, [rule(~w[s.9])], ctx(~w[s.1 s.9])) == []
    end
  end

  describe "a qualifier's reach" do
    test "each item's own qualifier, read on its own provision, does not flag (2005 c.15 s.178(1))" do
      head = "The following provisions come into force on the day on which this Act is passed—"

      items = [
        "sections 117(7) (and section 117(6) so far as relates to it), 158, 167, 172, 173, 176, 177, this section and section 179, and",
        "Part 1 of Schedule 17 and (so far as it relates to that Part of that Schedule) section 174(2)."
      ]

      rules = [
        rule(~w[s.178 s.117(7) s.158 s.167 s.172 s.173 s.176 s.177 s.179 sch.17.pt.1]),
        rule(~w[s.117(6) s.174(2)], purposes: :in_relation_to, treatment: :provision_qualified)
      ]

      assert Misreads.of(
               %{head: head, items: items},
               rules,
               ctx(
                 ~w[s.117 s.117(6) s.117(7) s.158 s.167 s.172 s.173 s.174 s.174(2) s.176 s.177 s.178 s.179 sch.17 sch.17.pt.1],
                 base: "s.178"
               )
             ) == []
    end

    test "a rule for the whole law from that list flags (2005 c.15 s.178(1))" do
      head = "The following provisions come into force on the day on which this Act is passed—"
      rules = [rule(:all, treatment: :clause_staged), rule(~w[s.158])]

      assert kinds(
               Misreads.of(
                 %{head: head, items: ["section 158."]},
                 rules,
                 ctx(~w[s.158 s.178], base: "s.178")
               )
             ) ==
               [:whole_law]
    end

    test "a territory one item states, on another item's provision (SI 2010/490 reg.1(4))" do
      head =
        "The following provisions come into force immediately after section 134 of the Marine Act (orders for protection of marine conservation zones in Wales) comes into force (so far as not already brought into force)—"

      items = [
        "paragraph (2) of regulation 38 (European marine sites: byelaws and orders), and paragraphs (3), (4) and (5) of that regulation in so far as they relate to paragraph (2); and",
        "paragraph (3) of regulation 133 (revocations), in so far as that paragraph relates to the revocation, as regards Wales, of— regulation 36 of the 1994 Regulations."
      ]

      rules = [
        rule(~w[reg.38 reg.133],
          when: {:appointed, "with another provision"},
          territory: "W",
          treatment: :provision_qualified
        )
      ]

      got =
        Misreads.of(
          %{head: head, items: items},
          rules,
          ctx(~w[reg.1 reg.38 reg.38(2) reg.38(3) reg.133 reg.133(3)], base: "reg.1")
        )

      assert words(got, :qualifier) == ["reg.38: no territory of its own"]
    end

    test "a qualifier pointing back limits what follows the provisions it names (1996 c.52 s.232(2))" do
      head =
        "The following provisions of this Act come into force at the end of the period of two months beginning with the date on which this Act is passed— sections 81 and 82 (restriction on termination of tenancy for failure to pay service charge), section 221 (exercise of compulsory purchase powers in relation to Crown land), paragraph 24 (powers of local housing authorities to acquire land for housing purposes) and paragraphs 27 to 29 of Schedule 18 (local authority assistance in connection with mortgages), and sections 222 and 227, and Schedule 19 (consequential repeals), in so far as they relate to those paragraphs."

      rules = [
        rule(~w[s.81 s.82 s.221 s.222 s.227 sch.18.para.27..sch.18.para.29],
          purposes: :in_relation_to,
          treatment: :provision_qualified
        )
      ]

      got =
        Misreads.of(
          %{head: head, items: []},
          rules,
          ctx(
            ~w[s.81 s.82 s.221 s.222 s.227 s.232 sch.18 sch.18.para.24 sch.18.para.27 sch.18.para.28 sch.18.para.29 sch.19],
            base: "s.232"
          )
        )

      assert words(got, :qualifier) == [
               "s.81: before the paragraphs limited",
               "s.82: before the paragraphs limited",
               "s.221: before the paragraphs limited"
             ]
    end

    test "an item limited to its repeals, held whole (2005 c.16 s.108(2)(h))" do
      head =
        "The provisions specified in subsection (2) come into force in accordance with provision made by order."

      items = [
        "sections 45 and 46;",
        "section 47, paragraph 4 of Schedule 4 and, in Part 4 of Schedule 5, the repeals to the Environmental Protection Act 1990, other than the repeal to section 33 of that Act;"
      ]

      rules = [rule(~w[s.45 s.46 s.47 sch.4.para.4 sch.5.pt.4], when: {:appointed, "by order"})]

      got =
        Misreads.of(
          %{head: head, items: items},
          rules,
          ctx(~w[s.45 s.46 s.47 s.108 sch.4 sch.4.para.4 sch.5 sch.5.pt.4], base: "s.108")
        )

      assert words(got, :qualifier) == ["sch.5.pt.4: its repeals or entries only"]
    end
  end

  describe "a qualifier inside an item's bracket, or in the head" do
    defp qualified(scope),
      do: rule(scope, purposes: :in_relation_to, treatment: :provision_qualified)

    test "\"(and Article 65 so far as relating thereto)\" is Article 65's own (NISI 2003/419 art.1(3))" do
      head =
        "The following provisions come into operation on the day after the day on which this Order is made—"

      items = [
        "Article 64;",
        "paragraph 1(2) of Schedule 3 (and Article 65 so far as relating thereto);",
        "Schedule 4 (and Article 65 so far as relating thereto)."
      ]

      rules = [rule(~w[reg.64 sch.3.para.1(2) sch.4]), qualified(~w[reg.65])]
      ids = ~w[reg.1 reg.1(3) reg.64 reg.65 sch.3 sch.3.para.1 sch.3.para.1(2) sch.4]

      assert Misreads.of(%{head: head, items: items}, rules, ctx(ids, base: "reg.1")) == []
    end

    test "\"(and Article 10(3) so far as relating to those paragraphs)\" (NISI 2006/2957 art.1(3))" do
      head =
        "The following provisions come into operation two months after the date on which this Order is made—"

      items = [
        "Article 9(2);",
        "paragraphs 4, 5, 8 and 17 of Schedule 1 (and Article 10(3) so far as relating to those paragraphs)."
      ]

      rules = [
        rule(~w[reg.9(2) sch.1.para.4 sch.1.para.5 sch.1.para.8 sch.1.para.17]),
        qualified(~w[reg.10(3)])
      ]

      ids =
        ~w[reg.1 reg.1(3) reg.9 reg.9(2) reg.10 reg.10(3) sch.1 sch.1.para.4 sch.1.para.5 sch.1.para.8 sch.1.para.17]

      assert Misreads.of(%{head: head, items: items}, rules, ctx(ids, base: "reg.1")) == []
    end

    test "a heading in a bracket is still no qualifier of the item's" do
      head = "The following provisions come into operation on the day this Order is made—"
      items = ["Article 64 (powers so far as relating to fees);", "Article 65."]
      rules = [rule(~w[reg.65]), qualified(~w[reg.64])]
      ids = ~w[reg.1 reg.1(3) reg.64 reg.65]

      got = Misreads.of(%{head: head, items: items}, rules, ctx(ids, base: "reg.1"))
      assert words(got, :qualifier) == ["reg.64: no qualifier of its own"]
    end

    test "the head's \"for the purposes only of\" reaches its items (SI 2013/1970 reg.1(3))" do
      head =
        "The following provisions of this instrument come into force on the making of these Regulations for the purposes only of the exercise of the powers to make regulations in the sections amended—"

      items = ["regulation 10;", "paragraph 12(b) and (c) of the Schedule."]
      rules = [qualified(~w[reg.10])]
      ids = ~w[reg.1 reg.1(3) reg.10]

      got = Misreads.of(%{head: head, items: items}, rules, ctx(ids, base: "reg.1"))
      assert words(got, :qualifier) == []
    end
  end

  describe "a container's list" do
    test "\"the following provisions of Schedule 22\" inside the qualifier is no container (SSI 2003/206 art.2)" do
      head =
        "Section 120(1) of the Environment Act 1995 shall come into force on 1st April 2003 in so far as it relates to the following provisions of Schedule 22:–"

      rules = [rule(~w[s.120(1)], purposes: :in_relation_to, territory: "S")]
      ctx = %{refs: &Order.refs_in/1, own: %{title: "Environment Act", year: "1995"}}

      assert Misreads.of(%{head: head, items: []}, rules, ctx) == []
    end

    test "\"the provisions of Schedule 11 to the Act\" is never Schedule 1 (WSI 2006/345 art.6(1))" do
      head =
        "1 April 2006 is the day appointed for the coming into force of the provisions of Schedule 11 to the Act referred to in paragraph (2) to the extent they relate to dental services in so far as not already in force and section 184 and paragraph 7 of that Schedule in so far as it relates to those provisions."

      rules = [
        rule(~w[s.184], purposes: :in_relation_to, territory: "W"),
        rule(~w[sch.11.para.2 sch.11.para.3], territory: "W")
      ]

      own = %{title: "Health and Social Care (Community Health and Standards) Act", year: "2003"}
      got = Misreads.of(%{head: head, items: []}, rules, %{refs: &Order.refs_in/1, own: own})
      assert words(got, :container) == []
    end

    @ids ~w[pt.2 s.55 s.56 sch.2 sch.2.para.1 sch.2.para.1(5) sch.2.para.1(5)(b) sch.2.para.1(9) sch.2.para.2 sch.2.pt.2]
    @head "The following provisions of Schedule 2, and section 55 to the extent it relates to those provisions, also come into force at the end of the period of two months beginning with the day on which this Act receives Royal Assent—"
    @items [
      "paragraph 1(5)(b) for the purposes of the application of section 53(5)(a) of the Agriculture Act 2020 (c. 21) in relation to Part 1 of Schedule 5 to that Act;",
      "paragraph 1(9) for the purposes of the repeal of Part 1 of Schedule 5 to the Agriculture Act 2020;",
      "paragraph 2;",
      "Part 2."
    ]

    test "refs of the Schedule do not flag (asc 2023/4 s.56(3))" do
      rules = [
        rule(~w[sch.2.para.2 sch.2.pt.2]),
        rule(~w[s.55 sch.2.para.1(5)(b) sch.2.para.1(9)],
          purposes: :in_relation_to,
          treatment: :provision_qualified
        )
      ]

      assert Misreads.of(%{head: @head, items: @items}, rules, ctx(@ids, base: "s.56")) == []
    end

    test "the Act's own Part 2 for the Schedule's flags" do
      rules = [
        rule(~w[sch.2.para.2 pt.2]),
        rule(~w[s.55 sch.2.para.1(5)(b) sch.2.para.1(9)],
          purposes: :in_relation_to,
          treatment: :provision_qualified
        )
      ]

      got = Misreads.of(%{head: @head, items: @items}, rules, ctx(@ids, base: "s.56"))
      assert words(got, :container) == ["pt.2: not of sch.2"]
    end
  end

  describe "an item no rule holds" do
    test "regulation 18 dropped (SI 2012/3039 reg.1(3)(b))" do
      head =
        "The following provisions come into force for the purposes specified on the day after the day on which these Regulations are made—"

      items = [
        "regulation 14, for the purposes of the Secretary of State granting consents under section 14(6) of the Animals (Scientific Procedures) Act 1986;",
        "regulation 18, for the purposes of the Secretary of State granting consents under section 17A of that Act;"
      ]

      rules = [rule(~w[reg.14], purposes: :in_relation_to, treatment: :provision_qualified)]

      got =
        Misreads.of(
          %{head: head, items: items},
          rules,
          ctx(~w[reg.1 reg.14 reg.18], base: "reg.1")
        )

      assert got == [%{kind: :item_dropped, words: "reg.18"}]
    end
  end

  describe "a law's rows" do
    test "the items of the list a sentence opens, each with its sub-items" do
      rows =
        for {id, text} <- [
              {"s.5(1)", "The following provisions come into force on Royal Assent—"},
              {"s.5(1)(a)", "section 1, so far as it relates to—"},
              {"s.5(1)(a)(i)", "England;"},
              {"s.5(1)(b)", "section 2."},
              {"s.5(2)", "Otherwise by order."}
            ],
            do: %{section_id: "UK_x:" <> id, text: text}

      assert Misreads.items("UK_x:s.5(1)", "… on Royal Assent—", rows) ==
               ["section 1, so far as it relates to— England;", "section 2."]

      assert Misreads.items("UK_x:s.5(2)", "Otherwise by order.", rows) == []

      assert Misreads.items(
               "UK_x:s.5(3)",
               "The provisions specified in subsection (1) come into force by order.",
               rows
             ) ==
               ["section 1, so far as it relates to— England;", "section 2."]
    end

    test "a group's shape names the kinds" do
      assert Misreads.shape("statement|x", [
               %{kind: :no_row, words: "s.9"},
               %{kind: :container, words: "pt.2"}
             ]) ==
               "statement|x | misread: container+no_row"
    end
  end
end

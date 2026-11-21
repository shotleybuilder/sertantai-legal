defmodule SertantaiLegal.Scraper.Commencement.MisreadsItemMarksTest do
  @moduledoc """
  The misread scan's qualifier checks never flag a right reading: an item
  limited to a Schedule Part's repeals, or to the provisions of Parts
  "which" confer a power, has a mark of its own for its partial rule; and
  a rule partial only by the territory its head states is not limited by
  an item's pointing-back aside.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Misreads, Rule}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  @by_order {:appointed, "by order"}

  defp rule(scope, opts),
    do:
      Rule.new(
        [
          commences: "UK_x",
          scope: scope,
          when: Keyword.get(opts, :when, {:date, ~D[2005-04-07]}),
          source: %{law: "UK_x", ref: "s.1", text: ""},
          treatment: Keyword.get(opts, :treatment, :provision_dated)
        ] ++ Keyword.take(opts, [:except, :territory, :purposes])
      )

  defp partial(scope, opts \\ []),
    do: rule(scope, [purposes: :in_relation_to, treatment: :provision_qualified] ++ opts)

  defp ctx(ids) do
    rows = Enum.map(ids, &row/1)
    %{refs: &Provisions.refs_in(&1, rows, "UK_x:s.1"), ids: nil}
  end

  # a Part is held by the rows in it
  defp row("pt." <> n), do: %{section_id: "UK_x:s.9#{n}", text: "", part: n, chapter: nil}
  defp row(id), do: %{section_id: "UK_x:" <> id, text: "", part: nil, chapter: nil}

  defp qualifier_words(statement, rules, ids),
    do: for(%{kind: :qualifier, words: w} <- Misreads.of(statement, rules, ctx(ids)), do: w)

  describe "an item's own mark" do
    test "a Schedule Part named for one repeal is marked (the Clean Neighbourhoods and Environment Act 2005 s.108(3)(g))" do
      statement = %{
        head:
          "These provisions come into force in accordance with provision made by order by the Secretary of State—",
        items: [
          "section 1;",
          "in Part 1 of Schedule 5, the repeal to section 3 of the London Local Authorities Act 2004 (c. i)."
        ]
      }

      rules = [
        rule(~w[s.1], when: @by_order, treatment: :provision_by_order),
        partial(~w[sch.5.pt.1], when: @by_order)
      ]

      assert qualifier_words(statement, rules, ~w[s.1 sch.5.pt.1]) == []
    end

    test "a Part's repeals beside a section are marked (the 2005 Act s.108(4)(a))" do
      statement = %{
        head:
          "These provisions come into force at the end of the period of two months beginning with the day on which this Act is passed—",
        items: [
          "sections 3 to 5 and, in Part 1 of Schedule 5, the repeals to the Greater London Council (General Powers) Act 1982 (c i) and section 11 of the London Local Authorities Act 2004 (c. i);",
          "section 18;"
        ]
      }

      rules = [rule(~w[s.3 s.4 s.5 s.18], []), partial(~w[sch.5.pt.1])]

      assert qualifier_words(statement, rules, ~w[s.3 s.4 s.5 s.18 sch.5.pt.1]) == []
    end

    test "the provisions of Parts which confer a power are marked (the Planning Act 2008 s.241(1)(a))" do
      statement = %{
        head:
          "The following provisions of this Act come into force on the day on which this Act is passed—",
        items: [
          "the provisions of Parts 1 to 9 (except section 194(2) to (5) and paragraph 7 of Schedule 7) which— confer power to make orders (other than orders granting, or making changes to orders granting, development consent), regulations or rules, or make provision about what is (or is not) permitted to be done, or what is required to be done, in the exercise of any such power;",
          "Part 11, except sections 206, 211(7), 224 and 225;"
        ]
      }

      rules = [rule(~w[pt.11], []), partial(~w[pt.1 pt.2 pt.9])]

      assert qualifier_words(statement, rules, ~w[pt.1 pt.2 pt.9 pt.11]) == []
    end

    test "the provisions of Parts that confer a power are marked (the Infrastructure (Wales) Act 2024 s.147(1)(b))" do
      statement = %{
        head:
          "The following provisions of this Act come into force on the day after the day on which this Act receives Royal Assent—",
        items: [
          "Part 1;",
          "the provisions of Parts 2 to 8 that— confer power to make regulations, or make provision about what is (or is not) permitted to be done in the exercise of a power to make regulations;"
        ]
      }

      rules = [rule(~w[pt.1], []), partial(~w[pt.2 pt.3 pt.8])]

      assert qualifier_words(statement, rules, ~w[pt.1 pt.2 pt.3 pt.8]) == []
    end

    test "an item with no mark of its own still flags" do
      statement = %{
        head: "The following provisions come into force on 1st April 2010—",
        items: ["section 2;", "section 3 so far as it confers power to make regulations;"]
      }

      assert qualifier_words(statement, [partial(~w[s.2 s.3])], ~w[s.2 s.3]) ==
               ["s.2: no qualifier of its own"]
    end
  end

  describe "a qualifier pointing back" do
    @wales "the following provisions come into force, in relation to Wales, on such day as the Welsh Ministers may by regulations appoint—"
    @item "section 56 and Schedule 6 except paragraphs 7 and 29 of that Schedule (and section 56 so far as relating to those paragraphs);"

    test "a rule partial only by its head's territory is not limited by it (the Building Safety Act 2022 s.170(4)(b)(ix))" do
      rules = [
        rule(~w[s.56 sch.6], territory: "W", when: @by_order, treatment: :provision_by_order)
      ]

      assert qualifier_words(%{head: @wales, items: [@item]}, rules, ~w[s.56 sch.6]) == []
    end

    test "a rule partial by purpose before the paragraphs pointed to still flags" do
      head = "The following provisions come into force on such day as may be appointed—"

      assert "sch.6: before the paragraphs limited" in qualifier_words(
               %{head: head, items: [@item]},
               [partial(~w[s.56 sch.6], when: @by_order)],
               ~w[s.56 sch.6]
             )
    end
  end
end

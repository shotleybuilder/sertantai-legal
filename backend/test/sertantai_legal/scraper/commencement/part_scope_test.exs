defmodule SertantaiLegal.Scraper.Commencement.PartScopeTest do
  @moduledoc """
  An amending law we hold no LAT rows for: a rule its own clause scopes to
  a Part reaches the Part's provisions, named from the law's own document
  when the rule is written (`PartScope.expand/2`), and no other Part's.
  The example is the Planning (Wales) Act 2015 s.58: Parts 3 to 8 come in
  two months after Royal Assent "so far as is necessary for enabling the
  Welsh Ministers to exercise any function of making regulations", and for
  the rest by order (WSI 2017/546 reg.3: sections 47 and 48, 5 May 2017) —
  so the Town and Country Planning Act 1990 s.78(4BA), inserted by s.47(1),
  is partly in force from 6 September 2015 and fully from 5 May 2017.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingCommencement
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, PartScope, Rule}

  @act "UK_anaw_2015_4"
  @order "UK_wsi_2017_546"

  defp row(sid, part, chapter \\ nil, text \\ "…"),
    do: %{section_id: "#{@act}:#{sid}", text: text, part: part, chapter: chapter}

  defp rows,
    do: [
      row("s.1", "1"),
      row("s.2", "2"),
      row("s.17", "5", "1"),
      row("s.18", "5", "2"),
      row("s.39", "6"),
      row("s.47", "7"),
      row("s.47(1)", "7"),
      row("s.48", "7"),
      row("s.54", "8"),
      row("s.55", "9"),
      row(
        "s.58(1)",
        "9",
        nil,
        "The following provisions come into force on the day on which this Act receives Royal Assent— (a) Part 1; (b) sections 56 and 57; (c) this section; (d) section 59."
      ),
      row(
        "s.58(2)",
        "9",
        nil,
        "The following provisions come into force at the end of the period of two months beginning with the day on which this Act receives Royal Assent— (a) section 55; (b) Parts 3 to 8, so far as is necessary for enabling the Welsh Ministers to exercise any function of making regulations or orders by statutory instrument under any enactment as amended by those Parts."
      ),
      row(
        "s.58(4)",
        "9",
        nil,
        "The following provisions come into force on such day as the Welsh Ministers appoint by order— (a) Part 2; (b) Parts 3 to 8, so far as they are not brought into force by subsection (2)(b)."
      )
    ]

  defp part_rule(scope, opts \\ []),
    do:
      Rule.new(
        commences: @act,
        scope: scope,
        except: Keyword.get(opts, :except, []),
        when: {:date, ~D[2015-09-06]},
        purposes: :in_relation_to,
        source: %{law: @act, ref: "s.58(2)", text: nil},
        treatment: :provision_qualified
      )

  defp order_rule,
    do:
      Rule.new(
        commences: @act,
        scope: ["s.47", "s.48"],
        when: {:date, ~D[2017-05-05]},
        source: %{law: @order, ref: "reg.3", text: nil},
        treatment: :order_date
      )

  defp value(claims, attribute),
    do: Enum.find_value(claims, &(&1.attribute == attribute && &1.value))

  describe "expand/2" do
    test "a Part is its provisions, in document order; other refs stay" do
      [rule] = PartScope.expand([part_rule(["s.55", "pt.7", "pt.8"])], rows())
      assert rule.scope == ["s.55", "s.47", "s.48", "s.54"]
    end

    test "a Chapter is its own provisions only" do
      [rule] = PartScope.expand([part_rule(["pt.5.ch.2"])], rows())
      assert rule.scope == ["s.18"]
    end

    test "the exceptions are expanded as the scope is" do
      [rule] = PartScope.expand([part_rule(["pt.5"], except: ["pt.5.ch.1"])], rows())
      assert {rule.scope, rule.except} == {["s.17", "s.18"], ["s.17"]}
    end

    test "a Part the document doesn't hold, a Schedule's Part, :all and :rest are kept as read" do
      rules = [
        part_rule(["pt.12", "sch.1.pt.2"]),
        %{part_rule(["pt.7"]) | scope: :all},
        %{part_rule(["pt.7"]) | scope: :rest}
      ]

      assert rules |> PartScope.expand(rows()) |> Enum.map(& &1.scope) ==
               [["pt.12", "sch.1.pt.2"], :all, :rest]
    end

    test "no rows: nothing changes" do
      rules = [part_rule(["pt.7"])]
      assert PartScope.expand(rules, []) == rules
    end
  end

  describe "a Part-scoped rule of an amending law" do
    test "reaches its Part's section and subsection, and no other Part's" do
      rules = PartScope.expand([part_rule(["pt.7"])], rows())

      for ref <- ["section-47", "section-47-1"] do
        assert %{partial_from: ~D[2015-09-06]} = AmendingCommencement.commencement(rules, ref)
      end

      assert %{entries: []} = AmendingCommencement.commencement(rules, "section-39")
    end

    test "unexpanded, it reaches nothing (the misreading)" do
      assert %{entries: []} =
               AmendingCommencement.commencement([part_rule(["pt.7"])], "section-47-1")
    end
  end

  describe "the Planning (Wales) Act 2015 s.47(1), from its own clause and WSI 2017/546" do
    defp act_rules do
      input = %{
        type_code: "anaw",
        rows: rows(),
        made: ~D[2015-07-06],
        clml_head: nil,
        lrt_date: nil
      }

      @act |> OwnClause.rules(input) |> PartScope.expand(rows())
    end

    test "the clause's Parts 3 to 8 are dated two months from Royal Assent, for some purposes" do
      assert %Rule{} =
               rule =
               Enum.find(act_rules(), &(&1.source.ref == "s.58(2)" and &1.purposes != nil))

      assert rule.when == {:date, ~D[2015-09-06]}
      assert "s.47" in rule.scope
      refute "s.55" in rule.scope
      refute "s.2" in rule.scope
    end

    test "partly in force from 6 September 2015, fully from 5 May 2017 by the order" do
      claims = AmendingCommencement.claims(act_rules() ++ [order_rule()], "section-47-1", "k")

      assert value(claims, :date) == ~D[2017-05-05]
      assert value(claims, :commenced_by) == @order

      assert [
               %{date: ~D[2015-09-06], partial: true, commenced_by: @act},
               %{date: ~D[2017-05-05], partial: false, commenced_by: @order}
             ] = value(claims, :stages)
    end
  end
end

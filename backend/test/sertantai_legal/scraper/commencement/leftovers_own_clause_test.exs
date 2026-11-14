defmodule SertantaiLegal.Scraper.Commencement.LeftoversOwnClauseTest do
  @moduledoc """
  The leftovers check's own errors on own clauses of the Fire and OH&S
  round: words that are no commencement of the law's provisions (how
  "commencement" is construed, the provision a statement is tied to, a
  pointer "as provided for in") leave nothing over.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Rule}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  defp rule(scope, when_, text, opts),
    do:
      Rule.new(
        [
          commences: "UK_x",
          scope: scope,
          when: when_,
          source: %{law: "UK_x", ref: "s.1", text: text},
          treatment: Keyword.get(opts, :treatment, :provision_dated)
        ] ++ Keyword.take(opts, [:except, :territory, :purposes])
      )

  defp refs(ids) do
    rows = Enum.map(ids, &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil})
    &Provisions.refs_in(&1, rows, "UK_x:s.1")
  end

  test "how \"commencement\" is to be construed is no commencement (1954 c.70 s.194)" do
    s =
      "This Act, except sections one hundred and seventy-two and one hundred and ninety thereof, shall come into operation on such day as the Minister may by order appoint, and those sections shall come into operation on the passing of this Act; and for the purposes of this Act and of the application thereto of section 13 of the Interpretation Act 1978 (which relates to the exercise of statutory powers between the passing and the commencement of an Act references to the commencement of this Act shall, notwithstanding the provisions of section 4 of the said Act of 1978 with respect to the construction of the expression “commencement”, be construed as references to the time at which this Act, except the said sections one hundred and seventy-two and one hundred and ninety, comes into operation."

    rules = [
      rule(:all, {:appointed, "by order"}, s, except: ~w(s.172 s.190), treatment: :by_order),
      rule(~w(s.172 s.190), {:date, ~D[1954-11-25]}, s, treatment: :act_enactment)
    ]

    assert Leftovers.of(s, rules, refs(~w(s.4 s.13 s.172 s.190))) == []
  end

  test "the provision a statement is tied to is not commenced by it (2021 c.24 s.4(5))" do
    s =
      "Section 3 comes into force at the same time as section 1 comes fully into force in relation to premises in England."

    rules = [
      rule(["s.3"], {:appointed, "with another provision"}, s, treatment: :provision_by_order)
    ]

    assert Leftovers.of(s, rules, refs(~w(s.1 s.3))) == []

    # unread, the statement's own provision is still left over
    assert [%{kind: :provision, words: "s.3"}] = Leftovers.of(s, [], refs(~w(s.1 s.3)))
  end

  test "\"as provided for in article 2(3)\" is a pointer (SI 2017/720 art.1(2))" do
    s =
      "This Order comes into force on 6th July2017 except for article 2(2) which comes into force as provided for in article 2(3)."

    rules = [
      rule(:all, {:date, ~D[2017-07-06]}, s, except: ["reg.2(2)"], treatment: :clause_date),
      rule(["reg.2(2)"], :unread, s, treatment: :provision_unread)
    ]

    rows =
      Enum.map(
        ~w[reg.1 reg.2(2) reg.2(3)],
        &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil}
      )

    assert Leftovers.of(s, rules, &Provisions.refs_in(&1, rows, "UK_x:reg.1")) == []
  end

  test "an application item and a made-relative day beside exit day (SI 2019/145 reg.1(2))" do
    s =
      "These Regulations come into force as follows— this regulation and Schedule 1 come into force on the seventh day after the day on which these Regulations are made; the provisions to which regulation 2 applies have effect in relation to financial years beginning on or after IP completion day; the rest of these Regulations come into force on exit day ."

    rules = [
      rule(:all, {:date, ~D[2019-02-06]}, s, treatment: :clause_staged),
      rule(["reg.1", "sch.1"], {:date, ~D[2019-02-06]}, s, []),
      rule(:rest, {:date, ~D[2020-12-31]}, s, except: ["reg.1"])
    ]

    assert Leftovers.of(s, rules, refs(~w(reg.1 reg.2 reg.3))) == []

    # the made-relative day unread, it is left over
    assert [%{kind: :relative_day}] =
             Leftovers.of(s, [List.last(rules)], refs(~w(reg.1 reg.2 reg.3)))
             |> Enum.filter(&(&1.kind == :relative_day))
  end

  test "an item excepted only to an extent is no exception left over (SI 1994/232 reg.1(a))" do
    s =
      "except for regulation 4 and regulation 6 to the extent that it applies to regulation 4, they shall come into force on 1st March 1994; and"

    rows =
      Enum.map(
        ~w(reg.1 reg.4 reg.6),
        &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil}
      )

    own = &Provisions.refs_in(&1, rows, "UK_x:reg.1")

    rules = [rule(:rest, {:date, ~D[1994-03-01]}, s, except: ["reg.1", "reg.4"])]
    assert Leftovers.of(s, rules, own) == []

    # regulation 4 not excepted, it is left over
    assert [%{kind: :exception, words: "reg.4"}] =
             Leftovers.of(s, [rule(:rest, {:date, ~D[1994-03-01]}, s, [])], own)
  end

  test "the day an agreement was signed is no commencement date (SI 2026/40 reg.1(2))" do
    s =
      "These Regulations come into force immediately after the Comprehensive Economic and Trade Agreement between the Government of Great Britain and Northern Ireland and the Government of the Republic of India signed on 24 July 2025 (“the Agreement”) enters into force (on which see Article 30.6 of the Agreement)."

    rules = [
      rule(:all, {:appointed, "with another enactment"}, s, treatment: :tied_to_other_law)
    ]

    assert Leftovers.of(s, rules, refs(~w(reg.1 reg.2))) == []
  end

  test "the power to appoint different days is no qualifier (1968 c.64 s.20(4))" do
    s =
      "the other provisions of this Act shall come into force on such day as the Lord Chancellor may by order made by statutory instrument appoint; and different days may be so appointed for different purposes of this Act or for the same purposes in relation to different courts or proceedings or otherwise in relation to different circumstances."

    rules = [
      rule(:rest, {:appointed, "by order"}, s, except: ~w(s.20), treatment: :provision_by_order)
    ]

    assert Leftovers.of(s, rules, refs(~w(s.13 s.20))) == []
  end
end

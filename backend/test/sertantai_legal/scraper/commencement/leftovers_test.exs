defmodule SertantaiLegal.Scraper.Commencement.LeftoversTest do
  @moduledoc """
  The words of a commencement statement that bear on a date — a date, a
  provision, an exception, a qualifier, a relative day — and that no rule
  read from it uses. Each form a Maritime Safety agent sample found
  (2026-11-05) gives its leftover from the reading before the fix, and none
  from the reading now.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Order, Rule}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  defp rule(scope, when_, text, opts \\ []),
    do:
      Rule.new(
        [
          commences: "UK_x",
          scope: scope,
          when: when_,
          source: %{law: "UK_x", ref: "reg.1", text: text},
          treatment: Keyword.get(opts, :treatment, :provision_dated)
        ] ++ Keyword.take(opts, [:except, :territory, :purposes])
      )

  defp rows(ids),
    do: Enum.map(ids, &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil})

  # the reader's own refs, bare ("reg.7")
  defp own_refs(rows), do: &Provisions.refs_in(&1, rows, "UK_x:reg.1")

  defp kinds(leftovers), do: leftovers |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.sort()

  defp words(leftovers, kind),
    do: for(%{kind: ^kind, words: w} <- leftovers, do: w)

  test "a second statement after \";\" (SI 2018/1107 reg.1(2))" do
    s =
      "These Regulations, other than regulations 7 and 9 to 14, come into force on 30th November 2018; regulations 7 and 9 to 14 come into force on 30th November 2019."

    refs = own_refs(rows(Enum.map(1..15, &"reg.#{&1}")))
    excepted = ~w(reg.7 reg.9 reg.10 reg.11 reg.12 reg.13 reg.14)

    before = [rule(:all, {:date, ~D[2018-11-30]}, s, except: excepted, treatment: :clause_date)]
    assert words(Leftovers.of(s, before, refs), :date) == ["30th November 2019"]

    now =
      before ++
        [
          rule(
            excepted,
            {:date, ~D[2019-11-30]},
            "regulations 7 and 9 to 14 come into force on 30th November 2019."
          )
        ]

    assert Leftovers.of(s, now, refs) == []
  end

  test "a second statement with no \";\" (SI 2012/3152 reg.1(2))" do
    s =
      "Regulations 2 and 4 come into force on 31st December 2012 the remaining regulations come into force on 12th January 2013."

    refs = own_refs(rows(~w(reg.1 reg.2 reg.3 reg.4)))
    before = [rule(["reg.2", "reg.4"], {:date, ~D[2012-12-31]}, s)]
    assert words(Leftovers.of(s, before, refs), :date) == ["12th January 2013"]

    now =
      before ++
        [
          rule(
            :rest,
            {:date, ~D[2013-01-12]},
            "the remaining regulations come into force on 12th January 2013.",
            except: ["reg.1"]
          )
        ]

    assert Leftovers.of(s, now, refs) == []
  end

  test "an exception tied to another law's commencement (SI 2012/2267 reg.1(2))" do
    s =
      "These Regulations come into force on 5th October 2012 except for regulation 3(3)(b) which comes into force on the date of commencement of Part 9A and Schedule 11ZA of the Merchant Shipping Act 1995."

    refs = own_refs(rows(~w[reg.1 reg.2 reg.3 reg.3(3) reg.3(3)(a) reg.3(3)(b)]))
    before = [rule(:all, {:date, ~D[2012-10-05]}, s, treatment: :clause_date)]
    assert words(Leftovers.of(s, before, refs), :exception) == ["reg.3(3)(b)"]

    now = [
      rule(:all, {:date, ~D[2012-10-05]}, s, except: ["reg.3(3)(b)"], treatment: :clause_date),
      rule(["reg.3(3)(b)"], :unread, s, treatment: :provision_unread)
    ]

    assert Leftovers.of(s, now, refs) == []
  end

  test "an order's \"rest of the Act, except …\" read as the exception's scope (SI 1996/3146 art.3)" do
    s =
      "The rest of the Act, except sections 85 to 87, shall come into force on 31st January 1997."

    before = [rule(["s.85..s.87"], {:date, ~D[1997-01-31]}, s, treatment: :order_date)]
    assert words(Leftovers.of(s, before, &Order.refs_in/1), :exception) == ["s.85..s.87"]

    now = [rule(:all, {:date, ~D[1997-01-31]}, s, except: ["s.85..s.87"], treatment: :order_date)]
    assert Leftovers.of(s, now, &Order.refs_in/1) == []
  end

  test "\"except that— (a) in relation to …, these Regulations shall come into force on …\" (SI 2007/3075 reg.1(a))" do
    s =
      "in relation to noise arising from the provision of music and entertainment on ships, these Regulations shall come into force on 6th April 2008; and"

    refs = own_refs(rows(~w(reg.1 reg.2)))
    assert kinds(Leftovers.of(s, [], refs)) == [:date, :qualifier]

    now = [
      rule(:rest, {:date, ~D[2008-02-23]}, s,
        except: ["reg.1"],
        purposes: :in_relation_to,
        treatment: :provision_qualified
      ),
      rule(:rest, {:date, ~D[2008-04-06]}, s, except: ["reg.1"])
    ]

    assert Leftovers.of(s, now, refs) == []
  end

  test "list items opening with their date: a list head's statement with its items (SI 2004/1495 reg.1)" do
    s =
      "These Regulations may be cited as the X Regulations 2004 and shall come into force — (a) from 1st July 2004 for international shipping; and (b) on 1st July 2005 for all other purposes."

    refs = own_refs(rows(~w(reg.1 reg.2)))
    head = "These Regulations may be cited as the X Regulations 2004 and shall come into force —"
    before = [rule(:all, {:date, ~D[2004-07-01]}, head, treatment: :clause_staged)]
    assert words(Leftovers.of(s, before, refs), :date) == ["1st July 2005"]

    now =
      before ++
        [
          rule(
            :rest,
            {:date, ~D[2004-07-01]},
            "from 1st July 2004 for international shipping; and",
            except: ["reg.1"],
            purposes: :in_relation_to,
            treatment: :provision_qualified
          ),
          rule(:rest, {:date, ~D[2005-07-01]}, "on 1st July 2005 for all other purposes.",
            except: ["reg.1"]
          )
        ]

    assert Leftovers.of(s, now, refs) == []
  end

  test "a laid-relative day (SI 2018/1221 reg.2): a named known limit, so its leftover stays" do
    s =
      "These Regulations come into force— (a) for the purposes of regulations 1, 2 and 3 on the 22nd day after the day on which these Regulations are laid, and (b) for all other purposes, on exit day."

    refs = own_refs(rows(~w(reg.1 reg.2 reg.3 reg.4)))
    held = [rule(:all, {:date, ~D[2020-12-31]}, s, treatment: :clause_staged)]
    leftovers = Leftovers.of(s, held, refs)

    assert :relative_day in kinds(leftovers)
    assert :qualifier in kinds(leftovers)
  end

  test "never counted: a mention; another law's provisions; a completing qualifier" do
    refs = own_refs(rows(~w(reg.1 reg.2)))

    assert Leftovers.of("Before regulation 2 comes into force on 1st May 2000, …", [], refs) == []

    # a power to provide for commencement (MSA 1995 s.84B(10))
    assert Leftovers.of(
             "The powers conferred by regulation 2 to make provision for the purpose of giving effect to an agreement include power to provide for the provision to come into force although the agreement has not come into force.",
             [],
             refs
           ) == []

    s =
      "These Regulations come into force on 1st May 2000, so far as not already in force, except section 4 of the Health and Safety at Work etc. Act 1974."

    assert Leftovers.of(
             s,
             [rule(:all, {:date, ~D[2000-05-01]}, s, treatment: :clause_date)],
             refs
           ) ==
             []
  end

  describe "never counted (first corpus run, 2026-11-05)" do
    test "a relative day the reader resolved to a date: \"at the end of the period of two months …\"" do
      s =
        "This Act shall come into force at the end of the period of two months beginning with the day on which it is passed."

      held = [rule(:all, {:date, ~D[1990-07-24]}, s, treatment: :clause_made_relative)]
      assert Leftovers.of(s, held, fn _ -> [] end) == []
    end

    test "pointers: \"Except as provided by subsection (2)\", \"Subject to subsection (2)\"" do
      refs = own_refs(rows(~w[reg.1 reg.1(2) reg.2]))

      for s <- [
            "Except as provided by paragraph (2), these Regulations come into force on such day as the Secretary of State may by order appoint.",
            "Subject to paragraph (2), these Regulations come into force on such day as the Secretary of State may by order appoint."
          ] do
        held = [rule(:all, {:appointed, "by order"}, s, treatment: :by_order)]
        assert Leftovers.of(s, held, refs) == [], s
      end
    end

    test "no time stated and no rule: a condition, not a statement" do
      refs = own_refs(rows(~w(reg.1 reg.2 reg.5)))
      assert Leftovers.of("Regulation 5 comes into force with regulation 2.", [], refs) == []
    end

    test "an order naming another law's provisions" do
      assert Order.refs_in("section 4 of the Health and Safety at Work etc. Act 1974") == []
    end

    test "completing forms and \"to the extent specified in\" (SI 2025/1173, 2025/272, 2009/2260)" do
      refs = own_refs(rows(~w[reg.1 reg.2 reg.4]))
      held = fn s -> [rule(["reg.2"], {:date, ~D[2025-12-02]}, s)] end

      for s <- [
            "Regulation 2 comes into force on 2nd December 2025, insofar as it is not already in force.",
            "Regulation 2 comes into force on 2nd December 2025, to the extent that it is not in force immediately before that date.",
            "Regulation 2 comes into force, to the extent specified in regulation 4, on 2nd December 2025."
          ] do
        assert Leftovers.of(s, held.(s), refs) == [], s
      end
    end

    test "another instrument's commencement; \"may be made so as to come into operation\"; Schedules" do
      refs = own_refs(rows(~w[s.1 s.38 s.38(1) s.48]))

      for s <- [
            "The regulations required by subsection (1) must come into force on the day on which this Part comes into force.",
            "Amendments of a code of practice issued under this section come into force at the end of the period of 21 days beginning with the day on which the amendments are issued.",
            "Arrangements imposed under this section come into force on the date determined by OFCOM.",
            "For the purpose of spreading the work, the order changing that period may be made so as to come into operation on different days."
          ] do
        assert Leftovers.of(s, [], refs) == [], s
      end

      s = "This Act comes into force on 1st May 2000 except Schedule 5."

      assert Leftovers.of(s, [rule(:all, {:date, ~D[2000-05-01]}, s)], fn _ -> ["sch.5"] end) ==
               []
    end

    test "containers, an instrument after a lead-in, the whole law's one time" do
      refs = own_refs(rows(~w[s.1 s.44 s.45 s.100 s.216 reg.21B]))

      s =
        "The following provisions of Part 1 come into force on such day as the Scottish Ministers may by order appoint—"

      assert Leftovers.of(s, [rule(["s.1"], {:appointed, "by order"}, s)], fn _ -> ["pt.1"] end) ==
               []

      assert Leftovers.of(
               "For the purpose of this article, a CFD transfer notice comes into force—",
               [],
               refs
             ) == []

      s =
        "This section and sections 44 and 45 come into force on such day as the Scottish Ministers may by order appoint."

      assert Leftovers.of(
               s,
               [rule(:all, {:appointed, "by order"}, s, treatment: :by_order)],
               refs
             ) ==
               []
    end

    test "the order power's own words, finer scope, \"those sections are\" (1963 c.41, SI 2009/2260, SI 1998/604)" do
      refs = own_refs(rows(~w[s.1 s.190 s.190(1) s.190(2) s.190(3)]))

      s =
        "This Act shall come into operation on such day as the Minister may by order appoint, and different days may be appointed in relation to premises of different classes."

      assert Leftovers.of(
               s,
               [rule(:all, {:appointed, "by order"}, s, treatment: :by_order)],
               refs
             ) ==
               []

      s =
        "This Act shall come into force on such day as Her Majesty may by Order in Council appoint; and a later day may be appointed for the purposes of section 190 than that appointed for the purposes of the other provisions of this Act."

      assert Leftovers.of(
               s,
               [rule(:all, {:appointed, "by order"}, s, treatment: :by_order)],
               refs
             ) ==
               []

      s = "Subsections (1) to (3) of section 190 shall come into force on 1st October 2009."
      held = [rule(["s.190(1)", "s.190(2)", "s.190(3)"], {:date, ~D[2009-10-01]}, s)]
      assert Leftovers.of(s, held, refs) == []

      s =
        "Section 190 (in so far as those sections are not already in force) shall come into force on 1st July 1998."

      assert Leftovers.of(s, [rule(["s.190"], {:date, ~D[1998-07-01]}, s)], refs) == []
    end
  end
end

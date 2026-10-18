defmodule SertantaiLegal.Scraper.Commencement.EvaluatorTest do
  @moduledoc """
  CR-02 golden cases: a provision's commencement from rules alone, shaped on
  laws met in A8.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Rule}

  defp rule(law, source, scope, when_, opts \\ []) do
    Rule.new(
      [
        commences: law,
        scope: scope,
        when: when_,
        source: %{law: source, ref: opts[:ref] || "art.1", text: nil},
        treatment: opts[:treatment] || :t
      ] ++ Keyword.take(opts, [:territory, :purposes, :except])
    )
  end

  defp eval(rules, provision, ctx \\ %{}), do: Evaluator.evaluate(rules, provision, ctx)

  describe "uksi 2017/469 art.1: named provisions the day after making, the rest on 8 May" do
    @rules [
      Rule.new(
        commences: "UK_uksi_2017_469",
        scope: ["art.1", "art.2", "art.11"],
        when: {:after, :made, {1, :day}},
        source: %{law: "UK_uksi_2017_469", ref: "art.1(2)", text: nil},
        treatment: :made_relative
      ),
      Rule.new(
        commences: "UK_uksi_2017_469",
        scope: :rest,
        when: {:date, ~D[2017-05-08]},
        source: %{law: "UK_uksi_2017_469", ref: "art.1(3)", text: nil},
        treatment: :clause_date
      )
    ]

    test "a named provision and its sub-provisions: the day after making" do
      ctx = %{made: ~D[2017-03-24]}
      assert %{full_from: ~D[2017-03-25]} = eval(@rules, "art.11", ctx)
      assert %{full_from: ~D[2017-03-25]} = eval(@rules, "art.11(2)", ctx)
      # the source's `rest` doesn't also reach a provision it names
      assert [%{date: ~D[2017-03-25]}] = eval(@rules, "art.1(1)", ctx).entries
    end

    test "the rest: 8 May; a full section id works as well as a bare ref" do
      assert %{full_from: ~D[2017-05-08], partial_from: nil, undated: []} =
               eval(@rules, "art.5(1A)", %{made: ~D[2017-03-24]})

      assert %{full_from: ~D[2017-05-08]} =
               eval(@rules, "UK_uksi_2017_469:art.5(1A)", %{made: ~D[2017-03-24]})
    end
  end

  test "SI 2019/696: all on exit day" do
    rules = [rule("UK_uksi_2019_696", "UK_uksi_2019_696", :all, {:named_day, :exit_day})]
    assert %{full_from: ~D[2020-01-31]} = eval(rules, "reg.4")
  end

  test "an Act two months after passing; an undated made date leaves it undated" do
    rules = [rule("UK_ukpga_1988_45", "UK_ukpga_1988_45", :all, {:after, :passed, {2, :month}})]
    assert %{full_from: ~D[1988-09-15]} = eval(rules, "s.3", %{passed: ~D[1988-07-15]})
    assert %{full_from: nil, undated: [_]} = eval(rules, "s.3")
  end

  describe "within one source the most specific rule wins" do
    test "s.62 on its own date, the rest of the Act on Royal Assent" do
      rules = [
        rule("L", "L", ["s.62"], {:date, ~D[2027-03-23]}),
        rule("L", "L", :rest, {:date, ~D[2024-11-13]})
      ]

      assert %{full_from: ~D[2027-03-23]} = eval(rules, "s.62(1)")
      assert %{full_from: ~D[2024-11-13]} = eval(rules, "s.61")
    end

    test "a source's `all` doesn't reach what another of its rules names; a Part rule yields to a section rule" do
      rules = [
        rule("L", "L", :all, {:date, ~D[2024-01-01]}),
        rule("L", "L", ["pt.2"], {:date, ~D[2025-01-01]}),
        rule("L", "L", ["s.12"], {:appointed, "by order"})
      ]

      parts = %{
        ancestors: fn
          "s.12" -> ["pt.2"]
          "s.11" -> ["pt.2"]
          _ -> []
        end
      }

      assert %{full_from: nil, undated: [%Rule{when: {:appointed, _}}]} =
               eval(rules, "s.12(1)", parts)

      assert %{full_from: ~D[2025-01-01]} = eval(rules, "s.11", parts)
      assert %{full_from: ~D[2024-01-01]} = eval(rules, "s.1", parts)
    end

    test "except: left to another rule" do
      rules = [
        rule("L", "L", :all, {:date, ~D[2024-01-01]}, except: ["s.5"]),
        rule("L", "L", ["s.5"], {:appointed, "by order"})
      ]

      assert %{full_from: nil} = eval(rules, "s.5(2)")
      assert %{full_from: ~D[2024-01-01]} = eval(rules, "s.6")
    end

    test "ranges, by document order or by number" do
      rules = [rule("L", "L", ["s.1..s.5"], {:date, ~D[2024-01-01]})]
      assert %{full_from: ~D[2024-01-01]} = eval(rules, "s.4A(1)")
      assert %{full_from: nil, entries: []} = eval(rules, "s.6")

      order = %{order: ["s.1", "s.5", "s.3"]}
      assert %{full_from: nil} = eval(rules, "s.3", order)
    end
  end

  describe "across sources: every rule, in date order (Gemini)" do
    test "for specified purposes, then the remaining provisions: partial, then full" do
      rules = [
        rule("L", "UK_uksi_2026_123", ["s.50"], {:date, ~D[2026-04-01]},
          purposes: :for_making_secondary_legislation
        ),
        rule("L", "UK_uksi_2026_987", :rest, {:date, ~D[2026-10-01]})
      ]

      r = eval(rules, "s.50")
      assert %{partial_from: ~D[2026-04-01], full_from: ~D[2026-10-01]} = r
      assert Evaluator.status(r, ~D[2026-01-01]) == :prospective
      assert Evaluator.status(r, ~D[2026-05-01]) == :in_force_partial
      assert Evaluator.status(r, ~D[2026-10-01]) == :in_force
    end

    test "EA 1995 s.57: for specified purposes only — never fully" do
      rules = [
        rule("UK_ukpga_1995_25", "UK_uksi_2000_340", ["s.57"], {:date, ~D[2000-04-01]},
          territory: "E",
          purposes: :for_specified_purposes
        )
      ]

      r = eval(rules, "s.57", %{extent: "E+W+S"})
      assert %{partial_from: ~D[2000-04-01], full_from: nil} = r
      assert Evaluator.status(r, ~D[2026-10-18]) == :in_force_partial
    end
  end

  describe "territory against the provision's extent" do
    defp water,
      do: [
        rule("UK_ukpga_2014_21", "UK_uksi_2017_1", ["s.11"], {:date, ~D[2017-04-01]},
          territory: "E"
        ),
        rule("UK_ukpga_2014_21", "UK_wsi_2019_1", ["s.11"], {:date, ~D[2019-04-01]},
          territory: "W"
        )
      ]

    test "Water Act 2014 s.11: England 2017, Wales 2019 → an E+W provision fully in force from 2019" do
      r = eval(water(), "s.11(3)", %{extent: "E+W"})
      assert %{partial_from: ~D[2017-04-01], full_from: ~D[2019-04-01]} = r
      assert Evaluator.status(r, ~D[2018-01-01]) == :in_force_partial
    end

    test "an E-only provision is fully in force from England's date; no extent known: never full by territory" do
      assert %{full_from: ~D[2017-04-01], partial_from: nil} =
               eval(water(), "s.11", %{extent: "E"})

      assert %{full_from: nil, partial_from: ~D[2017-04-01]} = eval(water(), "s.11")
    end
  end

  test "with: another provision's commencement" do
    rules = [rule("L", "L", ["s.9"], {:with, "UK_ukpga_2014_21:s.10"})]
    with = fn "UK_ukpga_2014_21:s.10" -> ~D[2015-04-06] end
    assert %{full_from: ~D[2015-04-06]} = eval(rules, "s.9", %{with: with})
    assert %{full_from: nil, undated: [_]} = eval(rules, "s.9")
  end

  test "no rule covers the provision: unknown" do
    r = eval([rule("L", "L", ["s.1"], {:date, ~D[2024-01-01]})], "s.2")
    assert %{entries: [], full_from: nil, partial_from: nil, undated: []} = r
    assert Evaluator.status(r, ~D[2026-01-01]) == :unknown
  end

  test "covered by an undated rule only: prospective (not yet in force), not unknown" do
    r = eval([rule("L", "L", :all, {:appointed, "by order"})], "s.2")
    assert Evaluator.status(r, ~D[2026-01-01]) == :prospective
  end
end

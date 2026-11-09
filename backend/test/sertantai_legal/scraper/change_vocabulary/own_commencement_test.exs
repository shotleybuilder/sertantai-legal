defmodule SertantaiLegal.Scraper.ChangeVocabulary.OwnCommencementTest do
  @moduledoc """
  CV-S04: the law's own commencement, every row accounted for — what
  `Readers.OwnCommencement` makes of a provision, one outcome a test.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.Rule

  @law "UK_ukpga_2000_1"

  defp rule(scope, when_, opts \\ []),
    do:
      Rule.new(
        [
          commences: @law,
          scope: scope,
          when: when_,
          source: %{law: @law, ref: "s.9", text: nil},
          treatment: Keyword.get(opts, :treatment, :provision_dated)
        ] ++ Keyword.take(opts, [:territory, :purposes])
      )

  defp outcome(rules, id), do: rules |> OwnCommencement.outcome(@law, id) |> elem(0)

  test "dated fully; partly first then fully (staged); partly only" do
    assert outcome([rule(:all, {:date, ~D[2000-04-01]})], "s.1(2)") == :dated

    staged = [
      rule(["s.1"], {:date, ~D[2000-01-01]}, purposes: :for_making_secondary_legislation),
      rule(:all, {:date, ~D[2000-04-01]})
    ]

    assert outcome(staged, "s.1") == :staged

    assert outcome([rule(["s.1"], {:date, ~D[2000-01-01]}, territory: "W")], "s.1") ==
             :partial_only
  end

  test "left to an order no rule dates (J6), wholly or for the rest" do
    assert outcome([rule(:all, {:appointed, "order"})], "s.1") == :by_order

    partly = [
      rule(["s.1"], {:date, ~D[2000-01-01]}, purposes: :for_specified_purposes),
      rule(["s.1"], {:appointed, "order"})
    ]

    assert outcome(partly, "s.1") == :by_order_partly
  end

  test "tied to another provision; only an unread statement" do
    assert outcome([rule(:all, {:with, "UK_ukpga_2022_1:s.83"})], "s.1") == :tied
    assert outcome([rule(:all, :unread)], "s.1") == :unread
  end

  test "text rules reaching it nowhere: our fault" do
    assert outcome([rule(["s.2"], {:date, ~D[2000-01-01]})], "s.1") == :not_reached
    assert OwnCommencement.fault?(:not_reached)
  end

  test "an Act with no clause: in force on Royal Assent (Interpretation Act 1978 s.4)" do
    assent = rule(:all, {:date, ~D[2000-01-01]}, treatment: :act_enactment)
    assert outcome([assent], "s.1") == :dated
  end

  test "no text rules: why" do
    staged = rule(:all, {:date, ~D[2000-01-01]}, treatment: :clause_staged)
    assert outcome([staged], "s.1") == :staged_start_only
    assert {:eu_directive, nil} = OwnCommencement.outcome([], "UK_eudr_1989_391", "art.1")

    assert {:eu_publication_relative, nil} =
             OwnCommencement.outcome([], "UK_eur_2006_1907", "art.1")

    refute OwnCommencement.fault?(:eu_publication_relative)
    assert outcome([], "s.1") == :no_rules
    assert OwnCommencement.fault?(:no_rules)
    refute OwnCommencement.fault?(:eu_directive)
  end

  test "a rule naming a part with no row commences the row holding it, partly (HSWA s.83(1), its text gone)" do
    rules = [
      rule(["s.83(1)"], {:date, ~D[1974-10-01]}),
      rule(["s.83"], {:date, ~D[1975-01-01]})
    ]

    stages =
      for {_key, target, claims} <- OwnCommencement.read(rules, @law, ["s.83", "s.84"]),
          do:
            {target, Enum.find_value(claims, &(&1.attribute == :date && &1.value)),
             Enum.find_value(claims, false, &(&1.attribute == :partial && &1.value))}

    assert {"s.83", ~D[1974-10-01], true} in stages
    assert {"s.83", ~D[1975-01-01], false} in stages
    refute Enum.any?(stages, &(elem(&1, 0) == "s.84"))
  end

  test "an order naming the row, or a range at its depth, says so (named); read down from above, not (SI 1974/1439 on HSWA s.10(2))" do
    named? = fn rules, id ->
      rules
      |> OwnCommencement.read(@law, [id])
      |> Enum.flat_map(&elem(&1, 2))
      |> Enum.any?(&(&1.attribute == :named and &1.value == true))
    end

    assert named?.([rule(["s.10(2)..s.10(4)"], {:date, ~D[1974-10-01]})], "s.10(2)")
    assert named?.([rule(["s.10(2)"], {:date, ~D[1974-10-01]})], "s.10(2)")
    refute named?.([rule(["s.10"], {:date, ~D[1974-10-01]})], "s.10(2)")
    refute named?.([rule(:all, {:date, ~D[1974-10-01]})], "s.10(2)")
  end

  test "a cross-heading no rule names commences with the first provision under it in force (MS & Maritime Security Act 1997 h.17)" do
    rules = [
      rule(:all, {:appointed, "by order"}, treatment: :by_order),
      rule(["s.17", "s.18"], {:date, ~D[1997-07-17]}, treatment: :order_date),
      rule(["s.24"], {:date, ~D[1997-03-19]})
    ]

    ctx =
      Map.put(
        SertantaiLegal.Scraper.Commencement.Order.context(),
        :order,
        ~w(s.16 h.17 s.17 s.18 h.24 s.24)
      )

    {:dated, %{full_from: ~D[1997-07-17]}} = OwnCommencement.outcome(rules, @law, "h.17", ctx)
    {:dated, %{full_from: ~D[1997-03-19]}} = OwnCommencement.outcome(rules, @law, "h.24", ctx)

    assert [{_, "h.17", _}] =
             rules
             |> OwnCommencement.read(@law, ["h.17"], ctx)
             |> Enum.filter(&(elem(&1, 1) == "h.17"))

    # a heading a rule names keeps its own; one whose provisions are undated stays so
    assert {:by_order, _} = OwnCommencement.outcome(Enum.take(rules, 1), @law, "h.17", ctx)
  end

  # Environmental Protection: Commencement reader (2026-11-09): the
  # Environment Act 2021 s.147 names Part 3's sections one by one under
  # different days, never the Part; the Environment (Wales) Act 2016 s.88(3)
  # leaves s.81 to an order, and no rule names its heading h.81
  test "a Part no rule names commences with the first provision in it; a heading over provisions left to an order is left so too" do
    rules = [
      rule(["s.51"], {:date, ~D[2022-01-09]}),
      rule(["s.50"], {:appointed, "by regulations"}, treatment: :provision_by_order),
      rule(["s.81"], {:appointed, "by order"}, treatment: :provision_by_order)
    ]

    ctx =
      Map.put(
        SertantaiLegal.Scraper.Commencement.Order.context(),
        :order,
        ~w(pt.3 h.50 s.50 s.51 pt.7 h.81 s.81)
      )

    {:dated, %{full_from: ~D[2022-01-09]}} = OwnCommencement.outcome(rules, @law, "pt.3", ctx)
    {:by_order, _} = OwnCommencement.outcome(rules, @law, "pt.7", ctx)
    {:by_order, _} = OwnCommencement.outcome(rules, @law, "h.81", ctx)
  end

  # Environmental Protection: Commencement reader (2026-11-09): SI 2020/206,
  # a staged clause read for its start only, with one Schedule tied to its
  # regulation; the tie dates no row, so the law is still its start only
  test "a law whose only text rules tie Schedules to their provisions is as it is without them" do
    rules = [
      rule(:all, {:date, ~D[2020-03-27]}, treatment: :clause_staged),
      rule(["sch.4A"], {:with, "reg.48A"}, treatment: :schedule_effect)
    ]

    assert outcome(rules, "pt.1") == :staged_start_only
  end
end

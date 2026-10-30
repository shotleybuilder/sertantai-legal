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
end

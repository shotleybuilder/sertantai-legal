defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmendingLawDroppedTest do
  @moduledoc "CV-S09 round 7 (N2): a whole substitution's quote no longer making a provision's old numbers ends them."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw.Dropped

  defp rule(targets, op, treatment),
    do:
      Rule.new(
        amends: "UK_uksi_2008_1597",
        targets: targets,
        operation: op,
        level: :provision,
        source: %{
          law: "UK_uksi_2026_867",
          ref: "regulation-2-4",
          text: "For regulation 12A, substitute—"
        },
        treatment: treatment
      )

  test "the held rows under the provision the quote leaves out are dropped; those under a provision it makes, or outside it, are not" do
    rules = [
      rule(["reg.12A", "reg.12A(1)", "reg.12A(2)", "reg.12A(2)(a)"], :substituted, :quoted)
    ]

    known =
      MapSet.new([
        "reg.12A",
        "reg.12A(1)",
        "reg.12A(2)",
        "reg.12A(2)(a)",
        "reg.12A(2)(b)",
        "reg.12A(8)",
        "reg.12A(8)(a)",
        "reg.12B"
      ])

    dropped = rules |> Dropped.rows(known) |> Enum.map(&elem(&1, 1)) |> Enum.sort()
    # (2)(b) sits under the (2) the quote makes: kept (an item it may not list)
    assert dropped == ["reg.12A(8)", "reg.12A(8)(a)"]
  end

  test "an insertion drops nothing" do
    rules = [rule(["reg.12A(9)"], :inserted, :quoted)]
    assert Dropped.rows(rules, MapSet.new(["reg.12A", "reg.12A(8)"])) == []
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmendingCommencementTest do
  @moduledoc """
  When an amending provision came into force, and by which law (CV-S08
  round 1): an Act's Royal Assent dates only a provision no other rule
  reaches; the rule's law is the change's `commenced_by`.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw
  alias SertantaiLegal.Scraper.Commencement.Rule

  @act "UK_ukpga_2025_36"
  @order "UK_uksi_2026_954"

  defp rule(source, scope, date, treatment),
    do:
      Rule.new(
        commences: @act,
        scope: scope,
        when: {:date, date},
        source: %{law: source, ref: "reg.3", text: nil},
        treatment: treatment
      )

  defp rules,
    do: [
      rule(@act, :all, ~D[2025-12-18], :act_enactment),
      rule(@order, ["s.152", "sch.12"], ~D[2026-10-01], :order_date)
    ]

  test "an order's rule wins over Royal Assent; the order commenced it" do
    result = AmendingLaw.commencement(rules(), "schedule-12-paragraph-3")
    assert result.full_from == ~D[2026-10-01]
    assert AmendingLaw.commenced_by(result) == @order
  end

  test "Royal Assent still dates a provision no other rule reaches" do
    result = AmendingLaw.commencement(rules(), "section-19")
    assert result.full_from == ~D[2025-12-18]
    assert AmendingLaw.commenced_by(result) == @act
  end

  test "a change to a provision \"as it applies to Scotland\" is that version's (Environment Act 1995 Sch.22)" do
    rule =
      SertantaiLegal.Scraper.Amendment.Rule.new(
        amends: "UK_ukpga_1974_37",
        targets: ["s.28(5)(b)"],
        operation: :substituted,
        level: :words,
        source: %{
          law: "UK_ukpga_1995_25",
          ref: "schedule-22-paragraph-30-6-f-iii",
          text:
            "in the said paragraph (b) as it applies to Scotland, for the words from the beginning to “in connection” there shall be substituted the words ."
        },
        treatment: :instruction
      )

    assert [{_key, "s.28(5)(b)", claims}] = AmendingLaw.read([rule])

    assert [%{value: "S"}] =
             Enum.filter(claims, &(&1.source == :law_text and &1.attribute == :territory))
  end
end

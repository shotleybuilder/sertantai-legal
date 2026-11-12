defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmendingCommencementTest do
  @moduledoc """
  When an amending provision came into force, and by which law (CV-S08
  round 1): an Act's Royal Assent dates only a provision no other rule
  reaches; the rule's law is the change's `commenced_by`.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmendingCommencement, AmendingLaw}
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

  describe "commenced territory by territory, never in full (Environmental Protection: Switch-over, Decision 3, B)" do
    defp territorial(source, date, territory),
      do:
        Rule.new(
          commences: "UK_ukpga_1995_25",
          scope: ["s.57"],
          when: {:date, date},
          territory: territory,
          source: %{law: source, ref: "art.2", text: nil},
          treatment: :order_date
        )

    # EA 1995 s.57 (EPA 1990 Part IIA): England, Scotland, Wales apart
    defp s57,
      do: [
        territorial("UK_uksi_2001_3211", ~D[2001-09-15], "W"),
        territorial("UK_uksi_2000_340", ~D[2000-04-01], "E"),
        territorial("UK_ssi_2000_180", ~D[2000-07-14], "S")
      ]

    defp claimed(claims, attribute),
      do: Enum.find_value(claims, &(&1.attribute == attribute && &1.value))

    test "dated from its first stage, partly in force, no commencing order named" do
      claims = AmendingCommencement.claims(s57(), "section-57", "k")

      assert claimed(claims, :date_staged) == ~D[2000-04-01]
      assert claimed(claims, :partial_staged) == true
      refute claimed(claims, :commenced_by)
      refute claimed(claims, :date)
      assert Enum.all?(claims, &(&1.source == :commencement and &1.ref == "k"))
    end

    test "a full commencement keeps its date, with no partial claim" do
      claims = AmendingCommencement.claims(rules(), "schedule-12-paragraph-3", "k")
      assert claimed(claims, :date) == ~D[2026-10-01]
      refute Enum.any?(claims, &(&1.attribute == :partial))
    end

    test "an order for one territory alone dates nothing: a devolved Act's order is its whole reach, the feed's stages stand (golden: TCPA 1990 s.78(4BA) by anaw 2015/4, WSI 2017/546)" do
      wales = [territorial("UK_wsi_2017_546", ~D[2017-05-05], "W")]
      claims = AmendingCommencement.claims(wales, "section-57", "k")
      assert claimed(claims, :date) == nil and claimed(claims, :date_staged) == nil
    end

    test "a partial stage with no territory dates nothing" do
      purposes = [
        %{
          territorial("UK_uksi_1995_1983", ~D[1995-09-21], nil)
          | purposes: :for_making_secondary_legislation
        }
      ]

      assert AmendingCommencement.claims(purposes, "section-57", "k") |> claimed(:date) == nil
    end
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

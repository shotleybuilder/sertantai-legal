defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmenderStartTest do
  @moduledoc "A change no source dates, at its amending law's first start (Jason 2026-11-01, CV-06)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmenderStart
  alias SertantaiLegal.Scraper.Commencement.Rule

  defp change(claims),
    do: %Change{
      key: "UK_ukpga_1984_55:schedule-7",
      target: "s.70",
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "k"})
    }

  defp rule(when_),
    do: %Rule{
      commences: "UK_ukpga_1984_55",
      scope: :all,
      when: when_,
      source: %{law: "UK_ukpga_1984_55", ref: "s.134", text: nil},
      treatment: :clause_date,
      except: []
    }

  defp rules,
    do: %{
      "UK_ukpga_1984_55" => [
        rule({:appointed, "by order"}),
        rule({:date, ~D[1984-12-01]}),
        rule({:date, ~D[1998-08-07]})
      ]
    }

  test "undated: the amending law's earliest dated start, marked as such" do
    claims =
      AmenderStart.claims(
        change([{:law_text, :by, "UK_ukpga_1984_55"}, {:law_text, :operation, :repealed}]),
        rules()
      )

    assert for(c <- claims, do: {c.attribute, c.value}) == [
             date: ~D[1984-12-01],
             via: "amender_first_start"
           ]
  end

  test "dated by any source, or its law's rules not held: nothing" do
    dated = change([{:law_text, :by, "UK_ukpga_1984_55"}, {:feed, :date, ~D[1984-12-01]}])
    assert AmenderStart.claims(dated, rules()) == []
    assert AmenderStart.claims(change([{:law_text, :by, "UK_ukpga_1999_1"}]), rules()) == []
  end
end

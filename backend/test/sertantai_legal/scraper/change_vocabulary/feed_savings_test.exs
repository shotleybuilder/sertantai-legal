defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSavingsTest do
  @moduledoc "Savings given as a range of provisions (CV-S08 round 1: HSWA s.51A(2A), SOCPA 2005 s.158(5)–(7))."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedSavings
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @page """
  <ukm:Effect EffectId="e-range" Type="inserted"><ukm:Savings><ukm:SectionRange Start="section-158-5" End="section-158-7"><ukm:Section Ref="section-158-5">s. 158(5)</ukm:Section></ukm:SectionRange></ukm:Savings></ukm:Effect>
  <ukm:Effect EffectId="e-plain" Type="repealed"><ukm:Savings><ukm:Section Ref="section-3"/></ukm:Savings></ukm:Effect>
  <ukm:Effect EffectId="e-none" Type="repealed"></ukm:Effect>
  """

  test "a range's provisions are read; savings without a range are left to ChangesFeed" do
    assert FeedSavings.from_pages([@page]) == %{
             "e-range" => ["section-158-5", "section-158-7"]
           }
  end

  test "apply/2 gives each effect its full savings" do
    effects = [
      %Effect{effect_id: "e-range", type: "inserted", affecting: nil, savings: []},
      %Effect{effect_id: "e-plain", type: "repealed", affecting: nil, savings: ["section-3"]}
    ]

    assert [%{savings: ["section-158-5", "section-158-7"]}, %{savings: ["section-3"]}] =
             FeedSavings.apply(effects, FeedSavings.from_pages([@page]))
  end
end

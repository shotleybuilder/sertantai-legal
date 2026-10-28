defmodule SertantaiLegal.Scraper.Amendment.CheckStrataTest do
  @moduledoc """
  The amendment reader check's strata (CV-S06 revised check): agreeing,
  disagreeing and law text only, from merged changes; and the agreement
  with legislation.gov.uk over the both-sourced ones.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.CheckStrata
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Evidence, Merge}

  @law "UK_uksi_2019_696"

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, level \\ :words),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, level},
        {:law_text, :by, @law},
        {:commencement, :date, ~D[2020-12-31]}
      ])

  defp feed(key, target, op, affecting, level \\ :words),
    do:
      set(key, target, [
        {:feed, :operation, op},
        {:feed, :level, level},
        {:feed, :by, @law},
        {:feed, :date, ~D[2020-12-31]},
        {:feed, :affecting, affecting}
      ])

  defp merged(sets), do: sets |> Merge.merge() |> Enum.map(&Evidence.resolve(&1, nil))

  defp strata(sets),
    do: sets |> merged() |> CheckStrata.classify() |> Enum.map(fn {c, s} -> {c.target, s} end)

  test "joined and saying the same is agreeing" do
    assert [{"reg.21", :A}] =
             strata([
               text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
             ])
  end

  test "the law's text alone, with nothing beside it, is law text only" do
    assert [{"reg.21", :L}] =
             strata([text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted)])
  end

  test "joined but at another level is disagreeing" do
    assert [{"reg.21", :D}] =
             strata([
               text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted, :provision),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"], :words)
             ])
  end

  test "the law's text left beside legislation.gov.uk's record of a likely same event is disagreeing" do
    assert [{"reg.21", :D}] =
             strata([
               text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, []),
               feed("key-b", "reg.21", :substituted, [])
             ])
  end

  test "agreement counts each attribute where both sides state it" do
    changes =
      merged([
        text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted, :provision),
        feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"], :words),
        text("#{@law}:schedule-12-paragraph-22", "reg.22", :inserted),
        feed("key-b", "reg.22", :inserted, ["sch.12.para.22"])
      ])

    assert %{operation: {2, 2}, level: {1, 2}, by: {2, 2}, target: {2, 2}} =
             CheckStrata.agreement(changes)
  end
end

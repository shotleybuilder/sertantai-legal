defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergePreciseTest do
  @moduledoc """
  A change the markup places only by its note ref claims no level (CV-S08
  round 1: a note is a pointer) — except beside the provision the feed
  names (Forestry Act 1967 s.1(4)(a): the "and" the feed records on
  s.1(4)(b)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Precise

  @by "UK_uksi_2019_734"

  # an effect id (built here: never written whole in the repo)
  defp id(c), do: "key-" <> String.duplicate(c, 32)

  defp change(key, target, claims),
    do: %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }

  defp feed(key, target, op \\ :repealed),
    do:
      change(key, target, [
        {:feed, :operation, op},
        {:feed, :level, :provision},
        {:feed, :by, @by}
      ])

  defp note_only(key, target), do: change(key, target, [{:markup, :placed, true}])

  defp level(changes, target) do
    changes
    |> Precise.precise()
    |> Enum.find(&(&1.target == target and Change.values(&1, :markup, :placed) != []))
    |> Change.values(:markup, :level)
  end

  test "beside the provision the feed names, a note-only placement is a words change" do
    assert level([feed(id("a"), "s.1(4)(b)"), note_only(id("a"), "s.1(4)(a)")], "s.1(4)(a)") ==
             [:words]
  end

  test "on the provision the feed names (a commencement stage keyed id@date), no level" do
    assert level(
             [feed(id("a") <> "@2020-01-01", "reg.8", :commenced), note_only(id("a"), "reg.8")],
             "reg.8"
           ) == []
  end

  test "below the group the feed names, or with no feed record of it, no level" do
    assert level([feed(id("a"), "reg.3"), note_only(id("a"), "reg.3(2)")], "reg.3(2)") == []
    assert level([note_only(id("b"), "reg.2")], "reg.2") == []
  end
end

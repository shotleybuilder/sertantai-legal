defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeStrataTest do
  @moduledoc """
  The merge check's strata (CV-S07): joined (J, two or more sources state
  the change: an over-join risk), unjoined (U, the conflict report's
  `:unjoined`: a split risk), candidates (C, a single-source change beside
  another source's change of the same family by the same law on the same
  provision or one above or below it: a split the report doesn't flag).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Evidence, Merge, MergeStrata}

  @law "UK_uksi_2019_696"
  @other "UK_uksi_2020_1"

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, by \\ @law),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, :words},
        {:law_text, :by, by},
        {:commencement, :date, ~D[2020-12-31]}
      ])

  defp feed(key, target, op, affecting, by \\ @law),
    do:
      set(key, target, [
        {:feed, :operation, op},
        {:feed, :level, :words},
        {:feed, :by, by},
        {:feed, :date, ~D[2020-12-31]},
        {:feed, :affecting, affecting}
      ])

  # an effect id (built here: never written whole in the repo)
  defp effect_id(c), do: "key-" <> String.duplicate(c, 32)

  defp markup(key, target, op, by \\ @law),
    do: set(key, target, [{:markup, :operation, op}, {:markup, :cited, by}])

  defp merged(sets), do: sets |> Merge.merge() |> Enum.map(&Evidence.resolve(&1, nil))

  defp strata(sets),
    do:
      sets
      |> merged()
      |> MergeStrata.classify()
      |> Enum.map(fn {c, s} -> {c.target, s} end)
      |> Enum.sort()

  test "a change two sources state is joined" do
    assert strata([
             text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted),
             feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
           ]) == [{"reg.21", :J}]

    assert strata([
             feed("key-a", "reg.21", :substituted, []),
             markup("key-a", "reg.21", :substituted)
           ]) == [{"reg.21", :J}]
  end

  test "the law's text left beside legislation.gov.uk's likely same event is unjoined; its twins aren't counted again" do
    assert strata([
             text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted),
             feed("key-a", "reg.21", :substituted, []),
             feed("key-b", "reg.21", :substituted, [])
           ]) == [{"reg.21", :U}]
  end

  test "a markup-only change beside a feed-only change of the same family by the same law is a candidate" do
    # (left apart by the merge: each names another amending provision)
    assert strata([
             feed("key-a", "reg.21", :repealed, ["reg.5"]),
             set(effect_id("f"), "reg.21(2)", [
               {:markup, :operation, :repealed},
               {:markup, :cited, @law},
               {:markup, :affecting, ["reg.9"]}
             ])
           ]) == [{"reg.21", :C}, {"reg.21(2)", :C}]
  end

  test "never a candidate: another law, another family, a provision not above or below, the same source" do
    for sets <- [
          [
            feed("key-a", "reg.21", :repealed, []),
            markup(effect_id("f"), "reg.21", :repealed, @other)
          ],
          [feed("key-a", "reg.21", :repealed, []), markup(effect_id("f"), "reg.21", :inserted)],
          [feed("key-a", "reg.21", :repealed, []), markup(effect_id("f"), "reg.22", :repealed)],
          [feed("key-a", "reg.21", :repealed, []), feed("key-b", "reg.21(2)", :repealed, [])]
        ] do
      assert strata(sets) == [], inspect(sets)
    end
  end

  test "a commencement is no text change: never classed" do
    sets = [
      set("key-c", "reg.21", [{:feed, :operation, :commenced}, {:feed, :by, @law}]),
      markup(effect_id("f"), "reg.21", :inserted)
    ]

    assert strata(sets) == []
  end

  test "counts by stratum and the join rate: law-text and markup changes that met a feed effect" do
    changes =
      merged([
        text("#{@law}:schedule-12-paragraph-21-a", "reg.21", :substituted),
        feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"]),
        text("#{@law}:schedule-12-paragraph-22", "reg.30", :repealed)
      ])

    assert MergeStrata.join_rate(changes) == %{law_text: {1, 2}, markup: {0, 0}}
  end

  test "spread: a key under more than three top provisions (an over-join's shape)" do
    changes =
      merged(
        for(n <- 1..4, do: feed("key-a", "reg.#{n}(1)", :substituted, [])) ++
          [
            feed("key-b", "reg.5(1)", :substituted, []),
            feed("key-b", "reg.5(2)", :substituted, [])
          ]
      )

    assert [{"key-a", tops}] = MergeStrata.spread(changes)
    assert length(tops) == 4
  end
end

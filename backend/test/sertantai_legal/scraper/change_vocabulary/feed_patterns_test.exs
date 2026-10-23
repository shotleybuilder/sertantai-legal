defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPatternsTest do
  @moduledoc """
  CV-S02b: the feed reader against the changes feed's pattern catalogue
  (`test/fixtures/feed_patterns/`, written by `mix lat.feed_patterns`).
  Every example — a real effect with the context the reader needs — must
  read as `expected.json` holds. A pattern with no status hasn't been
  reviewed and fails. A known limit is `pending: <why>`, its examples
  holding the correct outcome: `mix test --only pending` lists those still
  failing.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns

  @dir Path.expand("../../../fixtures/feed_patterns", __DIR__)
  @files Map.new(~w(patterns examples expected), &{&1, Path.join(@dir, &1 <> ".json")})
  for {_, path} <- @files, do: @external_resource(path)

  defp load(name) do
    case File.read(@files[name]) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  # compile time: which examples exist, and which belong to a pending pattern
  catalogue = fn name ->
    case File.read(Path.join(@dir, name <> ".json")) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  statuses = Map.get(catalogue.("expected"), "patterns", %{})

  pending =
    for {p, %{"examples" => ids}} <- Map.get(catalogue.("patterns"), "patterns", %{}),
        String.starts_with?(Map.get(statuses, p, ""), "pending"),
        id <- ids,
        into: MapSet.new(),
        do: id

  setup_all do
    %{patterns: load("patterns"), examples: load("examples"), expected: load("expected")}
  end

  describe "the catalogue" do
    test "every pattern is reviewed: accepted, or pending with why", ctx do
      statuses = ctx.expected["patterns"] || %{}
      patterns = ctx.patterns["patterns"] || %{}

      unreviewed = for {p, _} <- patterns, not Map.has_key?(statuses, p), do: p

      assert unreviewed == [],
             "#{length(unreviewed)} patterns not reviewed (mix lat.feed_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every effect classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] == 0
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id, fixtures do
        id = unquote(id)
        {effect, ctx} = FeedPatterns.decode(fixtures.examples[id])
        expected = fixtures.expected["examples"][id]

        assert expected, "#{id}: no expected outcome (mix lat.feed_patterns --accept)"
        assert FeedPatterns.outcome(FeedPatterns.read(effect, ctx)) == expected
      end
    end
  end

  describe "shapes" do
    test "id_shape/1: kind words kept, numbers N, levels below counted" do
      assert FeedPatterns.id_shape("section-28-3-f") == "section-N(+2)"

      assert FeedPatterns.id_shape("schedule-2-part-1-paragraph-3") ==
               "schedule-N-part-N-paragraph-N"

      assert FeedPatterns.id_shape("article-57-a-iv") == "article-N(+2)"

      assert FeedPatterns.id_shape("part-2-crossheading-obtaining-of-information") ==
               "part-N-crossheading-*"
    end

    test "target_shape/1" do
      assert FeedPatterns.target_shape("s.28(3)(f)") == "s.N(+2)"
      assert FeedPatterns.target_shape("art.Article 57(a)") == "art.Article N(+1)"
      assert FeedPatterns.target_shape("sch.1.para.2") == "sch.N.para.N"
      assert FeedPatterns.target_shape("annex.XVII") == "annex.N"
      assert FeedPatterns.target_shape("*") == "*"
    end

    test "legacy dated types are excluded" do
      e = %SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect{
        effect_id: "E",
        affecting: nil,
        type: "am (E) (1.1.2004)"
      }

      assert FeedPatterns.excluded(e) == "legacy dated type"
      assert FeedPatterns.excluded(%{e | type: "words substituted"}) == nil
    end
  end
end

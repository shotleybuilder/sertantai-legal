defmodule SertantaiLegal.Scraper.Commencement.CommencementPatternsTest do
  @moduledoc """
  CV-S04: the own-clause reader against the commencement sentences' pattern
  catalogue (`test/fixtures/commencement_patterns/`, written by `mix
  lat.commencement_patterns`). Every example — a real sentence, with its
  law's rows its reading needs (`laws.json`) — must read as `expected.json`
  holds. A
  pattern with no status hasn't been reviewed and fails. A known limit is
  `pending: <why>`, its examples holding the correct reading: `mix test
  --only pending` lists those still failing.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{OwnClause, SentencePatterns}

  @dir Path.expand("../../../fixtures/commencement_patterns", __DIR__)
  @files Map.new(~w(patterns examples laws expected), &{&1, Path.join(@dir, &1 <> ".json")})
  for {_, path} <- @files, do: @external_resource(path)

  defp load(name) do
    case File.read(@files[name]) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

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

  # each law read once (its examples share one input), in parallel
  setup_all do
    laws = load("laws")

    reads =
      laws
      |> Task.async_stream(
        fn {law, input} -> {law, OwnClause.read(law, SentencePatterns.input(law, input))} end,
        timeout: :infinity,
        ordered: false
      )
      |> Map.new(fn {:ok, r} -> r end)

    # kept where every test reads it without a copy (1,500 tests)
    :persistent_term.put({__MODULE__, :reads}, reads)
    :persistent_term.put({__MODULE__, :examples}, load("examples"))
    :persistent_term.put({__MODULE__, :expected}, load("expected"))

    %{patterns: load("patterns")}
  end

  defp fixture(name), do: :persistent_term.get({__MODULE__, name})

  describe "the catalogue" do
    test "every pattern is reviewed: accepted, or pending with why", ctx do
      statuses = fixture(:expected)["patterns"] || %{}
      patterns = ctx.patterns["patterns"] || %{}
      unreviewed = for {p, _} <- patterns, not Map.has_key?(statuses, p), do: p

      assert unreviewed == [],
             "#{length(unreviewed)} patterns not reviewed (mix lat.commencement_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every sentence classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] in [0, nil]
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id do
        %{"law" => law, "sentence" => s} = fixture(:examples)[unquote(id)]
        expected = fixture(:expected)["examples"][unquote(id)]

        assert expected,
               "#{unquote(id)}: no expected reading (mix lat.commencement_patterns --accept)"

        got = SentencePatterns.outcome(s, fixture(:reads)[law])
        assert %{"class" => got.class, "rules" => got.rules} == expected
      end
    end
  end

  describe "form/1" do
    test "a statement and a mention" do
      assert %{role: "statement", subject: "whole", verb: "shall", when: "date"} =
               SentencePatterns.form("These Regulations shall come into force on 1st April 2020.")

      assert %{role: "mention"} =
               SentencePatterns.form(
                 "The “relevant date” is the date on which this section comes into force."
               )
    end

    test "lead-ins, the rest, by order, a period" do
      assert %{lead: "except_as", subject: "rest", when: "by_order"} =
               SentencePatterns.form(
                 "Except as provided by subsections (2) and (3) below, the preceding sections of, and the Schedules to, this Act shall come into force on such day as the Secretary of State may by order appoint."
               )

      assert %{subject: "named", verb: "is_to", when: "period"} =
               SentencePatterns.form(
                 "Part II and paragraphs 4 to 10 and 21 of Schedule 3 are to come into force at the end of the period of two months beginning with the day on which this Act is passed."
               )
    end
  end
end

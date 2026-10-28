defmodule SertantaiLegal.Scraper.Amendment.AmendmentPatternsTest do
  @moduledoc """
  CV-S06: the amendment reader against the amending provisions' pattern
  catalogue (`test/fixtures/amendment_patterns/`, written by `mix
  lat.amendment_patterns`). Every example — a real amending provision, its
  law pruned to what the reading needs (`laws.json`) — must class as
  `expected.json` holds (the pattern, so its outcome: the rules' operations
  and levels). A pattern with no status hasn't been reviewed and fails. A
  known limit is `pending: <why>`, its examples holding the correct class:
  `mix test --only pending` lists those still failing.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.{Patterns, Rule}
  alias SertantaiLegal.Scraper.Amendment.Patterns.Example

  @dir Path.expand("../../../fixtures/amendment_patterns", __DIR__)
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

  # each example read once
  setup_all do
    examples = load("examples")

    classes =
      load("laws")
      |> Task.async_stream(
        fn {eid, json} ->
          {xmls, terms, law} = Example.from_json(json)
          %{"amending" => a, "id" => id} = examples[eid]
          {key, _rules} = Example.read(a, xmls, id, terms, law)
          {eid, key}
        end,
        timeout: :infinity,
        ordered: false
      )
      |> Map.new(fn {:ok, r} -> r end)

    :persistent_term.put({__MODULE__, :classes}, classes)
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
             "#{length(unreviewed)} patterns not reviewed (mix lat.amendment_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every amending law classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] in [0, nil]
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id do
        expected = fixture(:expected)["examples"][unquote(id)]
        assert expected, "#{unquote(id)}: no expected class (mix lat.amendment_patterns --accept)"
        assert fixture(:classes)[unquote(id)] == expected
      end
    end
  end

  describe "outcome/1 and key/2" do
    defp rule(op, level),
      do:
        Rule.new(
          amends: "UK_ukpga_1974_37",
          targets: ["s.1"],
          operation: op,
          level: level,
          source: %{law: "UK_uksi_2008_960", ref: "regulation-2", text: nil},
          treatment: :instruction
        )

    test "operations and levels, sorted; none for no rule" do
      assert Patterns.outcome([]) == "none"

      assert Patterns.outcome([rule(:substituted, :words), rule(:inserted, :provision)]) ==
               "rules:inserted+substituted:provision+words"
    end

    test "the key joins the form and the outcome" do
      form = %{shape: "instruction", verb: "repealed", quote: "none", place: "body", law: "named"}
      assert Patterns.key(form, "none") == "instruction|repealed|none|body|named|none"
    end
  end
end

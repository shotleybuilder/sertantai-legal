defmodule SertantaiLegal.Scraper.AmendingLaw.ExtentPatternsTest do
  @moduledoc """
  CV-S05: the extent reader against the extent and application sentences'
  pattern catalogue (`test/fixtures/extent_patterns/`, written by `mix
  lat.extent_patterns`). Every example — a real sentence, with its law
  flattened to what the reading needs (`laws.json`) — must read as
  `expected.json` holds. A pattern with no status hasn't been reviewed and
  fails. A known limit is `pending: <why>`, its examples holding the correct
  reading: `mix test --only pending` lists those still failing.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns

  @dir Path.expand("../../../fixtures/extent_patterns", __DIR__)
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

  # each law read once (its examples share one flattened document)
  setup_all do
    reads =
      load("laws")
      |> Task.async_stream(fn {law, xml} -> {law, Patterns.read(law, xml)} end,
        timeout: :infinity,
        ordered: false
      )
      |> Map.new(fn {:ok, r} -> r end)

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
             "#{length(unreviewed)} patterns not reviewed (mix lat.extent_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every law classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] in [0, nil]
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id do
        %{"law" => law, "ref" => ref, "sentence" => s} = fixture(:examples)[unquote(id)]
        expected = fixture(:expected)["examples"][unquote(id)]

        assert expected, "#{unquote(id)}: no expected class (mix lat.extent_patterns --accept)"

        got =
          Enum.find_value(fixture(:reads)[law], fn {r, sentence, class} ->
            if r == ref and sentence == s, do: class
          end)

        assert got == expected
      end
    end
  end

  describe "form/1 and statement/1" do
    test "a whole-law default, a list heading, a mention" do
      s = "Subject to the following provisions, this Act extends to England and Wales only."

      assert %{kind: "extent", subject: "whole", verb: "extends", lead: "subject_to", only: true} =
               Patterns.form(s)

      assert Extent.statement(s) == {:default, "E+W"}

      assert Extent.statement("The following extend also to Scotland— sections 1 to 54;") ==
               {:list, :also, "S"}

      assert Extent.statement(
               "Before exercising the power in relation to an enactment which extends to Scotland, the Secretary of State must consult."
             ) == nil
    end

    test "quoted words and amending instructions are not extent sentences" do
      refute Patterns.words?(
               "after “these Regulations” insert “as they apply in relation to Wales”"
             )

      refute Patterns.words?(
               "After subsection (3) insert— (3A) This section applies in relation to Wales."
             )

      assert Patterns.words?("These Regulations apply in relation to Wales only.")
    end
  end
end

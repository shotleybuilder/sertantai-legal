defmodule SertantaiLegal.Scraper.Commencement.OrderPatternsTest do
  @moduledoc """
  CV-S04: the order reader against the commencement orders' pattern
  catalogue (`test/fixtures/order_patterns/`, written by `mix
  lat.order_patterns`). Every example — a real statement, as its order cut
  to what its reading needs — must read as `expected.json` holds. A pattern
  with no status hasn't been reviewed and fails; a known gap is `pending:
  <why>` (`mix test --only pending` lists them).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OrderPatterns

  @dir Path.expand("../../../fixtures/order_patterns", __DIR__)
  @files Map.new(~w(patterns examples expected), &{&1, Path.join(@dir, &1 <> ".json")})
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

  setup_all do
    :persistent_term.put({__MODULE__, :examples}, load("examples"))
    :persistent_term.put({__MODULE__, :expected}, load("expected"))
    %{patterns: load("patterns")}
  end

  defp fixture(name), do: :persistent_term.get({__MODULE__, name})

  describe "the catalogue" do
    test "every pattern is reviewed: accepted, or pending with why", ctx do
      statuses = fixture(:expected)["patterns"] || %{}

      unreviewed =
        for {p, _} <- ctx.patterns["patterns"] || %{}, not Map.has_key?(statuses, p), do: p

      assert unreviewed == [],
             "#{length(unreviewed)} patterns not reviewed (mix lat.order_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every statement classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] in [0, nil]
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id do
        %{"order" => order, "act" => a, "unit" => u, "xml" => xml} =
          fixture(:examples)[unquote(id)]

        expected = fixture(:expected)["examples"][unquote(id)]
        assert expected, "#{unquote(id)}: no expected reading (mix lat.order_patterns --accept)"

        act = %{law: a["law"], title: a["title"], year: a["year"]}
        unit = %{kind: u["kind"], id: u["id"], text: u["text"]}
        got = OrderPatterns.read(order, act, xml, unit)
        assert %{"class" => got.class, "rules" => got.rules} == expected
      end
    end
  end
end

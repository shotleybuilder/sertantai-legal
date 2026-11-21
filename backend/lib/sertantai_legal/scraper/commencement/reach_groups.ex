defmodule SertantaiLegal.Scraper.Commencement.ReachGroups do
  @moduledoc """
  A catalogue's findings grouped by shape and ranked by reach: each group's
  count, its laws with their reach (LAT rows, or the changes a law makes
  on ours) and up to three examples from different laws; the summary and
  report lines a catalogue prints and its generated file. The commencement
  catalogues' leftovers and misreads use it, as do other steps' checks
  (through `Leftovers`' names). Pure.
  """

  @typedoc "A finding of a statement (a leftover or a misread): its words, with any other facts."
  @type finding :: %{required(:words) => String.t(), optional(atom()) => term()}

  @type groups :: %{String.t() => %{count: integer(), laws: map(), examples: [map()]}}

  @doc """
  Adds one statement's findings (leftovers or misreads: each with its
  `words`) to `groups` under its shape: the count,
  each law with its reach (its LAT rows, or the changes it makes on ours),
  up to 3 examples from different laws.
  """
  @spec add(groups(), String.t(), String.t(), String.t(), [finding()], integer()) ::
          groups()
  def add(groups, _shape, _law, _row, [], _reach), do: groups

  def add(groups, shape, law, row, leftovers, reach) do
    g = Map.get(groups, shape, %{count: 0, laws: %{}, examples: []})
    example = %{"law" => law, "row" => row, "words" => Enum.map(leftovers, & &1.words)}

    examples =
      if length(g.examples) < 3 and law not in Enum.map(g.examples, & &1["law"]),
        do: g.examples ++ [example],
        else: g.examples

    Map.put(groups, shape, %{
      count: g.count + 1,
      laws: Map.put(g.laws, law, reach),
      examples: examples
    })
  end

  @doc "The groups by reach (the sum of their laws'), widest first: `{shape, reach, group}`."
  @spec ranked(groups()) :: [{String.t(), integer(), map()}]
  def ranked(groups) do
    groups
    |> Enum.map(fn {shape, g} -> {shape, g.laws |> Map.values() |> Enum.sum(), g} end)
    |> Enum.sort_by(fn {shape, reach, _} -> {-reach, shape} end)
  end

  @doc "The summary a catalogue prints: the groups, the widest `n` with their review status, those with none."
  @spec summary([{String.t(), integer(), map()}], map(), integer()) :: [String.t()]
  def summary(ranked, reviewed, n \\ 30) do
    statements = ranked |> Enum.map(&elem(&1, 2).count) |> Enum.sum()
    unreviewed = Enum.count(ranked, fn {shape, _, _} -> not Map.has_key?(reviewed, shape) end)

    [
      "\nleftovers by shape (words no rule uses): #{length(ranked)} groups, #{statements} statements"
    ] ++
      for(
        {shape, reach, g} <- Enum.take(ranked, n),
        do: "  #{reach} reach, #{g.count}: #{shape} [#{Map.get(reviewed, shape, "no status")}]"
      ) ++ ["leftover groups with no status: #{unreviewed}"]
  end

  @doc "The groups as their generated file: shape → reach, count, laws, examples."
  @spec to_json(groups()) :: map()
  def to_json(groups) do
    Map.new(ranked(groups), fn {shape, reach, g} ->
      {shape,
       %{
         "reach" => reach,
         "count" => g.count,
         "laws" => map_size(g.laws),
         "examples" => g.examples
       }}
    end)
  end

  @doc "The ranked groups as report lines."
  @spec lines([{String.t(), integer(), map()}]) :: [String.t()]
  def lines(ranked) do
    for {shape, reach, g} <- ranked,
        line <-
          ["#{reach} reach, #{g.count} statements, #{map_size(g.laws)} laws — #{shape}"] ++
            for(
              e <- g.examples,
              do: "    #{e["law"]} #{e["row"]}: #{Enum.join(e["words"], " · ")}"
            ),
        do: line
  end
end

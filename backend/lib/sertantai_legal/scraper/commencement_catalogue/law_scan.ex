defmodule SertantaiLegal.Scraper.CommencementCatalogue.LawScan do
  @moduledoc """
  One law's part of the commencement catalogue: the examples its sentences
  give read alone (`scan/2`), and the catalogue's choice of examples made
  law by law in order (`select/4`). Pure but for the reader it calls.

  The catalogue holds up to three examples a pattern, from different laws,
  first come in law order; an example not held (too large, or reading
  differently alone) leaves its slot to the law's next sentence. A law
  scanned alone always finds room, so the examples it computes alone hold
  every one the whole run asks of it: where the run's pattern has room the
  law's steps for it are the same as alone, and where it is full the law
  takes nothing. So the scans run in the parallel, cached law read
  (`CommencementCatalogue.LawRead`), and `select/4` over them in law order
  gives the catalogue a serial run gives (as `FeedPatterns.LawScan`). Each
  law's held examples are then merged into one input (`laws.json`) and
  checked to read alone as in the law: that set is the whole run's, so the
  merge runs in `select/4`.
  """

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, SentencePatterns}

  @per_pattern 3
  # a law beyond this many rows holds no example needing every row's text
  @max_full 1000
  @levels [:tight, :named, :ids, :full]

  @type outcome :: {:held, map()} | :too_large | :mismatch | {:raise, String.t()}
  @type read :: %{input: map(), sentences: [map()], reach: non_neg_integer()}

  @doc "An empty catalogue."
  @spec new_acc() :: map()
  def new_acc,
    do: %{
      laws: 0,
      sentences: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      laws_inputs: %{},
      mismatch: [],
      too_large: [],
      leftovers: %{}
    }

  @doc """
  The examples the law's sentences give alone, by the sentence's place in
  the law: every one the whole run can ask of it. `example` (the place →
  `outcome/0`) computes each; by default the reader at each pruning.
  """
  @spec scan(
          String.t(),
          %{input: map(), sentences: [map()]},
          (non_neg_integer() -> outcome()) | nil
        ) ::
          %{non_neg_integer() => outcome()}
  def scan(law, %{input: input, sentences: sentences}, example \\ nil) do
    read = %{input: input, sentences: sentences, reach: 0}
    {_, outcomes} = take_all(new_acc(), law, read, example || reader(law, read), false)
    outcomes
  end

  defp reader(law, %{input: input, sentences: sentences}) do
    at = sentences |> Enum.with_index() |> Map.new(fn {s, i} -> {i, s} end)
    &example(law, input, Map.fetch!(at, &1))
  end

  @doc """
  The law's sentences taken into the catalogue `acc`, in law order, each
  example from `examples`: the law's scan (a map by the sentence's place),
  or a function of the place computing it. The law's held examples are
  then merged and checked (`opts`: `:merge` and `:read`, by default
  `SentencePatterns`'). Raises where an example raised, as a serial run.
  """
  @spec select(map(), String.t(), read(), map() | (non_neg_integer() -> outcome()), keyword()) ::
          map()
  def select(acc, law, read, examples, opts \\ [])

  def select(acc, law, read, outcomes, opts) when is_map(outcomes),
    do: select(acc, law, read, &Map.fetch!(outcomes, &1), opts)

  def select(acc, law, read, example, opts) when is_function(example, 1) do
    {acc, _} = take_all(%{acc | laws: acc.laws + 1}, law, read, example, true)
    merge_law(acc, law, read.input, opts)
  end

  defp take_all(acc, law, read, example, raise?) do
    read.sentences
    |> Enum.with_index()
    |> Enum.reduce({acc, %{}}, fn {sentence, i}, {acc, outcomes} ->
      take(acc, outcomes, law, read.reach, {sentence, i}, example, raise?)
    end)
  end

  defp take(acc, outcomes, law, reach, {sentence, i}, example, raise?) do
    %{row: row_id, sentence: s, pattern: key, leftovers: left} = sentence
    id = example_id(law, row_id, s)

    acc = %{
      acc
      | leftovers:
          Leftovers.add(acc.leftovers, Leftovers.shape(key, left), law, row_id, left, reach),
        sentences: acc.sentences + 1
    }

    entry = Map.get(acc.patterns, key, %{count: 0, examples: []})

    take? =
      length(entry.examples) < @per_pattern and law not in Enum.map(entry.examples, &law_of/1)

    acc =
      put_in(acc.patterns[key], %{
        entry
        | count: entry.count + 1,
          examples: if(take?, do: entry.examples ++ [id], else: entry.examples)
      })

    if take? do
      outcome = example.(i)
      {held(acc, key, id, law, sentence, outcome, raise?), Map.put(outcomes, i, outcome)}
    else
      {acc, outcomes}
    end
  end

  defp held(acc, _key, id, law, sentence, {:held, ex}, _raise?) do
    put_in(acc.examples[id], %{
      json: %{"law" => law, "row" => sentence.row, "sentence" => sentence.sentence},
      input: ex,
      outcome: %{"class" => sentence.outcome.class, "rules" => sentence.outcome.rules}
    })
  end

  defp held(_acc, _key, _id, _law, _sentence, {:raise, why}, true), do: raise(why)
  defp held(acc, key, id, _law, _sentence, {:raise, _}, false), do: not_held(acc, key, id, nil)
  defp held(acc, key, id, _law, _sentence, why, _raise?), do: not_held(acc, key, id, why)

  # the example at the smallest pruning that reads alone as in the law;
  # none held when even every row reads differently, nor when a large law
  # needs all its rows' text (too large to hold)
  defp example(law, input, %{row: row_id, sentence: s, outcome: outcome}) do
    held =
      Enum.find_value(@levels, fn level ->
        ex = SentencePatterns.example(row_id, input, level)
        if SentencePatterns.read(law, ex, s) == outcome, do: {level, ex}
      end)

    case held do
      {:full, _} when length(input.rows) > @max_full -> :too_large
      {_, ex} -> {:held, ex}
      nil -> :mismatch
    end
  rescue
    error -> {:raise, Exception.message(error)}
  end

  # the law's examples share one input (`laws.json`), each checked to read
  # alone as in the law still
  defp merge_law(acc, law, input, opts) do
    merge = Keyword.get(opts, :merge, &SentencePatterns.merge/2)
    read = Keyword.get(opts, :read, &SentencePatterns.read/3)
    ids = for {id, x} <- acc.examples, x.json["law"] == law, x[:input], do: id

    case ids do
      [] ->
        acc

      _ ->
        merged = merge.(input, Enum.map(ids, &acc.examples[&1].input))

        Enum.reduce(ids, put_in(acc.laws_inputs[law], merged), fn id, acc ->
          check(acc, id, read.(law, merged, acc.examples[id].json["sentence"]))
        end)
    end
  end

  # the example kept where it reads in the merged input as in the law
  defp check(acc, id, got) do
    x = acc.examples[id]

    if %{"class" => got.class, "rules" => got.rules} == x.outcome,
      do: put_in(acc.examples[id], Map.delete(x, :input)),
      else: drop(acc, id, :mismatch)
  end

  defp drop(acc, id, why) do
    acc = %{acc | examples: Map.delete(acc.examples, id)}

    patterns =
      Map.new(acc.patterns, fn {p, e} -> {p, %{e | examples: List.delete(e.examples, id)}} end)

    Map.update!(%{acc | patterns: patterns}, why, &[id | &1])
  end

  # the slot freed; `nil`: an example that raised alone, its law given up
  # on in the whole run wherever it is asked
  defp not_held(acc, key, id, why) do
    acc = put_in(acc.patterns[key].examples, List.delete(acc.patterns[key].examples, id))
    if why, do: Map.update!(acc, why, &[id | &1]), else: acc
  end

  # a short hash of the sentence: the example's id
  defp example_id(law, row_id, s),
    do:
      law <>
        "/" <>
        (:crypto.hash(:sha256, row_id <> s) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()
end

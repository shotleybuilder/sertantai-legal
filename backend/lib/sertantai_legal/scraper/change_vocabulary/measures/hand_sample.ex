defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.HandSample do
  @moduledoc """
  The measures' hand-check sample (WORKFLOW.md step 10): text changes drawn
  on a seed, each with the classes the measures give it (who states it,
  law-text coverage, dating, merge stratum), for an agent to judge against
  the sources. Pure; `mix lat.measures --sample` reads the store.

  The draw is the one CV-S10's hand check used (seed tuple `{s, 10, 10}`,
  `Draw.shuffled/3` by law, target and key), so OH&S's seed 911 draws its
  sample again.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Conflicts, MergeStrata}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.{Coverage, Draw}

  @type member :: {String.t(), Change.t(), [map()], %{{String.t(), String.t()} => atom()}}

  @doc """
  Each text change of the laws, with its law's conflict report and merge
  strata. `laws` is `[{law, changes}]` or `[{law, changes, conflicts}]`
  (the conflict report with the read pass's pointers, as `lat.measures`
  counts it).
  """
  @spec population([{String.t(), [Change.t()]} | {String.t(), [Change.t()], [map()]}]) ::
          [member()]
  def population(laws) do
    for entry <- laws,
        {law, changes, conflicts} = with_conflicts(entry),
        strata = Map.new(MergeStrata.classify(changes), fn {c, s} -> {{c.key, c.target}, s} end),
        c <- changes,
        Coverage.text?(c),
        do: {law, c, conflicts, strata}
  end

  defp with_conflicts({law, changes}), do: {law, changes, Conflicts.report(changes)}
  defp with_conflicts({_law, _changes, _conflicts} = entry), do: entry

  @doc "`n` members drawn on `seed`, as JSON-ready items numbered from 1."
  @spec draw([member()], non_neg_integer(), integer()) :: [map()]
  def draw(population, n, seed) do
    Draw.seed({seed, 10, 10})

    population
    |> Draw.shuffled(n, fn {law, c, _, _} -> {law, c.target, c.key} end)
    |> Enum.with_index(1)
    |> Enum.map(fn {member, i} -> item(member, i) end)
  end

  @claimed [:operation, :date, :commenced_by, :by, :affecting]

  defp item({law, c, conflicts, strata}, i) do
    r = c.resolved

    %{
      "n" => i,
      "law" => law,
      "target" => c.target,
      "key" => c.key,
      "aliases" => c.aliases,
      "claims" =>
        for(
          cl <- c.claims,
          cl.attribute in @claimed,
          do: %{
            "source" => str(cl.source),
            "attribute" => str(cl.attribute),
            "value" => inspect(cl.value),
            "ref" => cl.ref
          }
        ),
      "resolved" => %{
        "operation" => str(r.operation),
        "date" => r.date && Date.to_iso8601(r.date),
        "commenced_by" => r.commenced_by,
        "by" => r.by,
        # string keys: an atom-keyed map encodes in atom-table order, which a
        # rebuild can change, so the sample would not replicate byte for byte
        "sources" => Map.new(Map.get(r, :sources) || %{}, fn {k, v} -> {to_string(k), str(v)} end)
      },
      "classes" => classes(c, conflicts, strata)
    }
  end

  defp classes(c, conflicts, strata) do
    entry =
      Enum.find(
        conflicts,
        &(&1[:key] == c.key and &1[:target] == c.target and &1.kind in [:uncovered, :unread])
      )

    %{
      "stated_by" => str(Coverage.stated_by(c)),
      "law_text_coverage" => str(one(Coverage.law_text_coverage([c], conflicts))),
      "conflict_entry" =>
        entry && %{"kind" => str(entry.kind), "missing" => str(entry[:missing])},
      "dating" => str(one(Coverage.dating([c]))),
      "merge_stratum" => str(Map.get(strata, {c.key, c.target}))
    }
  end

  # the one class a single change's count map holds
  defp one(counts),
    do: counts |> Enum.find(fn {k, n} -> k != :total and n == 1 end) |> elem(0)

  defp str(v) when is_atom(v) and v != nil, do: Atom.to_string(v)
  defp str(v), do: v
end

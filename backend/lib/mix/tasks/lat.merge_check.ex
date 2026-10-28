defmodule Mix.Tasks.Lat.MergeCheck do
  @moduledoc """
  The merge check (change vocabulary CV-S07): a family's stored text
  changes in the merge's strata (`ChangeVocabulary.MergeStrata`) — joined
  (J: an over-join risk), unjoined (U) and candidates (C: split risks) —
  with the join rate (law-text and markup changes that met a feed effect),
  and with `--sample FILE` a reproducible random sample of one stratum with
  what judging each merge needs (`ChangeVocabulary.MergeSample`) for the
  `merge-check` agent; `--skip N` the next batch of the same draw.
  Read-only.

      mix lat.merge_check --family "OH&S: Occupational" --strata
      mix lat.merge_check --family F --stratum J --sample FILE --n 50 --seed N [--skip 50]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, PatternSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{MergeSample, MergeStrata, Store}

  @shortdoc "The merge check's strata and samples for a family (read-only)"

  @usage "usage: mix lat.merge_check --family F [--strata] " <>
           "[--sample FILE --stratum J|U|C --n N --seed S --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          strata: :boolean,
          sample: :string,
          stratum: :string,
          n: :integer,
          seed: :integer,
          skip: :integer
        ]
      )

    family = opts[:family] || Mix.raise(@usage)
    stratum = stratum(opts[:stratum])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = PatternSource.family_laws(family)
    by_law = Map.new(laws, &{&1, Store.for_law(&1)})

    classified =
      for {law, changes} <- by_law, {c, s} <- MergeStrata.classify(changes), do: {law, c, s}

    Mix.shell().info("#{length(laws)} laws; text changes in a stratum: #{length(classified)}")

    if opts[:strata], do: strata(classified, by_law)

    if path = opts[:sample] do
      seed = opts[:seed] || 1
      strata = Map.new(classified, fn {law, c, s} -> {{law, c.key, c.target}, s} end)

      population = for {law, c, s} <- classified, stratum in [nil, s], do: {law, c}

      items =
        population
        |> CheckSample.draw(length(population), seed)
        |> Enum.drop(opts[:skip] || 0)
        |> Enum.take(opts[:n] || 50)
        |> Enum.with_index(1)
        |> Enum.map(fn {{law, c}, i} ->
          MergeSample.item({law, c, strata[{law, c.key, c.target}]}, by_law[law], i)
        end)

      File.write!(path, Jason.encode!(items, pretty: true))

      Mix.shell().info(
        "sample: #{length(items)} of #{length(population)} changes (seed #{seed}, stratum " <>
          "#{stratum || "all"}, skip #{opts[:skip] || 0}) → #{path}"
      )
    end
  end

  defp strata(classified, by_law) do
    counts = Enum.frequencies_by(classified, &elem(&1, 2))
    text = by_law |> Map.values() |> List.flatten()

    Mix.shell().info("\nstrata:")

    for {s, label} <- [
          J: "joined (over-join risk)",
          U: "unjoined (split risk)",
          C: "candidates (split risk)"
        ],
        do: Mix.shell().info("  #{s}  #{label}: #{Map.get(counts, s, 0)}")

    rate =
      by_law
      |> Map.values()
      |> Enum.map(&MergeStrata.join_rate/1)
      |> Enum.reduce(%{}, &Map.merge(&2, &1, fn _, {a1, n1}, {a2, n2} -> {a1 + a2, n1 + n2} end))

    Mix.shell().info("\njoin rate (met a feed effect), of #{length(text)} stored changes:")

    for {source, {met, n}} <- Enum.sort(rate),
        do: Mix.shell().info("  #{source}: #{met}/#{n} (#{pct(met, n)})")
  end

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(J U C), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)

  defp pct(_, 0), do: "–"
  defp pct(a, n), do: :erlang.float_to_binary(100 * a / n, decimals: 1) <> "%"
end

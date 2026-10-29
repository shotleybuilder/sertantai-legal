defmodule Mix.Tasks.Lat.EvidenceCheck do
  @moduledoc """
  The evidence check (change vocabulary CV-S08): a family's merged changes
  in the evidence strata (`ChangeVocabulary.EvidenceStrata`) — value
  conflicts (V), markup–feed disagreements (D) and agreeing changes
  several sources state (A) — with which source won each attribute, and
  with `--sample FILE` a reproducible random sample of one stratum with
  what judging each value needs (`ChangeVocabulary.EvidenceSample`) for
  the `evidence-check` agent. D is drawn by pattern, up to `--per` items
  of each (default 10): the table applies one rule to a pattern's items.
  `--skip N` the next batch of the same draw. Read-only.

      mix lat.evidence_check --family "OH&S: Occupational" --strata
      mix lat.evidence_check --family F --stratum A --sample FILE --n 50 --seed N [--skip 50]
      mix lat.evidence_check --family F --stratum D --sample FILE --per 10 --seed N
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, PatternSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{EvidenceSample, EvidenceStrata, Store}

  @shortdoc "The evidence check's strata and samples for a family (read-only)"

  @usage "usage: mix lat.evidence_check --family F [--strata] " <>
           "[--sample FILE --stratum V|D|A --n N --per P --seed S --skip K]"

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
          per: :integer,
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
    all = by_law |> Map.values() |> List.flatten()

    classified =
      for {law, changes} <- by_law, {c, s} <- EvidenceStrata.classify(changes), do: {law, c, s}

    Mix.shell().info(
      "#{length(laws)} laws; #{length(all)} changes; in a stratum: #{length(classified)}"
    )

    if opts[:strata], do: strata(classified, all)

    if path = opts[:sample] do
      seed = opts[:seed] || 1
      population = for {law, c, s} <- classified, stratum in [nil, s], do: {law, c}
      drawn = CheckSample.draw(population, length(population), seed)

      drawn =
        if stratum == :D,
          do: by_pattern(drawn, opts[:per] || 10),
          else: drawn |> Enum.drop(opts[:skip] || 0) |> Enum.take(opts[:n] || 50)

      strata = Map.new(classified, fn {law, c, s} -> {{law, c.key, c.target}, s} end)

      items =
        drawn
        |> Enum.with_index(1)
        |> Enum.map(fn {{law, c}, i} ->
          EvidenceSample.item({law, c, strata[{law, c.key, c.target}]}, i)
        end)

      File.write!(path, Jason.encode!(items, pretty: true))

      Mix.shell().info(
        "sample: #{length(items)} of #{length(population)} changes (seed #{seed}, stratum " <>
          "#{stratum || "all"}, skip #{opts[:skip] || 0}) → #{path}"
      )
    end
  end

  # up to `per` of each pattern, in the draw's order
  defp by_pattern(drawn, per) do
    drawn
    |> Enum.group_by(fn {_, c} -> EvidenceSample.pattern(c) end)
    |> Enum.sort()
    |> Enum.flat_map(fn {_, items} -> Enum.take(items, per) end)
  end

  defp strata(classified, all) do
    counts = Enum.frequencies_by(classified, &elem(&1, 2))

    Mix.shell().info("\nstrata:")

    for {s, label} <- [
          V: "value conflicts (primary vs legislation.gov.uk)",
          D: "markup vs feed, no primary claim",
          A: "agreeing, several sources"
        ],
        do: Mix.shell().info("  #{s}  #{label}: #{Map.get(counts, s, 0)}")

    conflicts =
      for {_, c, :V} <- classified,
          {a, {ps, _}, {ds, _}} <- c.resolved.conflicts,
          do: "#{a} #{ps}/#{ds}"

    tally("\nV conflicts (attribute primary/derived):", conflicts)

    patterns = for {_, c, :D} <- classified, do: EvidenceSample.pattern(c)
    tally("\nD patterns (attribute markup/feed, chosen operation):", patterns)

    contested = for {_, c, :A} <- classified, a <- EvidenceStrata.contested(c), do: to_string(a)
    tally("\nA attributes several sources claim:", contested)

    winners =
      for %{resolved: %{sources: sources}} <- all,
          {a, s} <- sources,
          do: "#{a} #{s || "none"}"

    tally("\nwinning source per attribute, all changes:", winners)
  end

  defp tally(title, items) do
    Mix.shell().info(title)

    for {k, n} <- items |> Enum.frequencies() |> Enum.sort_by(fn {k, n} -> {-n, k} end),
        do: Mix.shell().info("  #{n}  #{k}")
  end

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(V D A), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)
end

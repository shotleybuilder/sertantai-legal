defmodule Mix.Tasks.Lat.MergeCheck do
  @moduledoc """
  The merge check (change vocabulary CV-S07): a family's stored text
  changes in the merge's strata (`ChangeVocabulary.MergeStrata`) — joined
  (J: an over-join risk), unjoined (U) and candidates (C: split risks) —
  with the join rate (law-text and markup changes that met a feed effect),
  and with `--sample FILE` a reproducible random sample of one stratum with
  what judging each merge needs (`ChangeVocabulary.MergeSample`) for the
  `merge-check` agent; `--skip N` the next batch of the same draw.
  `--gate [--all]`: the family gate (`ChangeVocabulary.MergeGate`; Decision
  1, Maritime Safety: Merge), each merge decision by cause and amending law,
  reviewed in `test/fixtures/merge/merges.json`; `--all` prints every group,
  else the groups not named. Read-only.

      mix lat.merge_check --family "OH&S: Occupational" --strata
      mix lat.merge_check --family F --gate [--all]
      mix lat.merge_check --family F --stratum J --sample FILE --n 50 --seed N [--skip 50]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, Disagreement, PatternSource}
  alias SertantaiLegal.Scraper.Amendment.Store, as: Rules
  alias SertantaiLegal.Scraper.ChangeVocabulary.{MergeGate, MergeSample, MergeStrata, Store}
  alias SertantaiLegal.Scraper.Commencement.Leftovers

  @shortdoc "The merge check's strata and samples for a family (read-only)"

  @reviewed "test/fixtures/merge/merges.json"
  # the amending-law reader's gate: an operation conflict it named
  @reader_reviewed "test/fixtures/amendment_patterns/disagreements.json"

  @usage "usage: mix lat.merge_check --family F [--strata] [--gate [--all]] " <>
           "[--sample FILE --stratum J|U|C --n N --seed S --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          strata: :boolean,
          gate: :boolean,
          all: :boolean,
          by_design: :boolean,
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
    step = if opts[:gate], do: gate(by_law, opts[:all])
    if path = opts[:sample], do: sample(path, opts, classified, by_law, stratum)
    step
  end

  defp sample(path, opts, classified, by_law, stratum) do
    seed = opts[:seed] || 1
    strata = Map.new(classified, fn {law, c, s} -> {{law, c.key, c.target}, s} end)

    population =
      for {law, c, s} <- classified,
          stratum in [nil, s],
          by_design?(c, s, opts[:by_design]),
          do: {law, c}

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

  # the agent pass's population (Decision 1): the joins named by design
  defp by_design?(c, s, true), do: s == :J and MergeGate.cause(c, :J) in MergeGate.by_design()
  defp by_design?(_c, _s, _all), do: true

  # the family gate: each merge decision by cause and amending law, reviewed
  # in merges.json (Decision 1, 2026-11-06); an operation conflict takes the
  # amending-law reader's status where its gate named it
  defp gate(by_law, all?) do
    shell = Mix.shell()
    entries = Enum.flat_map(by_law, fn {law, changes} -> MergeGate.entries(law, changes) end)
    items = MergeGate.items(entries, reviewed(@reviewed), reader_status(entries))
    gate = MergeGate.gate(items)

    counts = Enum.map_join(gate.counts, ", ", fn {k, n} -> "#{k} #{n}" end)
    shell.info("\nmerge decisions by cause (#{@reviewed}): #{length(items)} groups; #{counts}")

    for {cause, n} <-
          items
          |> Enum.group_by(& &1.shape, & &1.reach)
          |> Enum.map(fn {k, ns} -> {k, Enum.sum(ns)} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{pad(n)}  #{cause}")

    shown = if all?, do: Enum.sort_by(items, &{-&1.reach, &1.law, &1.shape}), else: gate.failing

    shell.info(
      "\n#{if all?, do: "every group", else: "not named"} (widest reach first): #{length(shown)}"
    )

    for i <- shown do
      shell.info("  #{pad(i.reach)}  #{i.shape} @ #{i.law}  [#{i.status || "no status"}]")
      for w <- Enum.take(i.words, 4), do: shell.info("           #{w}")
    end

    shell.info(
      "\n#{if gate.pass?, do: "PASS", else: "FAIL"} (groups not named: #{length(gate.failing)})"
    )

    Step.new("Merge", gate.pass?, length(gate.failing))
  end

  # an operation conflict's status in the amending-law reader's gate
  defp reader_status(entries) do
    reviewed = reviewed(@reader_reviewed)

    rules =
      for %{cause: "operation differs", law: law} <- entries,
          uniq: true,
          into: %{},
          do: {law, Rules.for_law(law)}

    fn
      %{cause: "operation differs", change: c, by: by, law: law} ->
        cause = Disagreement.cause(c, :D, Map.get(rules, law, []))
        Leftovers.status(cause, reviewed, by)

      _ ->
        nil
    end
  end

  defp reviewed(path) do
    case File.read(path) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 5)

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

    Mix.shell().info(
      "\njoin rate: of each source's text changes, those a feed effect states too (#{length(text)} stored changes):"
    )

    for {source, {met, n}} <- Enum.sort(rate),
        do: Mix.shell().info("  #{source}: #{met}/#{n} (#{pct(met, n)})")

    spread =
      for {law, changes} <- by_law,
          {key, tops} <- MergeStrata.spread(changes),
          do: {law, key, tops}

    Mix.shell().info(
      "\nkeys under more than 3 top provisions (an over-join's shape, to read): #{length(spread)}"
    )

    for {law, key, tops} <- Enum.take(Enum.sort_by(spread, &(-length(elem(&1, 2)))), 15),
        do:
          Mix.shell().info(
            "  #{law} #{short(key)}: #{length(tops)} (#{tops |> Enum.take(5) |> Enum.join(", ")}…)"
          )
  end

  # an effect id's last six characters (never printed whole)
  defp short("key-" <> rest), do: "key-…" <> String.slice(rest, -6, 6)
  defp short(key), do: key

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(J U C), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)

  defp pct(_, 0), do: "–"
  defp pct(a, n), do: :erlang.float_to_binary(100 * a / n, decimals: 1) <> "%"
end

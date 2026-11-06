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
  `--skip N` the next batch of the same draw. `--gate [--all]`: the
  family gate (`ChangeVocabulary.Gate.Evidence`; Decision 1, Maritime
  Safety: Evidence), each value conflict and markup–feed disagreement by
  cause and amending law, reviewed in `test/fixtures/evidence/evidence.json`
  (operation conflicts inherit the amending-law reader's status); `--all` prints every group, else the groups not
  named; then the gaps by cause. Read-only.

      mix lat.evidence_check --family "OH&S: Occupational" --strata
      mix lat.evidence_check --family F --gate [--all]
      mix lat.evidence_check --family F --stratum A --sample FILE --n 50 --seed N [--skip 50]
      mix lat.evidence_check --family F --stratum D --sample FILE --per 10 --seed N
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, Disagreement, PatternSource}
  alias SertantaiLegal.Scraper.Amendment.Store, as: Rules

  alias SertantaiLegal.Scraper.ChangeVocabulary.{
    EvidenceSample,
    EvidenceStrata,
    Store
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Evidence, as: Gate
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.Leftovers

  @shortdoc "The evidence check's strata and samples for a family (read-only)"

  @reviewed "test/fixtures/evidence/evidence.json"
  # the amending-law reader's gate: an operation conflict it named
  @reader_reviewed "test/fixtures/amendment_patterns/disagreements.json"

  @usage "usage: mix lat.evidence_check --family F [--strata] [--gate [--all]] " <>
           "[--sample FILE --stratum V|D|A --n N --per P --seed S --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          strata: :boolean,
          gate: :boolean,
          all: :boolean,
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
    if opts[:gate], do: gate(by_law, all, opts[:all])

    if path = opts[:sample], do: sample(path, opts, classified, stratum)
  end

  defp sample(path, opts, classified, stratum) do
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

  # the family gate (Decision 1, 2026-11-06): each evidence decision where
  # the sources disagree, by cause and amending law, then the gaps
  defp gate(by_law, all, all?) do
    shell = Mix.shell()
    entries = Enum.flat_map(by_law, fn {law, changes} -> Gate.entries(law, changes) end)
    items = Gate.items(entries, reviewed(@reviewed), inherited(entries))
    gate = Gate.gate(items)

    counts = Enum.map_join(gate.counts, ", ", fn {k, n} -> "#{k} #{n}" end)
    shell.info("\nevidence decisions by cause (#{@reviewed}): #{length(items)} groups; #{counts}")

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

    report_gaps(all)

    shell.info(
      "\n#{if gate.pass?, do: "PASS", else: "FAIL"} (groups not named: #{length(gate.failing)})"
    )
  end

  defp report_gaps(changes) do
    shell = Mix.shell()
    shell.info("\ngaps, a value no source claims (attribute, sources the change holds):")
    gaps = Gate.gaps(changes, ruled())

    for {{a, held}, n} <- Enum.sort_by(gaps, fn {k, n} -> {-n, k} end),
        do: shell.info("  #{pad(n)}  #{a}  #{held}")

    shell.info("gaps by attribute (total; amending law has no commencement rules):")

    for {a, t} <- gaps |> Gate.gap_totals() |> Enum.sort_by(fn {a, t} -> {-t.total, a} end),
        do: shell.info("  #{pad(t.total)}  #{a}  (#{t.no_rules})")
  end

  # an operation or level conflict of the law's text: its status in the
  # amending-law reader's gate (`Disagreement.cause`), one review, not two
  defp inherited(entries) do
    reader = reviewed(@reader_reviewed)

    rules =
      for %{cause: cause, law: law} <- entries,
          readers?(cause),
          uniq: true,
          into: %{},
          do: {law, Rules.for_law(law)}

    fn %{cause: cause, change: c, by: by, law: law} ->
      if readers?(cause),
        do: Leftovers.status(Disagreement.cause(c, :D, Map.get(rules, law, [])), reader, by)
    end
  end

  defp readers?(cause),
    do: String.starts_with?(cause, ["operation: law_text ", "level: law_text "])

  # the laws holding commencement rules (a gap's cause)
  defp ruled do
    %{rows: rows} = Repo.query!("select distinct commences from commencement_rules")
    MapSet.new(rows, &hd/1)
  end

  defp reviewed(path) do
    case File.read(path) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 5)

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

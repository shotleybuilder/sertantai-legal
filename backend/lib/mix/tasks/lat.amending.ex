defmodule Mix.Tasks.Lat.Amending do
  @moduledoc """
  A law's amendment ruleset (amendment-rules AR-01, AR-03), one readable
  line per rule — the law and targets, the operation (words-level or whole
  provisions), its treatment, and the amending provision it came from:

      mix lat.amending --law UK_uksi_2014_1638

      UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C … substitute—”

  The read pass (AR-03) reads each amending law once — the provisions our
  laws' notes and their changes feeds point to (one hop; one deduplicated
  set of pointers, CV-07), for every law they point from — and stores
  its rules (`amendment_rules`) with a small index (`Amendment.Index`:
  element ids, each repeals table's introducing section, the reader version,
  the laws read for), so the collector needs no XML:

      mix lat.amending --read                    # every amending law not read by this reader (resumable)
      mix lat.amending --read --stale [--family F]   # the amending laws behind the builds' amending_reader reason (`StepProcedures.AmendingStale`)
      mix lat.amending --read --stale --family F --preview --diff FILE   # the same, read and compared, nothing written
      mix lat.amending --read --amending A,B     # these amending laws (re-read)
      mix lat.amending --read --limit 20         # the next 20
      mix lat.amending --read --preview --amending A,B   # read, report what would change, write nothing
      mix lat.amending --read --preview --all    # every amending law, stale or not (a refactor's zero-diff gate)
      mix lat.amending --read --preview --regression     # the regression set (test/fixtures/amendment_read/regression.txt + the golden laws' amending laws)
      mix lat.amending --read --preview --amending A,B --diff FILE   # also each changed rule by field, grouped (`Amendment.Review.RuleDiff`)
      mix lat.amending --amending A --provision ID        # one amending provision: its words, stored rules and a fresh reading (`Amendment.Review.Probe`)
      mix lat.amending --fetch-enacted --amending A,B    # the repeals Schedules their revised text leaves out, as enacted or made (CV-06a; a fetch: ask first)

  Each changed amending law is reported (`ReadReport`: rules removed and
  added per amended law, the provisions behind them), then a summary.
  **Workflow (run time, 2026-10-25):** a reader fix is checked with
  `--preview` on the laws it concerns and on `--regression`; fixes are
  batched; one full `--read` per round, its report traced before
  accepting. Never a full pass per fix.

  An Act's own extent clause (CV-04: `extent_rules`) is read in the same
  pass; for the Acts changing a law, or named Acts, alone:

      mix lat.amending --extents --law UK_ukpga_1990_8
      mix lat.amending --extents --amending UK_ukpga_2005_15
      mix lat.amending --extents --amending A,B --cached   # the enabling cache only, never a fetch
      mix lat.amending --extents --amending @FILE          # one law a line (the last kept with no final newline)
      mix lat.amending --extents --stale [--family F]      # every law read by other reader code, or not read (its text held)
      mix lat.amending --extents --stale --preview [--diff FILE]   # read and compare, nothing written: rows gone and added by field

  One amending law at a time, each in its own process: a parsed amending
  law can take gigabytes (a 5-wide run exhausted memory, 2026-10-20).
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Text

  alias SertantaiLegal.Scraper.Amendment.{
    EnactedFetch,
    ProvisionRead,
    ReadLaw,
    ReadPass,
    ReadReport,
    Rule,
    Store
  }

  alias SertantaiLegal.Scraper.Amendment.Review.{Probe, RuleDiff}
  alias SertantaiLegal.Scraper.StepProcedures.{AmendingStale, ExtentDiff, ExtentStale, LawList}

  @shortdoc "Print a law's amendment rules; read amending laws into rules"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          read: :boolean,
          amending: :string,
          limit: :integer,
          extents: :boolean,
          cached: :boolean,
          workers: :integer,
          preview: :boolean,
          regression: :boolean,
          all: :boolean,
          fetch_enacted: :boolean,
          diff: :string,
          provision: :string,
          stale: :boolean,
          family: :string
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:amending] && (opts[:fetch_enacted] || opts[:provision]) ->
        one_amending(opts)

      opts[:extents] ->
        extents(opts)

      opts[:read] ->
        read(opts)

      opts[:law] ->
        for line <- opts[:law] |> Store.for_law() |> print(opts[:law]), do: Mix.shell().info(line)

      true ->
        Mix.raise(
          "usage: mix lat.amending --law X | --read [--amending A,B | --stale [--family F]] [--limit N] [--preview [--diff FILE]] | --amending A --provision ID | --extents --law X | --extents --amending A,B"
        )
    end
  end

  # the repeals Schedules the revised text leaves out, as enacted or made
  # (CV-06a): fetched for the amending laws named only
  defp fetch_enacted(amending) do
    for law <- String.split(amending, ",", trim: true) do
      results = EnactedFetch.run(law)

      Mix.shell().info(
        "#{law}: " <>
          if(results == [],
            do: "nothing wanted",
            else: Enum.map_join(results, ", ", fn {id, r} -> "#{id} #{inspect(r)}" end)
          )
      )
    end
  end

  # --amending A with --fetch-enacted, or with --provision ID
  defp one_amending(opts) do
    if opts[:fetch_enacted],
      do: fetch_enacted(opts[:amending]),
      else: probe(opts[:amending], opts[:provision])
  end

  # one amending provision: its words, its stored rules, a fresh reading for
  # the laws it is stored or noted against (one law parsed, nothing written)
  defp probe(amending, id) do
    stored = for r <- Store.for_source(amending), r.source.ref == id, do: r
    doc = ReadLaw.doc(amending) || Mix.raise("#{amending}: not in the CLML store")

    laws =
      Enum.uniq(Enum.map(stored, & &1.amends) ++ Enum.map(ReadLaw.notes(amending), & &1.law_name))

    fresh = ProvisionRead.read(doc, id, Enum.map(laws, &ReadLaw.law_ref/1))
    for l <- Probe.lines(amending, id, Text.of(doc, id), stored, fresh), do: Mix.shell().info(l)
  end

  @doc "The printed lines for a law's rules."
  @spec print([Rule.t()], String.t()) :: [String.t()]
  def print([], law), do: ["#{law}: no amendment rules (the readers write them: AR-03)"]

  def print(rules, law) do
    groups =
      rules
      |> Enum.group_by(& &1.source.law)
      |> Enum.sort()
      |> Enum.flat_map(fn {source, rs} ->
        ["", "  from #{source}" | Enum.map(rs, &("    " <> Rule.to_text(&1)))]
      end)

    ["#{law}: #{length(rules)} rule(s)" | groups]
  end

  # ── --extents ───────────────────────────────────────────────────────

  # the extent clauses of the laws changing a law (its feed's affecting
  # laws), the Acts named, or the stale ones, held in the CLML store
  defp extents(opts) do
    acts = opts |> extent_laws() |> Enum.filter(&(Extent.Store.reads?(&1) and ReadPass.held?(&1)))

    Mix.shell().info("#{length(acts)} laws to read for their extent clause")

    # the parent Acts the SIs' enabling powers lie in, read first (by this
    # reader), so an SI stating no extent is placed by them (CV-07) — those
    # among the laws read too: an SI never reads a parent not yet re-read
    # (several laws are read at once: run time, 2026-10-25)
    enabling_laws =
      for a <- acts,
          not Extent.Powers.act?(a),
          p <- Extent.Powers.enabling(a, opts[:cached]),
          law = p["law"],
          Extent.Store.reads?(law) and ReadPass.held?(law),
          uniq: true,
          do: law

    parents = Enum.reject(enabling_laws, &(&1 in acts))
    {first, rest} = Enum.split_with(acts, &(&1 in enabling_laws))

    Mix.shell().info("#{length(parents)} parent Acts of their enabling powers, read first")

    if opts[:preview],
      do: extents_preview(acts, opts),
      else: extents_write(parents, [first, rest], length(acts), opts)
  end

  defp extent_laws(opts) do
    cond do
      opts[:stale] ->
        stale_extent_laws(opts[:family])

      opts[:amending] ->
        LawList.parse(opts[:amending])

      opts[:law] ->
        affecting_laws(opts[:law])

      true ->
        Mix.raise("--extents needs --law X, --amending A,B (or @FILE) or --stale [--family F]")
    end
  end

  defp affecting_laws(law) do
    law
    |> SertantaiLegal.Scraper.LatStagedParser.law_effects(store: :only)
    |> Enum.map(& &1.affecting)
    |> Enum.uniq()
  end

  defp stale_extent_laws(family) do
    stale = ExtentStale.laws(family)

    Mix.shell().info(
      "stale: #{length(stale.old_code)} read by other reader code, #{length(stale.not_read)} not read (their text held)"
    )

    ExtentStale.all(stale)
  end

  defp extents_write(parents, batches, total, opts) do
    workers = Guard.workers(workers: opts[:workers])

    LawRunner.run(
      parents,
      fn p ->
        {:ok, _, _} =
          Extent.Write.write_read(p, Extent.ReadCache.law(p).read, cached: opts[:cached])
      end,
      fn _, _ -> :ok end,
      workers: workers
    )

    counter = :counters.new(1, [])

    # each in its own process (the parsed document goes when it exits);
    # the parents among them first
    for batch <- batches do
      LawRunner.run(
        batch,
        &extent_line(&1, opts[:cached]),
        &progress(counter, total, &1, &2),
        workers: workers
      )
    end
  end

  defp progress(counter, total, law, line) do
    :counters.add(counter, 1, 1)

    Mix.shell().info(
      "  [#{:counters.get(counter, 1)}/#{total}] " <>
        if(is_binary(line), do: line, else: "#{law}: #{inspect(line)}")
    )
  end

  # read, compared with the rows stored, nothing written: each changed law's
  # rows gone and added, by field (the parents' readings as stored: a
  # preview never re-reads them first)
  defp extents_preview(acts, opts) do
    {:ok, found} = Agent.start_link(fn -> [] end)

    LawRunner.run(
      acts,
      fn a ->
        plan = Extent.Write.plan(a, Extent.ReadCache.law(a).read, cached: opts[:cached])
        ExtentDiff.diff(plan.stored, plan.rows)
      end,
      fn law, diff -> Agent.update(found, &[{law, diff} | &1]) end,
      workers: Guard.workers(workers: opts[:workers])
    )

    found |> Agent.get(&Enum.sort/1) |> report_extents_preview(opts[:diff])
  end

  defp report_extents_preview(results, diff_path) do
    changed = for {law, %{} = d} <- results, not ExtentDiff.same?(d), do: {law, d}

    for {law, d} <- changed do
      Mix.shell().info(
        "#{law}: #{length(d.gone)} rows gone, #{length(d.added)} added — " <>
          Enum.map_join(ExtentDiff.by_field(d.changes), ", ", fn {f, n} -> "#{f} #{n}" end)
      )
    end

    Mix.shell().info(
      "preview: #{length(results)} laws read, #{length(changed)} would change, nothing written"
    )

    if diff_path,
      do: File.write!(diff_path, Jason.encode!(extent_diff_json(changed), pretty: true))
  end

  defp extent_diff_json(changed) do
    for {law, d} <- changed,
        do: %{law: law, by_field: ExtentDiff.by_field(d.changes), changes: d.changes}
  end

  defp extent_line(a, cached) do
    # the reading kept between runs (`Extent.ReadCache`, shared with the
    # catalogue and the check)
    {:ok, n, e} =
      Extent.Write.write_read(a, Extent.ReadCache.law(a).read, cached: cached)

    stated =
      cond do
        e.default -> e.default
        e.powers -> "#{e.powers} (by its enabling powers)"
        e.stated -> "#{e.stated} (stated on the whole Act)"
        e.competence -> "#{e.competence} (by its legislature's competence)"
        true -> "no clause"
      end

    "#{a}: #{stated} (#{n} rows)"
  end

  # ── --read ──────────────────────────────────────────────────────────

  defp read(opts) do
    Mix.shell().info("reading the changes feeds of our LAT laws for their pointers …")
    feed = ReadPass.feed_pointers()

    laws = to_read(opts, feed)
    preview? = opts[:preview] == true

    Mix.shell().info(
      "#{length(laws)} amending laws to read#{if preview?, do: " (preview: nothing written)", else: ""}"
    )

    # several at once where the machine allows (`LawRunner.Guard`): each
    # amending law writes only its own rules and index; each in its own
    # process, its parsed document gone when it exits
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        laws,
        &read_one(&1, Map.get(feed, &1, %{laws: MapSet.new(), refs: []}), preview?),
        fn a, result ->
          :counters.add(counter, 1, 1)
          mem = div(:erlang.memory(:total), 1_048_576)

          line =
            case result do
              {diff, ids, _pairs} -> "#{ids} provisions, #{diff.after} rules"
              other -> "FAILED #{inspect(other)}"
            end

          Mix.shell().info(
            "  [#{:counters.get(counter, 1)}/#{length(laws)}] #{a}: #{line} (#{mem} MB)"
          )
        end,
        # the read pass's own measure: 4 laws at once peaked at 2.1 GB for
        # the whole run (2026-10-25), so ~0.8 GB a law, at most 5 of 6
        # cores; the largest laws first
        workers: Guard.workers(workers: opts[:workers], per_law_kb: 800_000, max: 5),
        weight: &ReadPass.weight/1
      )

    diffs = for {a, {diff, _ids, _}} <- results, into: %{}, do: {a, diff}
    changed = diffs |> Enum.sort() |> Enum.flat_map(fn {a, d} -> ReadReport.lines(a, d) end)

    Mix.shell().info("\n#{if preview?, do: "would change", else: "changed"}:")
    for line <- changed, do: Mix.shell().info("  " <> line)
    Mix.shell().info(ReadReport.summary(diffs))
    if path = opts[:diff], do: rule_diff(path, results)
  end

  # the amending laws a read pass takes: named, the regression set, every
  # one, the builds' stale ones, or those not read by this reader; `--limit` the first N
  defp to_read(opts, feed) do
    laws =
      cond do
        opts[:regression] ->
          ReadPass.regression_laws()

        opts[:amending] ->
          LawList.parse(opts[:amending])

        opts[:all] ->
          ReadPass.amending_laws(feed)

        opts[:stale] ->
          stale_amending_laws(opts[:family])

        true ->
          feed |> ReadPass.amending_laws() |> Enum.filter(&ReadPass.stale?(&1, Map.get(feed, &1)))
      end

    if opts[:limit], do: Enum.take(laws, opts[:limit]), else: laws
  end

  # the amending laws behind the builds' `:amending_reader`, store-wide or
  # the family's (`StepProcedures.AmendingStale`)
  defp stale_amending_laws(family) do
    stale = AmendingStale.laws(family)

    Mix.shell().info(
      "stale#{if family, do: " for #{family}'s builds", else: ""}: #{length(stale.not_read)} not read, " <>
        "#{length(stale.old_code)} read by other reader code or from other text, " <>
        "#{length(stale.not_for_law)} not read for a built law"
    )

    AmendingStale.all(stale)
  end

  # each changed rule by field, grouped by field set, for review
  defp rule_diff(path, results) do
    groups =
      RuleDiff.grouped(for {a, {_, _, pairs}} <- results, pairs != [], into: %{}, do: {a, pairs})

    File.write!(path, Jason.encode!(groups, pretty: true))
    Mix.shell().info("\nchanged rules by field (#{length(groups)} groups) → #{path}")
    for l <- RuleDiff.lines(groups), do: Mix.shell().info(l)
  end

  # one amending law: its reading against its stored rules, stored unless a
  # preview
  defp read_one(amending, feed_entry, preview?) do
    old = Store.for_source(amending)

    case ReadPass.read(amending, feed_entry) do
      nil ->
        {ReadReport.diff(old, old), 0, []}

      r ->
        unless preview?, do: ReadPass.write(r, old)
        {ReadReport.diff(old, r.rules), length(r.ids), RuleDiff.pairs(old, r.rules)}
    end
  end
end

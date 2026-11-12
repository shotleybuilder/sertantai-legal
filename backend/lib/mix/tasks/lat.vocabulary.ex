defmodule Mix.Tasks.Lat.Vocabulary do
  @moduledoc """
  A law read through the LAT Change Pipeline's change records, for
  debugging: each change with its claims, the value each attribute took
  and the source that won, and the label periods — beside today's stored
  label. Reads the local CLML store and feed cache only.

      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14
      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14 --provision "reg.14(1)"
      mix lat.vocabulary --golden          # the CV-01 golden set: pass / fail per provision
      mix lat.vocabulary --golden --law X  # one golden law only
      mix lat.vocabulary --golden --stored # the same, folding the stored changes
      mix lat.vocabulary --golden --stored --tiers  # with each period's tier per field
      mix lat.vocabulary --golden --extended  # with the 23 CV-S09 provisions (golden_extended.exs)

  `--golden` reads `test/fixtures/change_vocabulary/golden.exs` (the signed-off
  golden set, normalised to D1) and compares each provision's vocabulary label
  with its expected periods — the change-vocabulary scoreboard (CV-03).
  `--extended` adds `golden_extended.exs`: the 23 provisions drafted in CV-S09,
  held apart until the workflow runs again from step 1 (Jason 2026-10-30).

  The change register (CV-04): `--build` writes a law's merged changes,
  for every LAT row, to `provision_changes` (one law at a time, each in its
  own process); `--stored` folds them instead of building.

      mix lat.vocabulary --build --law UK_ukpga_1990_8
      mix lat.vocabulary --build --golden  # every golden-set law
      mix lat.vocabulary --build --laws A,B
      mix lat.vocabulary --build --family "OH&S: Occupational / Personal Safety"
      mix lat.vocabulary --build --stale   # what lat.stale lists, stage by stage (#194)
      mix lat.vocabulary --check --family "OH&S: Occupational"   # build, conflict counts, golden from the store, every step's gate (mix lat.gates) — one app start
      mix lat.vocabulary --check --family F --no-gates           # the same without the gates (a fix round; the label gate folds the family)
      mix lat.vocabulary --conflicts --law UK_ukpga_1990_8 [--all]
                                           # where the law's text and legislation.gov.uk disagree

  `--build --stale` walks the two stages in order (#194): it rebuilds the
  built laws whose changes are stale (`ChangeStaleness`), then folds again
  the switched laws whose labels are stale (`LabelRefresh.refold/1`: the
  fold's code, the changes' output digest or the fold's inputs moved) —
  read after the rebuild, so a rebuild giving the same changes stales no
  label — and refreshes those parsed or failed since. Labels whose parse is
  stale are listed for `mix lat.reparse`.

  The affecting Acts' extent clauses come from `extent_rules` (`mix
  lat.amending --extents --law X`); an Act not read there is read from its
  document, and named.

  Provisions take their extent from `legal_articles` and the law's start
  from its law-level commencement record.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope

  alias SertantaiLegal.Scraper.{ChangeVocabulary, LabelRefresh, LatStagedParser}

  alias SertantaiLegal.Scraper.ChangeVocabulary.{
    Build,
    Conflicts,
    Fold,
    Golden,
    Show,
    StaleStages,
    Store
  }

  @shortdoc "A law's changes, evidence and labels through the change vocabulary; build the change register"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          laws: :string,
          family: :string,
          check: :boolean,
          gates: :boolean,
          provision: :keep,
          golden: :boolean,
          extended: :boolean,
          workers: :integer,
          build: :boolean,
          stale: :boolean,
          stored: :boolean,
          conflicts: :boolean,
          all: :boolean,
          tiers: :boolean
        ]
      )

    cond do
      opts[:check] -> check(opts)
      opts[:build] -> build(opts)
      opts[:conflicts] -> conflicts(opts)
      opts[:golden] -> golden(opts)
      true -> show(opts)
    end
  end

  # the laws named: --golden, --family F (its LAT laws), --laws A,B, --law X
  defp laws(opts, task) do
    cond do
      opts[:golden] ->
        Golden.laws(opts)

      opts[:family] ->
        Scope.family_laws(opts[:family])

      opts[:laws] ->
        String.split(opts[:laws], ",", trim: true)

      opts[:law] ->
        [opts[:law]]

      true ->
        Mix.raise("#{task} needs --law X, --laws A,B, --family F or --golden")
    end
  end

  # ── --check ─────────────────────────────────────────────────────────

  # One run, one app start: build the laws named, the conflict report's
  # counts over them, and the golden scoreboard from the store — naming the
  # golden laws built by older code (their stored changes aren't this
  # code's: rebuild them for a true score)
  defp check(opts) do
    build(opts)

    laws = laws(opts, "--check")
    conflict_totals(laws)

    golden = Golden.laws(opts)

    stale =
      Golden.older(golden, Golden.stored_versions(golden), ChangeVocabulary.Version.current())

    if stale != [],
      do:
        Mix.shell().info(
          "\n#{length(stale)} golden laws built by older code (scored as stored): #{Enum.join(stale, ", ")}"
        )

    golden(Keyword.put(opts, :stored, true))
    gates(opts, laws)
  end

  # every step's gate re-run on the family built: a rebuild can move an
  # earlier step's (Maritime Safety, 2026-11-06). Laws named without a
  # family get the sources gate only: the stored changes name the
  # documents the labels need (CV-S01; found failing in CV-S10)
  defp gates(opts, laws) do
    cond do
      opts[:gates] == false ->
        Mix.shell().info("\ngates not re-run (--no-gates)")

      opts[:family] ->
        Mix.Task.run("lat.gates", ["--family", opts[:family]])

      true ->
        Mix.shell().info("\nsources held, for the laws built (every step's gate needs --family):")
        Mix.Task.run("lat.sources", ["--laws", Enum.join(laws, ",")])
    end
  end

  defp conflict_totals(laws) do
    counts =
      laws
      |> Enum.flat_map(fn law ->
        changes = Store.for_law(law)
        Conflicts.report(changes, pointers(changes))
      end)
      |> Conflicts.counts()

    Mix.shell().info("\nconflicts over #{length(laws)} laws:")
    for {k, n} <- counts, do: Mix.shell().info("  #{n}  #{inspect(k)}")
  end

  # what the read pass read of each amending law behind `changes` (its index)
  defp pointers(changes) do
    for l <-
          changes
          |> Enum.map(& &1.resolved.by)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq(),
        index = SertantaiLegal.Scraper.Amendment.Index.get(l),
        index != nil,
        into: %{},
        do: {l, index["pointers"] || []}
  end

  # ── --conflicts ─────────────────────────────────────────────────────

  # the conflict report over the stored changes: counts by kind, then each
  # (`--all`) or the first ten of each kind
  defp conflicts(opts) do
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = laws(opts, "--conflicts")

    for law <- laws do
      changes = Store.for_law(law)

      report = Conflicts.report(changes, pointers(changes))

      counts = Conflicts.counts(report, detail: true)

      Mix.shell().info("\n## #{law}: #{length(changes)} changes, #{length(report)} conflicts")
      for {k, n} <- counts, do: Mix.shell().info("  #{n}  #{inspect(k)}")

      # sorted: a map's atom keys iterate in atom-table order (OTP 26+)
      for {kind, items} <- report |> Enum.group_by(& &1.kind) |> Enum.sort_by(&elem(&1, 0)),
          item <- if(opts[:all], do: items, else: Enum.take(items, 10)) do
        Mix.shell().info("    #{kind} " <> inspect(Map.drop(item, [:kind]), limit: 8))
      end
    end
  end

  # ── --build ─────────────────────────────────────────────────────────

  defp build(opts) do
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    if opts[:stale], do: build_stale(opts), else: build_laws(laws(opts, "--build"), opts)
  end

  # the stages in order (#194): the changes, then the labels read afresh
  defp build_stale(opts) do
    laws = StaleStages.stale_changes()
    Mix.shell().info("changes stage: #{length(laws)} built laws stale")
    if laws != [], do: build_laws(laws, opts)

    by_action =
      Enum.group_by(
        StaleStages.stale_labels(),
        &StaleStages.label_action(elem(&1, 1)),
        &elem(&1, 0)
      )

    [refold, refresh, reparse] =
      Enum.map([:refold, :refresh, :reparse], &Map.get(by_action, &1, []))

    Mix.shell().info(
      "labels stage: #{length(refold)} switched laws to fold again, #{length(refresh)} to refresh" <>
        ", #{length(reparse)} needing a re-parse (mix lat.reparse)"
    )

    label_run(refold, &LabelRefresh.refold/1, opts)
    label_run(refresh, &LabelRefresh.run/1, opts)
  end

  defp label_run([], _f, _opts), do: :ok

  defp label_run(laws, f, opts) do
    {us, results} =
      :timer.tc(fn ->
        SertantaiLegal.Scraper.LawRunner.run(laws, f, fn _law, _result -> :ok end,
          workers: opts[:workers]
        )
      end)

    failed = for {law, r} <- results, r != :ok, do: law

    Mix.shell().info(
      "  #{length(laws)} labels in #{Float.round(us / 1_000_000, 1)} s; #{length(failed)} failed" <>
        if(failed != [], do: " (labels_failed events): #{Enum.join(failed, ", ")}", else: "")
    )
  end

  defp build_laws(laws, opts) do
    # several at once where the machine allows (`LawRunner.Guard`): each
    # law writes only its own changes, and reads no other law's (run time,
    # 2026-10-25); each in its own process, its parsed documents gone when
    # it exits
    workers = SertantaiLegal.Scraper.LawRunner.Guard.workers(workers: opts[:workers])
    {us, _} = :timer.tc(fn -> run_builds(laws, workers, change_counts()) end)

    # build_time (CV-S11): the wall time of the whole build
    Mix.shell().info(
      "built #{length(laws)} laws in #{Float.round(us / 1_000_000, 1)} s (#{workers} workers)"
    )
  end

  defp run_builds(laws, workers, weights) do
    counter = :counters.new(1, [])

    SertantaiLegal.Scraper.LawRunner.run(
      laws,
      fn law -> :timer.tc(fn -> Build.law(law) end) end,
      fn law, result ->
        :counters.add(counter, 1, 1)

        Mix.shell().info(
          "  [#{:counters.get(counter, 1)}/#{length(laws)}] #{law}: #{built_line(result)}"
        )
      end,
      workers: workers,
      # the heaviest laws first, so the longest isn't left to run alone (#191)
      weight: &Map.get(weights, &1, 0)
    )
  end

  defp built_line({us, line}) when is_binary(line), do: "#{line} (#{div(us, 1_000_000)} s)"
  defp built_line(other), do: "FAILED #{inspect(other)}"

  # each built law's stored change count, its build's weight
  defp change_counts do
    %{rows: rows} =
      SertantaiLegal.Repo.query!(
        "SELECT law_name, count(*) FROM provision_changes GROUP BY law_name",
        [],
        timeout: :infinity
      )

    Map.new(rows, fn [law, n] -> {law, n} end)
  end

  defp show(opts) do
    law = opts[:law] || Mix.raise("--law is required")
    ids = Keyword.get_values(opts, :provision)
    if ids == [], do: Mix.raise("--provision is required (one or more)")

    Mix.Task.run("app.start")

    xml = Build.clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    provisions = Show.provisions(law, ids)

    opts =
      law
      |> Build.primary(effects)
      |> Keyword.merge(rows: law |> Build.rows() |> Map.keys(), xml_ids: Build.xml_ids(law))

    changes = ChangeVocabulary.changes(law, xml, effects, provisions, opts)
    labels = Fold.labels(law, xml, provisions, changes, opts)

    for id <- ids do
      Mix.shell().info(
        "\n## #{law} #{id}  (extent #{provisions[id].extent}, start #{provisions[id].start})"
      )

      Mix.shell().info("changes reaching it:")

      for c <- Show.reaching(changes, id) do
        r = c.resolved

        Mix.shell().info(
          "  #{c.key} on #{c.target}: #{r.operation} #{r.level} by #{r.by} on #{r.date} " <>
            "territory #{inspect(r.territory)} retained #{r.retained}  sources #{inspect(r.sources)}"
        )

        for cl <- c.claims,
            do: Mix.shell().info("      #{cl.source}.#{cl.attribute} = #{inspect(cl.value)}")
      end

      Mix.shell().info("vocabulary label:")
      for p <- labels[id], do: Mix.shell().info("  " <> Golden.line(p))
      Mix.shell().info("stored label today:")
      for p <- Show.stored(law, id), do: Mix.shell().info("  " <> Golden.line(p))
    end
  end

  defp golden(opts) do
    Mix.Task.run("app.start")
    cases = Golden.cases(opts)

    # each golden law read where the machine allows several at once
    # (`LawRunner.Guard`), in order (run time, 2026-10-25)
    workers = SertantaiLegal.Scraper.LawRunner.Guard.workers(workers: opts[:workers])

    results =
      cases
      |> Enum.filter(&(opts[:law] == nil or &1.law == opts[:law]))
      |> Enum.group_by(& &1.law)
      |> Enum.sort_by(&elem(&1, 0))
      |> Task.async_stream(
        fn {law, _} = group ->
          {us, rows} = :timer.tc(fn -> Golden.law_labels(group, opts) end)
          Mix.shell().info("  #{law}: #{div(us, 1_000_000)} s")
          rows
        end,
        max_concurrency: workers,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, rows} -> rows end)

    for {c, with_tiers} <- results do
      got = Golden.untiered(with_tiers)
      mark = if Golden.pass?(c, with_tiers), do: "PASS", else: "FAIL"

      Mix.shell().info(
        "#{mark}  #{c.law} #{c.id}  — #{c.case}#{if c.undecidable, do: " (undecidable)", else: ""}"
      )

      # each period's tier per field: the law's text (P) or legislation.gov.uk (D)
      if opts[:tiers] do
        for p <- with_tiers || [],
            do:
              Mix.shell().info("      " <> Golden.line(p) <> "   " <> Golden.tier_line(p[:tiers]))
      end

      if got != c.periods do
        Mix.shell().info("    expected:")
        for p <- c.periods, do: Mix.shell().info("      " <> Golden.line(p))
        Mix.shell().info("    got:")
        for p <- got, do: Mix.shell().info("      " <> Golden.line(p))
      end
    end

    passed = Golden.passed(results)
    Mix.shell().info("\n#{passed} / #{length(results)} golden provisions pass")

    # the result for `mix lat.preflight`; a golden failure is the step's whose change moved it
    Step.new("Golden", passed == length(results), length(results) - passed,
      owner: "the change that moved it (golden is frozen)"
    )
  end
end

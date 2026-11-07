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
      mix lat.vocabulary --check --family "OH&S: Occupational"   # build, conflict counts, golden from the store, every step's gate (mix lat.gates) — one app start
      mix lat.vocabulary --check --family F --no-gates           # the same without the gates (a fix round; the label gate folds the family)
      mix lat.vocabulary --conflicts --law UK_ukpga_1990_8 [--all]
                                           # where the law's text and legislation.gov.uk disagree

  The affecting Acts' extent clauses come from `extent_rules` (`mix
  lat.amending --extents --law X`); an Act not read there is read from its
  document, and named.

  Provisions take their extent from `legal_articles` and the law's start
  from its law-level commencement record.
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope

  alias SertantaiLegal.Scraper.{ChangeVocabulary, LatRef, LatStagedParser}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Conflicts, Golden, LabelSource, Store}

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

    stale =
      for l <- Golden.laws(opts),
          v =
            Repo.query!(
              "SELECT DISTINCT code_version FROM provision_changes WHERE law_name = $1",
              [l]
            ).rows,
          v != [[ChangeVocabulary.Version.current()]],
          do: l

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

      for {kind, items} <- Enum.group_by(report, & &1.kind),
          item <- if(opts[:all], do: items, else: Enum.take(items, 10)) do
        Mix.shell().info("    #{kind} " <> inspect(Map.drop(item, [:kind]), limit: 8))
      end
    end
  end

  # ── --build ─────────────────────────────────────────────────────────

  defp build(opts) do
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = laws(opts, "--build")

    # several at once where the machine allows (`LawRunner.Guard`): each
    # law writes only its own changes, and reads no other law's (run time,
    # 2026-10-25); each in its own process, its parsed documents gone when
    # it exits
    workers = SertantaiLegal.Scraper.LawRunner.Guard.workers(workers: opts[:workers])
    counter = :counters.new(1, [])
    weights = change_counts()

    {us, _} =
      :timer.tc(fn ->
        SertantaiLegal.Scraper.LawRunner.run(
          laws,
          fn law -> :timer.tc(fn -> Build.law(law) end) end,
          fn law, result ->
            :counters.add(counter, 1, 1)

            line =
              case result do
                {us, line} when is_binary(line) -> "#{line} (#{div(us, 1_000_000)} s)"
                other -> "FAILED #{inspect(other)}"
              end

            Mix.shell().info("  [#{:counters.get(counter, 1)}/#{length(laws)}] #{law}: #{line}")
          end,
          workers: workers,
          # the heaviest laws first, so the longest isn't left to run alone (#191)
          weight: &Map.get(weights, &1, 0)
        )
      end)

    # build_time (CV-S11): the wall time of the whole build
    Mix.shell().info(
      "built #{length(laws)} laws in #{Float.round(us / 1_000_000, 1)} s (#{workers} workers)"
    )
  end

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

    provisions = provisions(law, ids)

    opts =
      law
      |> Build.primary(effects)
      |> Keyword.merge(rows: law |> Build.rows() |> Map.keys(), xml_ids: Build.xml_ids(law))

    changes = ChangeVocabulary.changes(law, xml, effects, provisions, opts)
    labels = ChangeVocabulary.labels(law, xml, effects, provisions, opts)

    for id <- ids do
      Mix.shell().info(
        "\n## #{law} #{id}  (extent #{provisions[id].extent}, start #{provisions[id].start})"
      )

      Mix.shell().info("changes reaching it:")

      for c <- changes, c.target in [id, "*"] or c.target in tl(LatRef.ancestors(id)) do
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
      for p <- stored(law, id), do: Mix.shell().info("  " <> Golden.line(p))
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

    Mix.shell().info("\n#{Golden.passed(results)} / #{length(results)} golden provisions pass")
  end

  defp provisions(law, ids) do
    # from inputs, as the build resolves it (`Build.start/1`), never the old register
    start = Build.start(law).date || Mix.raise("no law start for #{law}")

    containers = LabelSource.containers(law)

    Map.new(ids, fn id ->
      %{rows: rows} =
        Repo.query!("SELECT extent_code FROM legal_articles WHERE section_id = $1", [
          "#{law}:#{id}"
        ])

      {id,
       %{
         extent: rows |> List.first() |> List.wrap() |> List.first(),
         start: start,
         containers: Map.get(containers, id, [])
       }}
    end)
  end

  defp stored(law, id) do
    %{rows: rows} =
      Repo.query!(
        "SELECT valid_from, valid_to, status, in_force_from, changed_by, territory FROM lat_label_timeline WHERE section_id = $1 ORDER BY valid_from",
        ["#{law}:#{id}"]
      )

    for [f, t, s, i, c, ter] <- rows,
        do: %{
          valid_from: f,
          valid_to: t,
          status: s,
          in_force_from: i,
          changed_by: c,
          territory: ter
        }
  end
end

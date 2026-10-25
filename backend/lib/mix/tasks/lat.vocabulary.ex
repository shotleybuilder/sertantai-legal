defmodule Mix.Tasks.Lat.Vocabulary do
  @moduledoc """
  A law read through the change vocabulary (change-vocabulary CV-02), for
  debugging: each change with its claims, the value each attribute took
  and the source that won, and the label periods — beside today's stored
  label. Reads the local CLML store and feed cache only.

      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14
      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14 --provision "reg.14(1)"
      mix lat.vocabulary --golden          # the CV-01 golden set: pass / fail per provision
      mix lat.vocabulary --golden --law X  # one golden law only
      mix lat.vocabulary --golden --stored # the same, folding the stored changes
      mix lat.vocabulary --golden --stored --tiers  # with each period's tier per field

  `--golden` reads `test/fixtures/change_vocabulary/golden.exs` (the signed-off
  golden set, normalised to D1) and compares each provision's vocabulary label
  with its expected periods — the change-vocabulary scoreboard (CV-03).

  The change register (CV-04): `--build` writes a law's merged changes,
  for every LAT row, to `provision_changes` (one law at a time, each in its
  own process); `--stored` folds them instead of building.

      mix lat.vocabulary --build --law UK_ukpga_1990_8
      mix lat.vocabulary --build --golden  # every golden-set law
      mix lat.vocabulary --build --laws A,B
      mix lat.vocabulary --build --family "OH&S: Occupational / Personal Safety"
      mix lat.vocabulary --check --family "OH&S: Occupational"   # build, conflict counts, golden from the store — one app start
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

  alias SertantaiLegal.Scraper.{ChangeVocabulary, LatRef, LatStagedParser}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Conflicts, Ref, Store}

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
          provision: :keep,
          golden: :boolean,
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
        golden_laws()

      opts[:family] ->
        Repo.query!(
          """
          SELECT name FROM uk_lrt WHERE family LIKE '%' || $1 || '%'
            AND name IN (SELECT DISTINCT law_name FROM legal_articles) ORDER BY name
          """,
          [opts[:family]]
        ).rows
        |> List.flatten()

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
      for l <- golden_laws(),
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
  end

  defp conflict_totals(laws) do
    counts =
      laws
      |> Enum.flat_map(fn law ->
        changes = Store.for_law(law)
        Conflicts.report(changes, pointers(changes))
      end)
      |> Enum.frequencies_by(fn
        %{kind: :value, attribute: a} -> {:value, a}
        %{kind: :uncovered, missing: m} -> {:uncovered, m}
        %{kind: k} -> k
      end)
      |> Enum.sort_by(&(-elem(&1, 1)))

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

      counts =
        report
        |> Enum.frequencies_by(fn
          %{kind: :value, attribute: a, primary: {ps, _}, derived: {ds, _}} -> {:value, a, ps, ds}
          %{kind: :uncovered, missing: m} -> {:uncovered, m}
          %{kind: k} -> k
        end)
        |> Enum.sort()

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

    SertantaiLegal.Scraper.LawRunner.run(
      laws,
      fn law -> :timer.tc(fn -> build_one(law) end) end,
      fn law, result ->
        :counters.add(counter, 1, 1)

        line =
          case result do
            {us, line} when is_binary(line) -> "#{line} (#{div(us, 1_000_000)} s)"
            other -> "FAILED #{inspect(other)}"
          end

        Mix.shell().info("  [#{:counters.get(counter, 1)}/#{length(laws)}] #{law}: #{line}")
      end,
      workers: workers
    )
  end

  defp build_one(law) do
    xml = clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    all = rows(law)
    opts = law |> primary(effects) |> Keyword.merge(rows: Map.keys(all), xml_ids: xml_ids(law))
    changes = ChangeVocabulary.changes(law, xml, effects, all, opts)
    {:ok, n} = Store.write(law, changes, inputs(law, effects, opts))
    "#{n.changes} changes, #{n.claims} claims"
  end

  # every LAT row of the law, with its extent (the change's bound)
  defp rows(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, extent_code FROM legal_articles WHERE law_name = $1 AND section_id IS NOT NULL",
        [law]
      )

    for [sid, ext] <- rows,
        into: %{},
        do: {String.replace_prefix(sid, law <> ":", ""), %{extent: ext}}
  end

  # each LAT row's XML id → its ref, as the parse named it (versions share
  # their base: "section-23" → "s.23")
  defp xml_ids(law) do
    Ref.xml_ids(
      law,
      Repo.query!(
        "SELECT section_id, source_xml_id FROM legal_articles WHERE law_name = $1 AND source_xml_id IS NOT NULL",
        [law]
      ).rows
    )
  end

  # what the build read, for staleness: each input's latest reading
  defp inputs(law, effects, opts) do
    affecting = effects |> Enum.map(& &1.affecting) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    sources = Map.keys(opts[:commencement])

    latest = fn sql, params ->
      case Repo.query!(sql, params).rows do
        [[%DateTime{} = t]] -> DateTime.to_iso8601(t)
        [[%NaiveDateTime{} = t]] -> NaiveDateTime.to_iso8601(t)
        _ -> nil
      end
    end

    [_, type, year, num] = String.split(law, "_", parts: 4)
    dir = "data/cache/clml/#{type}/#{year}/#{num}/body"

    meta = fn file ->
      case File.read(Path.join(dir, file)) do
        {:ok, json} -> Jason.decode!(json)
        _ -> %{}
      end
    end

    feed =
      Path.wildcard(Path.join(dir, "data.feed.page-*.gz.meta.json"))
      |> Enum.map(&(&1 |> File.read!() |> Jason.decode!() |> Map.get("fetched_at")))
      |> Enum.max(fn -> nil end)

    %{
      clml_valid: meta.("data.xml.gz.meta.json")["dct_valid"],
      feed_fetched: feed,
      amendment_rules:
        latest.("SELECT max(read_at) FROM amendment_rules WHERE amends = $1", [law]),
      commencement_rules:
        latest.(
          "SELECT max(read_at) FROM commencement_rules WHERE commences = $1 OR source_law = ANY($2)",
          [law, sources]
        ),
      extent_rules:
        latest.("SELECT max(read_at) FROM extent_rules WHERE source_law = ANY($1)", [affecting]),
      extents_unread: opts[:extents_unread]
    }
  end

  defp show(opts) do
    law = opts[:law] || Mix.raise("--law is required")
    ids = Keyword.get_values(opts, :provision)
    if ids == [], do: Mix.raise("--provision is required (one or more)")

    Mix.Task.run("app.start")

    xml = clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    provisions = provisions(law, ids)

    opts =
      law
      |> primary(effects)
      |> Keyword.merge(rows: law |> rows() |> Map.keys(), xml_ids: xml_ids(law))

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
      for p <- labels[id], do: Mix.shell().info("  " <> line(p))
      Mix.shell().info("stored label today:")
      for p <- stored(law, id), do: Mix.shell().info("  " <> line(p))
    end
  end

  @golden "test/fixtures/change_vocabulary/golden.exs"

  defp golden_laws do
    {cases, _} = Code.eval_file(@golden)
    cases |> Enum.map(& &1.law) |> Enum.uniq()
  end

  defp golden_law({law, entries}, opts) do
    xml = clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    provisions =
      Map.new(
        entries,
        &{&1.id, %{extent: &1.extent, start: &1.start, start_dated: not &1.undecidable}}
      )

    given =
      if opts[:stored],
        do: [changes: Store.for_law(law), title: title(law)],
        else:
          law
          |> primary(effects)
          |> Keyword.merge(rows: law |> rows() |> Map.keys(), xml_ids: xml_ids(law))

    labels = ChangeVocabulary.labels(law, xml, effects, provisions, given)
    Enum.map(entries, &{&1, labels[&1.id]})
  end

  defp golden(opts) do
    Mix.Task.run("app.start")
    {cases, _} = Code.eval_file(@golden)

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
          {us, rows} = :timer.tc(fn -> golden_law(group, opts) end)
          Mix.shell().info("  #{law}: #{div(us, 1_000_000)} s")
          rows
        end,
        max_concurrency: workers,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.flat_map(fn {:ok, rows} -> rows end)

    for {c, with_tiers} <- results do
      got = Enum.map(with_tiers || [], &Map.delete(&1, :tiers))
      mark = if got == c.periods, do: "PASS", else: "FAIL"

      Mix.shell().info(
        "#{mark}  #{c.law} #{c.id}  — #{c.case}#{if c.undecidable, do: " (undecidable)", else: ""}"
      )

      # each period's tier per field: the law's text (P) or legislation.gov.uk (D)
      if opts[:tiers] do
        for p <- with_tiers || [],
            do: Mix.shell().info("      " <> line(p) <> "   " <> tier_line(p[:tiers]))
      end

      if got != c.periods do
        Mix.shell().info("    expected:")
        for p <- c.periods, do: Mix.shell().info("      " <> line(p))
        Mix.shell().info("    got:")
        for p <- got, do: Mix.shell().info("      " <> line(p))
      end
    end

    passed =
      Enum.count(results, fn {c, got} ->
        Enum.map(got || [], &Map.delete(&1, :tiers)) == c.periods
      end)

    Mix.shell().info("\n#{passed} / #{length(results)} golden provisions pass")
  end

  # the amending laws' own text: their stored rules, and each one's
  # commencement rules
  defp primary(law, effects) do
    rules = SertantaiLegal.Scraper.Amendment.Store.for_law(law)

    # each amending law's commencement rules: the rules' sources and the
    # feed's affecting laws
    # … and the laws the notes cite: a change no source dates is dated from
    # its amending law at the provision its note names (CV-07)
    cited =
      Repo.query!(
        """
        SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment' AND coalesce(citation_law, changed_by) ~ '^UK_'
        """,
        [law]
      ).rows
      |> List.flatten()

    commencement =
      (Enum.map(rules, & &1.source.law) ++ Enum.map(effects, & &1.affecting) ++ cited)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Map.new(&{&1, SertantaiLegal.Scraper.Commencement.Store.for_law(&1)})

    title = title(law)

    # each affecting law's own extent clause (Act or SI): read into `extent_rules`,
    # else from its CLML held (named: `mix lat.amending --extents`)
    acts =
      effects
      |> Enum.map(& &1.affecting)
      |> Kernel.++(Enum.map(rules, & &1.source.law))
      |> Kernel.++(cited)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.filter(&ExtentStore.reads?/1)

    stored = ExtentStore.for_laws(acts)

    # (the reading kept between runs: `Extent.ReadCache`, run time 2026-10-25)
    unread =
      for law <- acts,
          not Map.has_key?(stored, law),
          reading = SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache.law(law),
          reading != nil,
          into: %{},
          do: {law, reading.read}

    if unread != %{},
      do:
        Mix.shell().info(
          "  #{map_size(unread)} Acts' extent clauses not in extent_rules (read from CLML): mix lat.amending --extents --law #{law}"
        )

    extents = Map.merge(stored, unread)

    own = SertantaiLegal.Scraper.Commencement.Store.for_law(law)

    # the law's row structure, for its own commencement (Parts, Chapters,
    # document order: CV-S04)
    own_context =
      Repo.query!(
        "SELECT section_id, part, chapter FROM legal_articles WHERE law_name = $1 ORDER BY position",
        [law]
      ).rows
      |> Enum.map(fn [s, p, c] -> %{section_id: s, part: p, chapter: c} end)
      |> SertantaiLegal.Scraper.Commencement.OwnClause.context()

    # when it was passed (an Act's Royal Assent), for its own sunset
    passed =
      Enum.find_value(own, fn r ->
        with :act_enactment <- r.treatment, {:date, d} <- r.when, do: d, else: (_ -> nil)
      end)

    # the orders continuing it, from their CLML held (the feed names them:
    # "continued until …"), each with its territory
    continuations =
      for law_c <-
            effects
            |> Enum.filter(&(&1.type =~ ~r/\bcontinu/i))
            |> Enum.map(& &1.affecting)
            |> Enum.uniq(),
          [_, t, y, n] <- [String.split(law_c, "_", parts: 4)],
          [path | _] <- [Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")] do
        doc =
          SertantaiLegal.Scraper.AmendingLaw.Doc.new(law_c, [
            path |> File.read!() |> :zlib.gunzip()
          ])

        %{
          law: law_c,
          text:
            doc.roots
            |> Enum.map(&SertantaiLegal.Scraper.AmendingLaw.Doc.text/1)
            |> Enum.join(" "),
          territory: SertantaiLegal.Scraper.LawTerritory.territory(law_c, register_extent(law_c))
        }
      end

    [
      rules: rules,
      commencement: commencement,
      extents: extents,
      extents_unread: unread |> Map.keys() |> Enum.sort(),
      passed: passed,
      act_title: title && String.replace(title, ~r/\s*\(repealed[^)]*\)\s*$/i, ""),
      continuations: continuations,
      own_commencement: own,
      own_context: own_context,
      title: title
    ]
  end

  # the law's title: its own place (a devolved law's territory)
  defp title(law) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} -> t
      _ -> nil
    end
  end

  defp register_extent(law) do
    case SertantaiLegal.Repo.query!(
           "SELECT title_en, geo_extent FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law]
         ) do
      %{rows: [[t, g]]} -> SertantaiLegal.Scraper.LawTerritory.extent(t, g)
      _ -> nil
    end
  end

  defp tier_line(nil), do: ""

  defp tier_line(tiers) do
    tiers
    |> Enum.sort()
    |> Enum.map_join(" ", fn {f, t} ->
      "#{f}:#{case t do
        :primary -> "P"
        :derived -> "D"
        nil -> "-"
      end}"
    end)
  end

  defp line(p),
    do:
      "#{p.valid_from} → #{p.valid_to || "…"}  #{p.status}  from #{p.in_force_from}  by #{inspect(p.changed_by)}  #{p.territory}"

  defp clml(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> path |> File.read!() |> :zlib.gunzip()
      [] -> Mix.raise("no stored CLML body for #{law}")
    end
  end

  defp provisions(law, ids) do
    %{rows: start_rows} =
      Repo.query!(
        "SELECT effective_from FROM lat_change_log WHERE law_name = $1 AND collector = 'commencement' AND section_id IS NULL LIMIT 1",
        [law]
      )

    start =
      case start_rows do
        [[%Date{} = d]] -> d
        _ -> Mix.raise("no law start for #{law}")
      end

    Map.new(ids, fn id ->
      %{rows: rows} =
        Repo.query!("SELECT extent_code FROM legal_articles WHERE section_id = $1", [
          "#{law}:#{id}"
        ])

      {id, %{extent: rows |> List.first() |> List.wrap() |> List.first(), start: start}}
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

defmodule Mix.Tasks.Lat.CommencementPatterns do
  @moduledoc """
  The own commencement sentences' pattern catalogue (change vocabulary
  CV-S04): every sentence saying something comes into force, in every law
  holding LAT and every amending law held as CLML (`mix lat.commencement
  --read-amending`'s laws), classed by its form and by what the own-clause
  reader made of it (`Commencement.SentencePatterns`), each pattern with
  its count and up to three real sentences (from different laws) as
  examples. Read-only over the DB and the stored law text; writes the
  fixture directory only with `--accept` (`CommencementCatalogue.Target`). Laws are read several at once (`LawRunner.Guard`),
  each law's sentences and the examples they give alone kept in
  `CatalogueCache` (`CommencementCatalogue.LawRead`, #195), and taken in
  law order (`CommencementCatalogue.LawScan`).

      mix lat.commencement_patterns                  # a dry run: report against the expectations; generated files under data/reports/commencement-reader/dry-run/, never the fixtures
      mix lat.commencement_patterns --accept         # write the fixtures, and accept new patterns as the reader reads them now
      mix lat.commencement_patterns --laws A,B --out DIR
      mix lat.commencement_patterns --no-cache       # read every law afresh

  Files (`test/fixtures/commencement_patterns/`), as `lat.markup_patterns`:
  `patterns.json` (generated: totals, each pattern's count and examples),
  `examples.json` (generated: each example's law, row and sentence),
  `laws.json` (generated: each example law's input, once, one law a line),
  `expected.json` (reviewed: each pattern's status — `accepted`, or
  `pending: <why>` with its examples holding the correct reading — and each
  example's expected reading). `CommencementPatternsTest` reads every
  example against `expected.json`.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeCollector
  alias SertantaiLegal.Scraper.{CatalogueCache, LawRunner}
  alias SertantaiLegal.Scraper.Commencement.{ClmlRows, Leftovers, Misreads}
  alias SertantaiLegal.Scraper.CommencementCatalogue.{LawRead, LawScan, Target}

  @shortdoc "Own commencement sentences' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/commencement_patterns"
  # a dry run's generated files: never the fixtures (`Target`)
  @dry_run_dir "data/reports/commencement-reader/dry-run/commencement_patterns"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          laws: :string,
          out: :string,
          accept: :boolean,
          workers: :integer,
          cache: :boolean
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    target = Target.dirs(opts, @dir, @dry_run_dir)
    File.mkdir_p!(target.write)

    laws = laws(opts[:laws])
    scoped = scoped()

    Mix.shell().info(
      "#{length(laws)} laws (#{Enum.count(laws, &(elem(&1, 1) == :lat))} with LAT)"
    )

    # each law read where the machine allows several at once
    # (`LawRunner.Guard`), its results taken in law order (examples are
    # chosen in that order, so the catalogue is the same however many ran)
    cache = Keyword.get(opts, :cache, true)
    # (what each amending law's leftovers reach, counted in one query)
    reaches = reaches()

    {acc, sources, merge_us} =
      laws
      |> LawRunner.ordered(
        fn {law, source} ->
          {law, law_read(law, {source, law in scoped}, %{cache: cache, reaches: reaches})}
        end,
        workers: opts[:workers]
      )
      |> Stream.with_index(1)
      |> Enum.reduce({LawScan.new_acc(), [], 0}, fn {{law, {read, from}}, i},
                                                    {acc, sources, us} ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")
        {t, acc} = :timer.tc(fn -> law_result(law, read, acc) end)
        {acc, [from | sources], us + t}
      end)

    Mix.shell().info(CatalogueCache.summary(sources))
    # the serial part: the examples chosen and each law's merged and checked
    Mix.shell().info("merge: #{div(merge_us, 1_000_000)} s")
    write(target.write, acc)
    report(target.held, acc, opts[:accept])
    Mix.shell().info(Target.notice(target))
  end

  defp law_result(law, {:ok, read}, acc) do
    LawScan.select(acc, law, read, read.outcomes)
  rescue
    error -> %{acc | unclassified: [{law, Exception.message(error)} | acc.unclassified]}
  end

  defp law_result(law, {:error, why}, acc),
    do: %{acc | unclassified: [{law, why} | acc.unclassified]}

  # every law holding LAT, then the amending laws held as CLML with none
  defp laws(nil) do
    lat =
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1").rows
      |> List.flatten()

    amending =
      Repo.query!("""
      SELECT DISTINCT coalesce(a.citation_law, a.changed_by) FROM amendment_annotations a
      WHERE a.code_type = 'amendment' AND coalesce(a.citation_law, a.changed_by) ~ '^UK_'
        AND NOT EXISTS (SELECT 1 FROM legal_articles l WHERE l.law_name = coalesce(a.citation_law, a.changed_by))
      ORDER BY 1
      """).rows
      |> List.flatten()
      |> Enum.filter(&held?/1)

    Enum.map(lat, &{&1, :lat}) ++ Enum.map(amending, &{&1, :clml})
  end

  defp laws(list) do
    held =
      MapSet.new(
        Repo.query!("SELECT DISTINCT law_name FROM legal_articles").rows
        |> List.flatten()
      )

    for law <- String.split(list, ",", trim: true),
        do: {law, if(MapSet.member?(held, law), do: :lat, else: :clml)}
  end

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, t, y, n] -> File.exists?("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")
      _ -> false
    end
  end

  defp rows(law, :lat) do
    for [s, t, p, c] <-
          Repo.query!(
            "SELECT section_id, text, part, chapter FROM legal_articles WHERE law_name = $1 ORDER BY position",
            [law]
          ).rows,
        do: %{section_id: s, text: t, part: p, chapter: c}
  end

  # (an amending law's rows from their cache, keyed on its CLML's digests:
  # `ClmlRows`)
  defp rows(law, :clml) do
    {rows, _} = ClmlRows.rows(law)
    rows || []
  end

  # a law's own reading, independent of every other law (run in parallel):
  # its rows and start input gathered, its sentences read through the
  # catalogue cache (#195)
  defp law_read(law, {source, scoped?}, %{cache: cache, reaches: reaches}) do
    rows = rows(law, source)
    input = ChangeCollector.law_start_input(law, rows)

    {%{sentences: sentences, outcomes: outcomes}, from} =
      LawRead.law(law, rows, input, cache: cache)

    read = %{input: input, sentences: sentences, outcomes: outcomes}
    # (a ref with no row is a misread only where the rows are the whole law's LAT)
    skip = if source == :clml or scoped?, do: [:no_row], else: []
    {{:ok, Map.merge(read, %{reach: reach(law, source, rows, reaches), skip: skip})}, from}
  rescue
    error -> {{:error, Exception.message(error)}, :read}
  end

  # the laws whose LAT holds only the fragments in scope (#166)
  defp scoped do
    Repo.query!("SELECT name FROM legal_register WHERE lat_scope IS NOT NULL").rows
    |> List.flatten()
    |> MapSet.new()
  end

  # what a law's leftovers reach: its LAT rows, or (an amending law) the
  # changes its notes record on ours
  defp reach(_law, :lat, rows, _reaches), do: length(rows)
  defp reach(law, :clml, _rows, reaches), do: Map.get(reaches, law, 0)

  # each amending law's notes on our rows, counted once a run (a scan of
  # the notes per law before: about 2,160 sequential scans)
  defp reaches do
    Repo.query!("""
    SELECT coalesce(citation_law, changed_by), count(*) FROM amendment_annotations
    WHERE coalesce(citation_law, changed_by) IS NOT NULL GROUP BY 1
    """).rows
    |> Map.new(fn [law, n] -> {law, n} end)
  end

  # ── files ────────────────────────────────────────────────────────────

  defp write(dir, acc) do
    patterns = %{
      "totals" => %{
        "laws" => acc.laws,
        "sentences" => acc.sentences,
        "unclassified" => length(acc.unclassified),
        "patterns" => map_size(acc.patterns),
        "examples" => map_size(acc.examples),
        "too_large" => length(acc.too_large)
      },
      "patterns" =>
        Map.new(acc.patterns, fn {p, e} ->
          {p, %{"count" => e.count, "examples" => e.examples}}
        end)
    }

    File.write!(Path.join(dir, "patterns.json"), Files.encode(patterns))

    File.write!(
      Path.join(dir, "examples.json"),
      Files.encode(Map.new(acc.examples, fn {id, x} -> {id, x.json} end))
    )

    # one law a line: its rows are many and short
    File.write!(Path.join(dir, "laws.json"), lines(acc.laws_inputs))

    File.write!(
      Path.join(dir, "leftover_groups.json"),
      Files.encode(Leftovers.to_json(acc.leftovers))
    )

    File.write!(
      Path.join(dir, "misread_groups.json"),
      Files.encode(Leftovers.to_json(acc.misreads))
    )
  end

  defp lines(map) do
    body =
      map
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map_join(",\n", fn {k, v} -> "  #{Jason.encode!(k)}: #{Jason.encode!(v)}" end)

    "{\n" <> body <> "\n}\n"
  end

  # ── report, accept ───────────────────────────────────────────────────

  defp report(dir, acc, accept?) do
    path = Path.join(dir, "expected.json")

    held =
      case File.read(path) do
        {:ok, body} -> Jason.decode!(body)
        _ -> %{"patterns" => %{}, "examples" => %{}}
      end

    shell = Mix.shell()
    shell.info("\n#{acc.sentences} sentences in #{acc.laws} laws")
    shell.info("unclassified: #{length(acc.unclassified)}")
    for {law, why} <- Enum.take(acc.unclassified, 20), do: shell.info("  #{law}: #{why}")

    shell.info(
      "#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples (#{length(acc.too_large)} too large to hold)"
    )

    shell.info(
      "examples not held, reading differently alone than in their law: #{length(acc.mismatch)}"
    )

    for id <- acc.mismatch |> Enum.sort() |> Enum.take(20), do: shell.info("  #{id}")

    # the statements by outcome: the reader's reach at a glance
    shell.info("\nstatements by outcome (sentences):")

    for {class, n} <-
          acc.patterns
          |> Enum.filter(fn {k, _} -> String.starts_with?(k, "statement|") end)
          |> Enum.group_by(fn {k, _} -> k |> String.split("|") |> List.last() end, fn {_, e} ->
            e.count
          end)
          |> Enum.map(fn {c, ns} -> {c, Enum.sum(ns)} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{n}  #{class}")

    leftovers(acc.leftovers, dir)
    misreads(acc.misreads, dir)
    shell.info(Misreads.not_held_line(acc.not_held))

    new = for p <- Map.keys(acc.patterns), not Map.has_key?(held["patterns"], p), do: p
    gone = for p <- Map.keys(held["patterns"]), not Map.has_key?(acc.patterns, p), do: p

    changed =
      for {id, x} <- acc.examples,
          want = held["examples"][id],
          want != nil and want != x.outcome,
          do: id

    shell.info("\nnew patterns (no status): #{length(new)}")
    shell.info("patterns no longer seen: #{length(gone)}")
    for p <- Enum.sort(gone), do: shell.info("  #{p}")
    shell.info("examples reading differently from expected: #{length(changed)}")
    for id <- changed |> Enum.sort() |> Enum.take(40), do: shell.info("  #{id}")

    if accept? do
      examples =
        Map.new(acc.examples, fn {id, x} -> {id, Map.get(held["examples"], id, x.outcome)} end)

      statuses =
        Map.new(acc.patterns, fn {p, _} -> {p, Map.get(held["patterns"], p, "accepted")} end)

      File.write!(path, Files.encode(%{"patterns" => statuses, "examples" => examples}))
      shell.info("\naccepted: #{length(new)} new patterns written to #{path}")
    end
  end

  # the words no rule uses, by shape, widest reach first; reviewed in
  # `leftovers.json` (fix / known / check), the report under data/reports
  defp leftovers(groups, dir) do
    ranked = Leftovers.ranked(groups)
    Enum.each(Leftovers.summary(ranked, reviewed(dir)), fn line -> Mix.shell().info(line) end)

    path = "data/reports/commencement-reader/leftovers-#{Date.utc_today()}.txt"
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Enum.join(Leftovers.lines(ranked), "\n") <> "\n")
    Mix.shell().info("report: #{path}")
  end

  # the words a rule uses wrongly, by shape; reviewed in `misreads.json`
  defp misreads(groups, dir) do
    ranked = Leftovers.ranked(groups)
    reviewed = reviewed(dir, "misreads.json")
    Enum.each(Misreads.summary(ranked, reviewed), fn line -> Mix.shell().info(line) end)

    path = "data/reports/commencement-reader/misreads-#{Date.utc_today()}.txt"
    File.write!(path, Enum.join(Leftovers.lines(ranked), "\n") <> "\n")
    Mix.shell().info("report: #{path}")
  end

  defp reviewed(dir, file \\ "leftovers.json") do
    case File.read(Path.join(dir, file)) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end
end

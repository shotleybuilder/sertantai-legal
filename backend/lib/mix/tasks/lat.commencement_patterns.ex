defmodule Mix.Tasks.Lat.CommencementPatterns do
  @moduledoc """
  The own commencement sentences' pattern catalogue (change vocabulary
  CV-S04): every sentence saying something comes into force, in every law
  holding LAT and every amending law held as CLML (`mix lat.commencement
  --read-amending`'s laws), classed by its form and by what the own-clause
  reader made of it (`Commencement.SentencePatterns`), each pattern with
  its count and up to three real sentences (from different laws) as
  examples. Read-only over the DB and the stored law text; writes only the
  fixture directory. One law at a time.

      mix lat.commencement_patterns                  # regenerate; report against the expectations
      mix lat.commencement_patterns --accept         # also accept new patterns as the reader reads them now
      mix lat.commencement_patterns --laws A,B --out DIR

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
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ChangeCollector
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, SentencePatterns}

  @shortdoc "Own commencement sentences' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/commencement_patterns"
  @per_pattern 3
  # a law beyond this many rows holds no example needing every row's text
  @max_full 1000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [laws: :string, out: :string, accept: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws = laws(opts[:laws])

    Mix.shell().info(
      "#{length(laws)} laws (#{Enum.count(laws, &(elem(&1, 1) == :lat))} with LAT)"
    )

    acc =
      laws
      |> Enum.with_index(1)
      |> Enum.reduce(new_acc(), fn {{law, source}, i}, acc ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")

        try do
          law_patterns(law, source, acc)
        rescue
          error -> %{acc | unclassified: [{law, Exception.message(error)} | acc.unclassified]}
        end
      end)

    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  defp new_acc,
    do: %{
      laws: 0,
      sentences: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      laws_inputs: %{},
      mismatch: [],
      too_large: []
    }

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

  defp rows(law, :clml) do
    [_, t, y, n] = String.split(law, "_", parts: 4)
    paths = Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/**/data.xml.gz")
    doc = Doc.new(law, paths |> Enum.sort() |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip())))
    OwnClause.doc_rows(doc)
  end

  defp law_patterns(law, source, acc) do
    rows = rows(law, source)
    input = ChangeCollector.law_start_input(law, rows)
    read = OwnClause.read(law, input)

    acc = %{acc | laws: acc.laws + 1}

    for {row_id, s} <- SentencePatterns.sentences(rows), reduce: acc do
      acc ->
        f = SentencePatterns.form(s)
        o = SentencePatterns.outcome(s, read)
        key = SentencePatterns.key(f, o.class)
        id = example_id(law, row_id, s)

        entry = Map.get(acc.patterns, key, %{count: 0, examples: []})
        laws = Enum.map(entry.examples, &law_of/1)

        take? = length(entry.examples) < @per_pattern and law not in laws

        acc = %{acc | sentences: acc.sentences + 1}

        acc =
          put_in(acc.patterns[key], %{
            entry
            | count: entry.count + 1,
              examples: if(take?, do: entry.examples ++ [id], else: entry.examples)
          })

        if take?, do: example(acc, key, id, law, row_id, s, input, o), else: acc
    end
    |> merge_law(law, input)
  end

  # the law's examples share one input (`laws.json`), each checked to read
  # alone as in the law still
  defp merge_law(acc, law, input) do
    ids = for {id, x} <- acc.examples, x.json["law"] == law, x[:input], do: id

    case ids do
      [] ->
        acc

      _ ->
        merged = SentencePatterns.merge(input, Enum.map(ids, &acc.examples[&1].input))

        Enum.reduce(ids, put_in(acc.laws_inputs[law], merged), fn id, acc ->
          x = acc.examples[id]
          got = SentencePatterns.read(law, merged, x.json["sentence"])

          if %{"class" => got.class, "rules" => got.rules} == x.outcome,
            do: put_in(acc.examples[id], Map.delete(x, :input)),
            else: drop(acc, id, :mismatch)
        end)
    end
  end

  defp drop(acc, id, why) do
    acc = %{acc | examples: Map.delete(acc.examples, id)}

    patterns =
      Map.new(acc.patterns, fn {p, e} -> {p, %{e | examples: List.delete(e.examples, id)}} end)

    Map.update!(%{acc | patterns: patterns}, why, &[id | &1])
  end

  # the example at the smallest pruning that reads alone as in the law;
  # none held when even every row reads differently, nor when a large law
  # needs all its rows' text (too large to hold)
  defp example(acc, key, id, law, row_id, s, input, outcome) do
    held =
      Enum.find_value([:tight, :named, :ids, :full], fn level ->
        ex = SentencePatterns.example(row_id, input, level)
        if SentencePatterns.read(law, ex, s) == outcome, do: {level, ex}
      end)

    case held do
      {:full, _} when length(input.rows) > @max_full ->
        not_held(acc, key, id, :too_large)

      {_, ex} ->
        put_in(acc.examples[id], %{
          json: %{"law" => law, "row" => row_id, "sentence" => s},
          input: ex,
          outcome: %{"class" => outcome.class, "rules" => outcome.rules}
        })

      nil ->
        not_held(acc, key, id, :mismatch)
    end
  end

  defp not_held(acc, key, id, why) do
    acc = put_in(acc.patterns[key].examples, List.delete(acc.patterns[key].examples, id))
    Map.update!(acc, why, &[id | &1])
  end

  # a short hash of the sentence: the example's id
  defp example_id(law, row_id, s),
    do:
      law <>
        "/" <>
        (:crypto.hash(:sha256, row_id <> s) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()

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
end

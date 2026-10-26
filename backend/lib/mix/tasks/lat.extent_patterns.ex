defmodule Mix.Tasks.Lat.ExtentPatterns do
  @moduledoc """
  The extent and application sentences' pattern catalogue (change
  vocabulary CV-S05): every sentence of a top-level provision saying where
  a law (or some of it) extends or applies, in every held law of a type
  whose extent the reader reads (`Extent.Store.reads?/1`), classed by its
  form and by what the extent reader made of it
  (`AmendingLaw.Extent.Patterns`), each pattern with its count and up to
  three real sentences (from different laws) as examples. Read-only over the
  stored law text; writes only the fixture directory. One law at a time.

      mix lat.extent_patterns                  # regenerate; report against the expectations
      mix lat.extent_patterns --accept         # also accept new patterns as the reader reads them now
      mix lat.extent_patterns --laws A,B --out DIR

  Files (`test/fixtures/extent_patterns/`), as `lat.commencement_patterns`:
  `patterns.json` (generated: totals, each pattern's count and examples),
  `examples.json` (generated: each example's law, provision and sentence),
  `laws.json` (generated: each example law flattened to what its reading
  needs, `Patterns.example/1`, one law a line), `expected.json` (reviewed:
  each pattern's status — `accepted`, or `pending: <why>` with its examples
  holding the correct reading — and each example's expected class).
  `ExtentPatternsTest` reads every example against `expected.json`.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Patterns, ReadCache}
  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  @shortdoc "Extent and application sentences' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/extent_patterns"
  @per_pattern 3

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, out: :string, accept: :boolean, workers: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws = laws(opts[:laws])
    Mix.shell().info("#{length(laws)} laws")

    # several at once where the machine allows (`LawRunner.Guard`), each
    # in its own process (the parsed document goes when it exits); merged
    # in law order, so the catalogue is the same however many ran at once
    workers = Guard.workers(workers: opts[:workers])
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        laws,
        &law_result/1,
        fn _law, _result ->
          :counters.add(counter, 1, 1)
          i = :counters.get(counter, 1)
          if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")
        end,
        workers: workers
      )

    acc =
      Enum.reduce(laws, new_acc(), fn law, acc ->
        case results[law] do
          {:ok, result} -> merge(acc, law, result)
          {:error, why} -> %{acc | unclassified: [{law, why} | acc.unclassified]}
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
      laws_xml: %{},
      mismatch: []
    }

  # every held body of a type whose extent the reader reads
  defp laws(nil), do: ReadCache.held()

  defp laws(list), do: String.split(list, ",", trim: true)

  # the law's classes, and the example its reading needs (with whether it
  # reads alone as in the law)
  # (the reading kept between runs: `ReadCache`, shared with the check
  # and the re-read)
  defp law_result(law) do
    case ReadCache.law(law) do
      nil ->
        {:ok, %{classes: [], xml: nil, alone: MapSet.new()}}

      r ->
        {:ok, %{classes: r.classes, xml: r.example, alone: MapSet.new(r.alone)}}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  # an example is held only where its sentence reads alone as in the law
  defp merge(acc, law, %{classes: classes, xml: xml, alone: alone}) do
    acc = %{acc | laws: acc.laws + 1}

    acc =
      for {ref, s, class} <- classes, reduce: acc do
        acc ->
          key = Patterns.key(Patterns.form(s), class)
          id = example_id(law, ref, s)
          entry = Map.get(acc.patterns, key, %{count: 0, examples: []})
          laws = Enum.map(entry.examples, &law_of/1)
          alone? = MapSet.member?(alone, {ref, s, class})
          take? = alone? and length(entry.examples) < @per_pattern and law not in laws

          acc = %{acc | sentences: acc.sentences + 1}

          acc =
            put_in(acc.patterns[key], %{
              entry
              | count: entry.count + 1,
                examples: if(take?, do: entry.examples ++ [id], else: entry.examples)
            })

          if take?,
            do:
              put_in(acc.examples[id], %{
                json: %{"law" => law, "ref" => ref, "sentence" => s},
                class: class
              }),
            else: acc
      end

    acc =
      if Enum.any?(classes, &(not MapSet.member?(alone, &1))),
        do: %{acc | mismatch: [law | acc.mismatch]},
        else: acc

    if Enum.any?(acc.examples, fn {_, x} -> x.json["law"] == law end),
      do: put_in(acc.laws_xml[law], xml),
      else: acc
  end

  # a short hash of the provision and sentence: the example's id
  defp example_id(law, ref, s),
    do:
      law <>
        "/" <>
        (:crypto.hash(:sha256, ref <> s) |> Base.encode16(case: :lower) |> binary_part(0, 10))

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
        "not_alone" => length(acc.mismatch)
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

    File.write!(Path.join(dir, "laws.json"), lines(acc.laws_xml))
  end

  # one law a line: its XML is long
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
    shell.info("#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples")

    shell.info(
      "laws with a sentence reading differently alone (not held as an example): #{length(acc.mismatch)}"
    )

    for law <- acc.mismatch |> Enum.sort() |> Enum.take(20), do: shell.info("  #{law}")

    # the reader's reach at a glance: sentences by outcome
    shell.info("\nsentences by outcome:")

    for {class, n} <-
          acc.patterns
          |> Enum.group_by(
            fn {k, _} -> k |> String.split("|") |> List.last() |> outcome_group() end,
            fn {_, e} -> e.count end
          )
          |> Enum.map(fn {c, ns} -> {c, Enum.sum(ns)} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{n}  #{class}")

    new = for p <- Map.keys(acc.patterns), not Map.has_key?(held["patterns"], p), do: p
    gone = for p <- Map.keys(held["patterns"]), not Map.has_key?(acc.patterns, p), do: p

    changed =
      for {id, x} <- acc.examples,
          want = held["examples"][id],
          want != nil and want != x.class,
          do: id

    shell.info("\nnew patterns (no status): #{length(new)}")
    shell.info("patterns no longer seen: #{length(gone)}")
    for p <- Enum.sort(gone), do: shell.info("  #{p}")
    shell.info("examples reading differently from expected: #{length(changed)}")
    for id <- changed |> Enum.sort() |> Enum.take(40), do: shell.info("  #{id}")

    if accept? do
      examples =
        Map.new(acc.examples, fn {id, x} -> {id, Map.get(held["examples"], id, x.class)} end)

      statuses =
        Map.new(acc.patterns, fn {p, _} -> {p, Map.get(held["patterns"], p, "accepted")} end)

      File.write!(path, Files.encode(%{"patterns" => statuses, "examples" => examples}))
      shell.info("\naccepted: #{length(new)} new patterns written to #{path}")
    end
  end

  # "default:E+W" → "default"; "unread:not_read" kept whole
  defp outcome_group("unread:" <> _ = c), do: c
  defp outcome_group(c), do: c |> String.split(":") |> hd()
end

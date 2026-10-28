defmodule Mix.Tasks.Lat.AmendmentPatterns do
  @moduledoc """
  The amending provisions' pattern catalogue (change vocabulary CV-S06):
  every provision the read pass reads for a family's laws (the notes' and
  the changes feed's pointers, `Amendment.PatternSource`), classed by its
  form and by what the amendment reader made of it
  (`Amendment.Patterns`), each pattern with its count and up to three
  examples (from different amending laws). Read-only over the stored law
  text, the database and the stored feed pages; writes only the fixture
  directory. One amending law at a time.

      mix lat.amendment_patterns --family "OH&S: Occupational"
      mix lat.amendment_patterns --family F --accept   # also accept new patterns as read now
      mix lat.amendment_patterns --laws A,B --out DIR

  Files (`test/fixtures/amendment_patterns/`), as `lat.extent_patterns`:
  `patterns.json` (generated: totals, each pattern's count and examples),
  `examples.json` (generated: each example's amending law, provision,
  amended law and words), `laws.json` (generated: each example pruned to
  what its reading needs, `Patterns.Example`, one a line), `expected.json`
  (reviewed: each pattern's status — `accepted`, or `pending: <why>` with
  its examples holding the correct class — and each example's expected
  class). `AmendmentPatternsTest` reads every example against
  `expected.json`.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Locator, Text}
  alias SertantaiLegal.Scraper.Amendment.{PatternSource, Patterns, ReadLaw}
  alias SertantaiLegal.Scraper.Amendment.Patterns.Example
  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  @shortdoc "Amending provisions' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/amendment_patterns"
  @per_pattern 3

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          laws: :string,
          out: :string,
          accept: :boolean,
          workers: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws =
      cond do
        opts[:family] -> PatternSource.family_laws(opts[:family])
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        true -> Mix.raise("needs --family F or --laws A,B")
      end

    pointers = PatternSource.pointers(laws)
    amending = pointers |> Map.keys() |> Enum.sort()
    Mix.shell().info("#{length(laws)} laws, #{length(amending)} amending laws")

    workers = Guard.workers(workers: opts[:workers])
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        amending,
        &amending_result(&1, pointers[&1]),
        fn _a, _result ->
          :counters.add(counter, 1, 1)
          i = :counters.get(counter, 1)
          if rem(i, 50) == 0, do: Mix.shell().info("  #{i}/#{length(amending)}")
        end,
        workers: workers
      )

    acc =
      Enum.reduce(amending, new_acc(), fn a, acc ->
        case results[a] do
          {:ok, result} -> merge(acc, a, result)
          {:error, why} -> %{acc | unclassified: [{a, inspect(why)} | acc.unclassified]}
          other -> %{acc | unclassified: [{a, inspect(other)} | acc.unclassified]}
        end
      end)

    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  # each provision read for each law the amending law changes, classed; the
  # first of each pattern in this law with its example (where it reads the
  # same alone)
  defp amending_result(amending, by_law) do
    case ReadLaw.doc(amending) do
      nil ->
        {:ok, %{held: false, units: [], examples: %{}}}

      doc ->
        terms = DefinedTerms.of(doc)

        {units, examples} =
          for {law, refs} <- Enum.sort(by_law),
              lr = ReadLaw.law_ref(law),
              id <- for(r <- refs, id <- Locator.ids(doc, r), uniq: true, do: id),
              reduce: {[], %{}} do
            {units, examples} ->
              {key, _rules} = class = Patterns.class(doc, id, terms, lr)
              units = [{law, id, key} | units]

              if Map.has_key?(examples, key) do
                {units, examples}
              else
                example =
                  case Example.build(doc, id, terms, lr, class) do
                    {:ok, xmls} ->
                      %{
                        law: law,
                        id: id,
                        words: words(doc, id),
                        json: Example.to_json(xmls, terms, lr)
                      }

                    :error ->
                      nil
                  end

                {units, Map.put(examples, key, example)}
              end
          end

        {:ok, %{held: true, units: Enum.reverse(units), examples: examples}}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp words(doc, id) do
    case Text.of(doc, id) do
      %Text{instruction: i} -> String.slice(i, 0, 400)
      nil -> ""
    end
  end

  defp new_acc,
    do: %{
      amending: 0,
      not_held: [],
      units: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      laws_json: %{},
      not_alone: 0
    }

  defp merge(acc, a, %{held: false}),
    do: %{acc | amending: acc.amending + 1, not_held: [a | acc.not_held]}

  defp merge(acc, a, %{units: units, examples: examples}) do
    acc = %{acc | amending: acc.amending + 1, units: acc.units + length(units)}

    acc =
      Enum.reduce(units, acc, fn {_law, _id, key}, acc ->
        entry = Map.get(acc.patterns, key, %{count: 0, examples: []})
        put_in(acc.patterns[key], %{entry | count: entry.count + 1})
      end)

    Enum.reduce(examples, acc, fn
      {_key, nil}, acc ->
        %{acc | not_alone: acc.not_alone + 1}

      {key, ex}, acc ->
        entry = acc.patterns[key]

        if length(entry.examples) < @per_pattern do
          eid = "#{a}/#{ex.law}/#{ex.id}"

          acc
          |> put_in([:patterns, key], %{entry | examples: entry.examples ++ [eid]})
          |> put_in([:examples, eid], %{
            json: %{"amending" => a, "law" => ex.law, "id" => ex.id, "words" => ex.words},
            class: key
          })
          |> put_in([:laws_json, eid], ex.json)
        else
          acc
        end
    end)
  end

  # ── files ────────────────────────────────────────────────────────────

  defp write(dir, acc) do
    patterns = %{
      "totals" => %{
        "amending_laws" => acc.amending,
        "not_held" => length(acc.not_held),
        "provisions" => acc.units,
        "unclassified" => length(acc.unclassified),
        "patterns" => map_size(acc.patterns),
        "examples" => map_size(acc.examples),
        "not_alone" => acc.not_alone
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

    File.write!(Path.join(dir, "laws.json"), lines(acc.laws_json))
  end

  # one example a line: its XML is long
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

    shell.info(
      "\n#{acc.units} provisions read in #{acc.amending} amending laws (#{length(acc.not_held)} not held)"
    )

    shell.info("unclassified: #{length(acc.unclassified)}")
    for {a, why} <- Enum.take(acc.unclassified, 20), do: shell.info("  #{a}: #{why}")

    shell.info(
      "#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples; " <>
        "a pattern's first in a law not reading the same alone: #{acc.not_alone}"
    )

    shell.info("\nprovisions by outcome:")

    for {class, n} <-
          acc.patterns
          |> Enum.group_by(
            fn {k, _} -> k |> String.split("|") |> List.last() end,
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
end

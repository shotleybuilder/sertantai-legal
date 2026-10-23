defmodule Mix.Tasks.Lat.MarkupPatterns do
  @moduledoc """
  The revised text's change-markup pattern catalogue (CV-S03): every change
  in every stored law text classed by what the markup reader decides
  (`ChangeVocabulary.MarkupPatterns`), each pattern with its count and up to
  three real changes (from different laws) as XML. Read-only over the
  stored law text; writes only the fixture directory. One law at a time.

      mix lat.markup_patterns                  # regenerate; report against the expectations
      mix lat.markup_patterns --accept         # also accept new patterns as the reader reads them now
      mix lat.markup_patterns --laws A,B --out DIR

  Files (`test/fixtures/markup_patterns/`), as `lat.feed_patterns`:

  - `patterns.json` — generated: totals, and each pattern's count and examples;
  - `examples.json` — generated: each example's law, key and XML;
  - `expected.json` — reviewed: each pattern's status (`accepted`, or
    `pending: <why>`, its examples holding the correct outcome) and each
    example's expected outcome. `--accept` adds what's missing and drops
    what's no longer generated; it never changes a held expectation.

  `MarkupPatternsTest` runs every example through the reader against
  `expected.json`; a pattern with no status fails.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files
  alias SertantaiLegal.Scraper.ChangeVocabulary.{MarkupPatterns, Ref}

  @shortdoc "The change markup's pattern catalogue, as test fixtures (read-only over the store)"

  @dir "test/fixtures/markup_patterns"
  @per_pattern 3

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [laws: :string, out: :string, accept: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws = laws(opts[:laws])
    rows = rows(Enum.map(laws, &elem(&1, 0)))
    Mix.shell().info("#{length(laws)} stored law texts")

    acc =
      laws
      |> Enum.with_index(1)
      |> Enum.reduce(new_acc(), fn {{law, path}, i}, acc ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")

        try do
          law_patterns(law, path, Ref.xml_ids(law, Map.get(rows, law, [])), acc)
        rescue
          error ->
            %{acc | unclassified: [{law, Exception.message(error)} | acc.unclassified]}
        end
      end)

    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  defp new_acc,
    do: %{
      laws: 0,
      changes: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      mismatch: [],
      too_large: 0
    }

  # every stored law text: UK_{type}_{year}_{number}
  defp laws(list) do
    all =
      "data/cache/clml/*/*/*/body/data.xml.gz"
      |> Path.wildcard()
      |> Enum.map(fn path ->
        [_, _, _, type, year, number, _, _] = Path.split(path)
        {"UK_#{type}_#{year}_#{number}", path}
      end)
      |> Enum.sort()

    case list do
      nil -> all
      list -> Enum.filter(all, fn {law, _} -> law in String.split(list, ",", trim: true) end)
    end
  end

  # each law's rows: [section_id, source_xml_id]
  defp rows(laws) do
    SertantaiLegal.Repo.query!(
      "SELECT law_name, section_id, source_xml_id FROM legal_articles WHERE law_name = ANY($1)",
      [laws]
    ).rows
    |> Enum.group_by(&hd/1, &tl/1)
  end

  defp law_patterns(law, path, xml_ids, acc) do
    doc =
      path
      |> File.read!()
      |> :zlib.gunzip()
      |> SweetXml.parse(quiet: true, namespace_conformant: false)

    sets = SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.read(doc, law, xml_ids)
    by_key = Enum.group_by(sets, &elem(&1, 0))
    changes = MarkupPatterns.changes(doc)

    acc = %{acc | laws: acc.laws + 1}

    changes
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce(acc, fn {key, change}, acc ->
      own = by_key |> Map.get(key, []) |> Enum.sort_by(fn {k, t, _} -> {k, t} end)
      classify(law, doc, xml_ids, change, own, %{acc | changes: acc.changes + 1})
    end)
  end

  defp classify(law, doc, xml_ids, change, sets, acc) do
    patterns = change |> MarkupPatterns.patterns(sets) |> Enum.map(&MarkupPatterns.key/1)
    id = example_id(law, change.key)

    {acc, wanted?} =
      Enum.reduce(patterns, {acc, false}, fn p, {acc, wanted?} ->
        entry = Map.get(acc.patterns, p, %{count: 0, examples: []})
        laws = Enum.map(entry.examples, &law_of/1)

        take? =
          id in entry.examples or
            (length(entry.examples) < @per_pattern and law not in laws)

        entry = %{
          entry
          | count: entry.count + 1,
            examples:
              if(take? and id not in entry.examples,
                do: entry.examples ++ [id],
                else: entry.examples
              )
        }

        {put_in(acc.patterns[p], entry), wanted? or take?}
      end)

    if wanted? and not Map.has_key?(acc.examples, id),
      do: example(id, law, doc, xml_ids, change, sets, acc),
      else: acc
  rescue
    error -> %{acc | unclassified: [{law, Exception.message(error)} | acc.unclassified]}
  catch
    :exit, reason -> %{acc | unclassified: [{law, inspect(reason)} | acc.unclassified]}
  end

  # the example's XML, checked to read as the whole law does
  defp example(id, law, doc, xml_ids, change, sets, acc) do
    case MarkupPatterns.example(change, doc) do
      nil ->
        drop(acc, id) |> Map.update!(:too_large, &(&1 + 1))

      {xml, named} ->
        expected = sets |> MarkupPatterns.outcome() |> MarkupPatterns.rekey(change.key, named)
        # the row names the example's ids need
        xml_ids = Map.filter(xml_ids, fn {x, _} -> String.contains?(xml, ~s(id="#{x}")) end)
        read = xml |> MarkupPatterns.read(named, law, xml_ids) |> MarkupPatterns.outcome()

        # an example reading differently alone isn't held (a pruned one can)
        if read == expected,
          do:
            put_in(acc.examples[id], %{
              json: %{"law" => law, "key" => named, "xml" => xml, "xml_ids" => xml_ids},
              outcome: expected
            }),
          else: acc |> drop(id) |> Map.update!(:mismatch, &[id | &1])
    end
  end

  # an example too large to hold leaves the patterns that took it
  defp drop(acc, id) do
    patterns =
      Map.new(acc.patterns, fn {p, e} -> {p, %{e | examples: List.delete(e.examples, id)}} end)

    %{acc | patterns: patterns}
  end

  # a short hash of the key: never an effect id itself (push protection)
  defp example_id(law, key),
    do:
      law <>
        "/" <> (:crypto.hash(:sha256, key) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()

  # ── files ────────────────────────────────────────────────────────────

  defp write(dir, acc) do
    patterns = %{
      "totals" => %{
        "laws" => acc.laws,
        "changes" => acc.changes,
        "unclassified" => length(acc.unclassified),
        "patterns" => map_size(acc.patterns),
        "examples" => map_size(acc.examples),
        "too_large" => acc.too_large
      },
      "patterns" =>
        Map.new(acc.patterns, fn {p, e} ->
          {p, %{"count" => e.count, "examples" => e.examples}}
        end)
    }

    examples = Map.new(acc.examples, fn {id, x} -> {id, x.json} end)

    File.write!(Path.join(dir, "patterns.json"), Files.encode(patterns))
    File.write!(Path.join(dir, "examples.json"), Files.encode(examples))
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

    shell.info("\n#{acc.changes} changes in #{acc.laws} laws")
    shell.info("unclassified: #{length(acc.unclassified)}")
    for {law, why} <- Enum.take(acc.unclassified, 20), do: shell.info("  #{law}: #{why}")

    shell.info(
      "#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples (#{acc.too_large} too large to hold)"
    )

    acc.patterns
    |> Map.keys()
    |> Enum.frequencies_by(&(&1 |> String.split(":") |> hd()))
    |> Enum.sort()
    |> Enum.each(fn {d, n} -> shell.info("  #{d}: #{n}") end)

    shell.info(
      "examples not held, reading differently alone than in their law: #{length(acc.mismatch)}"
    )

    for id <- Enum.sort(acc.mismatch) |> Enum.take(20), do: shell.info("  #{id}")

    new = for p <- Map.keys(acc.patterns), not Map.has_key?(held["patterns"], p), do: p
    gone = for p <- Map.keys(held["patterns"]), not Map.has_key?(acc.patterns, p), do: p

    changed =
      for {id, x} <- acc.examples,
          want = held["examples"][id],
          want != nil and want != x.outcome,
          do: id

    pending = for {p, "pending" <> _} <- held["patterns"], do: p

    shell.info("\nnew patterns (no status): #{length(new)}")
    for p <- Enum.sort(new) |> Enum.take(60), do: shell.info("  #{p}")
    shell.info("patterns no longer seen: #{length(gone)}")
    for p <- Enum.sort(gone), do: shell.info("  #{p}")

    shell.info(
      "examples reading differently from expected: #{length(changed)} (pending patterns: #{length(pending)})"
    )

    for id <- Enum.sort(changed) |> Enum.take(40), do: shell.info("  #{id}")

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

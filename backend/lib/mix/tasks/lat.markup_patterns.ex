defmodule Mix.Tasks.Lat.MarkupPatterns do
  @moduledoc """
  The revised text's change-markup pattern catalogue (CV-S03): every change
  in every stored law text classed by what the markup reader decides
  (`ChangeVocabulary.MarkupPatterns`), each pattern with its count and up to
  three real changes (from different laws) as XML. Read-only over the
  stored law text; writes only the fixture directory.

      mix lat.markup_patterns                  # regenerate; report against the expectations
      mix lat.markup_patterns --accept         # also accept new patterns as the reader reads them now
      mix lat.markup_patterns --laws A,B --out DIR
      mix lat.markup_patterns --no-cache       # scan every law afresh
      mix lat.markup_patterns --workers N      # else LawRunner.Guard decides

  Each law is scanned alone, several at once, and kept in `CatalogueCache`
  (`MarkupPatterns.LawRead`, #195): a re-run scans only the laws whose
  text, rows or catalogue code moved, and prints the cache's hits.

  Files (`test/fixtures/markup_patterns/`), as `lat.feed_patterns`:

  - `patterns.json` — generated: totals, and each pattern's count and examples;
  - `examples.json` — generated: each example's law, key and XML;
  - `expected.json` — reviewed: each pattern's status (`accepted`, or
    `pending: <why>`, its examples holding the correct outcome) and each
    example's expected outcome. `--accept` adds what's missing and drops
    what's no longer generated; it never changes a held expectation.

  The last catalogue's held examples (in `patterns.json` and held in
  `expected.json`) come first for their patterns (`LawScan`).

  `MarkupPatternsTest` runs every example through the reader against
  `expected.json`; a pattern with no status fails.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files
  alias SertantaiLegal.Scraper.{CatalogueCache, LawRunner}
  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.{LawRead, LawScan}

  @shortdoc "The change markup's pattern catalogue, as test fixtures (read-only over the store)"

  @dir "test/fixtures/markup_patterns"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          laws: :string,
          out: :string,
          accept: :boolean,
          cache: :boolean,
          workers: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws = laws(opts[:laws])
    rows = rows(Enum.map(laws, &elem(&1, 0)))
    Mix.shell().info("#{length(laws)} stored law texts")
    cache = Keyword.get(opts, :cache, true)
    held = held_examples(dir)

    # each law scanned alone, several at once and cached (#195), then taken
    # in law order: the catalogue a serial run gives
    {acc, sources} =
      laws
      |> Enum.map(fn {law, path} -> {law, path, Map.get(rows, law, [])} end)
      |> LawRunner.ordered(
        fn {law, path, rows} ->
          {law, LawRead.law(law, path, rows, LawScan.held_for(held, law), cache: cache)}
        end,
        workers: opts[:workers]
      )
      |> Stream.with_index(1)
      |> Enum.reduce({LawScan.new_acc(held), []}, fn {{law, {unit, source}}, i}, {acc, sources} ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")
        {LawScan.select(acc, law, unit), [source | sources]}
      end)

    Mix.shell().info(CatalogueCache.summary(sources))
    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  # each pattern's examples in the last catalogue that hold an expectation
  defp held_examples(dir) do
    with {:ok, patterns} <- File.read(Path.join(dir, "patterns.json")),
         {:ok, expected} <- File.read(Path.join(dir, "expected.json")) do
      expected = Jason.decode!(expected)["examples"]

      for {p, %{"examples" => ids}} <- Jason.decode!(patterns)["patterns"],
          ids = Enum.filter(ids, &Map.has_key?(expected, &1)),
          ids != [],
          into: %{},
          do: {p, ids}
    else
      _ -> %{}
    end
  end

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

  # each law's rows: [section_id, source_xml_id], in document order — a
  # concurrent scan of legal_articles rotates an unordered query's rows
  # (`catalogue-row-order`: UK_eur_2004_273's examples moved)
  defp rows(laws) do
    SertantaiLegal.Repo.query!(
      "SELECT law_name, section_id, source_xml_id FROM legal_articles WHERE law_name = ANY($1) ORDER BY law_name, position",
      [laws]
    ).rows
    |> Enum.group_by(&hd/1, &tl/1)
  end

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

    pointer_shares(acc.patterns, shell)

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

  # CV-S03's pointer shares: of the legacy and the effect-id changes, how
  # many carry a cited law, and how many the amending provisions too
  defp pointer_shares(patterns, shell) do
    counts = for {"pointers: " <> v, %{count: n}} <- patterns, do: {v, n}
    shell.info("pointers (changes):")

    for kind <- ["legacy", "effect id"] do
      mine = for {v, n} <- counts, String.starts_with?(v, kind <> " |"), do: {v, n}
      total = mine |> Enum.map(&elem(&1, 1)) |> Enum.sum()

      cited =
        for {v, n} <- mine,
            not String.ends_with?(v, "no cited law"),
            reduce: 0,
            do: (acc -> acc + n)

      both =
        for {v, n} <- mine,
            String.ends_with?(v, "amending provisions"),
            reduce: 0,
            do: (acc -> acc + n)

      shell.info(
        "  #{kind}: #{total}; a cited law #{cited} (#{share(cited, total)}); " <>
          "with the amending provisions #{both} (#{share(both, total)})"
      )
    end
  end

  defp share(_n, 0), do: "n/a"
  defp share(n, total), do: :erlang.float_to_binary(100 * n / total, decimals: 1) <> "%"
end

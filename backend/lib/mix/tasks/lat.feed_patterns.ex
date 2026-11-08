defmodule Mix.Tasks.Lat.FeedPatterns do
  @moduledoc """
  The changes feed's pattern catalogue (CV-S02b): every stored feed effect
  classed by what the feed reader decides (`ChangeVocabulary.FeedPatterns`),
  each pattern with its count and up to three real effects (from different
  laws) with the context the reader needs. Read-only over the stored feeds,
  law text and LAT rows; writes only the fixture directory.

      mix lat.feed_patterns                  # regenerate; report against the expectations
      mix lat.feed_patterns --accept         # also accept new patterns as the reader reads them now
      mix lat.feed_patterns --laws A,B --out DIR
      mix lat.feed_patterns --no-cache       # scan every law afresh
      mix lat.feed_patterns --workers N      # else LawRunner.Guard decides

  Each law is scanned alone, several at once, and kept in `CatalogueCache`
  (`FeedPatterns.LawRead`, #195): a re-run scans only the laws whose feed,
  text, rows or catalogue code moved, and prints the cache's hits.

  Files (`test/fixtures/feed_patterns/`):

  - `patterns.json` — generated: totals, and each pattern's count and examples;
  - `examples.json` — generated: each example's effect (its id "E") and context;
  - `expected.json` — reviewed: each pattern's status (`accepted`, or
    `pending: <why>` for a known limit, its examples holding the correct
    outcome) and each example's expected outcome. `--accept` adds what's
    missing from the reader's current output and drops what's no longer
    generated; it never changes a held expectation.

  `FeedPatternsTest` runs every example through the reader against
  `expected.json`; a pattern with no status fails.
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{CatalogueCache, LawRunner}
  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.{LawRead, LawScan}

  @shortdoc "The feed's pattern catalogue, as test fixtures (read-only over the store)"

  @dir "test/fixtures/feed_patterns"

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
    rows = rows(laws)
    Mix.shell().info("#{length(laws)} laws with stored feeds")

    # each law scanned alone, several at once and cached (#195), then taken
    # in law order: the catalogue a serial run gives
    {acc, sources} =
      laws
      |> Enum.map(&{&1, Map.get(rows, &1, [])})
      |> LawRunner.ordered(
        fn {law, rows} ->
          {law, LawRead.law(law, rows, cache: Keyword.get(opts, :cache, true))}
        end,
        workers: opts[:workers]
      )
      |> Stream.with_index(1)
      |> Enum.reduce({LawScan.new_acc(), []}, fn {{law, {unit, source}}, i}, {acc, sources} ->
        if rem(i, 100) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")
        {LawScan.select(acc, law, unit), [source | sources]}
      end)

    Mix.shell().info(CatalogueCache.summary(sources))
    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  # every law the store holds a feed for: UK_{type}_{year}_{number}
  defp laws(nil) do
    "data/cache/clml/changes/affected/*/*/*/data.feed.page-1.gz"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      [_, _, _, _, _, type, year, number, _] = Path.split(path)
      "UK_#{type}_#{year}_#{number}"
    end)
    |> Enum.sort()
  end

  defp laws(list), do: String.split(list, ",", trim: true)

  # each law's rows: [section_id, source_xml_id]
  defp rows(laws) do
    Repo.query!(
      "SELECT law_name, section_id, source_xml_id FROM legal_articles WHERE law_name = ANY($1)",
      [laws]
    ).rows
    |> Enum.group_by(&hd/1, &tl/1)
  end

  # ── files ────────────────────────────────────────────────────────────

  defp write(dir, acc) do
    patterns = %{
      "totals" => %{
        "effects" => acc.effects,
        "excluded" => acc.excluded,
        "unclassified" => length(acc.unclassified),
        "patterns" => map_size(acc.patterns),
        "examples" => map_size(acc.examples)
      },
      "patterns" =>
        Map.new(acc.patterns, fn {p, e} ->
          {p, %{"count" => e.count, "examples" => e.examples}}
        end)
    }

    examples = Map.new(acc.examples, fn {id, x} -> {id, x.json} end)

    File.write!(Path.join(dir, "patterns.json"), encode(patterns))
    File.write!(Path.join(dir, "examples.json"), encode(examples))
  end

  @doc false
  # JSON with keys sorted, for stable diffs
  def encode(term), do: term |> ordered() |> Jason.encode!(pretty: true) |> Kernel.<>("\n")

  defp ordered(map) when is_map(map) and not is_struct(map),
    do:
      map
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {k, v} -> {k, ordered(v)} end)
      |> Jason.OrderedObject.new()

  defp ordered(list) when is_list(list), do: Enum.map(list, &ordered/1)
  defp ordered(v), do: v

  # ── report, accept ───────────────────────────────────────────────────

  defp report(dir, acc, accept?) do
    path = Path.join(dir, "expected.json")

    held =
      case File.read(path) do
        {:ok, body} -> Jason.decode!(body)
        _ -> %{"patterns" => %{}, "examples" => %{}}
      end

    shell = Mix.shell()

    shell.info("\n#{acc.effects} effects; excluded #{inspect(acc.excluded)}")
    shell.info("unclassified: #{length(acc.unclassified)}")
    for {law, why} <- Enum.take(acc.unclassified, 20), do: shell.info("  #{law}: #{why}")

    shell.info("#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples")

    acc.patterns
    |> Map.keys()
    |> Enum.frequencies_by(&(&1 |> String.split(":") |> hd()))
    |> Enum.sort()
    |> Enum.each(fn {d, n} -> shell.info("  #{d}: #{n}") end)

    shell.info("examples needing their law's full context: #{length(acc.mismatch)}")

    new = for p <- Map.keys(acc.patterns), not Map.has_key?(held["patterns"], p), do: p
    gone = for p <- Map.keys(held["patterns"]), not Map.has_key?(acc.patterns, p), do: p

    changed =
      for {id, x} <- acc.examples,
          want = held["examples"][id],
          want != nil and want != x.outcome,
          do: id

    pending = for {p, "pending" <> _} <- held["patterns"], do: p

    shell.info("\nnew patterns (no status): #{length(new)}")
    for p <- Enum.sort(new) |> Enum.take(40), do: shell.info("  #{p}")
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

      File.write!(path, encode(%{"patterns" => statuses, "examples" => examples}))
      shell.info("\naccepted: #{length(new)} new patterns written to #{path}")
    end
  end
end

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
  alias SertantaiLegal.Scraper.ChangeVocabulary.{FeedPatterns, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "The feed's pattern catalogue, as test fixtures (read-only over the store)"

  @dir "test/fixtures/feed_patterns"
  @per_pattern 3
  @eu ~w(eur eudr eudn)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [laws: :string, out: :string, accept: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    laws = laws(opts[:laws])
    rows = rows(laws)
    Mix.shell().info("#{length(laws)} laws with stored feeds")

    acc =
      laws
      |> Enum.with_index(1)
      |> Enum.reduce(new_acc(), fn {law, i}, acc ->
        if rem(i, 100) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")

        try do
          law_patterns(law, Map.get(rows, law, []), acc)
        rescue
          error ->
            %{
              acc
              | unclassified: [
                  {law, Exception.format(:error, error, __STACKTRACE__)} | acc.unclassified
                ]
            }
        end
      end)

    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  defp new_acc,
    do: %{effects: 0, excluded: %{}, unclassified: [], patterns: %{}, examples: %{}, mismatch: []}

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

  defp law_patterns(law, row_ids, acc) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    {:ok, effects} = ChangesFeed.fetch(type, year, number, store: :only)

    eu? = type in @eu

    refs =
      Enum.map(row_ids, fn [sid, _] ->
        sid |> String.replace_prefix(law <> ":", "") |> Ref.canonical()
      end)

    full = %{
      law: law,
      xml_ids: Ref.xml_ids(law, row_ids),
      rows: if(eu?, do: refs, else: []),
      order:
        if(Enum.any?(effects, &(&1.affected_ranges != [])),
          do: order(type, year, number),
          else: []
        )
    }

    Enum.reduce(effects, acc, fn e, acc ->
      acc = %{acc | effects: acc.effects + 1}

      case FeedPatterns.excluded(e) do
        nil -> classify(e, full, acc)
        why -> %{acc | excluded: Map.update(acc.excluded, why, 1, &(&1 + 1))}
      end
    end)
  end

  defp order(type, year, number) do
    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/body/data.xml.gz") do
      [path | _] -> path |> File.read!() |> :zlib.gunzip() |> Markup.order()
      [] -> []
    end
  end

  defp classify(e, full, acc) do
    ctx = if e.affected_ranges == [], do: %{full | order: []}, else: full
    sets = FeedPatterns.read(e, ctx)
    patterns = Enum.map(FeedPatterns.patterns(e, sets, full), &FeedPatterns.key/1)
    id = example_id(full.law, e.effect_id)

    {acc, wanted?} =
      Enum.reduce(patterns, {acc, false}, fn p, {acc, wanted?} ->
        entry = Map.get(acc.patterns, p, %{count: 0, examples: []})
        laws = Enum.map(entry.examples, &law_of/1)

        take? =
          id in entry.examples or
            (length(entry.examples) < @per_pattern and full.law not in laws)

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
      do: example(id, e, ctx, sets, acc),
      else: acc
  rescue
    error ->
      %{acc | unclassified: [{full.law, Exception.message(error)} | acc.unclassified]}
  end

  # the example with only the context its effect needs, checked to read the same
  defp example(id, e, full, sets, acc) do
    ctx = minimal(e, full)
    e = %{e | effect_id: FeedPatterns.id()}
    expected = sets |> FeedPatterns.outcome() |> rekey(sets)

    {ctx, acc} =
      if FeedPatterns.outcome(FeedPatterns.read(e, ctx)) == expected,
        do: {ctx, acc},
        else: {full, %{acc | mismatch: [id | acc.mismatch]}}

    put_in(acc.examples[id], %{json: FeedPatterns.encode(e, ctx), outcome: expected})
  end

  # the reader's keys name the effect "E", as the example does
  defp rekey(outcome, [{key, _, _} | _]) do
    real = key |> String.split("@") |> hd()

    Enum.map(outcome, fn o ->
      %{o | "key" => String.replace_prefix(o["key"], real, FeedPatterns.id())}
    end)
  end

  defp rekey(outcome, []), do: outcome

  defp minimal(e, full) do
    order = span(full.order, e.affected_ranges)
    ids = MapSet.new(List.wrap(e.affected_refs) ++ order)
    xml_ids = Map.filter(full.xml_ids, fn {x, _} -> MapSet.member?(ids, x) end)

    articles =
      for r <- List.wrap(e.affected_refs),
          t = Map.get(full.xml_ids, r) || Ref.from_clml(r, full.law),
          t != nil,
          do: t

    rows =
      Enum.filter(full.rows, fn r ->
        Enum.any?(articles, &(r == &1 or String.starts_with?(r, &1 <> "(")))
      end)

    %{full | order: order, xml_ids: xml_ids, rows: rows}
  end

  # the stretch of document order from a range's first end to its last
  defp span(_order, []), do: []

  defp span(order, ranges) do
    indexed = Enum.with_index(order)
    ends = MapSet.new(Enum.flat_map(ranges, fn {a, b} -> [a, b] end))
    at = for {id, i} <- indexed, MapSet.member?(ends, id), do: i

    case at do
      [] -> []
      at -> Enum.slice(order, Enum.min(at)..Enum.max(at))
    end
  end

  # a short hash of the effect id: never the id itself (push protection)
  defp example_id(law, effect_id),
    do:
      law <>
        "/" <>
        (:crypto.hash(:sha256, effect_id) |> Base.encode16(case: :lower) |> binary_part(0, 10))

  defp law_of(id), do: id |> String.split("/") |> hd()

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

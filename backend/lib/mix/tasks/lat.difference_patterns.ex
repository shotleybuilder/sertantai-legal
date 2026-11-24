defmodule Mix.Tasks.Lat.DifferencePatterns do
  @moduledoc """
  The feed differences' one-law wordings looked for everywhere (RULES
  `feed-differences-are-patterns-by-feed-coverage`): each pattern of
  `Commencement.Review.DifferencePatterns` run over every law's own rows
  (laws with LAT) and every commencement order held, and each hit counted
  by whether the feed holds that commencement:

  - a law's own wording: the law's feed holds a coming-into-force record
    (`FeedCoverage.of/1`, Decision 1 (a));
  - an order's: the commenced Act's feed holds a record by that order
    (`FeedCoverage.by?/2`);
  - one order per territory: by each of its orders.

  Prints each pattern's hits and laws by coverage, and its verdict: held
  where the feed is silent, the Reader's to fix; else a known limit, the
  feed used. Read-only: the DB, the CLML store and the stored feeds. Writes
  the report (`hits.json`, `summary.txt`) to `--out` (default
  `data/reports/commencement-reader/feed-difference-patterns/`).

      mix lat.difference_patterns [--out DIR]
      mix lat.difference_patterns --rejudge           # a dry run: each judged entry of `feed_differences.json` restatused by its pattern's verdict, the whole file written beside the report (`feed_differences.proposed.json`), never the fixture
      mix lat.difference_patterns --rejudge --write   # write the fixture, on Jason's go
  """
  use Mix.Task

  alias Mix.Tasks.Lat.OrderPatterns, as: OrderCatalogue
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.{
    FeedCoverage,
    OrderPatterns,
    Review.DifferencePatterns
  }

  alias SertantaiLegal.Scraper.LegislationGovUk.{ClmlStore, FeedCache}

  @shortdoc "The feed differences' wordings looked for in every law and order, by feed coverage (read-only)"
  @out "data/reports/commencement-reader/feed-difference-patterns"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [out: :string, rejudge: :boolean, write: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    lat = lat_laws()
    feeds = :ets.new(:feeds, [:set, :public])
    covered = fn law -> law |> effects(feeds) |> FeedCoverage.of() |> Map.fetch!(:covered) end

    own = own_hits(lat, covered)
    Mix.shell().info("own rows: #{length(own)} hits")
    orders = OrderCatalogue.orders(nil)
    Mix.shell().info("#{length(orders)} orders held")
    order = order_hits(orders, lat, feeds)
    territory = territory_hits(orders, lat, feeds)

    hits = own ++ order ++ territory
    out = opts[:out] || @out
    File.mkdir_p!(out)
    File.write!(Path.join(out, "hits.json"), Jason.encode_to_iodata!(hits, pretty: true))
    lines = summary(hits)
    File.write!(Path.join(out, "summary.txt"), Enum.join(lines, "\n") <> "\n")
    Enum.each(lines, &Mix.shell().info(&1))
    if opts[:rejudge], do: rejudge(hits, out, opts[:write])
  end

  # ── the re-judging (dry run, or written on Jason's go) ──────────────

  @reviewed "test/fixtures/commencement_check/feed_differences.json"

  defp rejudge(hits, out, write?) do
    reviewed = @reviewed |> File.read!() |> Jason.decode!()

    changed =
      for name <- DifferencePatterns.names(),
          {verdict, counts} <- [verdict_of(name, hits)],
          key <- DifferencePatterns.entries(name),
          entry = Map.fetch!(reviewed, key),
          do:
            {key,
             %{
               entry
               | "status" => DifferencePatterns.status(name, verdict, counts, entry["status"])
             }}

    new = Map.merge(reviewed, Map.new(changed))
    body = sorted(new)
    path = if write?, do: @reviewed, else: Path.join(out, "feed_differences.proposed.json")
    File.write!(path, body <> "\n")
    Enum.each(changed, fn {key, e} -> Mix.shell().info("\n#{key}\n  #{e["status"]}") end)
    Mix.shell().info("\n#{length(changed)} entries restatused; written: #{path}")
  end

  defp verdict_of(name, hits) do
    laws = hits |> Enum.filter(&(&1.pattern == name)) |> Enum.uniq_by(& &1.law)
    counts = %{covered: Enum.count(laws, & &1.covered), none: Enum.count(laws, &(not &1.covered))}
    {DifferencePatterns.verdict(name, counts), counts}
  end

  # every key sorted, every entry's fields sorted, as the fixture is held
  defp sorted(reviewed) do
    reviewed
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> {k, Jason.OrderedObject.new(Enum.sort(v))} end)
    |> Jason.OrderedObject.new()
    |> Jason.encode!(pretty: true)
  end

  defp lat_laws,
    do:
      Repo.query!("SELECT DISTINCT law_name FROM legal_articles").rows
      |> List.flatten()
      |> MapSet.new()

  # a law's stored feed effects, read once
  defp effects(law, feeds) do
    case :ets.lookup(feeds, law) do
      [{^law, es}] ->
        es

      [] ->
        [_, type, year, number] = String.split(law, "_", parts: 4)
        es = with {:ok, es} <- FeedCache.effects(type, year, number), do: es
        es = if is_list(es), do: es, else: []
        :ets.insert(feeds, {law, es})
        es
    end
  end

  # ── own rows ─────────────────────────────────────────────────────────

  # every row stating a commencement, and every omitted row (dots), of
  # each law with LAT
  defp own_hits(lat, covered) do
    Repo.query!("""
    SELECT law_name, section_id, text FROM legal_articles
    WHERE text ~* 'into\\s+(force|operation)' OR text ~ '^[\\s.…]*(\\.\\s*){3,}[\\s.…]*$'
    """).rows
    |> Enum.group_by(&hd/1, fn [law, id, text] -> %{id: bare(id, law), text: text} end)
    |> Enum.filter(fn {law, _} -> MapSet.member?(lat, law) end)
    |> Enum.sort()
    |> Enum.flat_map(fn {law, rows} ->
      for {name, ref} <- DifferencePatterns.own(rows),
          do: hit(name, law, ref, law, covered.(law))
    end)
  end

  defp bare(id, law), do: String.replace_prefix(id, law <> ":", "")

  # ── orders ───────────────────────────────────────────────────────────

  defp order_hits(orders, lat, feeds) do
    orders
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {{order, acts}, i} ->
      if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(orders)}")
      acts = Enum.filter(acts, &MapSet.member?(lat, &1))
      if acts == [], do: [], else: order_units_hits(order, acts, feeds)
    end)
  end

  defp order_units_hits(order, acts, feeds) do
    units = units(Doc.new(order, ClmlStore.law_docs(order)))

    for {name, ref} <- DifferencePatterns.order(units),
        act <- acts,
        do: hit(name, act, ref, order, FeedCoverage.by?(effects(act, feeds), order))
  rescue
    error ->
      [%{pattern: "error", law: order, ref: Exception.message(error), by: order, covered: nil}]
  end

  # each article's whole text, and each Schedule table row
  defp units(doc) do
    articles =
      for id <- doc.ids,
          id =~ ~r/^(?:article|regulation)-\d+[A-Z]*$/,
          el = Doc.element(doc, id),
          el != nil,
          do: %{kind: "article", id: id, text: Doc.text(el)}

    articles ++ Enum.filter(OrderPatterns.units(doc), &(&1.kind == "table"))
  end

  defp territory_hits(orders, lat, feeds) do
    titles = titles(Enum.map(orders, &elem(&1, 0)))

    orders
    |> Enum.flat_map(fn {order, acts} ->
      for a <- acts, MapSet.member?(lat, a), do: {a, order}
    end)
    |> Enum.group_by(&elem(&1, 0), fn {_a, o} -> {o, titles[o]} end)
    |> DifferencePatterns.territory_orders()
    |> Enum.map(fn {name, act, os} ->
      hit(
        name,
        act,
        Enum.join(os, ","),
        act,
        Enum.all?(os, &FeedCoverage.by?(effects(act, feeds), &1))
      )
    end)
  end

  defp titles(laws),
    do:
      Repo.query!("SELECT name, title_en FROM uk_lrt WHERE name = ANY($1)", [laws]).rows
      |> Map.new(&List.to_tuple/1)

  defp hit(name, law, ref, by, covered),
    do: %{pattern: name, law: law, ref: ref, by: by, covered: covered}

  # ── the summary ──────────────────────────────────────────────────────

  defp summary(hits) do
    by = Enum.group_by(hits, & &1.pattern)

    lines =
      for name <- DifferencePatterns.names() do
        hs = Map.get(by, name, [])
        laws = hs |> Enum.uniq_by(& &1.law)

        counts = %{
          covered: Enum.count(laws, & &1.covered),
          none: Enum.count(laws, &(not &1.covered))
        }

        uncovered = laws |> Enum.reject(& &1.covered) |> Enum.map(& &1.law) |> Enum.take(8)

        "#{name}: #{length(hs)} hits in #{length(laws)} laws; feed holds #{counts.covered}, silent #{counts.none} " <>
          "→ #{DifferencePatterns.verdict(name, counts)}" <>
          if(uncovered == [], do: "", else: "\n    silent: #{Enum.join(uncovered, ", ")}")
      end

    errors = Map.get(by, "error", [])

    ["feed differences' wordings by feed coverage (law counts):" | lines] ++
      ["orders unread: #{length(errors)}"]
  end
end

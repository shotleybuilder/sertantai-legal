defmodule Mix.Tasks.Lat.OrderPatterns do
  @moduledoc """
  Commencement orders' pattern catalogue (change vocabulary CV-S04): every
  statement of every commencement order held — an article bringing
  provisions into force, a row of its Schedule table — classed by its form
  and by what the order reader made of it (`Commencement.OrderPatterns`),
  each pattern with its count and up to three real statements (from
  different orders) as examples. The orders: those found for an Act (`mix
  lat.commencement --read-orders`' cached lists) and those any stored rule
  was read from. Read-only over the DB and the stored law text; writes the
  fixture directory only with `--accept` (`CommencementCatalogue.Target`). One order at a time.

      mix lat.order_patterns                  # a dry run: report against the expectations; generated files under data/reports/commencement-reader/dry-run/, never the fixtures
      mix lat.order_patterns --accept         # write the fixtures, and accept new patterns as the reader reads them now
      mix lat.order_patterns --orders A,B --out DIR

  Files (`test/fixtures/order_patterns/`), as `lat.commencement_patterns`:
  `patterns.json`, `examples.json` (each example's order, Act, unit and XML)
  and `expected.json`. `OrderPatternsTest` reads every example against
  `expected.json`.
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.{
    Leftovers,
    ReachGroups,
    Misreads,
    Order,
    Orders
  }

  alias SertantaiLegal.Scraper.{CatalogueRun, LawRunner}
  alias SertantaiLegal.Scraper.CatalogueRun.Log
  alias SertantaiLegal.Scraper.LawRunner.Guard
  alias SertantaiLegal.Scraper.OrderCatalogue.LawRead
  alias SertantaiLegal.Scraper.CatalogueTarget, as: Target

  @shortdoc "Commencement orders' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/order_patterns"
  # a dry run's generated files: never the fixtures (`Target`)
  @dry_run_dir "data/reports/commencement-reader/dry-run/order_patterns"
  @per_pattern 3

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          orders: :string,
          out: :string,
          accept: :boolean,
          cache: :boolean,
          workers: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    target = Target.dirs(opts, @dir, @dry_run_dir)
    File.mkdir_p!(target.write)

    orders = orders(opts[:orders])
    Mix.shell().info("#{length(orders)} orders held, with the Act each commences")
    workers = Guard.workers(workers: opts[:workers])

    # each order read alone, several at once and cached (`OrderCatalogue.LawRead`),
    # then taken in order: the catalogue a serial run gives; the run recorded
    {_, run} =
      Log.record(
        [catalogue: "order_patterns", scope: CatalogueRun.scope(opts), workers: workers],
        fn ->
          catalogue(%{orders: orders, opts: opts, workers: workers, target: target})
        end
      )

    Mix.shell().info(Target.notice(target))
    Mix.shell().info(CatalogueRun.line(run))
  end

  # the catalogue's work, recorded by `CatalogueRun.Log.record/2`
  defp catalogue(%{orders: orders, opts: opts, workers: workers, target: target}) do
    cache = Keyword.get(opts, :cache, true)
    acts = acts(orders |> Enum.flat_map(&elem(&1, 1)) |> Enum.uniq())

    {acc, sources, serial_us} =
      orders
      |> LawRunner.ordered(
        fn {order, listed} -> {order, read(order, Enum.map(listed, &acts[&1]), cache)} end,
        workers: workers
      )
      |> Stream.with_index(1)
      |> Enum.reduce({new_acc(), [], 0}, fn {{order, {read, source}}, i}, {acc, sources, us} ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(orders)}")
        {t, acc} = :timer.tc(fn -> take(acc, order, read) end)
        {acc, [source | sources], us + t}
      end)

    write(target.write, acc)
    report(target.held, acc, opts[:accept])
    {:ok, %{"order" => sources}, serial_us}
  end

  # an order's reading, or why it raised (never cached)
  defp read(order, acts, cache) do
    {read, source} = LawRead.order(order, acts, cache: cache)
    {{:ok, read}, source}
  rescue
    error -> {{:error, Exception.message(error)}, :read}
  end

  defp take(acc, order, {:error, why}),
    do: %{acc | unclassified: [{order, why} | acc.unclassified]}

  defp take(acc, order, {:ok, read}), do: order_patterns(order, read, acc)

  defp new_acc,
    do: %{
      orders: 0,
      units: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      mismatch: [],
      too_large: [],
      leftovers: %{},
      misreads: %{},
      not_held: 0
    }

  # {order, [act]}: each held order once, with the Acts its lists or rules
  # name (the first listed first: the Act it commences is chosen in its
  # read, `OrderCatalogue.LawRead`)
  defp orders(only) do
    listed =
      for path <- Path.wildcard("data/cache/commencement-orders/*.json"),
          act = Path.basename(path, ".json"),
          order <- path |> File.read!() |> Jason.decode!(),
          do: {order, act}

    stored =
      Repo.query!("""
      SELECT DISTINCT source_law, commences FROM commencement_rules
      WHERE treatment IN ('order_date', 'order_schedule') AND source_law <> commences
      """).rows
      |> Enum.map(&List.to_tuple/1)

    (listed ++ stored)
    |> Enum.uniq()
    |> Enum.filter(fn {order, act} -> order != act and held?(order) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.to_list()
    |> then(fn os ->
      case only do
        nil -> os
        list -> Enum.filter(os, &(elem(&1, 0) in String.split(list, ",", trim: true)))
      end
    end)
    |> Enum.sort()
  end

  # each Act as an order's read takes it: named as `mix lat.commencement`
  # names it (the register's title, else the Act's own CLML title), with
  # what its leftovers reach (its LAT rows, else the changes its notes
  # record on ours) and its rows' bare ids (nil where it holds none or only
  # the fragments in scope, #166) — four queries for every Act
  defp acts(laws) do
    titles = by_law("SELECT name, title_en FROM uk_lrt WHERE name = ANY($1)", laws)

    rows =
      by_law(
        "SELECT law_name, count(*) FROM legal_articles WHERE law_name = ANY($1) GROUP BY 1",
        laws
      )

    notes =
      by_law(
        """
        SELECT coalesce(citation_law, changed_by), count(*) FROM amendment_annotations
        WHERE coalesce(citation_law, changed_by) = ANY($1) GROUP BY 1
        """,
        laws
      )

    ids = row_ids(laws)

    Map.new(laws, fn law ->
      n = Map.get(rows, law, 0)

      {law,
       %{
         act: act(law, Map.get(titles, law)),
         reach: if(n > 0, do: n, else: Map.get(notes, law, 0)),
         ids: Map.get(ids, law)
       }}
    end)
  end

  defp by_law(sql, laws),
    do: Repo.query!(sql, [laws]).rows |> Map.new(fn [law, v] -> {law, v} end)

  defp row_ids(laws) do
    Repo.query!(
      """
      SELECT law_name, section_id FROM legal_articles a WHERE law_name = ANY($1)
        AND NOT EXISTS (SELECT 1 FROM legal_register r WHERE r.name = a.law_name AND r.lat_scope IS NOT NULL)
      """,
      [laws]
    ).rows
    |> Enum.group_by(&hd/1, &List.last/1)
    |> Map.new(fn {law, sids} -> {law, Misreads.row_ids(sids)} end)
  end

  defp act(law, title) do
    [_, _, year, _] = String.split(law, "_", parts: 4)

    title =
      cond do
        is_binary(title) -> Orders.act_title(title, year)
        held?(law) -> Order.title(Doc.new(law, ClmlStore.law_docs(law)))
        true -> nil
      end

    %{law: law, title: title, year: year}
  end

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, t, y, n] -> File.exists?("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")
      _ -> false
    end
  end

  # an order's statements taken into the catalogue in order: its patterns,
  # leftovers and misreads; each pattern's examples (up to three, from
  # different orders) looked up from the order's own (`LawRead`)
  defp order_patterns(order, %{reach: reach, units: units, examples: examples}, acc) do
    acc = %{acc | orders: acc.orders + 1}

    for %{id: id, unit: unit, key: key, leftovers: left, misreads: wrong} <- units,
        reduce: acc do
      acc ->
        acc = %{
          acc
          | misreads: Misreads.add(acc.misreads, key, order, unit.id, wrong, reach),
            not_held: acc.not_held + Misreads.not_held(wrong),
            leftovers:
              ReachGroups.add(
                acc.leftovers,
                Leftovers.shape(key, left),
                order,
                unit.id,
                left,
                reach
              )
        }

        entry = Map.get(acc.patterns, key, %{count: 0, examples: []})

        take? =
          length(entry.examples) < @per_pattern and
            order not in Enum.map(entry.examples, &law_of/1)

        acc =
          put_in(acc.patterns[key], %{
            entry
            | count: entry.count + 1,
              examples: if(take?, do: entry.examples ++ [id], else: entry.examples)
          })

        acc = %{acc | units: acc.units + 1}
        if take?, do: example(acc, key, id, Map.fetch!(examples, id)), else: acc
    end
  end

  defp example(acc, _key, id, {:held, x}), do: put_in(acc.examples[id], x)
  defp example(acc, key, id, why), do: not_held(acc, key, id, why)

  defp not_held(acc, key, id, why) do
    acc = put_in(acc.patterns[key].examples, List.delete(acc.patterns[key].examples, id))
    Map.update!(acc, why, &[id | &1])
  end

  defp law_of(id), do: id |> String.split("/") |> hd()

  # ── files ────────────────────────────────────────────────────────────

  defp write(dir, acc) do
    patterns = %{
      "totals" => %{
        "orders" => acc.orders,
        "units" => acc.units,
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

    File.write!(
      Path.join(dir, "leftover_groups.json"),
      Files.encode(ReachGroups.to_json(acc.leftovers))
    )

    File.write!(
      Path.join(dir, "misread_groups.json"),
      Files.encode(ReachGroups.to_json(acc.misreads))
    )
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
    shell.info("\n#{acc.units} statements in #{acc.orders} orders")
    shell.info("unclassified: #{length(acc.unclassified)}")
    for {law, why} <- Enum.take(acc.unclassified, 20), do: shell.info("  #{law}: #{why}")

    shell.info(
      "#{map_size(acc.patterns)} patterns, #{map_size(acc.examples)} examples (#{length(acc.too_large)} too large to hold)"
    )

    shell.info(
      "examples not held, reading differently alone than in their order: #{length(acc.mismatch)}"
    )

    for id <- acc.mismatch |> Enum.sort() |> Enum.take(20), do: shell.info("  #{id}")

    shell.info("\nstatements by kind and outcome:")

    for {k, n} <-
          acc.patterns
          |> Enum.group_by(
            fn {k, _} -> k |> String.split("|") |> then(&"#{hd(&1)} → #{List.last(&1)}") end,
            fn {_, e} -> e.count end
          )
          |> Enum.map(fn {c, ns} -> {c, Enum.sum(ns)} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{n}  #{k}")

    {read, all} =
      Enum.reduce(acc.patterns, {0, 0}, fn {k, e}, {read, all} ->
        rules? = k |> String.split("|") |> List.last() |> String.starts_with?("rules")
        {read + if(rules?, do: e.count, else: 0), all + e.count}
      end)

    shell.info("  (read into rules: #{read} of #{all})")

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

  # the words a rule uses wrongly, by shape; reviewed in `misreads.json`
  defp misreads(groups, dir) do
    ranked = ReachGroups.ranked(groups)

    reviewed =
      case File.read(Path.join(dir, "misreads.json")) do
        {:ok, body} -> Jason.decode!(body)
        _ -> %{}
      end

    Enum.each(Misreads.summary(ranked, reviewed), fn line -> Mix.shell().info(line) end)

    path = "data/reports/commencement-reader/misreads-orders-#{Date.utc_today()}.txt"
    File.write!(path, Enum.join(ReachGroups.lines(ranked), "\n") <> "\n")
    Mix.shell().info("report: #{path}")
  end

  # the words no rule uses, by shape, widest reach first; reviewed in
  # `leftovers.json`, the report under data/reports
  defp leftovers(groups, dir) do
    ranked = ReachGroups.ranked(groups)

    reviewed =
      case File.read(Path.join(dir, "leftovers.json")) do
        {:ok, body} -> Jason.decode!(body)
        _ -> %{}
      end

    Enum.each(ReachGroups.summary(ranked, reviewed), fn line -> Mix.shell().info(line) end)

    path = "data/reports/commencement-reader/leftovers-orders-#{Date.utc_today()}.txt"
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Enum.join(ReachGroups.lines(ranked), "\n") <> "\n")
    Mix.shell().info("report: #{path}")
  end
end

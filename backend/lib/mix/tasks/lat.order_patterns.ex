defmodule Mix.Tasks.Lat.OrderPatterns do
  @moduledoc """
  Commencement orders' pattern catalogue (change vocabulary CV-S04): every
  statement of every commencement order held — an article bringing
  provisions into force, a row of its Schedule table — classed by its form
  and by what the order reader made of it (`Commencement.OrderPatterns`),
  each pattern with its count and up to three real statements (from
  different orders) as examples. The orders: those found for an Act (`mix
  lat.commencement --read-orders`' cached lists) and those any stored rule
  was read from. Read-only over the DB and the stored law text; writes only
  the fixture directory. One order at a time.

      mix lat.order_patterns                  # regenerate; report against the expectations
      mix lat.order_patterns --accept         # also accept new patterns as the reader reads them now
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
  alias SertantaiLegal.Scraper.Commencement.{Order, OrderPatterns}

  @shortdoc "Commencement orders' pattern catalogue, as test fixtures (read-only)"

  @dir "test/fixtures/order_patterns"
  @per_pattern 3
  @whole_max 20_000
  @max 30_000

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [orders: :string, out: :string, accept: :boolean])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dir = opts[:out] || @dir
    File.mkdir_p!(dir)

    pairs = pairs(opts[:orders])
    Mix.shell().info("#{length(pairs)} orders held, with the Act each commences")

    acc =
      pairs
      |> Enum.with_index(1)
      |> Enum.reduce(new_acc(), fn {{order, act}, i}, acc ->
        if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(pairs)}")

        try do
          order_patterns(order, act, acc)
        rescue
          error -> %{acc | unclassified: [{order, Exception.message(error)} | acc.unclassified]}
        end
      end)

    write(dir, acc)
    report(dir, acc, opts[:accept])
  end

  defp new_acc,
    do: %{
      orders: 0,
      units: 0,
      unclassified: [],
      patterns: %{},
      examples: %{},
      mismatch: [],
      too_large: []
    }

  # {order, act}: each held order once, with the Act its list or rules name
  defp pairs(only) do
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
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.filter(fn {order, act} -> order != act and held?(order) end)
    |> then(fn ps ->
      case only do
        nil -> ps
        list -> Enum.filter(ps, &(elem(&1, 0) in String.split(list, ",", trim: true)))
      end
    end)
    |> Enum.sort()
  end

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, t, y, n] -> File.exists?("data/cache/clml/#{t}/#{y}/#{n}/body/data.xml.gz")
      _ -> false
    end
  end

  defp doc(law) do
    Doc.new(law, ClmlStore.law_docs(law))
  end

  # as `mix lat.commencement` names the Act an order commences
  defp act(law) do
    [_, _, year, _] = String.split(law, "_", parts: 4)

    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) ->
          t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

        _ ->
          if held?(law), do: Order.title(doc(law))
      end

    %{law: law, title: title, year: year}
  end

  defp order_patterns(order, act_law, acc) do
    doc = doc(order)
    act = act(act_law)
    rules = Order.rules(doc, act)
    acc = %{acc | orders: acc.orders + 1}

    for unit <- OrderPatterns.units(doc), reduce: acc do
      acc ->
        f = OrderPatterns.form(unit)
        o = OrderPatterns.outcome(unit, rules)
        key = OrderPatterns.key(f, o.class)
        id = example_id(order, unit)

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
        if take?, do: example(acc, key, id, order, act, doc, unit, o), else: acc
    end
  end

  # the order whole when small, else cut; held when it reads alone as the
  # whole order does
  defp example(acc, key, id, order, act, doc, unit, outcome) do
    whole = OrderPatterns.example(doc, unit, :whole)

    xml =
      if byte_size(whole) <= @whole_max, do: whole, else: OrderPatterns.example(doc, unit, :cut)

    cond do
      byte_size(xml) > @max ->
        not_held(acc, key, id, :too_large)

      OrderPatterns.read(order, act, xml, unit) == outcome ->
        put_in(acc.examples[id], %{
          json: %{
            "order" => order,
            "act" => %{"law" => act.law, "title" => act.title, "year" => act.year},
            "unit" => %{"kind" => unit.kind, "id" => unit.id, "text" => unit.text},
            "xml" => xml
          },
          outcome: %{"class" => outcome.class, "rules" => outcome.rules}
        })

      true ->
        not_held(acc, key, id, :mismatch)
    end
  end

  defp not_held(acc, key, id, why) do
    acc = put_in(acc.patterns[key].examples, List.delete(acc.patterns[key].examples, id))
    Map.update!(acc, why, &[id | &1])
  end

  defp example_id(order, unit),
    do:
      order <>
        "/" <>
        (:crypto.hash(:sha256, unit.id <> unit.text)
         |> Base.encode16(case: :lower)
         |> binary_part(0, 10))

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
end

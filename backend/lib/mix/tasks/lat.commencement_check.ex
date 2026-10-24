defmodule Mix.Tasks.Lat.CommencementCheck do
  @moduledoc """
  The commencement reader's check (change vocabulary CV-S04), for a scope:

  1. **Rows:** every LAT row's own commencement accounted for — what
     `Readers.OwnCommencement` makes of it from the law's text rules
     (`OwnCommencement.outcome/4`), our faults counted; beside it, the
     law's own feed's coming-into-force record for the row (a yardstick,
     never a source). The reader's context as the build gives it: the
     rows' Parts and Chapters, document order, each provision's extent.
  2. **Gaps:** every stored change no other source dates, and what the
     gap-filler makes of it (`NoteDate.why/2`): dated, by which pointer, or
     undated and why.
  3. With `--sample FILE`, a reproducible sample of each (`--n` each,
     stratified by outcome so every kind is seen), with the rules and words
     behind each, for checking.

  Read-only: `commencement_rules`, LAT rows, stored changes
  (`mix lat.vocabulary --build`). One law at a time.

      mix lat.commencement_check --family "OH&S: Occupational"
      mix lat.commencement_check --laws A,B --all
      mix lat.commencement_check --family F --sample FILE --n 50 [--seed N]
      mix lat.commencement_check --family F --fresh   # the laws' own clauses re-read now (a dry run of `mix lat.commencement --read`)
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Ref, Store}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmendingLaw, NoteDate, OwnCommencement}
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}
  alias SertantaiLegal.Scraper.Commencement.Store, as: Rules
  alias SertantaiLegal.Scraper.{LatRef, LawStart}

  @shortdoc "Every row's commencement and every undated change accounted for (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          fresh: :boolean,
          family: :string,
          laws: :string,
          all: :boolean,
          sample: :string,
          n: :integer,
          seed: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = scope(opts)

    {rows, gaps, _cache} =
      Enum.reduce(laws, {[], [], %{}}, fn law, {rows, gaps, cache} ->
        {law_gaps, cache} = law_gaps(law, cache)
        {rows ++ law_rows(law, opts[:fresh]), gaps ++ law_gaps, cache}
      end)

    report_rows(rows, opts)
    report_gaps(gaps, opts)

    if opts[:sample], do: sample(rows, gaps, opts[:sample], opts[:n] || 50, opts[:seed])

    faults = Enum.count(rows, &OwnCommencement.fault?(&1.outcome))
    Mix.shell().info("\n#{if faults == 0, do: "PASS", else: "FAIL"} (rows: our faults #{faults})")
  end

  defp scope(opts) do
    cond do
      opts[:family] ->
        Repo.query!(
          """
          SELECT name FROM uk_lrt WHERE family LIKE '%' || $1 || '%'
            AND name IN (SELECT DISTINCT law_name FROM legal_articles) ORDER BY name
          """,
          [opts[:family]]
        ).rows
        |> List.flatten()

      opts[:laws] ->
        String.split(opts[:laws], ",", trim: true)

      true ->
        Mix.raise(
          "usage: mix lat.commencement_check --family F | --laws A,B [--all] [--sample FILE --n N]"
        )
    end
  end

  # ── rows ─────────────────────────────────────────────────────────────

  defp law_rows(law, fresh?) do
    rows =
      for [sid, text, part, chapter, extent] <-
            Repo.query!(
              "SELECT section_id, text, part, chapter, extent_code FROM legal_articles WHERE law_name = $1 ORDER BY position",
              [law]
            ).rows,
          do: %{section_id: sid, text: text, part: part, chapter: chapter, extent_code: extent}

    rules = if fresh?, do: fresh_rules(law, rows), else: Rules.for_law(law)

    feed = feed_commenced(law)
    # the reader's context, as the build gives it (`lat.vocabulary`)
    ctx = OwnClause.context(rows)
    rows = Enum.map(rows, &Map.put(&1, :id, &1.section_id |> bare(law) |> Ref.canonical()))
    extents = base_extents(rows)

    # no rules: a law with no clause and no register date is `LawStart`'s
    # `no_clause` (a known limit), not a law never read
    no_clause? =
      rules == [] and
        LawStart.resolve(SertantaiLegal.Scraper.ChangeCollector.law_start_input(law, rows)).treatment ==
          :no_clause

    rows
    |> Enum.map(& &1.id)
    |> Enum.map(&base/1)
    |> Enum.uniq()
    |> Enum.map(fn id ->
      {outcome, result} =
        OwnCommencement.outcome(rules, law, id, Map.put(ctx, :extent, Map.get(extents, id)))

      outcome = if outcome == :no_rules and no_clause?, do: :no_clause, else: outcome

      %{
        law: law,
        id: id,
        outcome: outcome,
        result: result,
        full_from: result && result.full_from,
        partial_from: result && result.partial_from,
        feed: feed_at(feed, id)
      }
    end)
    |> Enum.map(&Map.put(&1, :yardstick, yardstick(&1)))
  end

  # the law's own clause re-read now, beside the stored rules of every other
  # source (what `mix lat.commencement --read` would write) — and, for a
  # law its clause leaves to orders, the orders found for it before (`mix
  # lat.commencement --read-orders`' cached list; never a search) and held,
  # read now (CR-07)
  defp fresh_rules(law, rows) do
    own = OwnClause.treatments()

    clause =
      OwnClause.rules(law, SertantaiLegal.Scraper.ChangeCollector.law_start_input(law, rows))

    orders =
      if Enum.any?(clause, &match?({:appointed, _}, &1.when)), do: cached_orders(law), else: []

    read = MapSet.new(orders)

    kept =
      Enum.reject(Rules.for_law(law), fn r ->
        # an order's rules commencing itself go when it is re-read (CV-S04)
        (r.source.law == law and r.treatment in own) or
          (r.source.law == law and r.treatment in [:order_date, :order_schedule]) or
          (MapSet.member?(read, r.source.law) and r.treatment in [:order_date, :order_schedule])
      end)

    act = %{law: law, title: title(law), year: law |> String.split("_") |> Enum.at(2)}
    kept ++ clause ++ Enum.flat_map(orders, &order_rules(&1, act))
  end

  defp cached_orders(law) do
    case File.read("data/cache/commencement-orders/#{law}.json") do
      {:ok, json} -> Jason.decode!(json)
      _ -> []
    end
  end

  defp order_rules(order, act) do
    with [_, t, y, n] <- String.split(order, "_", parts: 4),
         [_ | _] = paths <- Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/**/data.xml.gz") do
      doc =
        SertantaiLegal.Scraper.AmendingLaw.Doc.new(
          order,
          paths |> Enum.sort() |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip()))
        )

      SertantaiLegal.Scraper.Commencement.Order.rules(doc, act)
    else
      _ -> []
    end
  end

  # as `mix lat.commencement` names the Act an order commences
  defp title(law) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} when is_binary(t) ->
        t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

      _ ->
        nil
    end
  end

  # as the build: a provision's own row's extent, else its versions' together
  defp base_extents(rows) do
    rows
    |> Enum.group_by(&base(&1.id), & &1)
    |> Map.new(fn {b, rs} ->
      case Enum.find(rs, &(&1.id == b)) do
        %{extent_code: e} when is_binary(e) ->
          {b, e}

        _ ->
          {b,
           case rs |> Enum.map(& &1.extent_code) |> Enum.reject(&is_nil/1) do
             [] -> nil
             es -> SertantaiLegal.Scraper.Territory.union(es)
           end}
      end
    end)
  end

  defp bare(sid, law), do: String.replace_prefix(sid, law <> ":", "")
  defp base(id), do: String.replace(id, ~r/\[[^\]]+\]$/, "")

  # the law's own feed's coming-into-force records, by target: its first
  # and full dates
  defp feed_commenced(law) do
    Repo.query!(
      """
      SELECT target, min(date), min(date) FILTER (WHERE NOT partial) FROM provision_changes
      WHERE law_name = $1 AND operation = 'commenced' AND key NOT LIKE '%:commencement:%'
        AND date IS NOT NULL GROUP BY target
      """,
      [law]
    ).rows
    |> Map.new(fn [t, first, full] -> {t |> Ref.canonical() |> base(), {first, full}} end)
  end

  # the nearest record at the row or above it
  defp feed_at(feed, id), do: Enum.find_value(LatRef.ancestors(id), &Map.get(feed, &1))

  defp yardstick(%{feed: nil, full_from: nil}), do: :neither
  defp yardstick(%{feed: nil}), do: :own_only
  defp yardstick(%{feed: {_, full}, full_from: full}) when full != nil, do: :agree
  defp yardstick(%{full_from: nil}), do: :feed_only
  defp yardstick(%{feed: {_, nil}}), do: :feed_partial_only
  defp yardstick(_), do: :differ

  defp report_rows(rows, opts) do
    shell = Mix.shell()
    laws = rows |> Enum.map(& &1.law) |> Enum.uniq() |> length()
    shell.info("\n#{length(rows)} rows in #{laws} laws — own commencement:")

    for {k, n} <- rows |> Enum.frequencies_by(& &1.outcome) |> Enum.sort_by(&(-elem(&1, 1))) do
      ls = rows |> Enum.filter(&(&1.outcome == k)) |> Enum.map(& &1.law) |> Enum.uniq()
      fault = if OwnCommencement.fault?(k), do: "  (our fault)", else: ""
      shell.info("  #{n}  #{k} (#{length(ls)} laws)#{fault}")
    end

    shell.info("\nagainst the law's own feed (a yardstick):")

    for {k, n} <- rows |> Enum.frequencies_by(& &1.yardstick) |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{n}  #{k}")

    faults = Enum.filter(rows, &OwnCommencement.fault?(&1.outcome))

    for {law, rs} <-
          faults |> Enum.group_by(& &1.law) |> Enum.take(if(opts[:all], do: 999, else: 20)),
        do: shell.info("  fault #{hd(rs).outcome}: #{law} (#{length(rs)} rows) e.g. #{hd(rs).id}")

    for {law, rs} <-
          rows
          |> Enum.filter(&(&1.yardstick == :differ))
          |> Enum.group_by(& &1.law)
          |> Enum.take(if(opts[:all], do: 999, else: 10)),
        do:
          shell.info(
            "  differ: #{law} (#{length(rs)} rows) e.g. #{hd(rs).id} own #{hd(rs).full_from} feed #{inspect(hd(rs).feed)}"
          )
  end

  # ── gaps ─────────────────────────────────────────────────────────────

  # each stored change no other source dates: what the gap-filler makes of
  # it (its own claims set aside)
  defp law_gaps(law, cache) do
    changes = Enum.map(Store.for_law(law), &without_gap_fill/1)
    amenders = changes |> Enum.map(&amender/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()
    cache = Enum.reduce(amenders, cache, &Map.put_new_lazy(&2, &1, fn -> Rules.for_law(&1) end))
    commencement = Map.take(cache, amenders)

    gaps =
      for c <- changes,
          why = NoteDate.why(c, commencement),
          why != :not_a_gap,
          do: %{law: law, change: c, why: why, amender: amender(c), commencement: commencement}

    {gaps, cache}
  end

  defp amender(c), do: Change.value(c, :feed, :by) || Change.value(c, :markup, :cited)

  # the gap-filler's own claims (a date with `:via`), set aside to ask it again
  defp without_gap_fill(%Change{} = c) do
    if Change.values(c, :commencement, :via) == [],
      do: c,
      else: %{
        c
        | claims:
            Enum.reject(c.claims, &(&1.source == :commencement and &1.attribute in [:date, :via]))
      }
  end

  @text_ops [:inserted, :substituted, :repealed, :repealed_in_part, :renumbered]

  defp report_gaps(gaps, opts) do
    shell = Mix.shell()
    text = Enum.filter(gaps, &(&1.change.resolved.operation in @text_ops))

    shell.info(
      "\n#{length(gaps)} changes no other source dates (#{length(text)} text changes) — the gap-filler:"
    )

    # a text change on a Schedule or annex lands where LAT holds no row (K1)
    on_rows = Enum.reject(text, &String.match?(&1.change.target, ~r/^(?:sch|annex)\./))

    for {k, n} <- gaps |> Enum.frequencies_by(&class/1) |> Enum.sort_by(&(-elem(&1, 1))) do
      t = Enum.count(text, &(class(&1) == k))
      r = Enum.count(on_rows, &(class(&1) == k))
      shell.info("  #{n}  #{k}  (text changes #{t}, of them not in a Schedule or annex #{r})")
    end

    for {k, gs} <- gaps |> Enum.reject(&match?({:dated, _, _}, &1.why)) |> Enum.group_by(&class/1) do
      amenders = gs |> Enum.frequencies_by(& &1.amender) |> Enum.sort_by(&(-elem(&1, 1)))

      shell.info(
        "  #{k}: by #{amenders |> Enum.take(if(opts[:all], do: 999, else: 6)) |> Enum.map_join(", ", fn {l, n} -> "#{l || "?"} ×#{n}" end)}"
      )
    end
  end

  defp class(%{why: {:dated, _, via}}), do: "dated via #{via}"
  defp class(%{why: {:undated, why}}), do: "undated: #{why}"

  # ── sample ───────────────────────────────────────────────────────────

  # stratified: round-robin over the outcomes, random within each (fixed
  # seed; `--seed N` draws another)
  defp sample(rows, gaps, file, n, seed) do
    :rand.seed(:exsss, if(seed, do: {seed, seed, seed}, else: {2026, 10, 23}))

    picked_rows =
      rows
      |> Enum.sort_by(&{&1.law, &1.id})
      |> stratified(&{&1.outcome, &1.yardstick}, n)
      |> Enum.map(&row_item/1)

    picked_gaps =
      gaps
      |> Enum.sort_by(&{&1.law, &1.change.key, &1.change.target})
      |> stratified(&class/1, n)
      |> Enum.map(&gap_item/1)

    File.write!(file, Jason.encode!(%{rows: picked_rows, gaps: picked_gaps}, pretty: true))

    Mix.shell().info(
      "\nsample of #{length(picked_rows)} rows and #{length(picked_gaps)} gaps written to #{file}"
    )
  end

  defp stratified(items, by, n) do
    groups =
      items
      |> Enum.group_by(by)
      |> Enum.sort_by(&inspect(elem(&1, 0)))
      |> Enum.map(fn {_, xs} -> Enum.shuffle(xs) end)

    groups
    |> Stream.unfold(fn
      [] -> nil
      gs -> {Enum.map(gs, &hd/1), gs |> Enum.map(&tl/1) |> Enum.reject(&(&1 == []))}
    end)
    |> Enum.flat_map(& &1)
    |> Enum.take(n)
  end

  defp row_item(r) do
    %{
      law: r.law,
      row: r.id,
      reader: %{
        outcome: r.outcome,
        full_from: r.full_from,
        partial_from: r.partial_from,
        entries:
          for(
            e <- (r.result && r.result.entries) || [],
            do: %{
              date: e.date,
              territory: e.territory,
              purposes: e.purposes,
              role: e.role,
              rule: rule(e.rule)
            }
          ),
        undated: for(u <- (r.result && r.result.undated) || [], do: rule(u))
      },
      feed: r.feed && %{first: elem(r.feed, 0), full: elem(r.feed, 1)},
      yardstick: r.yardstick
    }
  end

  defp gap_item(g) do
    c = g.change
    rules = Map.get(g.commencement, g.amender, [])

    refs =
      case Change.values(c, :feed, :affecting) |> List.flatten() do
        [] -> Change.values(c, :markup, :affecting) |> List.flatten()
        feed -> feed
      end

    %{
      law: g.law,
      target: c.target,
      key: short(c.key),
      operation: c.resolved.operation,
      amending_law: g.amender,
      named_provisions: refs,
      gap_filler: inspect(g.why),
      at_each:
        for ref <- refs do
          r = AmendingLaw.commencement(rules, ref)

          %{
            ref: ref,
            full_from: r && r.full_from,
            rules:
              if(r,
                do: Enum.map(r.entries, &rule(&1.rule)) ++ Enum.map(r.undated, &rule/1),
                else: []
              )
          }
        end
    }
  end

  defp rule(%Rule{} = r) do
    %{
      text: Rule.to_text(r),
      source_law: r.source.law,
      source_ref: r.source.ref,
      words: r.source.text && String.slice(r.source.text, 0, 400)
    }
  end

  # an effect id shortened (push protection)
  defp short("key-" <> hex), do: "key-…" <> String.slice(hex, -6, 6)
  defp short(id), do: id
end

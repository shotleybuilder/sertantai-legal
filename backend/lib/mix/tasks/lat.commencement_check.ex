defmodule Mix.Tasks.Lat.CommencementCheck do
  @moduledoc """
  The commencement reader's check (LAT Change Pipeline, step: Commencement
  reader), for a scope. The check itself is `Commencement.Check` (pure);
  this task reads the DB and prints.

  1. **Rows:** every LAT row's own commencement accounted for — what
     `Readers.OwnCommencement` makes of it from the law's text rules, our
     faults counted; beside it, the law's own feed's coming-into-force
     record for the row (a yardstick, never a source).
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
      mix lat.commencement_check --family F --fresh   # the laws' own clauses, and their amending laws', re-read now (a dry run of `mix lat.commencement --read` and `--read-amending`)
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw

  alias SertantaiLegal.Scraper.Commencement.{
    AmendingRead,
    Check,
    FamilyLeftovers,
    HeldAmenders,
    Leftovers,
    Orders,
    OwnClause,
    OwnRead,
    PartScope,
    Rule
  }

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Review.PartItems
  alias SertantaiLegal.Scraper.LawStart.Input

  alias SertantaiLegal.Scraper.Commencement.Store, as: Rules
  alias SertantaiLegal.Scraper.LawStart

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
          seed: :integer,
          part_items: :boolean,
          lat: :boolean,
          out: :string
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    if opts[:part_items], do: part_items(opts), else: check(opts)
  end

  # ── the Part items review (`--part-items`; read-only) ───────────────

  # every own-clause rule naming a Part or Chapter with the law's words for
  # it, and the rules a fresh reading qualifies that the store dates in
  # full: amending laws (no LAT rows), or with `--lat` the laws with rows
  defp part_items(opts) do
    {items, moved} =
      opts[:lat]
      |> part_item_laws()
      |> Enum.reduce({[], []}, fn law, {items, moved} ->
        {i, m} = if opts[:lat], do: {[], lat_moved(law)}, else: part_item_read(law)
        {items ++ i, moved ++ m}
      end)

    limited = PartItems.full_with_limit(items)

    lines =
      Enum.map(items, &PartItems.line/1) ++
        ["", "newly qualified (stored full, read now for some purposes):"] ++
        Enum.map(moved, &Rule.to_text/1) ++
        [
          "",
          "Part items #{length(items)}; their words limited #{Enum.count(items, & &1.limited)}; " <>
            "dated full with a limit #{length(limited)}; newly qualified rules #{length(moved)}"
        ] ++ Enum.map(limited, &("  full with a limit: " <> PartItems.line(&1)))

    if opts[:out], do: File.write!(opts[:out], Enum.join(lines, "\n") <> "\n")
    Enum.each(Enum.take(lines, -(length(limited) + 1)), &Mix.shell().info(&1))
  end

  # (the laws with rows: only those whose text holds a limiting relative
  # clause, the one form the reading of an item changed on)
  defp part_item_laws(lat?) do
    lat = "EXISTS (SELECT 1 FROM legal_articles a WHERE a.law_name = c.commences"
    limit = " AND a.text ~* 'provisions? of [^;]*(which|that)\\M')"
    scope = if lat?, do: lat <> limit, else: "NOT " <> lat <> ")"

    Repo.query!(
      "SELECT DISTINCT c.commences FROM commencement_rules c " <>
        "WHERE c.source_law = c.commences AND c.treatment <> 'feed_commencement' " <>
        "AND #{scope} ORDER BY 1"
    ).rows
    |> List.flatten()
  end

  # an amending law with Parts: its clause read now, before and after its
  # Parts are written out, beside its stored own rules
  defp part_item_read(law) do
    xmls = ClmlStore.law_docs(law)

    if Enum.any?(xmls, &String.contains?(&1, "<Part ")) do
      rows = law |> Doc.new(xmls) |> OwnClause.doc_rows()
      rules = OwnClause.rules(law, Input.of(law, rows))

      {PartItems.items(law, rules, rows),
       PartItems.newly_qualified(stored_own(law), PartScope.expand(rules, rows))}
    else
      {[], []}
    end
  end

  defp lat_moved(law), do: PartItems.newly_qualified(stored_own(law), OwnRead.rules(law))

  defp stored_own(law) do
    own = OwnClause.treatments()
    law |> Rules.for_law() |> Enum.filter(&(&1.source.law == law and &1.treatment in own))
  end

  defp check(opts) do
    laws = scope(opts)

    {rows, gaps, _cache} =
      Enum.reduce(laws, {[], [], %{}}, fn law, {rows, gaps, cache} ->
        {law_gaps, cache} = law_gaps(law, cache, opts[:fresh])
        {rows ++ law_rows(law, opts[:fresh]), gaps ++ law_gaps, cache}
      end)

    report_rows(rows, opts)
    report_gaps(gaps, opts)

    if opts[:sample], do: sample(rows, gaps, opts[:sample], opts[:n] || 50, opts[:seed])

    gate = leftovers_gate(laws, gaps, opts)
    faults = length(Check.faults(rows))
    unnamed = length(gate.failing)

    Mix.shell().info(
      "\n#{if faults == 0 and gate.pass?, do: "PASS", else: "FAIL"} (rows: our faults #{faults}; leftovers not named: #{unnamed})"
    )

    Step.new("Commencement reader", faults == 0 and gate.pass?, faults + unnamed)
  end

  # ── the leftovers gate ──────────────────────────────────────────────

  # the commencement leftovers reaching the family (Decision 1 (c), Jason
  # 2026-11-05): its laws' own clauses, their orders held, and the held
  # amending laws its undated changes point to; each must be named
  # (`known:` in `leftovers.json`)
  defp leftovers_gate(laws, gaps, opts) do
    amenders =
      gaps
      |> Enum.map(& &1.amender)
      |> Enum.reject(&(is_nil(&1) or &1 in laws))
      |> Enum.frequencies()
      |> Map.drop(lat_laws())

    gate = laws |> FamilyLeftovers.for_family(amenders) |> Leftovers.gate()
    shell = Mix.shell()

    shell.info(
      "\nleftovers reaching the family (words of a commencement statement no rule uses):"
    )

    for {k, n} <- Enum.sort(gate.counts), do: shell.info("  #{n}  #{k}")

    for i <- Enum.take(gate.failing, if(opts[:all], do: 9999, else: 30)),
        do:
          shell.info(
            "  #{i.reach} #{i.source} #{i.law} #{i.ref}: #{Enum.join(i.words, " · ")} [#{i.status || "no status"}]"
          )

    path = "data/reports/commencement-reader/gate-#{slug(opts)}-#{Date.utc_today()}.txt"
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      Enum.map_join(gate.failing, "\n", fn i ->
        "#{i.reach}\t#{i.source}\t#{i.law}\t#{i.ref}\t#{Enum.join(i.words, " · ")}\t#{i.status || "no status"}\t#{i.shape}"
      end) <> "\n"
    )

    shell.info("gate report: #{path}")
    gate
  end

  defp lat_laws,
    do: Repo.query!("SELECT DISTINCT law_name FROM legal_articles").rows |> List.flatten()

  defp slug(opts),
    do:
      (opts[:family] || "laws")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")

  defp scope(opts) do
    cond do
      opts[:family] ->
        Scope.family_laws(opts[:family])

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

    rules = if fresh?, do: fresh_rules(law), else: Rules.for_law(law)

    # no rules: a law with no clause and no register date is `LawStart`'s
    # `no_clause` (a known limit), not a law never read
    no_clause? =
      rules == [] and
        LawStart.resolve(SertantaiLegal.Scraper.ChangeCollector.law_start_input(law, rows)).treatment ==
          :no_clause

    Check.rows(law, rows, rules, feed_commenced(law), no_clause?)
  end

  # the law's own clause re-read now, beside the stored rules of every other
  # source (what `mix lat.commencement --read` would write) — and, for a
  # law its clause leaves to orders, the orders found for it before (`mix
  # lat.commencement --read-orders`' cached list; never a search) and held,
  # read now (CR-07)
  defp fresh_rules(law) do
    own = OwnClause.treatments()

    # as `--read` reads it: the clause and the Schedules' effect (SI 2020/206)
    clause = OwnRead.rules(law)

    orders =
      if Enum.any?(clause, &match?({:appointed, _}, &1.when)), do: cached_orders(law), else: []

    read = MapSet.new(orders)

    kept =
      Enum.reject(Rules.for_law(law), fn r ->
        # an order's rules commencing itself go when it is re-read
        (r.source.law == law and r.treatment in own) or
          (r.source.law == law and r.treatment in [:order_date, :order_schedule]) or
          (MapSet.member?(read, r.source.law) and r.treatment in [:order_date, :order_schedule])
      end)

    year = law |> String.split("_") |> Enum.at(2)
    act = %{law: law, title: title(law, year), year: year}
    kept ++ clause ++ Enum.flat_map(orders, &order_rules(&1, act))
  end

  # the list kept and the orders whose rules are stored, as `--read-orders`
  # reads them
  defp cached_orders(law), do: Orders.candidates(Orders.cached(law), Rules.order_sources(law))

  defp order_rules(order, act) do
    with [_ | _] = xmls <- ClmlStore.law_docs(order) do
      doc = SertantaiLegal.Scraper.AmendingLaw.Doc.new(order, xmls)

      SertantaiLegal.Scraper.Commencement.Order.rules(doc, act)
    else
      _ -> []
    end
  end

  # as `mix lat.commencement` names the Act an order commences
  defp title(law, year) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} when is_binary(t) -> Orders.act_title(t, year)
      _ -> nil
    end
  end

  # the law's own feed's coming-into-force records, by target: its first
  # and full dates — any stored change carrying a feed claim, as Merge joins
  # an agreeing feed record into the own-clause change (its key)
  defp feed_commenced(law) do
    Repo.query!(
      """
      SELECT target, min(date), min(date) FILTER (WHERE NOT partial) FROM provision_changes pc
      WHERE law_name = $1 AND operation = 'commenced' AND date IS NOT NULL
        AND EXISTS (SELECT 1 FROM provision_change_claims c
                    WHERE c.change_id = pc.id AND c.source = 'feed')
      GROUP BY target
      """,
      [law]
    ).rows
    |> Check.feed_index()
  end

  defp report_rows(rows, opts) do
    shell = Mix.shell()
    t = Check.row_tallies(rows)
    shell.info("\n#{length(rows)} rows in #{t.laws} laws — own commencement:")

    for {k, n, laws, fault?} <- t.outcomes do
      fault = if fault?, do: "  (our fault)", else: ""
      shell.info("  #{n}  #{k} (#{laws} laws)#{fault}")
    end

    shell.info("  (left to orders, by_order + by_order_partly: #{t.by_order})")
    shell.info("\nagainst the law's own feed (a yardstick):")
    for {k, n} <- t.yardstick, do: shell.info("  #{n}  #{k}")

    for {law, rs} <-
          rows
          |> Check.faults()
          |> Enum.group_by(& &1.law)
          |> Enum.take(if(opts[:all], do: 999, else: 20)),
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

  defp law_gaps(law, cache, fresh?) do
    changes = Store.for_law(law)
    amenders = changes |> Enum.map(&Check.amender/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    cache =
      Enum.reduce(amenders, cache, &Map.put_new_lazy(&2, &1, fn -> amender_rules(&1, fresh?) end))

    {Check.gaps(law, changes, Map.take(cache, amenders)), cache}
  end

  # an amending law's rules: stored, or with `--fresh` its own clause read
  # now from the CLML held (a dry run of `mix lat.commencement
  # --read-amending`) — never a law with LAT rows (`--read`'s) nor a
  # commencement order (read as an order)
  defp amender_rules(law, true) do
    if lat?(law) or HeldAmenders.order?(law),
      do: Rules.for_law(law),
      else: AmendingRead.fresh(law)
  end

  defp amender_rules(law, _stored), do: Rules.for_law(law)

  defp lat?(law),
    do:
      Repo.query!("SELECT EXISTS (SELECT 1 FROM legal_articles WHERE law_name = $1)", [law]).rows ==
        [[true]]

  defp report_gaps(gaps, opts) do
    shell = Mix.shell()
    t = Check.gap_tallies(gaps)

    shell.info(
      "\n#{length(gaps)} changes no other source dates (#{t.text} text changes) — the gap-filler:"
    )

    for {k, n, text, on_rows} <- t.classes,
        do:
          shell.info(
            "  #{n}  #{k}  (text changes #{text}, of them not in a Schedule or annex #{on_rows})"
          )

    for {k, amenders} <- t.amenders do
      shell.info(
        "  #{k}: by #{amenders |> Enum.take(if(opts[:all], do: 999, else: 6)) |> Enum.map_join(", ", fn {l, n} -> "#{l || "?"} ×#{n}" end)}"
      )
    end
  end

  # ── sample ───────────────────────────────────────────────────────────

  # stratified: round-robin over the outcomes, random within each (fixed
  # seed; `--seed N` draws another)
  defp sample(rows, gaps, file, n, seed) do
    Draw.seed(if(seed, do: {seed, seed, seed}, else: {2026, 10, 23}))

    picked_rows =
      rows
      |> Enum.sort_by(&{&1.law, &1.id})
      |> Draw.round_robin(&{&1.outcome, &1.yardstick}, n)
      |> Enum.map(&Check.row_item/1)

    picked_gaps =
      gaps
      |> Enum.sort_by(&{&1.law, &1.change.key, &1.change.target})
      |> Draw.round_robin(&Check.gap_class/1, n)
      |> Enum.map(&Check.gap_item/1)

    File.write!(file, Jason.encode!(%{rows: picked_rows, gaps: picked_gaps}, pretty: true))

    Mix.shell().info(
      "\nsample of #{length(picked_rows)} rows and #{length(picked_gaps)} gaps written to #{file}"
    )
  end
end

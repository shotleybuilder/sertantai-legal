defmodule Mix.Tasks.Lat.Commencement do
  @moduledoc """
  A law's commencement ruleset (commencement-rules CR-01, CR-03), one
  readable line per rule — what it brings into force, when, where and how
  far, its treatment, and the words it came from:

      mix lat.commencement --law UK_uksi_2017_469

      art.1, art.2, art.11 — made + 1 day — everywhere, fully — made_relative — UK_uksi_2017_469 art.1(2): “…”
      rest — 2017-05-08 — everywhere, fully — clause_date — UK_uksi_2017_469 art.1(3): “…”

  Grouped by the source read (the law's own clause, each commencement
  order).

      mix lat.commencement --read --law X[,Y] | --all       # write the laws' own-clause rules (CR-03)
      mix lat.commencement --compare --all --tag cr03_cmp   # the evaluator vs today's register, per row
      mix lat.commencement --effects                        # amending Acts: their feed's "coming into force" effects as rules (CR-04)
      mix lat.commencement --effects --law A,B              # those Acts only, from the store alone; replaces only the feed rules commencing them
      mix lat.commencement --read-orders                    # amending Acts before 2002: the rules the orders their notes cite state (where no effect reaches)
      mix lat.commencement --read-orders --law X,Y          # a labelled law's own commencement orders (CR-07: its by-order rows); searches legislation.gov.uk for a law with no order list kept
      mix lat.commencement --read-orders --law X,Y --held   # the same from what is held: the list kept and the orders whose rules are stored; never a search
      mix lat.commencement --read-orders --family F         # `--held` for the family's laws and its changes' amending laws (the re-read after a reader change)
      mix lat.commencement --read-orders … --preview        # what it would write, per order: stored → read; writes nothing
      mix lat.commencement --read --law X,Y | --family F --preview   # a fix's reach: per law, the own-clause rules a fresh reading adds and drops; writes nothing
      mix lat.commencement --read-amending --family F --preview      # the same for the amending laws' own clauses
      mix lat.commencement --read-amending                  # amending laws with no LAT: their own clause from the CLML held (CR-06; one hop, no fetch)
      mix lat.commencement --read-amending --law A,B --workers 1   # these amending laws (CV-07: just fetched)
      mix lat.commencement --read-amending --family F --workers 1  # the amending laws of a family's changes (`Commencement.HeldAmenders`: never a commencement order)
      mix lat.commencement --amenders --family F [--out FILE]      # that list, printed (read-only)

  `--read` writes only `commencement_rules` (no label changes). `--compare`
  writes `data/reports/commencement-rules/<tag>.csv` — each row whose
  evaluated start differs from the register's (the law's start, or the
  row's own LR-34 start; J6 by-order rows as `by_order`) with its class —
  and `<tag>.classes.csv`. Read-only.
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Scraper.{ChangeCollector, LabelTimeline, LawRunner}
  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope

  alias SertantaiLegal.Scraper.Commencement.{
    AmendingRead,
    Effects,
    Evaluator,
    HeldAmenders,
    Order,
    OrderRead,
    Orders,
    OwnClause,
    OwnRead,
    Rule,
    Store
  }

  alias SertantaiLegal.Scraper.LawStart.Input
  alias SertantaiLegal.Scraper.StepProcedures.RuleDiff
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Print, read or compare a law's commencement rules"

  # the first mode asked for, in this order (`--read --law X` reads)
  @modes ~w(read compare orders effects read_orders amenders read_amending law)a

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          all: :boolean,
          read: :boolean,
          compare: :boolean,
          orders: :boolean,
          effects: :boolean,
          read_orders: :boolean,
          read_amending: :boolean,
          amenders: :boolean,
          held: :boolean,
          preview: :boolean,
          family: :string,
          out: :string,
          tag: :string,
          workers: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    dispatch(Enum.find(@modes, &opts[&1]), opts)
  end

  defp dispatch(:read, opts), do: read(laws(opts), opts)
  defp dispatch(:compare, opts), do: compare(laws(opts), opts)
  defp dispatch(:orders, _opts), do: orders()
  defp dispatch(:effects, opts), do: effects(opts)
  defp dispatch(:read_orders, opts), do: read_orders(opts)
  defp dispatch(:amenders, opts), do: amenders(opts)
  defp dispatch(:read_amending, opts), do: read_amending(opts)
  defp dispatch(:law, opts), do: opts[:law] |> Store.for_law() |> print(opts[:law])

  defp dispatch(nil, _opts),
    do:
      Mix.raise(
        "usage: mix lat.commencement --law X | --read (--law X | --all) | --compare --all --tag T"
      )

  defp laws(opts) do
    cond do
      opts[:law] ->
        String.split(opts[:law], ",", trim: true)

      opts[:all] ->
        List.flatten(Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1").rows)

      opts[:family] ->
        Scope.family_laws(opts[:family])

      true ->
        Mix.raise("--law X, --family F or --all")
    end
  end

  defp print([], law),
    do: Mix.shell().info("#{law}: no commencement rules (the readers write them: CR-03, CR-04)")

  defp print(rules, law) do
    Mix.shell().info("#{law}: #{length(rules)} rule(s)")

    rules
    |> Enum.group_by(& &1.source.law)
    |> Enum.each(fn {source, rs} ->
      Mix.shell().info("\n  from #{source}")
      for r <- rs, do: Mix.shell().info("    " <> Rule.to_text(r))
    end)
  end

  # ── --read ──────────────────────────────────────────────────────────

  defp read(laws, opts) do
    results =
      LawRunner.run(
        laws,
        fn law ->
          read_or_preview(law, OwnRead.rules(law), opts)
        end,
        fn _law, _n -> :ok end,
        workers: opts[:workers]
      )

    read_summary(results, opts)
  end

  # a law's own-clause rules written, or with `--preview` compared with the
  # stored ones (a fix's reach: `StepProcedures.RuleDiff`), nothing written
  defp read_or_preview(law, rules, opts) do
    if opts[:preview] do
      diff = RuleDiff.diff(RuleDiff.stored(law, OwnClause.treatments()), rules)

      unless RuleDiff.same?(diff),
        do:
          Mix.shell().info(
            "  #{law}: +#{length(diff.added)} −#{length(diff.gone)} rules#{refs(diff)}"
          )

      {:preview, length(diff.added), length(diff.gone)}
    else
      {:ok, n, how} = Store.write_changed(law, rules, treatments: OwnClause.treatments())
      {how, n}
    end
  end

  defp refs(diff) do
    refs =
      (diff.added ++ diff.gone) |> Enum.map(& &1.source.ref) |> Enum.uniq() |> Enum.take(8)

    if refs == [], do: "", else: " (#{Enum.join(refs, ", ")})"
  end

  defp read_summary(results, opts) do
    errors = for {law, {:error, e}} <- results, do: {law, e}
    values = Map.values(results)

    if opts[:preview] do
      changed = for {:preview, a, g} <- values, a + g > 0, do: {a, g}

      Mix.shell().info(
        "#{map_size(results)} laws read (preview: nothing written): #{length(changed)} laws change, +#{changed |> Enum.map(&elem(&1, 0)) |> Enum.sum()} −#{changed |> Enum.map(&elem(&1, 1)) |> Enum.sum()} rules, #{length(errors)} errors"
      )
    else
      written = for {:written, n} <- values, do: n
      unchanged = Enum.count(values, &match?({:unchanged, _}, &1))
      none = Enum.count(values, &(&1 == 0))

      Mix.shell().info(
        "#{map_size(results)} laws read: #{length(written)} written (#{Enum.sum(written)} rules), #{unchanged} unchanged (stamp only), #{none} with no reading, #{length(errors)} errors"
      )
    end

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{inspect(e)}")
  end

  # ── --read-amending (CR-06) ─────────────────────────────────────────

  # every law a note on our rows points to (one hop), held in the CLML
  # store, with no LAT: its own clause from its CLML
  defp read_amending(opts) do
    # the laws named (CV-07: the amending laws just fetched, which no note
    # may cite yet), else those our notes cite (queried only then)
    laws =
      cond do
        opts[:family] -> for {law, _} <- family_amenders(opts[:family]).read, do: law
        opts[:law] -> String.split(opts[:law], ",", trim: true)
        true -> HeldAmenders.cited_without_lat()
      end
      |> Enum.filter(&HeldAmenders.text_held?/1)

    Mix.shell().info("#{length(laws)} amending laws held with no LAT")

    results =
      LawRunner.run(
        laws,
        fn law ->
          case AmendingRead.rules(law) do
            nil ->
              0

            rules ->
              read_or_preview(law, rules, opts)
          end
        end,
        fn _law, _n -> :ok end,
        workers: opts[:workers]
      )

    read_summary(results, opts)
  end

  # the amending laws of a family's stored changes (never listed by hand:
  # Environmental Protection's list took in 21 commencement orders)
  defp family_amenders(family),
    do: family |> Scope.family_laws() |> HeldAmenders.for_laws()

  # ── --amenders (read-only) ──────────────────────────────────────────

  defp amenders(opts) do
    family = opts[:family] || Mix.raise("--amenders --family F")
    picked = family_amenders(family)
    shell = Mix.shell()

    for {kind, label} <- [
          read: "held, to read",
          orders: "commencement orders (read as orders)",
          lat: "with LAT rows (read by --read)",
          not_held: "not held"
        ] do
      laws = Map.fetch!(picked, kind)

      shell.info(
        "#{length(laws)} #{label}; changes #{laws |> Enum.map(&elem(&1, 1)) |> Enum.sum()}"
      )
    end

    if opts[:out] do
      File.write!(opts[:out], Enum.map_join(picked.read, "\n", &elem(&1, 0)) <> "\n")
      shell.info("the laws to read: #{opts[:out]}")
    end
  end

  # ── --orders / --read-orders (CR-04) ────────────────────────────────

  # the Acts whose amending provisions the amending-law collector reads
  @doc """
  Which Acts `--effects` reads, the store mode and the write's scope:
  `--law A,B` reads those Acts from the store alone and replaces only the
  feed rules commencing them, a law at a time (Fire and OH&S: Commencement reader, Decision
  5 a); else every amending Act, preferring the store.
  """
  @spec effects_scope(keyword()) ::
          {[String.t()] | :amending_acts, :only | :prefer, [] | :per_law}
  def effects_scope(opts) do
    case opts[:law] do
      nil ->
        {:amending_acts, :prefer, []}

      list ->
        {String.split(list, ",", trim: true), :only, :per_law}
    end
  end

  @doc """
  An order's feed rules as writes: all at once, or (`:per_law`) one write
  per law they commence, each replacing only that law's rules.
  """
  @spec effects_writes([Rule.t()], [] | :per_law) :: [{keyword(), [Rule.t()]}]
  def effects_writes(rules, []), do: [{[], rules}]

  def effects_writes(rules, :per_law),
    do:
      rules
      |> Enum.group_by(& &1.commences)
      |> Enum.map(fn {law, rs} -> {[commences: law], rs} end)

  defp amending_acts do
    Repo.query!("""
    SELECT DISTINCT affecting_law FROM lat_change_log
    WHERE collector = 'amending_law' AND affecting_law ~ '^UK_(ukpga|asp|anaw|asc|nia|apni|mwa)_'
    ORDER BY 1
    """).rows
    |> List.flatten()
  end

  # the Act an order commences (`Orders.act/1`); an Act the register holds
  # no title for is named by its own CLML (`Order.title/1`)
  defp act(law) do
    case Orders.act(law) do
      %{title: nil} = act -> %{act | title: (d = doc(law)) && Order.title(d)}
      act -> act
    end
  end

  defp orders do
    lists =
      for law <- amending_acts(), a = act(law), do: {law, Orders.for_act(law, a.title, a.year)}

    all = lists |> Enum.flat_map(&elem(&1, 1)) |> Enum.uniq()
    missing = Enum.reject(all, &order_held?/1)
    dir = "data/reports/commencement-rules"
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "orders_missing.txt"), Enum.join(missing, "\n") <> "\n")

    Mix.shell().info(
      "#{length(lists)} Acts, #{length(all)} commencement orders, #{length(missing)} not held → #{dir}/orders_missing.txt (mix clml.fetch --whole --laws …)"
    )
  end

  # effects first (Jason 2026-10-18): an amending Act's own changes feed
  # (one per Act, through the store) states when its provisions came into
  # force; legislation.gov.uk's changes data covers changes from 2002
  defp effects(opts) do
    # every amending Act: the feed records commencements from 2002 on, of
    # older Acts too (CROW 2000 in 2004–05; EPA 1990 in Scotland in 2015)
    {acts, store, scope} = effects_scope(opts)
    acts = if acts == :amending_acts, do: amending_acts(), else: acts

    {by_order, errors} =
      Enum.reduce(acts, {%{}, []}, fn law, {acc, errs} ->
        [_, t, y, n] = String.split(law, "_", parts: 4)

        case ChangesFeed.fetch(t, y, n, store: store) do
          {:ok, effects} ->
            {Enum.reduce(Effects.rules(law, effects), acc, fn r, a ->
               Map.update(a, r.source.law, [r], &[r | &1])
             end), errs}

          {:error, e} ->
            {acc, [{law, e} | errs]}
        end
      end)

    for {order, rules} <- by_order,
        {opts, rs} <- effects_writes(rules, scope),
        do: Store.write(order, Enum.reverse(rs), [treatments: [:feed_commencement]] ++ opts)

    Mix.shell().info(
      "#{length(acts)} amending Acts, #{map_size(by_order)} commencing instruments, #{by_order |> Map.values() |> List.flatten() |> length()} rules, #{length(errors)} feed errors"
    )

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{e}")
  end

  defp year(law), do: law |> String.split("_") |> Enum.at(2) |> String.to_integer()

  # a labelled law's own commencement orders (CR-07: its by-order rows),
  # every one held
  defp read_orders(opts) do
    cond do
      opts[:family] -> read_law_orders(family_sources(opts[:family]), [held: true] ++ opts)
      opts[:law] -> read_law_orders(String.split(opts[:law], ",", trim: true), opts)
      true -> read_cited_orders(opts)
    end
  end

  # the laws whose rules a family's build reads: its own and its changes'
  # amending laws
  defp family_sources(family) do
    laws = Scope.family_laws(family)
    picked = HeldAmenders.for_laws(laws)

    amenders =
      for kind <- [:read, :orders, :lat, :not_held], {law, _} <- Map.fetch!(picked, kind), do: law

    Enum.uniq(laws ++ amenders)
  end

  defp read_law_orders(laws, opts) do
    totals =
      for law <- laws, orders = law_orders(law, opts[:held]), orders != [] do
        a = act(law)
        stored = Store.for_law(a.law)

        read =
          for order <- orders,
              %{doc: %Doc{}, rules: rules} <- [OrderRead.read(order, a, stored)],
              do: {order, rules}

        unless opts[:preview], do: Enum.each(read, &write_order(&1, a.law))
        report_orders(law, orders, read, stored, opts[:preview])
        {length(read), read |> Enum.map(&length(elem(&1, 1))) |> Enum.sum()}
      end

    Mix.shell().info(
      "#{length(totals)} laws with orders, #{totals |> Enum.map(&elem(&1, 0)) |> Enum.sum()} orders read, #{totals |> Enum.map(&elem(&1, 1)) |> Enum.sum()} rules#{if opts[:preview], do: " (preview: nothing written)"}"
    )
  end

  # the orders to read for a law: its list (searched for when none is kept,
  # unless `--held`) with the orders whose rules for it are stored, so an
  # order a later list drops is read again, never left on an old reading
  defp law_orders(law, true), do: Orders.candidates(Orders.cached(law), Store.order_sources(law))

  defp law_orders(law, _search) do
    a = act(law)
    Orders.candidates(Orders.for_act(law, a.title, a.year), Store.order_sources(law))
  end

  # only its rules for this law: an order listed for two laws keeps the
  # other's (SI 1996/186); an order read as commencing nothing leaves none
  defp write_order({order, rules}, law) do
    {:ok, _} =
      Store.write(order, rules, treatments: [:order_date, :order_schedule], commences: law)
  end

  defp report_orders(law, orders, read, stored, preview?) do
    Mix.shell().info(
      "#{law}: #{length(orders)} orders, #{length(read)} held and read, #{read |> Enum.map(&length(elem(&1, 1))) |> Enum.sum()} rules"
    )

    if preview? do
      was = stored |> Enum.filter(&order_rule?/1) |> Enum.frequencies_by(& &1.source.law)

      for {order, rules} <- read,
          Map.get(was, order, 0) != length(rules),
          do:
            Mix.shell().info(
              "  #{order}: stored #{Map.get(was, order, 0)} → read #{length(rules)}"
            )
    end
  end

  defp order_rule?(rule), do: rule.treatment in [:order_date, :order_schedule]

  # each cited order read for the Act citing it, and written as its rules
  # for that Act alone (an order two Acts cite keeps both Acts' rules; one
  # read as commencing nothing leaves none: a re-read never leaves a stale one)
  defp read_cited_orders(opts) do
    cited = cited_orders()

    read =
      for law <- amending_acts(),
          year(law) < 2002,
          orders = Map.get(cited, law, []),
          orders != [],
          a = act(law),
          stored = Store.for_law(a.law),
          order <- orders,
          %{doc: %Doc{}, rules: rules} <- [OrderRead.read(order, a, stored)],
          do: {{order, rules}, a.law}

    unless opts[:preview], do: for({reading, law} <- read, do: write_order(reading, law))

    Mix.shell().info(
      "#{length(read)} orders read, #{read |> Enum.map(fn {{_, rules}, _} -> length(rules) end) |> Enum.sum()} rules#{if opts[:preview], do: " (preview: nothing written)", else: " written"}"
    )
  end

  # the commencing instruments the notes cite, per amending law (the
  # amending-law collector's records' pointers)
  defp cited_orders do
    %{rows: rows} =
      Repo.query!("""
      SELECT DISTINCT l.affecting_law, a.code, a.text, a.citation_law, a.affected_sections
      FROM lat_change_log l
      JOIN amendment_annotations a ON a.law_name = l.law_name AND a.code = l.pointer
      WHERE l.collector = 'amending_law'
      """)

    for [law, code, text, cl, sids] <- rows,
        {si, _} <-
          SertantaiLegal.Scraper.AmendingLaw.Pointer.parse(%{
            code: code,
            text: text,
            citation_law: cl,
            affected_sections: sids || []
          }).commencing,
        reduce: %{} do
      acc -> Map.update(acc, law, [si], &Enum.uniq([si | &1]))
    end
  end

  # an order is held with its body and its schedules — the table its
  # article brings in ("specified in column 1 of the Schedule to this
  # Order": SI 1976/731) — or a stored 404 where it has none (Decision 1,
  # Jason 2026-11-05: 31 orders were held without their Schedule)
  defp order_held?(law) do
    HeldAmenders.text_held?(law) and
      case String.split(law, "_", parts: 4) do
        [_, t, y, n] -> ClmlStore.get("/#{t}/#{y}/#{n}/schedules/data.xml") != :none
        _ -> false
      end
  end

  defp doc(law) do
    case ClmlStore.law_docs(law) do
      [] -> nil
      xmls -> Doc.new(law, xmls)
    end
  end

  # ── --compare ───────────────────────────────────────────────────────

  @cols ~w(law section_id register evaluated_full evaluated_partial class rules)

  defp compare(laws, opts) do
    tag = opts[:tag] || Mix.raise("--tag")
    dir = "data/reports/commencement-rules"
    File.mkdir_p!(dir)
    path = Path.join(dir, "#{tag}.csv")
    out = File.open!(path, [:write, :utf8])
    IO.write(out, Enum.join(@cols, ",") <> "\n")

    counts =
      laws
      |> LawRunner.run(
        &compare_law/1,
        fn _law, rows ->
          for r <- List.wrap(rows), r.class != "same", do: IO.write(out, csv(r) <> "\n")
        end,
        workers: opts[:workers]
      )
      |> Enum.flat_map(fn
        {_law, rows} when is_list(rows) -> Enum.map(rows, & &1.class)
        {_law, {:error, _}} -> ["error"]
      end)
      |> Enum.frequencies()

    File.close(out)

    File.write!(
      Path.join(dir, "#{tag}.classes.csv"),
      "class,count\n" <>
        Enum.map_join(Enum.sort_by(counts, &(-elem(&1, 1))), "", fn {c, n} -> "#{c},#{n}\n" end)
    )

    Mix.shell().info("#{inspect(counts)}\nreport #{path}")
  end

  defp compare_law(law) do
    {rows, input} = input(law)
    rules = OwnClause.rules(law, input)
    ctx = OwnClause.context(rows)
    law_start = LabelTimeline.law_start(law)
    starts = LabelTimeline.row_starts(law)

    for row <- rows do
      register =
        case Map.get(starts, row.section_id) do
          {"provision_dated", %Date{} = d, _} -> d
          {"provision_by_order", _, _} -> :by_order
          _ -> law_start
        end

      r = Evaluator.evaluate(rules, row.section_id, Map.put(ctx, :extent, row.extent_code))

      %{
        law: law,
        section_id: row.section_id,
        register: register,
        full: r.full_from,
        partial: r.partial_from,
        class: class(register, r),
        rules: Enum.map_join(r.entries, " | ", &Rule.to_text(&1.rule))
      }
    end
  end

  defp class(:by_order, %{full_from: nil, partial_from: nil, undated: [_ | _]}), do: "same"
  defp class(:by_order, %{full_from: nil, partial_from: nil}), do: "by_order → unknown"
  defp class(:by_order, _r), do: "by_order → dated"
  defp class(d, %{full_from: d}), do: "same"
  defp class(nil, %{full_from: nil, partial_from: nil}), do: "same"
  defp class(nil, %{full_from: nil}), do: "unknown → partial"
  defp class(nil, _r), do: "unknown → dated"
  defp class(%Date{} = d, %{partial_from: d}), do: "dated → partial first (qualified)"
  defp class(%Date{}, %{full_from: nil, partial_from: nil}), do: "dated → unknown"
  defp class(%Date{}, %{full_from: nil}), do: "dated → partial only"

  defp class(%Date{} = d, %{full_from: f}),
    do: if(Date.compare(f, d) == :gt, do: "later", else: "earlier")

  defp csv(r) do
    [r.law, r.section_id, val(r.register), val(r.full), val(r.partial), r.class, r.rules]
    |> Enum.map_join(",", &esc/1)
  end

  defp val(nil), do: ""
  defp val(%Date{} = d), do: Date.to_iso8601(d)
  defp val(a), do: to_string(a)

  defp esc(s) do
    s = to_string(s)

    if String.contains?(s, [",", "\"", "\n"]),
      do: "\"" <> String.replace(s, "\"", "\"\"") <> "\"",
      else: s
  end

  # the law's rows (document order) and LawStart's input
  defp input(law) do
    rows = Input.rows(law)
    {rows, ChangeCollector.law_start_input(law, rows)}
  end
end

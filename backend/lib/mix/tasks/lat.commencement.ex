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
      mix lat.commencement --read-orders                    # amending Acts before 2002: the rules the orders their notes cite state (where no effect reaches)
      mix lat.commencement --read-orders --law X,Y          # a labelled law's own commencement orders (CR-07: its by-order rows)
      mix lat.commencement --read-amending                  # amending laws with no LAT: their own clause from the CLML held (CR-06; one hop, no fetch)
      mix lat.commencement --read-amending --law A,B --workers 1   # these amending laws (CV-07: just fetched)

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

  alias SertantaiLegal.Scraper.Commencement.{
    Effects,
    Evaluator,
    Order,
    Orders,
    OwnClause,
    ScheduleEffect,
    Rule,
    Store
  }

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Print, read or compare a law's commencement rules"

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
          tag: :string,
          workers: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:read] ->
        read(laws(opts), opts)

      opts[:compare] ->
        compare(laws(opts), opts)

      opts[:orders] ->
        orders()

      opts[:effects] ->
        effects()

      opts[:read_orders] ->
        read_orders(opts)

      opts[:read_amending] ->
        read_amending(opts)

      opts[:law] ->
        opts[:law] |> Store.for_law() |> print(opts[:law])

      true ->
        Mix.raise(
          "usage: mix lat.commencement --law X | --read (--law X | --all) | --compare --all --tag T"
        )
    end
  end

  defp laws(opts) do
    cond do
      opts[:law] ->
        String.split(opts[:law], ",", trim: true)

      opts[:all] ->
        List.flatten(Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1").rows)

      true ->
        Mix.raise("--law X or --all")
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
          input = clause_input(law)

          {:ok, n} =
            Store.write(
              law,
              OwnClause.rules(law, input) ++ ScheduleEffect.rules(law, input.rows, doc(law)),
              treatments: OwnClause.treatments()
            )

          n
        end,
        fn _law, _n -> :ok end,
        workers: opts[:workers]
      )

    errors = for {law, {:error, e}} <- results, do: {law, e}
    rules = results |> Map.values() |> Enum.filter(&is_integer/1) |> Enum.sum()

    Mix.shell().info(
      "#{map_size(results)} laws read, #{rules} rules written, #{length(errors)} errors"
    )

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{inspect(e)}")
  end

  # ── --read-amending (CR-06) ─────────────────────────────────────────

  # every law a note on our rows points to (one hop), held in the CLML
  # store, with no LAT: its own clause from its CLML
  defp read_amending(opts) do
    %{rows: rows} =
      Repo.query!("""
      SELECT DISTINCT coalesce(a.citation_law, a.changed_by) FROM amendment_annotations a
      WHERE a.code_type = 'amendment' AND coalesce(a.citation_law, a.changed_by) ~ '^UK_'
        AND NOT EXISTS (SELECT 1 FROM legal_articles l WHERE l.law_name = coalesce(a.citation_law, a.changed_by))
      ORDER BY 1
      """)

    # the laws named (CV-07: the amending laws just fetched, which no note
    # may cite yet), else those our notes cite
    laws =
      case opts[:law] do
        nil -> List.flatten(rows)
        list -> String.split(list, ",", trim: true)
      end
      |> Enum.filter(&held?/1)

    Mix.shell().info("#{length(laws)} amending laws held with no LAT")

    results =
      LawRunner.run(
        laws,
        fn law ->
          case doc(law) do
            nil ->
              0

            d ->
              input = ChangeCollector.law_start_input(law, OwnClause.doc_rows(d))

              {:ok, n} =
                Store.write(
                  law,
                  OwnClause.rules(law, input) ++ ScheduleEffect.rules(law, input.rows, d),
                  treatments: OwnClause.treatments()
                )

              n
          end
        end,
        fn _law, _n -> :ok end,
        workers: opts[:workers]
      )

    errors = for {law, {:error, e}} <- results, do: {law, e}
    rules = results |> Map.values() |> Enum.filter(&is_integer/1) |> Enum.sum()

    Mix.shell().info(
      "#{map_size(results)} laws read, #{rules} rules written, #{length(errors)} errors"
    )

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{inspect(e)}")
  end

  # ── --orders / --read-orders (CR-04) ────────────────────────────────

  # the Acts whose amending provisions the amending-law collector reads
  defp amending_acts do
    Repo.query!("""
    SELECT DISTINCT affecting_law FROM lat_change_log
    WHERE collector = 'amending_law' AND affecting_law ~ '^UK_(ukpga|asp|anaw|asc|nia|apni|mwa)_'
    ORDER BY 1
    """).rows
    |> List.flatten()
  end

  defp act(law) do
    [_, _, year, _] = String.split(law, "_", parts: 4)

    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) ->
          t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

        _ ->
          (d = doc(law)) && Order.title(d)
      end

    %{law: law, title: title, year: year}
  end

  defp orders do
    lists =
      for law <- amending_acts(), a = act(law), do: {law, Orders.for_act(law, a.title, a.year)}

    all = lists |> Enum.flat_map(&elem(&1, 1)) |> Enum.uniq()
    missing = Enum.reject(all, &held?/1)
    dir = "data/reports/commencement-rules"
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "orders_missing.txt"), Enum.join(missing, "\n") <> "\n")

    Mix.shell().info(
      "#{length(lists)} Acts, #{length(all)} commencement orders, #{length(missing)} not held → #{dir}/orders_missing.txt (mix clml.fetch --laws …)"
    )
  end

  # effects first (Jason 2026-10-18): an amending Act's own changes feed
  # (one per Act, through the store) states when its provisions came into
  # force; legislation.gov.uk's changes data covers changes from 2002
  defp effects do
    # every amending Act: the feed records commencements from 2002 on, of
    # older Acts too (CROW 2000 in 2004–05; EPA 1990 in Scotland in 2015)
    acts = amending_acts()

    {by_order, errors} =
      Enum.reduce(acts, {%{}, []}, fn law, {acc, errs} ->
        [_, t, y, n] = String.split(law, "_", parts: 4)

        case ChangesFeed.fetch(t, y, n, store: :prefer) do
          {:ok, effects} ->
            {Enum.reduce(Effects.rules(law, effects), acc, fn r, a ->
               Map.update(a, r.source.law, [r], &[r | &1])
             end), errs}

          {:error, e} ->
            {acc, [{law, e} | errs]}
        end
      end)

    for {order, rules} <- by_order,
        do: Store.write(order, Enum.reverse(rules), treatments: [:feed_commencement])

    Mix.shell().info(
      "#{length(acts)} amending Acts, #{map_size(by_order)} commencing instruments, #{by_order |> Map.values() |> List.flatten() |> length()} rules, #{length(errors)} feed errors"
    )

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{e}")
  end

  defp year(law), do: law |> String.split("_") |> Enum.at(2) |> String.to_integer()

  # a labelled law's own commencement orders (CR-07: its by-order rows),
  # every one held
  defp read_orders(opts) do
    case opts[:law] do
      nil -> read_cited_orders()
      laws -> read_law_orders(String.split(laws, ",", trim: true))
    end
  end

  defp read_law_orders(laws) do
    for law <- laws do
      a = act(law)
      orders = Orders.for_act(law, a.title, a.year)

      read =
        for order <- orders, d = doc(order), d != nil do
          {:ok, n} =
            Store.write(
              order,
              Order.rules(d, a) |> Order.resolve_appointed_for(Store.for_law(a.law)),
              treatments: [:order_date, :order_schedule]
            )

          n
        end

      Mix.shell().info(
        "#{law}: #{length(orders)} orders, #{length(read)} held and read, #{Enum.sum(read)} rules"
      )
    end
  end

  defp read_cited_orders do
    cited = cited_orders()

    # every order read is rewritten, with no rules too: a re-read never
    # leaves a stale one
    by_order =
      for law <- amending_acts(),
          year(law) < 2002,
          a = act(law),
          order <- Map.get(cited, law, []),
          d = doc(order),
          d != nil,
          reduce: %{} do
        acc ->
          Map.update(
            acc,
            order,
            Order.rules(d, a) |> Order.resolve_appointed_for(Store.for_law(a.law)),
            &((&1 ++ Order.rules(d, a)) |> Order.resolve_appointed_for(Store.for_law(a.law)))
          )
      end

    for {order, rules} <- by_order,
        do: Store.write(order, rules, treatments: [:order_date, :order_schedule])

    Mix.shell().info(
      "#{map_size(by_order)} orders read, #{by_order |> Map.values() |> List.flatten() |> length()} rules written"
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

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, _, _, _] -> ClmlStore.law_files(law) != []
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

  # the input a law's own clause is read from: its LAT rows — or, for a law
  # whose LAT holds part of it (a scope), its whole CLML held, where its
  # commencement provision is (CV-S04: the REUL Act 2023's scoped LAT holds
  # no s.22, so its clause read as none, Royal Assent)
  defp clause_input(law) do
    with scope when scope not in [nil, []] <- SertantaiLegal.Scraper.LatScope.get(law),
         %Doc{} = d <- doc(law) do
      ChangeCollector.law_start_input(law, OwnClause.doc_rows(d))
    else
      _ -> law |> input() |> elem(1)
    end
  end

  # the law's rows (document order) and LawStart's input
  defp input(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, part, chapter, extent_code FROM legal_articles WHERE law_name = $1 ORDER BY position",
        [law]
      )

    rows =
      for [s, t, p, c, e] <- rows,
          do: %{section_id: s, text: t, part: p, chapter: c, extent_code: e}

    {rows, ChangeCollector.law_start_input(law, rows)}
  end
end

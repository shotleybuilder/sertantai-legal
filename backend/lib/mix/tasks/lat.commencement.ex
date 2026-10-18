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

      mix lat.commencement --read --law X | --all           # write the laws' own-clause rules (CR-03)
      mix lat.commencement --compare --all --tag cr03_cmp   # the evaluator vs today's register, per row

  `--read` writes only `commencement_rules` (no label changes). `--compare`
  writes `data/reports/commencement-rules/<tag>.csv` — each row whose
  evaluated start differs from the register's (the law's start, or the
  row's own LR-34 start; J6 by-order rows as `by_order`) with its class —
  and `<tag>.classes.csv`. Read-only.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeCollector, LabelTimeline, LawRunner}
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, OwnClause, Rule, Store}

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
        [opts[:law]]

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
          {_rows, input} = input(law)
          {:ok, n} = Store.write(law, OwnClause.rules(law, input))
          n
        end,
        fn _law, _n -> :ok end,
        workers: opts[:workers] || LawRunner.default_workers()
      )

    errors = for {law, {:error, e}} <- results, do: {law, e}
    rules = results |> Map.values() |> Enum.filter(&is_integer/1) |> Enum.sum()

    Mix.shell().info(
      "#{map_size(results)} laws read, #{rules} rules written, #{length(errors)} errors"
    )

    for {law, e} <- Enum.take(errors, 10), do: Mix.shell().info("  #{law}: #{inspect(e)}")
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
        workers: opts[:workers] || LawRunner.default_workers()
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
          {"provision_dated", %Date{} = d} -> d
          {"provision_by_order", _} -> :by_order
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

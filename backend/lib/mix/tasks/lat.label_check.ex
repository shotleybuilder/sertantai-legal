defmodule Mix.Tasks.Lat.LabelCheck do
  @moduledoc """
  The label check (change vocabulary CV-S09): a family's provision rows
  folded from their stored changes (`ChangeVocabulary.LabelSource`), in
  the label strata (`ChangeVocabulary.LabelStrata`) — the fold rules
  acting on a row (S, by shape), where the fold differs from today's
  stored label (T, by class) and every row (R, random) — and with
  `--sample FILE` a reproducible sample of one stratum with what judging
  each period needs (`ChangeVocabulary.LabelSample`) for the `label-check`
  agent. S and T are drawn up to `--per` rows of each shape or class
  (default 10); R takes `--n` rows (default 30), `--skip N` the next batch
  of the same draw. Golden (G) is `mix lat.vocabulary --golden`. Read-only.

      mix lat.label_check --family "OH&S: Occupational" --strata
      mix lat.label_check --family F --stratum S --sample FILE --per 10 --seed N
      mix lat.label_check --family F --stratum R --sample FILE --n 30 --seed N [--skip 30]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelSample, LabelSource, LabelStrata}

  @shortdoc "The label check's strata and samples for a family (read-only)"

  @usage "usage: mix lat.label_check --family F [--strata] " <>
           "[--sample FILE --stratum S|T|R --n N --per P --seed S --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          strata: :boolean,
          sample: :string,
          stratum: :string,
          n: :integer,
          per: :integer,
          seed: :integer,
          skip: :integer
        ]
      )

    family = opts[:family] || Mix.raise(@usage)
    stratum = stratum(opts[:stratum])
    if opts[:sample] && !stratum, do: Mix.raise(@usage)

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    {rows, failed} =
      family
      |> PatternSource.family_laws()
      |> Enum.reduce({[], []}, fn law, {rows, failed} ->
        case LabelSource.rows(law) do
          {:error, why} -> {rows, [{law, why} | failed]}
          rs -> {rows ++ Enum.map(rs, &classify(law, &1)), failed}
        end
      end)

    laws = rows |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()
    Mix.shell().info("#{laws} laws folded; #{length(rows)} rows; not folded: #{inspect(failed)}")

    if opts[:strata], do: strata(rows)
    if path = opts[:sample], do: sample(rows, stratum, path, opts)
  end

  defp classify(law, row) do
    {law, row, LabelStrata.shapes(row.id, row.periods, row.reaching),
     LabelStrata.difference(row.periods, row.today)}
  end

  defp sample(rows, stratum, path, opts) do
    seed = opts[:seed] || 1
    index = Map.new(rows, fn {law, row, _, _} = r -> {{law, row.id}, r} end)

    drawn =
      rows
      |> Enum.map(fn {law, row, _, _} -> {law, row.id} end)
      |> LabelStrata.draw(length(rows), seed)

    picked =
      case stratum do
        :R ->
          drawn |> Enum.drop(opts[:skip] || 0) |> Enum.take(opts[:n] || 30)

        s ->
          drawn
          |> Enum.flat_map(fn k -> for p <- patterns(index[k], s), do: {p, k} end)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Enum.sort()
          |> Enum.flat_map(fn {_, ks} -> Enum.take(ks, opts[:per] || 10) end)
          |> Enum.uniq()
      end

    items =
      picked
      |> Enum.with_index(1)
      |> Enum.map(fn {k, i} ->
        {law, row, shapes, diff} = index[k]
        LabelSample.item({law, row}, stratum, shapes, diff, i)
      end)

    File.write!(path, Jason.encode!(items, pretty: true))

    Mix.shell().info(
      "sample: #{length(items)} rows (seed #{seed}, stratum #{stratum}, skip #{opts[:skip] || 0}) → #{path}"
    )
  end

  defp patterns({_, _, shapes, _}, :S), do: shapes
  defp patterns({_, _, _, nil}, :T), do: []
  defp patterns({_, _, _, diff}, :T), do: [diff]

  defp strata(rows) do
    tally("\nS shapes (rows):", for({_, _, shapes, _} <- rows, s <- shapes, do: to_string(s)))
    tally("\nT differences from today (rows):", for({_, _, _, d} <- rows, d != nil, do: d))

    status =
      for {_, row, _, _} <- rows,
          p = List.last(row.periods),
          do: if(p, do: to_string(p.status), else: "no periods")

    tally("\ncurrent status (rows):", status)
  end

  defp tally(title, items) do
    Mix.shell().info(title)

    for {k, n} <- items |> Enum.frequencies() |> Enum.sort_by(fn {k, n} -> {-n, k} end),
        do: Mix.shell().info("  #{n}  #{k}")
  end

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(S T R), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)
end

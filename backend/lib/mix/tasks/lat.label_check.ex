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
  of the same draw. Golden (G) is `mix lat.vocabulary --golden`.

  `--gate` (Maritime Safety: Label fold, Decision 1) groups every breach of
  the label rules and the table's rules by rule and law
  (`ChangeVocabulary.Gate.Label`), reviewed in
  `test/fixtures/label/labels.json`; `--all` prints every group, else the
  groups not named; then the gaps by shape. `--laws L1,L2` folds only the
  family's laws named (a pre-flight). Read-only.

      mix lat.label_check --family "OH&S: Occupational" --strata
      mix lat.label_check --family F --gate [--all] [--laws L1,L2]
      mix lat.label_check --family F --stratum S --sample FILE --per 10 --seed N
      mix lat.label_check --family F --stratum R --sample FILE --n 30 --seed N [--skip 30]
      mix lat.label_check --family F --stratum SR --sample FILE --per 2 --n 23 --seed N
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Scraper.Amendment.PatternSource

  alias SertantaiLegal.Scraper.ChangeVocabulary.{
    KnownLimits,
    LabelPeriods,
    LabelSample,
    LabelSource,
    LabelStrata
  }

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Label, as: Gate
  alias SertantaiLegal.Scraper.ChangeVocabulary.LabelRules.Context

  @reviewed "test/fixtures/label/labels.json"

  @shortdoc "The label check's strata and samples for a family (read-only)"

  @usage "usage: mix lat.label_check --family F [--strata] [--gate [--all]] [--laws L1,L2] " <>
           "[--sample FILE --stratum S|T|R|SR --n N --per P --seed S --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          strata: :boolean,
          gate: :boolean,
          all: :boolean,
          laws: :string,
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
      |> only(opts[:laws])
      |> Enum.reduce({[], []}, fn law, {rows, failed} ->
        case LabelSource.rows(law) do
          {:error, why} -> {rows, [{law, why} | failed]}
          rs -> {rows ++ Enum.map(rs, &classify(law, &1)), failed}
        end
      end)

    laws = rows |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length()
    Mix.shell().info("#{laws} laws folded; #{length(rows)} rows; not folded: #{inspect(failed)}")

    if opts[:strata], do: strata(rows)
    step = if opts[:gate], do: gate(rows, opts[:all])
    if path = opts[:sample], do: sample(rows, stratum, path, opts)
    step
  end

  defp only(laws, nil), do: laws
  defp only(laws, named), do: Enum.filter(laws, &(&1 in String.split(named, ",")))

  defp gate(rows, all?) do
    shell = Mix.shell()
    folded = for {law, row, _, _} <- rows, do: Map.put(row, :law, law)
    ctx = Context.for_rows(folded)
    known = KnownLimits.sids()

    entries =
      folded
      |> Enum.group_by(& &1.law)
      |> Enum.flat_map(fn {law, rs} -> Gate.entries(law, rs, ctx, known) end)

    items = Gate.items(entries, reviewed())
    gate = Gate.gate(items)

    counts = Enum.map_join(gate.counts, ", ", fn {k, n} -> "#{k} #{n}" end)
    shell.info("\nlabel breaches by rule (#{@reviewed}): #{length(items)} groups; #{counts}")
    shown = if all?, do: Enum.sort_by(items, &{-&1.reach, &1.law, &1.shape}), else: gate.failing

    shell.info(
      "\n#{if all?, do: "every group", else: "not named"} (widest reach first): #{length(shown)}"
    )

    for i <- shown do
      shell.info("  #{pad(i.reach)}  #{i.shape} @ #{i.law}  [#{i.status || "no status"}]")
      for w <- Enum.take(i.words, 6), do: shell.info("           #{w}")
    end

    shell.info("\ngaps, a value no source gives (rows):")

    for {shape, n} <- rows |> Enum.map(&elem(&1, 2)) |> Gate.gaps() |> Enum.sort(),
        do: shell.info("  #{pad(n)}  #{shape}")

    shell.info(
      "\n#{if gate.pass?, do: "PASS", else: "FAIL"} (groups not named: #{length(gate.failing)})"
    )

    Step.new("Label fold", gate.pass?, length(gate.failing))
  end

  defp reviewed do
    case File.read(@reviewed) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 5)

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

    picked = pick(drawn, index, stratum, opts)

    items =
      picked
      |> Enum.with_index(1)
      |> Enum.map(fn {{k, s}, i} ->
        {law, row, shapes, diff} = index[k]
        LabelSample.item({law, row}, s, shapes, diff, i)
      end)

    File.write!(path, Jason.encode!(items, pretty: true))

    Mix.shell().info(
      "sample: #{length(items)} rows (seed #{seed}, stratum #{stratum}, skip #{opts[:skip] || 0}) → #{path}"
    )
  end

  # each drawn row with the stratum it was drawn for; SR (Maritime Safety:
  # Label fold, Decision 1): S by shape, then `--n` rows at random apart
  defp pick(drawn, _index, :R, opts),
    do: drawn |> Enum.drop(opts[:skip] || 0) |> Enum.take(opts[:n] || 30) |> tag(:R)

  defp pick(drawn, index, :SR, opts) do
    s = by_shape(drawn, index, :S, opts[:per])
    rest = drawn |> Enum.reject(&(&1 in s)) |> Enum.take(opts[:n] || 30)
    tag(s, :S) ++ tag(rest, :R)
  end

  defp pick(drawn, index, s, opts), do: drawn |> by_shape(index, s, opts[:per]) |> tag(s)

  defp by_shape(drawn, index, s, per) do
    drawn
    |> Enum.flat_map(fn k -> for p <- patterns(index[k], s), do: {p, k} end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort()
    |> Enum.flat_map(fn {_, ks} -> Enum.take(ks, per || 10) end)
    |> Enum.uniq()
  end

  defp tag(ks, s), do: Enum.map(ks, &{&1, s})

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

    # the periods as timeline rows (CV-05): the table's rules hold
    timeline =
      Enum.flat_map(rows, fn {law, row, _, _} ->
        LabelPeriods.periods(law, row.sid, row.periods, row.reaching)
      end)

    violations = LabelPeriods.violations(timeline)

    Mix.shell().info(
      "\ntimeline rows: #{length(timeline)} periods, #{length(violations)} breaking the table's rules"
    )

    tally("  by rule:", for({_, why} <- violations, do: to_string(why)))
  end

  defp tally(title, items) do
    Mix.shell().info(title)

    for {k, n} <- items |> Enum.frequencies() |> Enum.sort_by(fn {k, n} -> {-n, k} end),
        do: Mix.shell().info("  #{n}  #{k}")
  end

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(S T R SR), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)
end

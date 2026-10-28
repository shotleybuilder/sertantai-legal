defmodule Mix.Tasks.Lat.AmendingCheck do
  @moduledoc """
  The amendment reader's precision check (change vocabulary CV-S06): how
  many of a family's stored changes the amending law's text states (alone,
  or with legislation.gov.uk), and with `--sample FILE` a reproducible
  random sample of them with the words behind each (`Amendment.CheckSample`)
  for the `amending-reader-check` agent. `--strata` counts the strata
  (agreeing, disagreeing, law text only; `Amendment.CheckStrata`) and the
  agreement with legislation.gov.uk over every both-sourced change;
  `--stratum A|D|L` samples one stratum, `--skip N` the next batch of the
  same draw. Read-only.

      mix lat.amending_check --family "OH&S: Occupational" --strata
      mix lat.amending_check --family F --sample FILE --n 50 --seed N [--stratum A] [--skip 50]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, CheckStrata, PatternSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store

  @shortdoc "The amendment reader's precision sample for a family (read-only)"

  @usage "usage: mix lat.amending_check --family F [--strata] " <>
           "[--sample FILE --n N --seed S --stratum A|D|L --skip K]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          sample: :string,
          n: :integer,
          seed: :integer,
          strata: :boolean,
          stratum: :string,
          skip: :integer
        ]
      )

    family = opts[:family] || Mix.raise(@usage)
    stratum = stratum(opts[:stratum])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = PatternSource.family_laws(family)
    by_law = Map.new(laws, &{&1, Store.for_law(&1)})

    classified =
      for {law, changes} <- by_law, {c, s} <- CheckStrata.classify(changes), do: {law, c, s}

    stated = Enum.frequencies_by(classified, fn {_, c, _} -> CheckSample.stated_by(c) end)

    Mix.shell().info(
      "#{length(laws)} laws; changes the law's text states: #{length(classified)} #{inspect(stated)}"
    )

    if opts[:strata], do: strata(classified, by_law)

    if path = opts[:sample] do
      seed = opts[:seed] || 1

      items =
        for({law, c, s} <- classified, stratum in [nil, s], do: {law, c})
        |> CheckSample.draw(length(classified), seed)
        |> Enum.drop(opts[:skip] || 0)
        |> Enum.take(opts[:n] || 50)
        |> Enum.with_index(1)
        |> Enum.map(fn {lc, i} -> CheckSample.item(lc, i) end)

      File.write!(path, Jason.encode!(items, pretty: true))

      Mix.shell().info(
        "sample: #{length(items)} changes (seed #{seed}, stratum #{stratum || "all"}, " <>
          "skip #{opts[:skip] || 0}) → #{path}"
      )
    end
  end

  defp strata(classified, by_law) do
    counts = Enum.frequencies_by(classified, &elem(&1, 2))
    total = length(classified)

    Mix.shell().info("\nstrata:")

    for {s, label} <- [A: "agreeing", D: "disagreeing", L: "law text only"] do
      n = Map.get(counts, s, 0)
      Mix.shell().info("  #{s}  #{label}: #{n} (#{pct(n, total)})")
    end

    agreement =
      by_law
      |> Map.values()
      |> Enum.map(&CheckStrata.agreement/1)
      |> Enum.reduce(%{}, &Map.merge(&2, &1, fn _, {a1, n1}, {a2, n2} -> {a1 + a2, n1 + n2} end))

    Mix.shell().info("\nagreement with legislation.gov.uk over both-sourced changes:")

    for {attribute, {a, n}} <- Enum.sort(agreement),
        do: Mix.shell().info("  #{attribute}: #{a}/#{n} (#{pct(a, n)})")
  end

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(A D L), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)

  defp pct(_, 0), do: "–"
  defp pct(a, n), do: :erlang.float_to_binary(100 * a / n, decimals: 1) <> "%"
end

defmodule Mix.Tasks.Lat.AmendingCheck do
  @moduledoc """
  The amendment reader's precision check (change vocabulary CV-S06): how
  many of a family's stored changes the amending law's text states (alone,
  or with legislation.gov.uk), and with `--sample FILE` a reproducible
  random sample of them with the words behind each (`Amendment.CheckSample`)
  for the `amending-reader-check` agent. Read-only.

      mix lat.amending_check --family "OH&S: Occupational"
      mix lat.amending_check --family F --sample FILE --n 50 --seed N
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, PatternSource}

  @shortdoc "The amendment reader's precision sample for a family (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, sample: :string, n: :integer, seed: :integer]
      )

    family =
      opts[:family] ||
        Mix.raise("usage: mix lat.amending_check --family F [--sample FILE --n N --seed S]")

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = PatternSource.family_laws(family)
    population = CheckSample.population(laws)

    stated = Enum.frequencies_by(population, fn {_, c} -> CheckSample.stated_by(c) end)

    Mix.shell().info(
      "#{length(laws)} laws; changes the law's text states: #{length(population)} #{inspect(stated)}"
    )

    if path = opts[:sample] do
      items =
        population
        |> CheckSample.draw(opts[:n] || 50, opts[:seed] || 1)
        |> Enum.with_index(1)
        |> Enum.map(fn {lc, i} -> CheckSample.item(lc, i) end)

      File.write!(path, Jason.encode!(items, pretty: true))
      Mix.shell().info("sample: #{length(items)} changes (seed #{opts[:seed] || 1}) → #{path}")
    end
  end
end

defmodule Mix.Tasks.Lat.Commencement do
  @moduledoc """
  A law's commencement ruleset (commencement-rules CR-01), one readable line
  per rule — what it brings into force, when, where and how far, its
  treatment, and the words it came from:

      mix lat.commencement --law UK_uksi_2017_469

      art.1, art.2, art.11 — made + 1 day — everywhere, fully — made_relative — UK_uksi_2017_469 art.1(2): “…”
      rest — 2017-05-08 — everywhere, fully — clause_date — UK_uksi_2017_469 art.1(3): “…”

  Grouped by the source read (the law's own clause, each commencement
  order). The rules are written by the readers (CR-03, CR-04). Report only.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.Commencement.{Rule, Store}

  @shortdoc "Print a law's commencement rules, one readable line each"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [law: :string])
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    case opts[:law] do
      nil -> Mix.raise("usage: mix lat.commencement --law LAW_NAME")
      law -> law |> Store.for_law() |> print(law)
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
end

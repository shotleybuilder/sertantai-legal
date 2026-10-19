defmodule Mix.Tasks.Lat.Amending do
  @moduledoc """
  A law's amendment ruleset (amendment-rules AR-01), one readable line per
  rule — the law and targets, the operation (words-level or whole
  provisions), its treatment, and the amending provision it came from:

      mix lat.amending --law UK_uksi_2014_1638

      UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C … substitute—”

  Grouped by the amending law. The readers write the rules (AR-03).
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.{Rule, Store}

  @shortdoc "Print a law's amendment rules"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [law: :string])
    law = opts[:law] || Mix.raise("usage: mix lat.amending --law X")

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    for line <- law |> Store.for_law() |> print(law), do: Mix.shell().info(line)
  end

  @doc "The printed lines for a law's rules."
  @spec print([Rule.t()], String.t()) :: [String.t()]
  def print([], law), do: ["#{law}: no amendment rules (the readers write them: AR-03)"]

  def print(rules, law) do
    groups =
      rules
      |> Enum.group_by(& &1.source.law)
      |> Enum.sort()
      |> Enum.flat_map(fn {source, rs} ->
        ["", "  from #{source}" | Enum.map(rs, &("    " <> Rule.to_text(&1)))]
      end)

    ["#{law}: #{length(rules)} rule(s)" | groups]
  end
end

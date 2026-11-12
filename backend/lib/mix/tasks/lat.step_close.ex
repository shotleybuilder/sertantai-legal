defmodule Mix.Tasks.Lat.StepClose do
  @moduledoc """
  A step's close check for one family (Tooling: step-close check): every
  gate up to the step re-run (`ChangeVocabulary.Gate.Steps.through/1`,
  `mix lat.gates`), the switch-over's checked rows (`mix lat.label_checked`)
  and the family's stale laws (`mix lat.stale --family`; only the switched
  families' labels once the step is Switch-over). One line per check; the
  task exits non-zero when any fails, naming who takes it. A gate that
  passed at its step's close fails once a later step changes shared code
  (four times over three families), so no step closes without this.
  A failure is parked with its owner, never fixed in the closing step.
  Read-only.

      mix lat.step_close --family "ENVIRONMENTAL PROTECTION" --step "Merge"

  Time: minutes through the Amending-law reader; the Label fold's gate
  folds the family (about 12½ min).
  """
  use Mix.Task

  alias Mix.Tasks.Lat.Gates
  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.{Step, Steps}

  @shortdoc "A step's close: every gate up to it, the checked rows, stale laws (read-only)"

  @usage ~s(usage: mix lat.step_close --family F --step "Step name")

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [family: :string, step: :string])
    family = opts[:family] || Mix.raise(@usage)
    step = opts[:step] || Mix.raise(@usage)
    gates = Steps.through(step)

    results =
      Gates.results(family, gates) ++
        [
          Gates.check("Checked rows", "lat.label_checked", []),
          Gates.check("Stale laws", "lat.stale", ["--family", family | stale_args(step)])
        ]

    summary = Step.summary(results)
    Mix.shell().info("\n#{step}'s close, #{family}:")
    for l <- summary.lines, do: Mix.shell().info("  #{l}")
    Mix.shell().info("\n#{if summary.pass?, do: "PASS", else: "FAIL"} (step close)")

    if not summary.pass?, do: exit({:shutdown, 1})
    summary
  end

  # once switched, the family's labels come from the change register alone
  defp stale_args("Switch-over"), do: ["--switched"]
  defp stale_args(_), do: []
end

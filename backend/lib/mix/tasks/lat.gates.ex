defmodule Mix.Tasks.Lat.Gates do
  @moduledoc """
  Every step's gate re-run for one family (Maritime Safety: Store and
  build): a rebuild after a step closes can move that step's gate (on
  2026-11-06 three Maritime gates had passed and failed), so the build's
  check re-runs them all. Each step's check task runs as it does alone,
  with its gate, and returns its result (`ChangeVocabulary.Gate.Step`);
  one line per step follows, and the task exits non-zero when any fails.
  A failure belongs to its step: it is parked there, never fixed here.

      mix lat.gates --family "TRANSPORT: Maritime Safety"

  `mix lat.vocabulary --check --family F` ends with it. The label gate
  folds the family (about 12½ min on Maritime Safety).
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  @shortdoc "Re-run every step's gate for a family; fail when any fails"

  # each step's check task and the arguments that run its gate
  @steps [
    {"Sources", "lat.sources", []},
    {"Feed reader", "lat.feed_check", []},
    {"Markup reader", "lat.markup_check", []},
    {"Commencement reader", "lat.commencement_check", []},
    {"Extent reader", "lat.extent_check", []},
    {"Amending-law reader", "lat.amending_check", ["--gate"]},
    {"Merge", "lat.merge_check", ["--gate"]},
    {"Evidence", "lat.evidence_check", ["--gate"]},
    {"Label fold", "lat.label_check", ["--gate"]}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [family: :string])
    family = opts[:family] || Mix.raise("usage: mix lat.gates --family F")

    results =
      for {step, task, extra} <- @steps do
        Mix.shell().info("\n── #{step} (mix #{task}) ──")
        result(step, Mix.Task.rerun(task, ["--family", family | extra]))
      end

    summary = Step.summary(results)
    Mix.shell().info("\nevery step's gate, #{family}:")
    for l <- summary.lines, do: Mix.shell().info("  #{l}")
    Mix.shell().info("\n#{if summary.pass?, do: "PASS", else: "FAIL"} (gates)")

    if not summary.pass?, do: exit({:shutdown, 1})
    summary
  end

  defp result(_step, %Step{} = r), do: r
  defp result(step, other), do: {step, other}
end

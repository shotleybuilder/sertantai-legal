defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.Steps do
  @moduledoc """
  The LAT Change Pipeline's 14 steps in order, each with the check task
  and arguments that run its gate, or none (Tooling: step-close check).
  A step closes on every gate up to it re-run (`mix lat.step_close`), as
  the build's check re-runs them all (`mix lat.gates`): a gate that passed
  at its step's close fails once later steps change shared code (four
  times over three families, 2026-10-22 to 2026-11-11). Outside
  `ChangeVocabulary.Version`'s files: a check, never what a build reads.
  Pure.
  """

  @steps [
    {"Making laws", nil},
    {"Sources", {"lat.sources", []}},
    {"Feed reader", {"lat.feed_check", []}},
    {"Markup reader", {"lat.markup_check", []}},
    {"Commencement reader", {"lat.commencement_check", []}},
    {"Extent reader", {"lat.extent_check", []}},
    {"Amending-law reader", {"lat.amending_check", ["--gate"]}},
    {"Merge", {"lat.merge_check", ["--gate"]}},
    {"Evidence", {"lat.evidence_check", ["--gate"]}},
    {"Label fold", {"lat.label_check", ["--gate"]}},
    {"Measures", nil},
    {"Store and build", nil},
    {"Labels side by side", nil},
    {"Switch-over", nil}
  ]

  @type gate :: {step :: String.t(), task :: String.t(), args :: [String.t()]}

  @doc "Every step's name, in the pipeline's order."
  @spec names() :: [String.t()]
  def names, do: Enum.map(@steps, &elem(&1, 0))

  @doc "Every step's gate, in order (the steps with no gate task left out)."
  @spec gates() :: [gate()]
  def gates, do: for({step, {task, args}} <- @steps, do: {step, task, args})

  @doc """
  The gates a step closes on: its own and every earlier step's. Raises on
  a name that is no step.
  """
  @spec through(String.t()) :: [gate()]
  def through(step) do
    index =
      Enum.find_index(names(), &(&1 == step)) ||
        raise ArgumentError,
              "no step #{inspect(step)}; the steps: #{Enum.join(names(), ", ")}"

    upto = @steps |> Enum.take(index + 1) |> Enum.map(&elem(&1, 0))
    Enum.filter(gates(), fn {s, _, _} -> s in upto end)
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step do
  @moduledoc """
  One step's gate result, as its check task returns it, and the summary
  of every step's (Maritime Safety: Store and build). A rebuild after a
  step closes can move that step's gate, so the build's check
  (`mix lat.gates`, which `mix lat.vocabulary --check --family` runs)
  re-runs them all and passes only when each does. A failure belongs to
  the step whose gate it is, and is parked there. Outside
  `ChangeVocabulary.Version`'s files: a check, never what a build reads.
  Pure.
  """

  @enforce_keys [:step, :pass?]
  defstruct [:step, :pass?, :owner, failing: 0]

  @type t :: %__MODULE__{
          step: String.t(),
          pass?: boolean(),
          failing: non_neg_integer(),
          owner: String.t() | nil
        }

  @doc """
  A check's result: `failing` counts what failed it (groups not named,
  faults). A check that is no step's gate (the checked rows, stale laws)
  names in `owner:` who takes its failures; a step's gate is its own.
  """
  @spec new(String.t(), boolean(), non_neg_integer(), keyword()) :: t()
  def new(step, pass?, failing \\ 0, opts \\ []),
    do: %__MODULE__{step: step, pass?: pass?, failing: failing, owner: opts[:owner]}

  @doc """
  The results in order: pass only when every step passed; the failing
  steps' names; one line each. A task that returned no result is given as
  `{step, value}` and fails.
  """
  @spec summary([t() | {String.t(), term()}]) :: %{
          pass?: boolean(),
          failing: [String.t()],
          lines: [String.t()]
        }
  def summary(results) do
    failing = for r <- results, not passed?(r), do: name(r)
    %{pass?: failing == [], failing: failing, lines: Enum.map(results, &line/1)}
  end

  defp passed?(%__MODULE__{pass?: p}), do: p
  defp passed?(_), do: false

  defp name(%__MODULE__{step: s}), do: s
  defp name({s, _}), do: s

  defp line(%__MODULE__{step: s, pass?: true}), do: "PASS  #{s}"

  defp line(%__MODULE__{step: s, failing: n, owner: nil}),
    do: "FAIL  #{s} (#{n} failing; owned by the #{s} step)"

  defp line(%__MODULE__{step: s, failing: n, owner: owner}),
    do: "FAIL  #{s} (#{n} failing; #{owner})"

  defp line({s, _}), do: "FAIL  #{s} (no gate result returned)"
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.StepBugs do
  @moduledoc """
  The step report's bugs by owner (Jason 2026-11-19, after Waste, Water and
  Climate: Feed reader): the step session's frontmatter bugs sorted into
  four buckets, so a step's close says plainly what it fixed, what it left,
  what it passed on and what it inherited.

  - **This step, fixed:** the session's bugs marked `fixed` (or `moved`,
    with a pointer), whatever step they were raised under.
  - **This step, left open:** `open`, owned by this step, with their size.
  - **Passed to other steps:** `open`, owned by another step.
  - **Inherited:** the close's failing checks owned by another step (a
    gate of an earlier step, the checked rows, stale laws).

  Outside `ChangeVocabulary.Version`'s files: a report, never what a build
  reads. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  @type bug :: %{category: String.t(), step: String.t(), affected: String.t()}
  @type inherited :: %{check: String.t(), failing: non_neg_integer()}
  @type t :: %{
          fixed: [bug()],
          left_open: [bug()],
          passed_on: [bug()],
          inherited: [inherited()]
        }

  @doc """
  The buckets for `step`, from the session's `bugs` (frontmatter maps with
  string keys; nil when it has none) and the close's check results.
  """
  @spec buckets([map()] | nil, String.t(), [Step.t() | {String.t(), term()}]) :: t()
  def buckets(bugs, step, results) do
    bugs = Enum.map(bugs || [], &bug/1)
    open = Enum.filter(bugs, &(&1.status == "open"))
    {here, other} = Enum.split_with(open, &(&1.step == step))

    %{
      fixed: Enum.filter(bugs, &(&1.status in ["fixed", "moved"])),
      left_open: here,
      passed_on: Enum.sort_by(other, &{&1.step, &1.category}),
      inherited: for(r <- results, inherited?(r, step), do: inherited(r))
    }
  end

  @doc "The buckets as report lines, each bucket named, empty ones as \"none\"."
  @spec lines(t()) :: [String.t()]
  def lines(b) do
    ["Bugs by owner:"] ++
      section("This step, fixed", b.fixed, &label/1) ++
      section("This step, left open", b.left_open, &sized/1) ++
      section("Passed to other steps", b.passed_on, &"#{&1.step}: #{sized(&1)}") ++
      section("Inherited from other steps", b.inherited, &"#{&1.check} (#{&1.failing} failing)")
  end

  defp section(title, [], _show), do: ["  #{title} (0): none"]

  defp section(title, items, show),
    do: ["  #{title} (#{length(items)}):" | Enum.map(items, &"    - #{show.(&1)}")]

  defp label(bug), do: bug.category
  defp sized(%{affected: ""} = bug), do: bug.category
  defp sized(bug), do: "#{bug.category} (#{bug.affected})"

  defp bug(map) do
    %{
      category: to_string(map["category"] || map["pattern"] || "?"),
      step: to_string(map["step"] || "?"),
      status: to_string(map["status"] || "open"),
      affected: to_string(map["affected"] || "")
    }
  end

  defp inherited?(%Step{pass?: false, step: s}, step), do: s != step
  defp inherited?(%Step{}, _step), do: false
  defp inherited?({s, _}, step), do: s != step

  defp inherited(%Step{step: s, failing: n}), do: %{check: s, failing: n}
  defp inherited({s, _}), do: %{check: s, failing: 0}
end

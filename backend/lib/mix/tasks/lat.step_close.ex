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
  Then the step report's bugs by owner (`Gate.StepBugs`), from the step
  session's frontmatter (`.claude/sessions/**`, titled "<family>: <step>"):
  fixed here, left open here, passed to other steps, inherited. Read-only.

      mix lat.step_close --family "ENVIRONMENTAL PROTECTION" --step "Merge"

  Time: minutes through the Amending-law reader; the Label fold's gate
  folds the family (about 12½ min).
  """
  use Mix.Task

  alias Mix.Tasks.Lat.Gates
  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.{Step, StepBugs, Steps}

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
    Mix.shell().info("")
    for l <- bugs_report(family, step, results), do: Mix.shell().info(l)
    Mix.shell().info("\n#{if summary.pass?, do: "PASS", else: "FAIL"} (step close)")

    if not summary.pass?, do: exit({:shutdown, 1})
    summary
  end

  @sessions "../.claude/sessions"

  # the step session's bugs, sorted by owner; its frontmatter is fresher
  # than the session index, which is rebuilt only at the session's close
  defp bugs_report(family, step, results) do
    case session(String.downcase("#{family}: #{step}")) do
      nil ->
        ["Bugs by owner: no step session titled \"#{family}: #{step}\""]

      {path, front} ->
        [
          Path.relative_to(path, @sessions)
          | StepBugs.lines(StepBugs.buckets(front["bugs"], step, results))
        ]
    end
  end

  defp session(title) do
    Path.wildcard(Path.join(@sessions, "**/*.md"))
    |> Enum.sort(:desc)
    |> Enum.find_value(fn path ->
      front = frontmatter(path)
      if String.downcase(to_string(front["session"])) == title, do: {path, front}
    end)
  end

  defp frontmatter(path) do
    with {:ok, body} <- File.read(path),
         [_, yaml | _] <- String.split(body, ~r/^---\s*$/m, parts: 3),
         {:ok, %{} = front} <- YamlElixir.read_from_string(yaml) do
      front
    else
      _ -> %{}
    end
  end

  # once switched, the family's labels come from the change register alone
  defp stale_args("Switch-over"), do: ["--switched"]
  defp stale_args(_), do: []
end

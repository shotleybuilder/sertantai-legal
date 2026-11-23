defmodule Mix.Tasks.Lat.Reread do
  @moduledoc """
  The Commencement reader's re-read chain for a family or round: the stale
  rules its builds read, sorted into the substeps that re-read them (own
  clause, amending laws' clause, held orders, feed effects), then the
  family's rebuild and `mix lat.stale` (`StepProcedures.Reread`).

      mix lat.reread --family "Waste, Water and Climate"            # the chain, printed (read-only)
      mix lat.reread --family "Waste, Water and Climate" --run --tag wwc-reread   # runs it, on Jason's go

  `--run` writes: each substep runs in turn as its own `mix` under
  `systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0`, its
  output to `data/reports/commencement-reader/<tag>-<substep>.txt`, and
  stops at the first failure. Take a restore point of `commencement_rules`,
  `provision_changes` and `provision_change_claims` first.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.StepProcedures.{Reread, RereadStale}
  alias SertantaiLegal.Scraper.StepProcedures.Reread.Step

  @shortdoc "The Commencement reader's re-read chain for a family (printed; --run runs it)"
  @usage ~s(usage: mix lat.reread --family F [--run --tag T])
  @reports "data/reports/commencement-reader"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [family: :string, run: :boolean, tag: :string])

    family = opts[:family] || Mix.raise(@usage)
    Mix.Task.run("app.start")

    steps = family |> RereadStale.rules() |> Reread.chain(family)
    print(family, steps)
    if opts[:run] && steps != [], do: execute(steps, opts[:tag] || Mix.raise(@usage))
  end

  defp print(family, []),
    do: Mix.shell().info("#{family}: no stale commencement rule; nothing to re-read")

  defp print(family, steps) do
    Mix.shell().info("#{family}: the re-read chain (#{length(steps)} substeps)")

    for %Step{} = s <- steps do
      laws = if s.laws == [], do: "", else: " (#{length(s.laws)} laws)"
      Mix.shell().info("  #{s.substep}#{laws}: mix #{Enum.map_join(s.args, " ", &shell_arg/1)}")
    end
  end

  defp execute(steps, tag) do
    results = Reread.run(steps, &run_step(&1, tag))
    for {s, exit, secs} <- results, do: Mix.shell().info("#{s} exit #{exit} #{secs} s")
    if Enum.any?(results, fn {_, exit, _} -> exit != 0 end), do: exit({:shutdown, 1})
  end

  defp run_step(%Step{substep: s, args: args}, tag) do
    out = Path.join(@reports, "#{tag}-#{s}.txt")
    t0 = System.monotonic_time(:second)
    scope = ~w(--user --scope -q -p MemoryMax=12G -p MemorySwapMax=0 mix)

    {_, exit} =
      System.cmd("systemd-run", scope ++ args, into: File.stream!(out), stderr_to_stdout: true)

    {exit, System.monotonic_time(:second) - t0}
  end

  defp shell_arg(arg), do: if(String.contains?(arg, [" ", "&"]), do: ~s("#{arg}"), else: arg)
end

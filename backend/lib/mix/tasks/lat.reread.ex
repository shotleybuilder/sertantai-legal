defmodule Mix.Tasks.Lat.Reread do
  @moduledoc """
  The re-read chain for a family or round: first the amending laws behind
  its builds' `:amending_reader` (not read, old reader code, or not read
  for a built law: `StepProcedures.AmendingStale`), then the stale
  commencement rules its builds read, sorted into the substeps that re-read
  them (own clause, amending laws' clause, held orders, feed effects), then
  the stale extent readings (old reader code, or not read:
  `StepProcedures.ExtentStale`), then the family's rebuild and `mix
  lat.stale` (`StepProcedures.Reread`). Each list is taken before the run:
  an extent reading the amending read writes is read again.

      mix lat.reread --family "Waste, Water and Climate"            # the chain, printed (read-only)
      mix lat.reread --family "Waste, Water and Climate" --run --tag wwc-reread   # runs it, on Jason's go

  `--run` writes: each substep runs in turn as its own `mix` under
  `systemd-run --user --scope -p MemoryMax=12G -p MemorySwapMax=0`, its
  output to `data/reports/reread/<tag>-<substep>.txt`, and stops at the
  first failure. Take a restore point first: `./scripts/nas/nas-backup.sh
  --tables amendment_rules,commencement_rules,extent_rules,provision_changes,provision_change_claims,lat_events
  --tag T`, and a tar of `data/cache/amendment-index/` when the chain reads
  amending laws.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.StepProcedures.{AmendingStale, ExtentStale, Reread, RereadStale}
  alias SertantaiLegal.Scraper.StepProcedures.Reread.Step

  @shortdoc "The re-read chain for a family: amending laws, commencement, then extent (printed; --run runs it)"
  @usage ~s(usage: mix lat.reread --family F [--run --tag T])
  @reports "data/reports/reread"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [family: :string, run: :boolean, tag: :string])

    family = opts[:family] || Mix.raise(@usage)
    Mix.Task.run("app.start")

    extents = family |> ExtentStale.laws() |> ExtentStale.all()
    amending = family |> AmendingStale.laws() |> AmendingStale.all()
    steps = family |> RereadStale.rules() |> Reread.chain(family, extents, amending)
    print(family, steps)
    if opts[:run] && steps != [], do: execute(steps, opts[:tag] || Mix.raise(@usage))
  end

  defp print(family, []),
    do:
      Mix.shell().info(
        "#{family}: no stale amending law, commencement rule or extent reading; nothing to re-read"
      )

  defp print(family, steps) do
    Mix.shell().info("#{family}: the re-read chain (#{length(steps)} substeps)")

    for %Step{} = s <- steps do
      laws = if s.laws == [], do: "", else: " (#{length(s.laws)} laws)"

      Mix.shell().info(
        "  #{s.substep}#{laws}: mix #{Enum.map_join(s.args, " ", &(&1 |> shown(s.laws) |> shell_arg()))}"
      )
    end
  end

  defp execute(steps, tag) do
    results = Reread.run(steps, &run_step(&1, tag))
    for {s, exit, secs} <- results, do: Mix.shell().info("#{s} exit #{exit} #{secs} s")
    if Enum.any?(results, fn {_, exit, _} -> exit != 0 end), do: exit({:shutdown, 1})
  end

  defp run_step(%Step{substep: s, args: args}, tag) do
    File.mkdir_p!(@reports)
    out = Path.join(@reports, "#{tag}-#{s}.txt")
    t0 = System.monotonic_time(:second)
    scope = ~w(--user --scope -q -p MemoryMax=12G -p MemorySwapMax=0 mix)

    {_, exit} =
      System.cmd("systemd-run", scope ++ args, into: File.stream!(out), stderr_to_stdout: true)

    {exit, System.monotonic_time(:second) - t0}
  end

  # a long law list printed as its first three (`--run` passes them all)
  defp shown(arg, laws) when length(laws) > 10 do
    if arg == Enum.join(laws, ","),
      do: Enum.join(Enum.take(laws, 3), ",") <> ",…",
      else: arg
  end

  defp shown(arg, _laws), do: arg

  defp shell_arg(arg), do: if(String.contains?(arg, [" ", "&"]), do: ~s("#{arg}"), else: arg)
end

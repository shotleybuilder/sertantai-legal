defmodule Mix.Tasks.Lat.Stale do
  @moduledoc """
  Laws whose LAT or labels are stale (lat-refactor LR-25, `LabelStaleness`):
  parsed by other parser code, labels not refreshed since the parse, built
  by other label code, or a failed refresh. 0 stale is part of every wave's
  verification.

      mix lat.stale                 # counts by reason
      mix lat.stale --list          # also each stale law and its reasons
      mix lat.stale --strict        # exit non-zero when any law is stale

  Fix: `mix lat.reparse` for `parser_version` / `no_parse_event` (the parse
  refreshes the labels), `mix lat.relabel --stale` for the label reasons.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.{LabelStaleness, LabelVersion, ParserVersion}

  @shortdoc "Report laws whose LAT or labels are stale"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [list: :boolean, strict: :boolean])
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    current = %{parser: ParserVersion.current(), labels: LabelVersion.current()}

    stale =
      for {law, facts} <- LabelStaleness.facts(),
          reasons = LabelStaleness.reasons(facts, current),
          reasons != [],
          do: {law, reasons}

    Mix.shell().info(
      "parser #{current.parser}, labels #{current.labels}: #{length(stale)} stale laws"
    )

    stale
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.each(fn {reason, n} -> Mix.shell().info("  #{reason}: #{n}") end)

    if opts[:list],
      do: for({law, reasons} <- stale, do: Mix.shell().info("#{law}\t#{Enum.join(reasons, ",")}"))

    if opts[:strict] == true and stale != [], do: exit({:shutdown, 1})
  end
end

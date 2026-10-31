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

  The change register (`provision_changes`, CV-S11) is reported after them:
  the built laws stale by reason (`ChangeStaleness`: built by other code,
  or an input moved since the build), and how many laws holding LAT have no
  build. Fix: `mix lat.vocabulary --build`. It doesn't count towards
  `--strict` until the labels read the change register (CV-06).
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.{ChangeStaleness, LabelStaleness, LabelVersion, ParserVersion}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Store, Version}

  @shortdoc "Report laws whose LAT or labels are stale"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [list: :boolean, strict: :boolean])
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    current = %{parser: ParserVersion.current(), labels: LabelVersion.current()}
    facts = LabelStaleness.facts()

    stale =
      for {law, facts} <- facts,
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

    changes(Enum.map(facts, &elem(&1, 0)), opts)

    if opts[:strict] == true and stale != [], do: exit({:shutdown, 1})
  end

  # the change register: each built law's reasons, from its inputs taken again
  defp changes(lat_laws, opts) do
    builds = Store.builds()
    version = Version.current()

    stale =
      for {law, b} <- Enum.sort(builds),
          current = %{
            code_version: version,
            inputs: Store.Inputs.of(law, b.affecting || [], b.commencement_sources || [])
          },
          reasons = ChangeStaleness.reasons(b, current),
          reasons != [],
          do: {law, reasons}

    unbuilt = Enum.count(lat_laws, &(not Map.has_key?(builds, &1)))

    Mix.shell().info(
      "\nchange register, code #{version}: #{length(stale)} of #{map_size(builds)} built laws stale"
    )

    stale
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {r, _} ->
      Enum.find_index([:code_version | ChangeStaleness.inputs()], &(&1 == r))
    end)
    |> Enum.each(fn {reason, n} -> Mix.shell().info("  #{reason}: #{n}") end)

    Mix.shell().info("  laws holding LAT with no build: #{unbuilt}")

    if opts[:list],
      do:
        for(
          {law, reasons} <- stale,
          do: Mix.shell().info("#{law}\tchanges: #{Enum.join(reasons, ",")}")
        )
  end
end

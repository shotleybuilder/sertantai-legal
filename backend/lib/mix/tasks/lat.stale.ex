defmodule Mix.Tasks.Lat.Stale do
  @moduledoc """
  Laws whose LAT or labels are stale (lat-refactor LR-25, `LabelStaleness`):
  parsed by other parser code, labels not refreshed since the parse, built
  by other label code, or a failed refresh; a switched family's law also
  when its labels were refreshed by other change-vocabulary code or before
  its changes were last built (#193). 0 stale is part of every wave's
  verification.

      mix lat.stale                 # counts by reason
      mix lat.stale --list          # also each stale law and its reasons
      mix lat.stale --strict        # exit non-zero when any law is stale
      mix lat.stale --strict --switched   # only the switched families' laws' labels count (with the change register)
      mix lat.stale --sample FILE --family F --built 20 --unbuilt 10 --seed S
                                    # the change register's staleness hand sample

  Fix: `mix lat.reparse` for `parser_version` / `no_parse_event` (the parse
  refreshes the labels), `mix lat.relabel --stale` for the label reasons.

  The change register (`provision_changes`, CV-S11) is reported after them:
  the built laws stale by reason (`ChangeStaleness`: built by other code,
  an input moved since the build, or readings it read made by other reader
  code), and how many laws holding LAT have no build. Fix: re-read for a
  reader reason, then `mix lat.vocabulary --build`. It counts towards
  `--strict`: the switched families' labels are made from it (#193).
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.{ChangeStaleness, LabelStaleness}
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Store, Version}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.StaleSample

  @shortdoc "Report laws whose LAT or labels are stale"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          list: :boolean,
          strict: :boolean,
          switched: :boolean,
          sample: :string,
          family: :string,
          built: :integer,
          unbuilt: :integer,
          seed: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    current = LabelStaleness.current()
    facts = LabelStaleness.facts()

    stale =
      for {law, f} <- facts,
          reasons = LabelStaleness.reasons(f, current),
          reasons != [],
          do: {law, reasons}

    # the switched families' laws: their labels are served from the change
    # register (Decision 1, #193); the old path's backlog is reported only
    switched = for {law, %{switched: true}} <- facts, into: MapSet.new(), do: law
    stale_switched = Enum.filter(stale, &MapSet.member?(switched, elem(&1, 0)))

    Mix.shell().info(
      "parser #{current.parser}, labels #{current.labels}: #{length(stale)} stale laws" <>
        " (switched families: #{length(stale_switched)} of #{MapSet.size(switched)})"
    )

    stale
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.frequencies()
    |> Enum.sort()
    |> Enum.each(fn {reason, n} -> Mix.shell().info("  #{reason}: #{n}") end)

    if opts[:list],
      do: for({law, reasons} <- stale, do: Mix.shell().info("#{law}\t#{Enum.join(reasons, ",")}"))

    stale_changes = changes(Enum.map(facts, &elem(&1, 0)), opts)

    counted = if opts[:switched], do: stale_switched, else: stale

    if opts[:strict] == true and (counted != [] or stale_changes != []),
      do: exit({:shutdown, 1})
  end

  @fixes [
    commencement_reader: "mix lat.commencement (the mode that wrote them), then build",
    extent_reader: "mix lat.amending --extents --amending A,B, then build"
  ]

  # the change register: each built law's reasons, from its inputs taken again
  defp changes(lat_laws, opts) do
    builds = Store.builds()
    version = Version.current()

    # each built law's reasons and its inputs taken now
    verdicts =
      Map.new(builds, fn {law, b} ->
        {affecting, sources} = {b.affecting || [], b.commencement_sources || []}
        inputs = Store.Inputs.of(law, affecting, sources)
        readers = Store.Inputs.readers(law, affecting, sources)
        current = %{code_version: version, inputs: inputs, readers: readers}
        {law, {ChangeStaleness.reasons(b, current), inputs}}
      end)

    stale = for {law, {reasons, _}} <- Enum.sort(verdicts), reasons != [], do: {law, reasons}
    unbuilt_laws = Enum.reject(lat_laws, &Map.has_key?(builds, &1))
    unbuilt = length(unbuilt_laws)

    Mix.shell().info(
      "\nchange register, code #{version}: #{length(stale)} of #{map_size(builds)} built laws stale" <>
        " (#{no_changes(builds)} built with no changes)"
    )

    stale
    |> Enum.flat_map(&elem(&1, 1))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {r, _} ->
      Enum.find_index(
        [:code_version | ChangeStaleness.inputs()] ++ Keyword.keys(@fixes),
        &(&1 == r)
      )
    end)
    |> Enum.each(fn {reason, n} ->
      fix = if f = @fixes[reason], do: "  (fix: #{f})", else: ""
      Mix.shell().info("  #{reason}: #{n}#{fix}")
    end)

    Mix.shell().info("  laws holding LAT with no build: #{unbuilt}")

    if opts[:list],
      do:
        for(
          {law, reasons} <- stale,
          do: Mix.shell().info("#{law}\tchanges: #{Enum.join(reasons, ",")}")
        )

    if path = opts[:sample], do: sample(path, opts, verdicts, unbuilt_laws, version)
    stale
  end

  # built laws holding no change: no `provision_changes` rows, so that
  # table's law count is lower than the builds' (281 against 285, #193)
  defp no_changes(builds) do
    %{rows: [[n]]} =
      Repo.query!(
        "SELECT count(*) FROM unnest($1::text[]) l WHERE NOT EXISTS (SELECT 1 FROM provision_changes p WHERE p.law_name = l)",
        [Map.keys(builds)]
      )

    n
  end

  # the hand sample (WORKFLOW.md step 11): built and unbuilt laws on a
  # seed, each with its verdict, latest build event and inputs now.
  # `--family` scopes the built laws; the unbuilt are drawn from every law
  # holding LAT (a family through the build has none: Maritime Safety)
  defp sample(path, opts, verdicts, unbuilt, version) do
    scope = if f = opts[:family], do: MapSet.new(Scope.family_laws(f))
    in_scope = fn law -> scope == nil or MapSet.member?(scope, law) end

    {built, unbuilt} =
      StaleSample.draw(
        verdicts |> Map.keys() |> Enum.filter(in_scope),
        unbuilt,
        opts[:built] || 20,
        opts[:unbuilt] || 10,
        opts[:seed] || 1
      )

    events = latest_events(built)

    items =
      for(
        law <- built,
        {reasons, inputs} = verdicts[law],
        do: StaleSample.item(law, reasons, events[law], version, inputs)
      ) ++ for(law <- unbuilt, do: StaleSample.item(law, [:no_build], nil, version, nil))

    File.write!(path, Jason.encode!(items, pretty: true))

    Mix.shell().info(
      "\nsample: #{length(built)} built, #{length(unbuilt)} unbuilt (seed #{opts[:seed] || 1}) → #{path}"
    )
  end

  defp latest_events(laws) do
    Repo.query!(
      """
      SELECT DISTINCT ON (law_name) law_name, at, provenance
      FROM lat_events WHERE event = 'changes_built' AND law_name = ANY($1)
      ORDER BY law_name, at DESC, id DESC
      """,
      [laws]
    ).rows
    |> Map.new(fn [law, at, p] -> {law, %{at: at, provenance: p}} end)
  end
end

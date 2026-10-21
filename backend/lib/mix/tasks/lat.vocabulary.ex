defmodule Mix.Tasks.Lat.Vocabulary do
  @moduledoc """
  A law read through the change vocabulary (change-vocabulary CV-02), for
  debugging: each change with its claims, the value each attribute took
  and the source that won, and the label periods — beside today's stored
  label. Reads the local CLML store and feed cache only; writes nothing.

      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14
      mix lat.vocabulary --law UK_uksi_2010_404 --provision reg.14 --provision "reg.14(1)"
      mix lat.vocabulary --golden          # the CV-01 golden set: pass / fail per provision

  `--golden` reads `test/fixtures/change_vocabulary/golden.exs` (the signed-off
  golden set, normalised to D1) and compares each provision's vocabulary label
  with its expected periods — the change-vocabulary scoreboard (CV-03).

  Provisions take their extent from `legal_articles` and the law's start
  from its law-level commencement record.
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeVocabulary, LatRef, LatStagedParser}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Evidence, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, Markup}

  @shortdoc "Print a law's changes, evidence and labels through the change vocabulary (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [law: :string, provision: :keep, golden: :boolean])

    if opts[:golden], do: golden(), else: show(opts)
  end

  defp show(opts) do
    law = opts[:law] || Mix.raise("--law is required")
    ids = Keyword.get_values(opts, :provision)
    if ids == [], do: Mix.raise("--provision is required (one or more)")

    Mix.Task.run("app.start")

    xml = clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    provisions = provisions(law, ids)

    changes =
      (Feed.read(effects) ++ Markup.read(xml))
      |> Merge.merge()
      |> Enum.map(&Evidence.resolve(&1, get_in(provisions, [&1.target, :extent])))

    labels = ChangeVocabulary.labels(law, xml, effects, provisions)

    for id <- ids do
      Mix.shell().info(
        "\n## #{law} #{id}  (extent #{provisions[id].extent}, start #{provisions[id].start})"
      )

      Mix.shell().info("changes reaching it:")

      for c <- changes, c.target == id or c.target in tl(LatRef.ancestors(id)) do
        r = c.resolved

        Mix.shell().info(
          "  #{c.key} on #{c.target}: #{r.operation} #{r.level} by #{r.by} on #{r.date} " <>
            "territory #{inspect(r.territory)} retained #{r.retained}  sources #{inspect(r.sources)}"
        )

        for cl <- c.claims,
            do: Mix.shell().info("      #{cl.source}.#{cl.attribute} = #{inspect(cl.value)}")
      end

      Mix.shell().info("vocabulary label:")
      for p <- labels[id], do: Mix.shell().info("  " <> line(p))
      Mix.shell().info("stored label today:")
      for p <- stored(law, id), do: Mix.shell().info("  " <> line(p))
    end
  end

  @golden "test/fixtures/change_vocabulary/golden.exs"

  defp golden do
    Mix.Task.run("app.start")
    {cases, _} = Code.eval_file(@golden)

    results =
      cases
      |> Enum.group_by(& &1.law)
      |> Enum.flat_map(fn {law, entries} ->
        xml = clml(law)

        effects =
          law
          |> LatStagedParser.law_effects(store: :only)
          |> LatStagedParser.with_affecting_territory(law)

        provisions =
          Map.new(
            entries,
            &{&1.id, %{extent: &1.extent, start: &1.start, start_dated: not &1.undecidable}}
          )

        labels = ChangeVocabulary.labels(law, xml, effects, provisions)
        Enum.map(entries, &{&1, labels[&1.id]})
      end)

    for {c, got} <- results do
      got = Enum.map(got || [], &Map.delete(&1, :tiers))
      mark = if got == c.periods, do: "PASS", else: "FAIL"

      Mix.shell().info(
        "#{mark}  #{c.law} #{c.id}  — #{c.case}#{if c.undecidable, do: " (undecidable)", else: ""}"
      )

      if got != c.periods do
        Mix.shell().info("    expected:")
        for p <- c.periods, do: Mix.shell().info("      " <> line(p))
        Mix.shell().info("    got:")
        for p <- got || [], do: Mix.shell().info("      " <> line(p))
      end
    end

    passed =
      Enum.count(results, fn {c, got} ->
        Enum.map(got || [], &Map.delete(&1, :tiers)) == c.periods
      end)

    Mix.shell().info("\n#{passed} / #{length(results)} golden provisions pass")
  end

  defp line(p),
    do:
      "#{p.valid_from} → #{p.valid_to || "…"}  #{p.status}  from #{p.in_force_from}  by #{inspect(p.changed_by)}  #{p.territory}"

  defp clml(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> path |> File.read!() |> :zlib.gunzip()
      [] -> Mix.raise("no stored CLML body for #{law}")
    end
  end

  defp provisions(law, ids) do
    %{rows: start_rows} =
      Repo.query!(
        "SELECT effective_from FROM lat_change_log WHERE law_name = $1 AND collector = 'commencement' AND section_id IS NULL LIMIT 1",
        [law]
      )

    start =
      case start_rows do
        [[%Date{} = d]] -> d
        _ -> Mix.raise("no law start for #{law}")
      end

    Map.new(ids, fn id ->
      %{rows: rows} =
        Repo.query!("SELECT extent_code FROM legal_articles WHERE section_id = $1", [
          "#{law}:#{id}"
        ])

      {id, %{extent: rows |> List.first() |> List.wrap() |> List.first(), start: start}}
    end)
  end

  defp stored(law, id) do
    %{rows: rows} =
      Repo.query!(
        "SELECT valid_from, valid_to, status, in_force_from, changed_by, territory FROM lat_label_timeline WHERE section_id = $1 ORDER BY valid_from",
        ["#{law}:#{id}"]
      )

    for [f, t, s, i, c, ter] <- rows,
        do: %{
          valid_from: f,
          valid_to: t,
          status: s,
          in_force_from: i,
          changed_by: c,
          territory: ter
        }
  end
end

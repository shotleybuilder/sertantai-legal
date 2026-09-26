defmodule Mix.Tasks.Lat.Reparse do
  @moduledoc """
  Gated batch LAT re-parse that keeps provision enrichment (see
  `SertantaiLegal.Scraper.LatReparse`).

      mix lat.reparse --laws UK_uksi_2010_2221,UK_ssi_2000_95 --tag pilot1
      mix lat.reparse --older-format --limit 30 --offset 0 --tag batch01
      mix lat.reparse --older-format --list          # just list the candidates
      mix lat.reparse --laws A,B --force --tag x     # bypass the enrichment gate (accepted loss)
      mix lat.reparse --older-format --enriched --dry-run --tag preview
                                                      # plan only, persist nothing

  Each run snapshots the batch to `lat_reparse_<tag>` (+ `_cm`), re-parses
  law by law (legislation.gov.uk, rate-limited), stops at the first error
  or failed enrichment gate, and writes `data/reports/lat-reparse/<tag>.csv`.
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LatReparse

  @shortdoc "Gated batch LAT re-parse keeping enrichment"

  @columns ~w(law_name rows_before rows_after enriched_before enriched_after carried renamed changed ambiguous dropped orphaned_mappings error)a

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          laws: :string,
          older_format: :boolean,
          limit: :integer,
          offset: :integer,
          tag: :string,
          list: :boolean,
          dry_run: :boolean,
          enriched: :boolean,
          force: :boolean
        ]
      )

    Mix.Task.run("app.start")

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:older_format] -> LatReparse.older_format_laws()
        true -> Mix.raise("give --laws A,B or --older-format")
      end
      |> filter_enriched(opts[:enriched])
      |> Enum.drop(opts[:offset] || 0)
      |> then(&if opts[:limit], do: Enum.take(&1, opts[:limit]), else: &1)

    cond do
      opts[:list] ->
        Enum.each(laws, fn law -> Mix.shell().info(law) end)
        Mix.shell().info("#{length(laws)} laws")

      opts[:dry_run] ->
        preview(laws, opts[:tag] || "preview")

      true ->
        tag = opts[:tag] || Mix.raise("--tag is required (snapshot and report name)")
        reparse(laws, tag, opts)
    end
  end

  defp filter_enriched(laws, true) do
    enriched = MapSet.new(LatReparse.enriched_laws())
    Enum.filter(laws, &MapSet.member?(enriched, &1))
  end

  defp filter_enriched(laws, _), do: laws

  @preview_columns ~w(law_name rows_before rows_after enriched enriched_carried enriched_changed enriched_dropped enriched_ambiguous lost_unchanged renamed error)a

  defp preview(laws, tag) do
    reports =
      Enum.map(laws, fn law ->
        r = LatReparse.preview(law)

        Mix.shell().info(
          "  #{String.pad_trailing(law, 24)} " <>
            if(r.error,
              do: "ERROR #{r.error}",
              else:
                "enriched #{r.enriched}: carried #{r.enriched_carried} changed #{r.enriched_changed} dropped #{r.enriched_dropped} ambiguous #{r.enriched_ambiguous} lost_unchanged #{r.lost_unchanged}"
            )
        )

        r
      end)

    ok = Enum.reject(reports, & &1.error)
    sum = &Enum.sum(Enum.map(ok, fn r -> Map.fetch!(r, &1) end))

    Mix.shell().info(
      "\nTotals over #{length(ok)} laws: enriched #{sum.(:enriched)}, carried #{sum.(:enriched_carried)}, " <>
        "changed #{sum.(:enriched_changed)}, dropped #{sum.(:enriched_dropped)}, ambiguous #{sum.(:enriched_ambiguous)}, " <>
        "gate failures #{Enum.count(ok, &(&1.lost_unchanged > 0))}; errors #{length(reports) - length(ok)}"
    )

    write_csv(tag, @preview_columns, reports)
  end

  defp reparse(laws, tag, opts) do
    Mix.shell().info("Re-parsing #{length(laws)} laws (snapshot lat_reparse_#{tag})")

    report =
      LatReparse.run(laws,
        snapshot: "lat_reparse_" <> tag,
        force: Keyword.get(opts, :force, false),
        on_law: fn r ->
          Mix.shell().info(
            "  #{String.pad_trailing(r.law_name, 24)} rows #{r.rows_before}→#{r.rows_after} " <>
              "enriched #{r.enriched_before}→#{r.enriched_after} carried #{r.carried} " <>
              "renamed #{r.renamed} changed #{r.changed} ambiguous #{r.ambiguous} dropped #{r.dropped}" <>
              if(r.orphaned_mappings > 0, do: " ORPHANED #{r.orphaned_mappings}", else: "") <>
              if(r.error, do: "\n    ERROR #{r.error}", else: "")
          )
        end
      )

    path = write_csv(tag, @columns, report.laws)
    Mix.shell().info("\n#{inspect(report.status)} — report #{path}")
  end

  defp write_csv(tag, columns, rows) do
    path = Path.join(["data", "reports", "lat-reparse", tag <> ".csv"])
    File.mkdir_p!(Path.dirname(path))

    csv =
      [Enum.join(columns, ",")] ++
        Enum.map(rows, fn r ->
          Enum.map_join(
            columns,
            ",",
            &(r |> Map.get(&1) |> to_string() |> String.replace(",", ";"))
          )
        end)

    File.write!(path, Enum.join(csv, "\n") <> "\n")
    Mix.shell().info("report #{path}")
    path
  end
end

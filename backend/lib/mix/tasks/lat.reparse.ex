defmodule Mix.Tasks.Lat.Reparse do
  @moduledoc """
  Gated batch LAT re-parse that keeps provision enrichment (see
  `SertantaiLegal.Scraper.LatReparse`).

      mix lat.reparse --laws UK_uksi_2010_2221,UK_ssi_2000_95 --tag pilot1
      mix lat.reparse --older-format --limit 30 --offset 0 --tag batch01
      mix lat.reparse --older-format --list          # just list the candidates

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
          list: :boolean
        ]
      )

    Mix.Task.run("app.start")

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:older_format] -> LatReparse.older_format_laws()
        true -> Mix.raise("give --laws A,B or --older-format")
      end
      |> Enum.drop(opts[:offset] || 0)
      |> then(&if opts[:limit], do: Enum.take(&1, opts[:limit]), else: &1)

    if opts[:list] do
      Enum.each(laws, fn law -> Mix.shell().info(law) end)
      Mix.shell().info("#{length(laws)} laws")
    else
      tag = opts[:tag] || Mix.raise("--tag is required (snapshot and report name)")
      reparse(laws, tag)
    end
  end

  defp reparse(laws, tag) do
    Mix.shell().info("Re-parsing #{length(laws)} laws (snapshot lat_reparse_#{tag})")

    report =
      LatReparse.run(laws,
        snapshot: "lat_reparse_" <> tag,
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

    path = Path.join(["data", "reports", "lat-reparse", tag <> ".csv"])
    File.mkdir_p!(Path.dirname(path))

    csv =
      [Enum.join(@columns, ",")] ++
        Enum.map(report.laws, fn r ->
          Enum.map_join(
            @columns,
            ",",
            &(r |> Map.get(&1) |> to_string() |> String.replace(",", ";"))
          )
        end)

    File.write!(path, Enum.join(csv, "\n") <> "\n")

    Mix.shell().info("\n#{inspect(report.status)} — report #{path}")
  end
end

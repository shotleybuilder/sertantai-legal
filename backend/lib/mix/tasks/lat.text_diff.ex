defmodule Mix.Tasks.Lat.TextDiff do
  @moduledoc """
  Which LAT rows a parser change alters, without persisting anything: each
  law is fetched and parsed (`LatStagedParser.fetch_rows/1`, scope-aware)
  and its row text compared with the stored LAT (`LatTextDiff`).

      mix lat.text_diff --laws UK_uksi_1992_3004,UK_ukpga_1974_37
      mix lat.text_diff --all                  # every law holding LAT
      mix lat.text_diff --all --out data/reports/lat-parser-coverage/x.csv

  Written as it goes: each law's changes are appended to the CSV (law_name,
  section_id, change, kind, old_text, new_text) and the law is added to
  `<out>.done`, so an interrupted run loses nothing and a re-run skips the
  laws already done. `kind` is `reordered` (same words: the list-text fix)
  or `other` (e.g. an amendment since the last parse).
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatStagedParser, LatTextDiff}

  @shortdoc "Row-text diff of a fresh parse against stored LAT (no persist)"

  @header ~w(law_name section_id change kind old_text new_text)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [laws: :string, all: :boolean, out: :string])
    Mix.Task.run("app.start")

    out =
      opts[:out] ||
        Path.join(["data", "reports", "lat-parser-coverage", "text-diff-#{Date.utc_today()}.csv"])

    done_path = out <> ".done"
    File.mkdir_p!(Path.dirname(out))
    unless File.exists?(out), do: File.write!(out, CSV.dump_to_iodata([@header]))

    done =
      if File.exists?(done_path),
        do: done_path |> File.read!() |> String.split("\n", trim: true) |> MapSet.new(),
        else: MapSet.new()

    laws =
      cond do
        opts[:laws] -> String.split(opts[:laws], ",", trim: true)
        opts[:all] -> laws_with_lat()
        true -> Mix.raise("Give --laws A,B or --all")
      end
      |> Enum.reject(&MapSet.member?(done, &1))

    Mix.shell().info("#{length(laws)} laws to diff (#{MapSet.size(done)} already done) → #{out}")

    for law <- laws do
      case diff_law(law) do
        {:ok, changes} ->
          rows =
            Enum.map(changes, fn {id, change, old, new} ->
              [law, id, change, LatTextDiff.kind(old, new), old || "", new || ""]
            end)

          File.write!(out, CSV.dump_to_iodata(rows), [:append])
          File.write!(done_path, law <> "\n", [:append])
          reordered = Enum.count(rows, &(Enum.at(&1, 3) == "reordered"))
          Mix.shell().info("  #{law}: #{length(rows)} changed (#{reordered} reordered)")

        {:error, reason} ->
          Mix.shell().error("  #{law}: #{reason} (not marked done)")
      end
    end
  end

  defp diff_law(law) do
    with {:ok, rows, _law_id} <- LatStagedParser.fetch_rows(law) do
      new = Map.new(rows, &{&1.section_id, &1.text})
      {:ok, LatTextDiff.diff(stored(law), new)}
    end
  end

  defp stored(law) do
    %{rows: rows} =
      Repo.query!("SELECT section_id, text FROM legal_articles WHERE law_name = $1", [law])

    Map.new(rows, fn [id, text] -> {id, text} end)
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("""
      SELECT name FROM legal_register
      WHERE country = 'uk' AND lat_count > 0 AND NOT coalesce((lat_scope->>'excluded')::boolean, false)
      ORDER BY name
      """)

    List.flatten(rows)
  end
end

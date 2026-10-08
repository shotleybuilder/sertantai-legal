defmodule Mix.Tasks.Lat.BackfillTitles do
  @moduledoc """
  Fill `legal_articles.title` from a fresh parse without re-parsing the LAT
  (LAT parser coverage II): each law is parsed (`LatStagedParser.fetch_rows/2`,
  scope-aware) and only the titles of stored rows with the same `section_id`
  are set, changed or cleared (`LatTitles.plan/2`). Row text, ids, hashes and
  `updated_at` are untouched.

      mix lat.backfill_titles --all --store only            # dry run
      mix lat.backfill_titles --all --store only --apply
      mix lat.backfill_titles --laws UK_uksi_1992_3004 --apply
      mix lat.backfill_titles --column repealed_extent --all --store only

  `--column title|repealed_extent` (default `title`): any parser-derived
  column that isn't row text, set the same way.

  Every planned update is written to `--out` (CSV, default
  `data/reports/lat-parser-coverage-ii/titles-backfill-<date>.csv`). With
  `--apply` each law is written in its own UPDATE as it is parsed and logged
  to `<out>.done`, so a rerun resumes. `--store prefer|only|refresh`
  (default `prefer`): the local CLML store (#175).
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatStagedParser, LatTitles}

  @shortdoc "Set LAT row titles from a fresh parse (title only, no re-parse)"

  @header ~w(law_name section_id value)

  # columns this task may write (the SQL takes the name from here only)
  @columns %{"title" => :title, "repealed_extent" => :repealed_extent}

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          laws: :string,
          all: :boolean,
          out: :string,
          store: :string,
          apply: :boolean,
          column: :string
        ]
      )

    column =
      Map.get(@columns, opts[:column] || "title") ||
        Mix.raise("--column must be one of #{@columns |> Map.keys() |> Enum.join(", ")}")

    Mix.Task.run("app.start")
    apply? = Keyword.get(opts, :apply, false)
    out = opts[:out] || default_out(column, apply?)
    done_path = out <> ".done"
    File.mkdir_p!(Path.dirname(out))
    unless File.exists?(out), do: File.write!(out, CSV.dump_to_iodata([@header]))
    done = read_done(done_path)
    laws = opts |> law_list() |> Enum.reject(&MapSet.member?(done, &1))
    mode = store_mode(opts[:store])

    Mix.shell().info(
      "#{length(laws)} laws (#{MapSet.size(done)} already done), #{if apply?, do: "APPLY", else: "dry run"} → #{out}"
    )

    totals =
      Enum.reduce(laws, %{laws: 0, set: 0, cleared: 0, errors: 0}, fn law, acc ->
        tally(acc, backfill_law(law, column, mode, apply?, out, done_path))
      end)

    Mix.shell().info(
      "#{totals.laws} laws: #{totals.set} #{column} set, #{totals.cleared} cleared, #{totals.errors} errors"
    )
  end

  # Plan one law, write it (with --apply) and log it as done.
  defp backfill_law(law, column, mode, apply?, out, done_path) do
    case plan_law(law, column, mode) do
      {:ok, updates} ->
        if apply? and updates != [], do: write!(law, column, updates)
        rows = Enum.map(updates, fn {id, title} -> [law, id, title || ""] end)
        File.write!(out, CSV.dump_to_iodata(rows), [:append])
        File.write!(done_path, law <> "\n", [:append])
        cleared = Enum.count(updates, &is_nil(elem(&1, 1)))
        Mix.shell().info("  #{law}: #{length(updates) - cleared} set, #{cleared} cleared")
        {:ok, length(updates) - cleared, cleared}

      {:error, reason} ->
        Mix.shell().error("  #{law}: #{inspect(reason)} (not marked done)")
        :error
    end
  end

  defp tally(acc, {:ok, set, cleared}),
    do: %{acc | laws: acc.laws + 1, set: acc.set + set, cleared: acc.cleared + cleared}

  defp tally(acc, :error), do: %{acc | errors: acc.errors + 1}

  defp default_out(column, apply?) do
    suffix = if apply?, do: "", else: "-dry"

    Path.join([
      "data",
      "reports",
      "lat-parser-coverage-ii",
      "#{if column == :title, do: "titles", else: column}-backfill-#{Date.utc_today()}#{suffix}.csv"
    ])
  end

  defp read_done(path) do
    if File.exists?(path),
      do: path |> File.read!() |> String.split("\n", trim: true) |> MapSet.new(),
      else: MapSet.new()
  end

  defp law_list(opts) do
    cond do
      opts[:laws] -> String.split(opts[:laws], ",", trim: true)
      opts[:all] -> laws_with_lat()
      true -> Mix.raise("Give --laws A,B or --all")
    end
  end

  defp store_mode(nil), do: :prefer
  defp store_mode(m) when m in ~w(prefer only refresh), do: String.to_atom(m)
  defp store_mode(m), do: Mix.raise("--store must be prefer, only or refresh, got #{m}")

  defp plan_law(law, column, mode) do
    with {:ok, rows, _law_id} <- LatStagedParser.fetch_rows(law, store: mode) do
      %{rows: stored} =
        Repo.query!("SELECT section_id, #{column} FROM legal_articles WHERE law_name = $1", [law])

      stored = Enum.map(stored, fn [id, value] -> %{:section_id => id, column => value} end)
      {:ok, LatTitles.plan(stored, rows, column)}
    end
  end

  defp write!(law, column, updates) do
    {ids, values} = Enum.unzip(updates)

    Repo.query!(
      """
      UPDATE legal_articles a SET #{column} = u.value
      FROM unnest($2::text[], $3::text[]) AS u(section_id, value)
      WHERE a.law_name = $1 AND a.section_id = u.section_id
      """,
      [law, ids, values]
    )
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

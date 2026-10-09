defmodule Mix.Tasks.Lat.TextDiff do
  @moduledoc """
  Which LAT rows a parser change alters, without persisting anything: each
  law is fetched and parsed (`LatStagedParser.fetch_rows/1`, scope-aware)
  and its row text compared with the stored LAT (`LatTextDiff`).

      mix lat.text_diff --laws UK_uksi_1992_3004,UK_ukpga_1974_37
      mix lat.text_diff --all                  # every law holding LAT
      mix lat.text_diff --all --out data/reports/lat-parser-coverage/x.csv
      mix lat.text_diff --all --store only --expect data/reports/lr/expect-lr02.txt

  Written as it goes: each law's changed rows are appended to the CSV
  (law_name, section_id, change, kind, classes, old_text, new_text,
  old_excluded, new_excluded) and the law is added to `<out>.done`, so an
  interrupted run loses nothing and a re-run skips the laws already done.
  A row is changed when its text, title, excluded_extent or extent_code
  differ. `kind` is `reordered` (same words: the list-text fix) or `other`;
  `classes` (`LatDiffClass`, "; "-joined) says how, e.g.
  "excluded_extent: nil → W" or "text: brackets added".

  At the end the whole CSV is summarised by class into `<out>.classes.csv`
  (class, rows, laws, example). `--expect FILE` (one regex per line, `#`
  comments) lists the classes a change is meant to cause; any other class is
  reported as unexpected, with its count (LAT Parser Refactor, LR-01).

  `--store prefer|only|refresh` (default `prefer`): the local CLML store
  (#175). `--store only` is the offline whole-corpus diff: no requests.
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatDiffClass, LatStagedParser, LatTextDiff}

  @shortdoc "Classified row diff of a fresh parse against stored LAT (no persist)"

  @header ~w(law_name section_id change kind classes old_text new_text old_excluded new_excluded)
  @fields [:text, :title, :excluded_extent, :extent_code]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, out: :string, store: :string, expect: :string]
      )

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

    mode =
      case opts[:store] do
        nil -> :prefer
        m when m in ~w(prefer only refresh) -> String.to_atom(m)
        m -> Mix.raise("--store must be prefer, only or refresh, got #{m}")
      end

    for law <- laws do
      case diff_law(law, mode) do
        {:ok, changes} ->
          rows =
            Enum.map(changes, fn {id, change, classes, old, new} ->
              [
                law,
                id,
                change,
                LatTextDiff.kind(old[:text], new[:text]),
                Enum.join(classes, "; "),
                old[:text] || "",
                new[:text] || "",
                old[:excluded_extent] || "",
                new[:excluded_extent] || ""
              ]
            end)

          File.write!(out, CSV.dump_to_iodata(rows), [:append])
          File.write!(done_path, law <> "\n", [:append])
          Mix.shell().info("  #{law}: #{length(rows)} changed")

        {:error, reason} ->
          Mix.shell().error("  #{law}: #{reason} (not marked done)")
      end
    end

    summarise(out, opts[:expect])
  end

  # Class → rows, laws, an example, over the whole CSV (resumed runs included).
  defp summarise(out, expect) do
    [_header | rows] = out |> File.read!() |> CSV.parse_string(skip_headers: false)

    by_class =
      rows
      |> Enum.flat_map(fn [law, id, _change, _kind, classes | _] ->
        classes |> String.split("; ", trim: true) |> Enum.map(&{&1, law, id})
      end)
      |> Enum.group_by(&elem(&1, 0))

    counts = Map.new(by_class, fn {class, hits} -> {class, length(hits)} end)

    summary =
      by_class
      |> Enum.sort_by(fn {_class, hits} -> -length(hits) end)
      |> Enum.map(fn {class, [{_, _, example} | _] = hits} ->
        laws = hits |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length()
        [class, length(hits), laws, example]
      end)

    File.write!(
      out <> ".classes.csv",
      CSV.dump_to_iodata([~w(class rows laws example) | summary])
    )

    Mix.shell().info("\n#{length(rows)} rows changed; by class (#{out}.classes.csv):")

    Enum.each(summary, fn [class, n, laws, example] ->
      Mix.shell().info("  #{n}\t#{laws} laws\t#{class}\t(#{example})")
    end)

    if expect do
      unexpected = LatDiffClass.unexpected(counts, expected_patterns(expect))
      total = unexpected |> Map.values() |> Enum.sum()
      Mix.shell().info("unexpected: #{total} rows in #{map_size(unexpected)} classes")
      Enum.each(unexpected, fn {class, n} -> Mix.shell().info("  #{n}\t#{class}") end)
    end
  end

  defp expected_patterns(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.reject(&String.starts_with?(&1, "#"))
    |> Enum.map(&Regex.compile!(&1, "u"))
  end

  defp diff_law(law, mode) do
    with {:ok, rows, _law_id} <- LatStagedParser.fetch_rows(law, store: mode) do
      new = Map.new(rows, &{&1.section_id, Map.take(&1, @fields)})
      {:ok, changes(stored(law), new)}
    end
  end

  # {section_id, change, classes, old, new} for every row whose fields differ
  defp changes(old, new) do
    (Map.keys(old) ++ Map.keys(new))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn id ->
      {o, n} = {old[id], new[id]}

      case LatDiffClass.classify(o, n) do
        [] -> []
        ["inserted"] = c -> [{id, "inserted", c, %{}, n}]
        ["removed"] = c -> [{id, "removed", c, o, %{}}]
        c -> [{id, "changed", c, o, n}]
      end
    end)
  end

  defp stored(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, title, excluded_extent, extent_code FROM legal_articles WHERE law_name = $1",
        [law]
      )

    Map.new(rows, fn [id, text, title, excluded, extent] ->
      {id, %{text: text, title: title, excluded_extent: excluded, extent_code: extent}}
    end)
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

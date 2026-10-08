defmodule Mix.Tasks.Lat.PlaceNotes do
  @moduledoc """
  Place stored amendment notes on their provisions without a re-parse (LAT
  parser coverage II): notes cited only by a `CommentaryRef` attribute
  (Addition/Substitution/Repeal) or from a P1group Title had no
  `affected_sections`.

      mix lat.place_notes --all --store only            # dry run
      mix lat.place_notes --all --store only --apply
      mix lat.place_notes --laws UK_uksi_1998_2306 --apply

  Per law, in one transaction: the law is parsed from the CLML store
  (`LatStagedParser.fetch_notes/2`), each stored note that matches a parsed
  one exactly (`NotePlacement.plan/2`) gets its sections, and
  `LatStatus.Apply.refresh/1` re-derives row statuses and row
  `effective_from`/`changed_by` from the newly placed notes. A dry run does
  the same and rolls back, so its counts are exact. LAT rows' text, ids and
  counts are untouched.

  Written as it goes to `--out` (default
  `data/reports/lat-parser-coverage-ii/notes-place-<date>[-dry].csv`, one
  line per law) with a `.done` list. `--store prefer|only|refresh` (default
  `prefer`): the local CLML store (#175).
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatStagedParser, NotePlacement}
  alias SertantaiLegal.Scraper.LatStatus.Apply

  @shortdoc "Set amendment notes' affected_sections from a store parse"

  @header ~w(law_name notes_placed notes_moved unmatched still_unplaced statuses_changed change_rows transitions)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, all: :boolean, out: :string, store: :string, apply: :boolean]
      )

    Mix.Task.run("app.start")
    apply? = Keyword.get(opts, :apply, false)
    out = opts[:out] || default_out(apply?)
    File.mkdir_p!(Path.dirname(out))
    unless File.exists?(out), do: File.write!(out, CSV.dump_to_iodata([@header]))
    done = read_done(out <> ".done")
    laws = opts |> law_list() |> Enum.reject(&MapSet.member?(done, &1))
    mode = store_mode(opts[:store])

    Mix.shell().info(
      "#{length(laws)} laws (#{MapSet.size(done)} already done), #{if apply?, do: "APPLY", else: "dry run"} → #{out}"
    )

    totals =
      Enum.reduce(laws, %{laws: 0, placed: 0, unmatched: 0, errors: 0}, fn law, acc ->
        case place_law(law, mode, apply?) do
          {:ok, stats} ->
            row = [law | Enum.map(tl(@header), &to_string(Map.fetch!(stats, String.to_atom(&1))))]
            File.write!(out, CSV.dump_to_iodata([row]), [:append])
            File.write!(out <> ".done", law <> "\n", [:append])

            Mix.shell().info(
              "  #{law}: #{stats.notes_placed} placed, #{stats.notes_moved} moved, #{stats.unmatched} unmatched, #{stats.still_unplaced} still unplaced; #{stats.statuses_changed} statuses, #{stats.change_rows} change rows"
            )

            %{
              acc
              | laws: acc.laws + 1,
                placed: acc.placed + stats.notes_placed,
                unmatched: acc.unmatched + stats.unmatched
            }

          {:error, reason} ->
            Mix.shell().error("  #{law}: #{inspect(reason)} (not marked done)")
            %{acc | errors: acc.errors + 1}
        end
      end)

    Mix.shell().info(
      "#{totals.laws} laws: #{totals.placed} notes placed, #{totals.unmatched} unmatched, #{totals.errors} errors"
    )
  end

  defp place_law(law, mode, apply?) do
    with {:ok, parsed} <- LatStagedParser.fetch_notes(law, store: mode) do
      Repo.transaction(
        fn ->
          stored = stored_notes(law)
          plan = NotePlacement.plan(stored, parsed)

          was_placed =
            for n <- stored, (n.affected_sections || []) != [], into: MapSet.new(), do: n.id

          moved = Enum.count(plan.updates, fn {id, _} -> MapSet.member?(was_placed, id) end)
          write_sections!(plan.updates)
          refreshed = Apply.refresh(law)

          stats = %{
            notes_placed: length(plan.updates) - moved,
            notes_moved: moved,
            unmatched: plan.unmatched,
            still_unplaced: unplaced(law),
            statuses_changed: refreshed.changed,
            change_rows: refreshed.change_rows,
            transitions:
              Enum.map_join(refreshed.transitions, ";", fn {{from, to}, n} ->
                "#{from}>#{to}:#{n}"
              end)
          }

          if apply?, do: stats, else: Repo.rollback({:dry_run, stats})
        end,
        timeout: :infinity
      )
      |> case do
        {:ok, stats} -> {:ok, stats}
        {:error, {:dry_run, stats}} -> {:ok, stats}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp stored_notes(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT id, code_type, code, text, affected_sections FROM amendment_annotations WHERE law_name = $1",
        [law]
      )

    Enum.map(rows, fn [id, type, code, text, sections] ->
      %{id: id, code_type: type, code: code, text: text, affected_sections: sections}
    end)
  end

  defp write_sections!([]), do: :ok

  defp write_sections!(updates) do
    {ids, sections} = Enum.unzip(updates)

    # unnest can't take a ragged array: sections travel as JSON
    Repo.query!(
      """
      UPDATE amendment_annotations a
      SET affected_sections = ARRAY(SELECT jsonb_array_elements_text(u.sections::jsonb))
      FROM unnest($1::text[], $2::text[]) AS u(id, sections)
      WHERE a.id = u.id
      """,
      [ids, Enum.map(sections, &Jason.encode!/1)]
    )
  end

  defp unplaced(law) do
    %{rows: [[n]]} =
      Repo.query!(
        "SELECT count(*) FROM amendment_annotations WHERE law_name = $1 AND coalesce(cardinality(affected_sections), 0) = 0",
        [law]
      )

    n
  end

  defp default_out(apply?) do
    suffix = if apply?, do: "", else: "-dry"

    Path.join([
      "data",
      "reports",
      "lat-parser-coverage-ii",
      "notes-place-#{Date.utc_today()}#{suffix}.csv"
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
      opts[:all] -> laws_with_notes()
      true -> Mix.raise("Give --laws A,B or --all")
    end
  end

  defp laws_with_notes do
    %{rows: rows} =
      Repo.query!("""
      SELECT DISTINCT a.law_name FROM amendment_annotations a
      JOIN legal_register r ON r.name = a.law_name AND r.country = 'uk' AND r.lat_count > 0
      ORDER BY 1
      """)

    List.flatten(rows)
  end

  defp store_mode(nil), do: :prefer
  defp store_mode(m) when m in ~w(prefer only refresh), do: String.to_atom(m)
  defp store_mode(m), do: Mix.raise("--store must be prefer, only or refresh, got #{m}")
end

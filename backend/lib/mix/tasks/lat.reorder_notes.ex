defmodule Mix.Tasks.Lat.ReorderNotes do
  @moduledoc """
  One-off: rewrite stored amendment note text in document order and re-key
  everything derived from it (LAT parser coverage II). Notes were stored
  scrambled (xmerl's `//text()` puts direct text before the Citations');
  `CommentaryParser` now reads them in order.

      mix lat.reorder_notes --all --store only            # dry run
      mix lat.reorder_notes --all --store only --apply
      mix lat.reorder_notes --laws UK_uksi_1998_2306 --apply

  Per law, in one transaction: each stored note whose text is exactly the old
  extraction of its commentary in the stored XML (`NoteReorder.plan/2`) gets
  the ordered text; `LatStatus.Apply.refresh/1` re-derives the notes' fields
  (effect, dates, changed_by, change_id), row statuses and row
  `effective_from`/`changed_by`; the `change_ids` in `lat_changes` are mapped
  to the new ids. A dry run does the same and rolls back, so its counts are
  exact. Notes that no longer match the source (drift) are left for a
  re-parse.

  Written as it goes to `--out` (default
  `data/reports/lat-parser-coverage-ii/notes-reorder-<date>[-dry].csv`, one
  line per law) with a `.done` list; with `--apply` the old → new change_id
  mapping goes to `<out>.change-ids.csv` (for fractalaw).
  `--store prefer|only|refresh` (default `prefer`): the local CLML store (#175).
  """

  use Mix.Task

  alias NimbleCSV.RFC4180, as: CSV
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{CommentaryParser, LatStagedParser, NoteReorder}
  alias SertantaiLegal.Scraper.LatStatus.Apply

  @shortdoc "Rewrite amendment note text in document order (one-off re-key)"

  @header ~w(law_name notes_updated unmatched notes_refreshed statuses_changed change_rows lat_changes_rekeyed)

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
      Enum.reduce(laws, %{laws: 0, updated: 0, unmatched: 0, errors: 0}, fn law, acc ->
        case reorder_law(law, mode, apply?) do
          {:ok, stats, mapping} ->
            record!(out, law, stats, mapping, apply?)
            info(law, stats)

            %{
              acc
              | laws: acc.laws + 1,
                updated: acc.updated + stats.notes_updated,
                unmatched: acc.unmatched + stats.unmatched
            }

          {:error, reason} ->
            Mix.shell().error("  #{law}: #{inspect(reason)} (not marked done)")
            %{acc | errors: acc.errors + 1}
        end
      end)

    Mix.shell().info(
      "#{totals.laws} laws: #{totals.updated} notes reordered, #{totals.unmatched} unmatched, #{totals.errors} errors"
    )
  end

  defp reorder_law(law, mode, apply?) do
    with {:ok, xmls, _law_id} <- LatStagedParser.fetch_docs(law, store: mode) do
      pairs = Enum.flat_map(xmls, &CommentaryParser.text_pairs/1)

      Repo.transaction(
        fn ->
          before = change_ids(law)
          plan = law |> stored_notes() |> NoteReorder.plan(pairs)
          write_text!(plan.updates)
          refreshed = Apply.refresh(law)

          mapping =
            for {id, new} <- change_ids(law),
                (old = before[id]) && old != new,
                into: %{},
                do: {old, new}

          rekeyed = rekey_lat_changes!(law, mapping)

          stats = %{
            notes_updated: length(plan.updates),
            unmatched: plan.unmatched,
            notes_refreshed: refreshed.notes_changed,
            statuses_changed: refreshed.changed,
            change_rows: refreshed.change_rows,
            lat_changes_rekeyed: rekeyed
          }

          if apply?, do: {stats, mapping}, else: Repo.rollback({:dry_run, stats, mapping})
        end,
        timeout: :infinity
      )
      |> case do
        {:ok, {stats, mapping}} -> {:ok, stats, mapping}
        {:error, {:dry_run, stats, mapping}} -> {:ok, stats, mapping}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp stored_notes(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT id, code_type, code, text FROM amendment_annotations WHERE law_name = $1",
        [law]
      )

    Enum.map(rows, fn [id, type, code, text] ->
      %{id: id, code_type: type, code: code, text: text}
    end)
  end

  defp change_ids(law) do
    %{rows: rows} =
      Repo.query!("SELECT id, change_id FROM amendment_annotations WHERE law_name = $1", [law])

    Map.new(rows, fn [id, cid] -> {id, cid} end)
  end

  defp write_text!([]), do: :ok

  defp write_text!(updates) do
    {ids, texts} = Enum.unzip(updates)

    Repo.query!(
      """
      UPDATE amendment_annotations a SET text = u.text
      FROM unnest($1::text[], $2::text[]) AS u(id, text)
      WHERE a.id = u.id
      """,
      [ids, texts]
    )
  end

  defp rekey_lat_changes!(_law, mapping) when map_size(mapping) == 0, do: 0

  defp rekey_lat_changes!(law, mapping) do
    %{rows: rows} =
      Repo.query!(
        "SELECT id, change_ids FROM lat_changes WHERE law_name = $1 AND change_ids && $2::text[]",
        [law, Map.keys(mapping)]
      )

    for [id, ids] <- rows do
      Repo.query!("UPDATE lat_changes SET change_ids = $2 WHERE id = $1", [
        id,
        NoteReorder.rekey(ids, mapping)
      ])
    end

    length(rows)
  end

  defp record!(out, law, stats, mapping, apply?) do
    row = [law | Enum.map(tl(@header), &(stats |> Map.fetch!(String.to_atom(&1)) |> to_string()))]
    File.write!(out, CSV.dump_to_iodata([row]), [:append])

    if apply? and mapping != %{} do
      ids = Enum.map(mapping, fn {old, new} -> [law, old, new] end)
      File.write!(out <> ".change-ids.csv", CSV.dump_to_iodata(ids), [:append])
    end

    File.write!(out <> ".done", law <> "\n", [:append])
  end

  defp info(law, s) do
    Mix.shell().info(
      "  #{law}: #{s.notes_updated} reordered, #{s.unmatched} unmatched; refreshed #{s.notes_refreshed} notes, #{s.statuses_changed} statuses, #{s.change_rows} change rows; #{s.lat_changes_rekeyed} lat_changes"
    )
  end

  defp default_out(apply?) do
    suffix = if apply?, do: "", else: "-dry"

    Path.join([
      "data",
      "reports",
      "lat-parser-coverage-ii",
      "notes-reorder-#{Date.utc_today()}#{suffix}.csv"
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
      Repo.query!("SELECT DISTINCT law_name FROM amendment_annotations ORDER BY 1")

    List.flatten(rows)
  end

  defp store_mode(nil), do: :prefer
  defp store_mode(m) when m in ~w(prefer only refresh), do: String.to_atom(m)
  defp store_mode(m), do: Mix.raise("--store must be prefer, only or refresh, got #{m}")
end

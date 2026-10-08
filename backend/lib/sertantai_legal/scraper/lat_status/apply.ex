defmodule SertantaiLegal.Scraper.LatStatus.Apply do
  @moduledoc """
  Refreshes a law's note-derived LAT fields (#167) in one pass, writing only
  what changes:

  - each amendment note's parsed fields (`AmendmentNote`, L8.2): effect,
    effective_dates, effective_from, changed_by, change_id
  - each row's `status` (`LatStatus`, L8.1)
  - each row's `effective_from` / `changed_by` (L8.2): the latest dated
    amendment/commencement note on the row or an ancestor

  Called by `CommentaryPersister` after notes are committed (every parse path)
  and by `mix lat.status` (backfill / recompute).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{AmendmentNote, LatStatus}

  require Logger

  @type result :: %{
          law_name: String.t(),
          rows: non_neg_integer(),
          changed: non_neg_integer(),
          transitions: %{{String.t() | nil, String.t()} => pos_integer()},
          change_rows: non_neg_integer(),
          notes_changed: non_neg_integer()
        }

  @doc """
  Recompute the law's note fields, statuses and change fields. Options:
  `dry_run: true` resolves and reports without writing.
  """
  @spec refresh(String.t(), keyword()) :: result()
  def refresh(law_name, opts \\ []) when is_binary(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, status, effective_from, changed_by, excluded_extent, extent_code FROM legal_articles WHERE law_name = $1",
        [law_name],
        timeout: :infinity
      )

    %{rows: note_rows} =
      Repo.query!(
        """
        SELECT id, affected_sections, text, code_type, code,
               effect, effective_dates, effective_from, changed_by, change_id
        FROM amendment_annotations WHERE law_name = $1
        """,
        [law_name],
        timeout: :infinity
      )

    notes =
      Enum.map(note_rows, fn [id, sections, text, type, code | stored] ->
        %{
          id: id,
          affected_sections: sections,
          text: text || "",
          code_type: type,
          stored: stored,
          parsed: text |> AmendmentNote.parse(type, law_name) |> marginal(code)
        }
      end)

    notes = resolve_welsh(notes)

    note_changes =
      for n <- notes, n.stored != note_values(n.parsed), do: {n.id, n.parsed}

    current =
      Map.new(rows, fn [sid, _text, status, from, by | _] -> {sid, {status, [from, by]}} end)

    statuses =
      LatStatus.resolve(
        Enum.map(rows, fn [sid, text, status, _from, _by, repealed, extent] ->
          %{
            section_id: sid,
            text: text,
            status: status,
            excluded_extent: repealed,
            extent_code: extent
          }
        end),
        notes
      )

    status_changes =
      for {sid, status} <- statuses, elem(current[sid], 0) != status, do: {sid, status}

    # every row a note is placed on (LH-01), not only the last
    by_target =
      notes
      |> Enum.flat_map(fn n -> Enum.map(LatStatus.note_targets(n), &{&1, n.parsed}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    holders = holders(law_name)

    change_changes =
      for [sid | _] <- rows,
          {from, by} =
            (holders[sid] || sid)
            |> LatStatus.ancestors()
            |> Enum.flat_map(&Map.get(by_target, &1, []))
            |> AmendmentNote.row_effective(),
          elem(current[sid], 1) != [from, by],
          do: {sid, from, by}

    unless opts[:dry_run] do
      write_notes!(note_changes)
      write_statuses!(status_changes)
      write_change_fields!(change_changes)
    end

    %{
      law_name: law_name,
      rows: length(rows),
      changed: length(status_changes),
      transitions:
        Enum.frequencies_by(status_changes, fn {sid, s} -> {elem(current[sid], 0), s} end),
      change_rows: length(change_changes),
      notes_changed: length(note_changes)
    }
  end

  @doc "Refresh after notes are persisted; a failure is logged and never fails the caller."
  @spec refresh_after_parse(String.t()) :: :ok
  def refresh_after_parse(law_name) do
    r = refresh(law_name)

    Logger.info(
      "[LatStatus] #{law_name}: #{r.changed} status, #{r.change_rows} change rows, #{r.notes_changed} notes"
    )

    :ok
  rescue
    e ->
      Logger.warning("[LatStatus] refresh failed for #{law_name}: #{Exception.message(e)}")
      :ok
  end

  # Table and figure rows sit inside a provision but their ids (table.3041)
  # don't nest under it: each takes the nearest preceding other row in
  # document order as the provision whose notes date it (LH-06).
  defp holders(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id FROM legal_articles WHERE law_name = $1 ORDER BY sort_key",
        [law_name]
      )

    {pairs, _} =
      Enum.map_reduce(List.flatten(rows), nil, fn sid, holder ->
        if Regex.match?(~r/:(table|figure)\./, sid),
          do: {{sid, holder}, holder},
          else: {nil, sid}
      end)

    for {sid, holder} <- pairs, holder != nil, into: %{}, do: {sid, holder}
  end

  # A marginal citation (code "M…": "Amended by S.I. 2011/1515 …") only
  # refers to laws; it changes nothing, so no instrument and no dates (LH-06).
  defp marginal(parsed, "M" <> _),
    do: %{parsed | changed_by: nil, effective_dates: [], effective_from: nil}

  defp marginal(parsed, _code), do: parsed

  # A Welsh SI cited as plain "S.I." parses as uksi: when only its wsi twin
  # is in the register, use the twin (AmendmentNote.resolve_law/2).
  defp resolve_welsh(notes) do
    uksi =
      for n <- notes,
          match?("UK_uksi_" <> _, n.parsed.changed_by),
          uniq: true,
          do: n.parsed.changed_by

    if uksi == [] do
      notes
    else
      candidates = uksi ++ Enum.map(uksi, &String.replace_prefix(&1, "UK_uksi_", "UK_wsi_"))

      %{rows: rows} =
        Repo.query!("SELECT name FROM legal_register WHERE name = ANY($1)", [candidates])

      known = MapSet.new(List.flatten(rows))

      Enum.map(notes, fn n ->
        by = AmendmentNote.resolve_law(n.parsed.changed_by, known)
        put_in(n, [:parsed, Access.key(:changed_by)], by)
      end)
    end
  end

  defp note_values(%AmendmentNote{} = n),
    do: [n.effect, n.effective_dates, n.effective_from, n.changed_by, n.change_id]

  defp write_notes!([]), do: :ok

  defp write_notes!(changes) do
    changes
    |> Enum.chunk_every(5_000)
    |> Enum.each(fn batch ->
      Repo.query!(
        """
        UPDATE amendment_annotations AS a
        SET effect = c.effect, effective_from = c.effective_from, changed_by = c.changed_by,
            change_id = c.change_id, effective_dates = ARRAY(SELECT jsonb_array_elements_text(c.dates::jsonb)::date)
        FROM unnest($1::text[], $2::text[], $3::date[], $4::text[], $5::text[], $6::text[])
             AS c(id, effect, effective_from, changed_by, change_id, dates)
        WHERE a.id = c.id
        """,
        [
          Enum.map(batch, &elem(&1, 0)),
          Enum.map(batch, &elem(&1, 1).effect),
          Enum.map(batch, &elem(&1, 1).effective_from),
          Enum.map(batch, &elem(&1, 1).changed_by),
          Enum.map(batch, &elem(&1, 1).change_id),
          # dates per note as a JSON array string (a nested list would bind as a 2-D array)
          Enum.map(
            batch,
            &Jason.encode!(Enum.map(elem(&1, 1).effective_dates, fn d -> Date.to_iso8601(d) end))
          )
        ],
        timeout: :infinity
      )
    end)
  end

  defp write_statuses!([]), do: :ok

  defp write_statuses!(changes) do
    {ids, statuses} = Enum.unzip(changes)

    Repo.query!(
      """
      UPDATE legal_articles AS a SET status = c.status
      FROM unnest($1::text[], $2::text[]) AS c(section_id, status)
      WHERE a.section_id = c.section_id
      """,
      [ids, statuses],
      timeout: :infinity
    )

    :ok
  end

  defp write_change_fields!([]), do: :ok

  defp write_change_fields!(changes) do
    Repo.query!(
      """
      UPDATE legal_articles AS a SET effective_from = c.effective_from, changed_by = c.changed_by
      FROM unnest($1::text[], $2::date[], $3::text[]) AS c(section_id, effective_from, changed_by)
      WHERE a.section_id = c.section_id
      """,
      [
        Enum.map(changes, &elem(&1, 0)),
        Enum.map(changes, &elem(&1, 1)),
        Enum.map(changes, &elem(&1, 2))
      ],
      timeout: :infinity
    )

    :ok
  end
end

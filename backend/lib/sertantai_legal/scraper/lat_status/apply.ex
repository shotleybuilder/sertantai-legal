defmodule SertantaiLegal.Scraper.LatStatus.Apply do
  @moduledoc """
  Refreshes a law's change facts (#167; LR-07: from effects, notes as
  hints) in one pass, writing only what changes:

  - each note's effect, effective_dates, effective_from, changed_by,
    change_id and `fact_provenance` — from the effects behind it
    (`effect_ids`), else its text (`AmendmentNote`)
  - each row's `status`, `effective_from` / `changed_by` and
    `change_provenance` (`ChangeFacts.resolve/5`)

  Effects come from `opts[:effects]`, else the law's changes feed through
  the local store (`opts[:store]`, default `:prefer`).

  Called by `CommentaryPersister` after notes are committed (every parse path)
  and by `mix lat.status` (backfill / recompute).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{AmendmentNote, ChangeFacts, LatStagedParser, LatStatus, Territory}

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
  `dry_run: true` resolves and reports without writing; `effects:` the
  law's effects (else fetched, `store:` mode, default `:prefer`).
  """
  @spec refresh(String.t(), keyword()) :: result()
  def refresh(law_name, opts \\ []) when is_binary(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT section_id, text, status, effective_from, changed_by, excluded_extent,
               extent_code, effect_ids, change_provenance
        FROM legal_articles WHERE law_name = $1 ORDER BY sort_key
        """,
        [law_name],
        timeout: :infinity
      )

    %{rows: note_rows} =
      Repo.query!(
        """
        SELECT id, affected_sections, text, code_type, code, effect_ids,
               effect, effective_dates, effective_from, changed_by, change_id, fact_provenance
        FROM amendment_annotations WHERE law_name = $1 ORDER BY id
        """,
        [law_name],
        timeout: :infinity
      )

    effects =
      Keyword.get_lazy(opts, :effects, fn ->
        LatStagedParser.law_effects(law_name, store: Keyword.get(opts, :store, :prefer)) || []
      end)

    by_id = for e <- effects, e.effect_id != nil, into: %{}, do: {e.effect_id, e}

    notes =
      Enum.map(note_rows, fn [id, sections, text, type, code, effect_ids | stored] ->
        %{
          id: id,
          affected_sections: sections,
          text: text || "",
          code_type: type,
          code: code,
          effect_ids: effect_ids || [],
          stored: stored
        }
      end)

    row_maps =
      Enum.map(rows, fn [sid, text, status, _from, _by, excluded, extent, effect_ids, _prov] ->
        %{
          section_id: sid,
          text: text,
          status: base_status(status, text, excluded, extent),
          excluded_extent: excluded,
          extent_code: extent,
          effect_ids: effect_ids || []
        }
      end)

    {facts, out} =
      ChangeFacts.resolve(row_maps, notes, by_id, law_name,
        holders: rows |> Enum.map(&hd/1) |> ChangeFacts.holders(),
        known_laws: known_laws(notes, law_name)
      )

    note_changes =
      for {n, f} <- Enum.zip(notes, facts), n.stored != note_values(f), do: {n.id, f}

    current =
      Map.new(rows, fn [sid, _text, status, from, by, _ex, _ext, _ids, prov] ->
        {sid, {status, [from, by], prov}}
      end)

    status_changes =
      for {sid, r} <- out, elem(current[sid], 0) != r.status, do: {sid, r.status}

    change_changes =
      for {sid, r} <- out,
          {_status, fields, prov} = current[sid],
          fields != [r.effective_from, r.changed_by] or prov != provenance(r),
          do: {sid, r.effective_from, r.changed_by, provenance(r)}

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

  # the parser's status from the row itself (LatParser assign_status): the
  # stored Prospective flag, repealed text, retained everywhere; else in force
  defp base_status("prospective", _text, _excluded, _extent), do: "prospective"

  defp base_status(_stored, text, excluded, extent) do
    cond do
      LatStatus.repealed_text?(text) -> "repealed"
      excluded != nil and Territory.covers?(excluded, extent) -> "repealed_saved"
      true -> "in_force"
    end
  end

  # A Welsh SI cited as plain "S.I." parses as uksi: the register names its
  # notes cite that are uksi or their wsi twins (AmendmentNote.resolve_law/2).
  defp known_laws(notes, law_name) do
    uksi =
      for n <- notes,
          by = AmendmentNote.parse(n.text, n.code_type, law_name).changed_by,
          match?("UK_uksi_" <> _, by),
          uniq: true,
          do: by

    if uksi == [] do
      MapSet.new()
    else
      candidates = uksi ++ Enum.map(uksi, &String.replace_prefix(&1, "UK_uksi_", "UK_wsi_"))

      %{rows: rows} =
        Repo.query!("SELECT name FROM legal_register WHERE name = ANY($1)", [candidates])

      rows |> List.flatten() |> MapSet.new()
    end
  end

  defp provenance(r),
    do: %{
      "status" => to_string(r.status_source),
      "change" => r.change_source && to_string(r.change_source)
    }

  defp note_values(f),
    do: [
      f.effect,
      f.effective_dates,
      f.effective_from,
      f.changed_by,
      f.change_id,
      %{"facts" => to_string(f.source), "dates" => f.dates_source && to_string(f.dates_source)}
    ]

  defp write_notes!([]), do: :ok

  defp write_notes!(changes) do
    changes
    |> Enum.chunk_every(5_000)
    |> Enum.each(fn batch ->
      Repo.query!(
        """
        UPDATE amendment_annotations AS a
        SET effect = c.effect, effective_from = c.effective_from, changed_by = c.changed_by,
            change_id = c.change_id, effective_dates = ARRAY(SELECT jsonb_array_elements_text(c.dates::jsonb)::date),
            fact_provenance = c.prov::jsonb
        FROM unnest($1::text[], $2::text[], $3::date[], $4::text[], $5::text[], $6::text[], $7::text[])
             AS c(id, effect, effective_from, changed_by, change_id, dates, prov)
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
          ),
          Enum.map(batch, &Jason.encode!(&1 |> elem(1) |> note_values() |> List.last()))
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
      UPDATE legal_articles AS a
      SET effective_from = c.effective_from, changed_by = c.changed_by, change_provenance = c.prov::jsonb
      FROM unnest($1::text[], $2::date[], $3::text[], $4::text[])
           AS c(section_id, effective_from, changed_by, prov)
      WHERE a.section_id = c.section_id
      """,
      [
        Enum.map(changes, &elem(&1, 0)),
        Enum.map(changes, &elem(&1, 1)),
        Enum.map(changes, &elem(&1, 2)),
        Enum.map(changes, &Jason.encode!(elem(&1, 3)))
      ],
      timeout: :infinity
    )

    :ok
  end
end

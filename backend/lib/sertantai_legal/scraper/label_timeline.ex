defmodule SertantaiLegal.Scraper.LabelTimeline do
  @moduledoc """
  Builds a law's labels timeline (lat-refactor LR-24) into
  `lat_label_timeline`: reads its rows (`legal_articles`), its changes
  (`lat_change_log_rows`) and its start (the register's `commencement`
  record, LR-33), runs `LabelProjection.timeline/4`, and replaces the law's
  periods in one transaction. Thin: the rules are `LabelProjection`'s.

  The CLML markup status (J2) is the row's `status` where its provenance is
  `markup` and it is repealed or prospective. The law's start, and the
  treatment that decided it, are `LawStart`'s (LR-33).
  """

  alias SertantaiLegal.Scraper.LatRef
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelProjection, LabelsToday}
  alias SertantaiLegal.Scraper.LatParser.Effects

  @doc """
  J2's input (LR-24, LR-25): what the revised text shows, when it says the
  provision is repealed or not yet in force; nil otherwise. Read from the
  parse's `markup_status`, never from a relabelled status.
  """
  @spec j2_markup(String.t() | nil) :: String.t() | nil
  def j2_markup(markup) when markup in ~w(repealed prospective), do: markup
  def j2_markup(_markup), do: nil

  @doc """
  Refuses a law whose rows were parsed before `markup_status` existed
  (LR-25): J2 would silently find no markup reading. `rows`: `[section_id,
  markup_status]` pairs. Re-parse the law first (the wave, or the hook).
  """
  @spec require_markup!(String.t(), [[String.t() | nil]]) :: :ok
  def require_markup!(law_name, rows) do
    case Enum.count(rows, fn [_sid, markup] -> is_nil(markup) end) do
      0 ->
        :ok

      n ->
        raise ArgumentError,
              "#{law_name}: #{n} of #{length(rows)} rows have no markup_status " <>
                "(parsed before LR-25); re-parse the law before building its timeline"
    end
  end

  @doc "The code version stamped on the periods a build writes: the git commit, else \"unknown\"."
  @spec code_version() :: String.t()
  def code_version do
    case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> "unknown"
    end
  end

  @doc """
  J5: a note on a whole provision inserted, added or substituted (a pointer
  only: it withholds the law's start). A words, definition or entry note
  never is (V1-03: "definition of … inserted", NISI 2003/419), the place
  between "Words" and the verb read across its abbreviations ("Words in
  art. 18(1) inserted": SI 2015/595).
  """
  @spec whole_insertion_note?(String.t() | nil) :: boolean()
  def whole_insertion_note?(nil), do: false

  def whole_insertion_note?(text) do
    text =~ ~r/\b(?:inserted|added|substituted)\b/i and
      not (text =~
             ~r/\b(?:words?|definitions?|entr(?:y|ies))\b(?:[^.;]|\.\s*(?=[\d(]))*?\b(?:inserted|added|substituted)\b/i)
  end

  @doc """
  A law's identity for T1 (V1-03): a Welsh SI's note cites its uksi URI
  ("UK_uksi_2011_971") while the feed records "UK_wsi_2011_971" — one law.
  """
  @spec law_key(String.t() | nil) :: String.t() | nil
  def law_key("UK_wsi_" <> rest), do: "UK_uksi_" <> rest
  def law_key(law), do: law

  @doc "A law's timeline from the DB: `%{periods, gaps, rows}` (`rows[].today`: the stored timeline as at today, for the diff)."
  @spec build(String.t(), Date.t()) :: map()
  def build(law_name, today) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT section_id, extent_code, markup_status, excluded_extent, territory_provenance
        FROM legal_articles WHERE law_name = $1 ORDER BY position
        """,
        [law_name]
      )

    :ok = require_markup!(law_name, Enum.map(rows, fn [sid, _, m | _] -> [sid, m] end))

    # the stored timeline's labels as at today, for `mix lat.timeline`'s diff
    stored = LabelsToday.for_law(law_name)

    # J5: rows a note points to as inserted / substituted whole — the row or
    # an ancestor (a pointer only: it withholds the law's start, it supplies
    # no fact; 1962/58 s.58B(2) under "S. 58B inserted")
    %{rows: pointed} =
      Repo.query!(
        """
        SELECT affected_sections, text FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment'
        """,
        [law_name]
      )

    pointed =
      MapSet.new(
        for [sids, text] <- pointed, whole_insertion_note?(text), sid <- sids || [], do: sid
      )

    # T1: the laws each row's amendment notes name (a pointer), to check the
    # register dates a change by each on the row
    %{rows: noted} =
      Repo.query!(
        """
        SELECT s, code, coalesce(citation_law, changed_by) FROM amendment_annotations,
               unnest(affected_sections) s
        WHERE law_name = $1 AND code_type = 'amendment'
        """,
        [law_name]
      )

    noted = Enum.group_by(noted, &hd/1, fn [_, code, l] -> {code, l} end)

    law_type = law_name |> String.split("_") |> Enum.at(1)

    rows =
      for [sid, extent, markup, excluded, claims] <- rows do
        %{
          section_id: sid,
          # LR-26: a row with no extent of its own takes the one its law's
          # type fixes (SSI: S, WSI: E+W, NI: NI); UK types stay unknown
          extent_code: extent || Effects.type_extent(law_type),
          markup_status: j2_markup(markup),
          excluded_extent: excluded,
          # LR-26: the claims behind the row's territory (territory_provenance)
          claims:
            for(
              c <- claims || [],
              do: %{effect_id: c["effect_id"], territory: c["territory"], source: c["source"]}
            ),
          inserted_pointer: sid |> LatRef.ancestors() |> Enum.any?(&MapSet.member?(pointed, &1)),
          # the stored timeline as at today (`mix lat.timeline` diffs a fresh
          # build against it)
          today:
            Map.merge(
              %{status: nil, effective_from: nil, changed_by: nil},
              Map.get(stored, sid, %{})
            )
            |> Map.put(:source, "timeline")
        }
      end

    %{rows: changes, columns: cols} =
      Repo.query!(
        """
        SELECT section_id, evidence, operation, effect_type, affecting_law, in_force,
               effective_from, savings, via, prospective, applied, effect_extent,
               territorial_application, source, pointer, affected_ref
        FROM lat_change_log_rows
        WHERE law_name = $1 AND section_id IS NOT NULL AND collector <> 'commencement'
        """,
        [law_name]
      )

    changes =
      Enum.map(changes, fn r ->
        cols |> Enum.map(&String.to_atom/1) |> Enum.zip(r) |> Map.new()
      end)

    undated? = undated_change(changes, noted)

    rows = Enum.map(rows, &Map.put(&1, :undated_change, undated?.(&1.section_id)))

    law_start = law_start(law_name)
    starts = row_starts(law_name)

    rows =
      Enum.map(rows, fn row ->
        case Map.get(starts, row.section_id) do
          {"provision_dated", %Date{} = d, in_force} ->
            row |> Map.put(:law_start, d) |> clause_in_force(in_force)

          {"provision_qualified", _, [_ | _] = in_force} ->
            row |> Map.put(:law_start, first(in_force)) |> clause_in_force(in_force)

          {"provision_by_order", _, _} ->
            Map.put(row, :by_order, true)

          _ ->
            row
        end
      end)

    law_name
    |> LabelProjection.timeline(rows, changes,
      today: today,
      law_start: law_start,
      made: made_date(law_name),
      text_date: text_date(law_name)
    )
    |> Map.put(:rows, rows)
  end

  @doc """
  Each row's own start from the law's commencement clause (LR-34; CR-06:
  the evaluator's): section_id → `{treatment, date, in_force}` for
  `provision_dated`, `provision_qualified` and `provision_by_order`
  records (`in_force`: the record's entries, partial ones qualified).
  """
  @spec row_starts(String.t()) :: %{String.t() => {String.t(), Date.t() | nil, [map()]}}
  def row_starts(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT section_id, effect_type, effective_from, in_force FROM lat_change_log_rows
        WHERE law_name = $1 AND collector = 'commencement' AND section_id IS NOT NULL
          AND effect_type IN ('provision_dated', 'provision_qualified', 'provision_by_order')
        """,
        [law_name]
      )

    Map.new(rows, fn [sid, t, d, in_force] -> {sid, {t, d, in_force || []}} end)
  end

  # a row partly in force before its full start carries the clause's
  # entries (CR-06: a qualified sentence is a partial rule)
  defp clause_in_force(row, in_force) do
    if Enum.any?(in_force, &(&1["qualification"] != nil)),
      do: Map.put(row, :clause_in_force, in_force),
      else: row
  end

  defp first(in_force),
    do: in_force |> Enum.map(&Date.from_iso8601!(&1["date"])) |> Enum.min(Date)

  @doc """
  The date of the revised text we hold (LR-34 D1 b): the latest parse's
  `source_valid_date` (`dct:valid`), else the day it was parsed.
  """
  @spec text_date(String.t()) :: Date.t() | nil
  def text_date(law_name) do
    case Repo.query!(
           """
           SELECT coalesce(source_valid_date, at::date) FROM lat_events
           WHERE law_name = $1 AND event = 'parsed' ORDER BY at DESC LIMIT 1
           """,
           [law_name]
         ) do
      %{rows: [[%Date{} = d]]} -> d
      _ -> nil
    end
  end

  @doc """
  When the law was made (LR-39): an SI's made date, else an Act's
  enactment (Royal Assent); from then a provision the law commences itself
  exists, prospective until its start.
  """
  @spec made_date(String.t()) :: Date.t() | nil
  def made_date(law_name) do
    case Repo.query!(
           "SELECT coalesce(md_made_date, md_enactment_date) FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law_name]
         ) do
      %{rows: [[%Date{} = d]]} -> d
      _ -> nil
    end
  end

  @doc """
  The law's start (J1's `law_start`): the register's `commencement` record,
  dated by the `LawStart` treatment named in its `effect_type` (LR-33); nil
  for a known limit or a law not yet collected.
  """
  @spec law_start(String.t()) :: Date.t() | nil
  def law_start(law_name) do
    case Repo.query!(
           """
           SELECT effective_from FROM lat_change_log
           WHERE law_name = $1 AND collector = 'commencement' AND section_id IS NULL
             AND effect_type NOT LIKE 'provision\\_%'
           LIMIT 1
           """,
           [law_name]
         ) do
      %{rows: [[%Date{} = d]]} -> d
      _ -> nil
    end
  end

  @doc """
  T1 as a test on a row's section_id: it has an undatable text change when
  change markup on it has no date (`undated_markup/1`), or a note on it
  (`noted`: section_id → [{code, law}]) names a law with no dated text
  change on the row or an ancestor (or names none) — unless a dated text
  change on the row is joined to that very note (V1-03: "inserted by S.I.
  2019/465 … (as substituted) by S.I. 2020/1359", which the feed dates as
  2020/1359's). An ending is a text change (`EffectFacts.kind/2`).
  """
  @spec undated_change([map()], %{String.t() => [{String.t() | nil, String.t() | nil}]}) ::
          (String.t() -> boolean())
  def undated_change(changes, noted) do
    dated =
      for c <- changes,
          c.effective_from != nil,
          c.operation != "other",
          into: MapSet.new(),
          do: {c.section_id, law_key(c.affecting_law)}

    joined =
      for c <- changes,
          c.effective_from != nil,
          c.operation != "other",
          is_binary(c[:pointer]),
          into: MapSet.new(),
          do: {c.section_id, c.pointer}

    unexplained = unexplained_markup(changes)

    # a note on the row is undated unless a dated change joined to it, or a
    # dated text change by the law it names, is on the row or above
    undated_note? = fn levels, {code, law} ->
      not Enum.any?(levels, &MapSet.member?(joined, {&1, code})) and
        (law == nil or not Enum.any?(levels, &MapSet.member?(dated, {&1, law_key(law)})))
    end

    fn sid ->
      levels = LatRef.ancestors(sid)
      notes = Map.get(noted, sid, [])

      by_code =
        Map.new(notes, fn {code, law} -> {code |> String.split(":") |> List.last(), law} end)

      # markup no dated record explains is still explained when its note's
      # law has a dated text change here (an orphan id the feed doesn't hold:
      # "Words in reg. 2(1) substituted (E.) … by S.I. 2023/911", V1-03)
      Enum.any?(Map.get(unexplained, sid, []), fn ref ->
        case Map.fetch(by_code, ref) do
          {:ok, law} -> undated_note?.(levels, {nil, law})
          :error -> true
        end
      end) or Enum.any?(notes, &undated_note?.(levels, &1))
    end
  end

  # markup records no dated record explains: section_id → [ref]
  defp unexplained_markup(changes) do
    explained = explained_refs(changes)

    changes
    |> Enum.filter(
      &(&1.source == "markup" and not MapSet.member?(explained, {&1.section_id, &1[:pointer]}))
    )
    |> Enum.group_by(& &1.section_id, & &1[:pointer])
  end

  defp explained_refs(changes) do
    for c <- changes,
        c.source in ["law", "effect"],
        c.effective_from != nil,
        # the note it points to, or (an effect the markup joined) its id
        ref <- [c[:pointer], if(c.source == "effect", do: c[:evidence])],
        is_binary(ref),
        into: MapSet.new(),
        do: {c.section_id, ref |> String.split(":") |> List.last()}
  end

  @doc """
  Rows with change markup no source dates (T1): a markup record makes its
  row "date unknown" unless a dated law record — or a dated feed effect
  joined through that note (V1-03: legacy `M_F_` markup the feed dates) —
  on the same row points to the same note (the markup's commentary ref =
  the record's note code, "c950488" / "F:c950488": the same change, dated;
  LR-08).
  """
  @spec undated_markup([map()]) :: MapSet.t()
  def undated_markup(changes), do: changes |> unexplained_markup() |> Map.keys() |> MapSet.new()

  @doc "Replace the law's periods. Returns the number written."
  @spec write(String.t(), [LabelProjection.Period.t()], String.t()) :: {:ok, non_neg_integer()}
  def write(law_name, periods, code_version) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM lat_label_timeline WHERE law_name = $1", [law_name])

      periods
      |> Enum.map(fn p ->
        p
        |> Map.from_struct()
        |> Map.merge(%{id: Ecto.UUID.bingenerate(), code_version: code_version, built_at: now})
      end)
      |> Enum.chunk_every(2000)
      |> Enum.reduce(0, fn chunk, n ->
        {k, _} = Repo.insert_all("lat_label_timeline", chunk)
        n + k
      end)
    end)
  end
end

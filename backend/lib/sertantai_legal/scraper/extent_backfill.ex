defmodule SertantaiLegal.Scraper.ExtentBackfill do
  @moduledoc """
  Re-resolve `geo_extent` for stored laws from DB-held sources (#162).

  Sources available without re-scraping: law-level `md_restrict_extent`, LAT
  `extent_code` per provision, whole-instrument extent clauses in LAT text,
  and the type code. `document_status` is only known for laws scraped since
  it was persisted, so a stored law-level extent is trusted when present
  (ContentsItem extents are not stored and are not used here).

  `plan/1` is pure. `load_rows/1` reads the sources; `apply!/2` writes the
  planned changes in batches, each law getting an `extent` change-log entry.
  `Mix.Tasks.Extent.Resolve` snapshots first and reports.

  **Application** rides along (live status parse session, 2026-09-28): the
  same LAT read collects whole-instrument application clauses
  (`ApplicationClause`) into the law's `application_clause`, with
  `text_repealed` when legislation.gov.uk has replaced (almost) all its
  provision text with ". . ." placeholders (repealed in full). It is written
  only when the law holds LAT, so a lean-LAT discard never clears it.
  `refresh/1` then re-decides the law's live status (`LiveStatus.Recompute`).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ApplicationClause
  alias SertantaiLegal.Scraper.ExtentResolver
  alias SertantaiLegal.Scraper.LiveStatus

  # Provisions carrying text of their own (not structure, notes or signatures)
  @substantive "coalesce(a.text, '') <> '' AND a.section_type NOT IN ('title', 'part', 'chapter', 'heading', 'heading_group', 'schedule', 'signed', 'note', 'commencement', 'annex', 'table', 'figure')"

  # legislation.gov.uk replaces the text of wholly repealed provisions with
  # ". . ." placeholders: text this repealed means the law is revoked in full.
  @repealed_share 0.95

  @doc """
  Pure: the resolution for one row and whether it should be written.

  The row carries `lat_extent_codes` and `clause_texts` alongside the stored
  extent fields.
  """
  @spec plan(map()) :: %{
          row: map(),
          resolution: ExtentResolver.result(),
          change?: boolean(),
          application: map() | nil,
          application_change?: boolean()
        }
  def plan(row) do
    resolution =
      ExtentResolver.resolve(%{
        restrict_extent: row.md_restrict_extent,
        document_status: row.document_status,
        lat_extent_codes: row.lat_extent_codes,
        lat_coded_provisions: Map.get(row, :lat_coded_provisions),
        contents_item_extents: [],
        extent_clauses:
          row.clause_texts |> Enum.map(&ExtentResolver.extent_clause/1) |> Enum.reject(&is_nil/1),
        type_code: row.type_code
      })

    change? =
      ExtentResolver.overwrite?(row.geo_extent_source, resolution.source) and
        {row.geo_extent, row.geo_region || [], row.geo_extent_source} !=
          {resolution.geo_extent, resolution.geo_region, resolution.source}

    application = application(row, resolution)

    %{
      row: row,
      resolution: resolution,
      change?: change?,
      application: application,
      application_change?:
        application != nil and
          Map.drop(application, ["lat_hash"]) !=
            Map.drop(Map.get(row, :application_clause) || %{}, ["lat_hash"])
    }
  end

  # Only with LAT held: a law without LAT keeps its stored application.
  defp application(%{has_lat: true} = row, resolution) do
    clauses =
      for %{"text" => text, "section_id" => sid} <- Map.get(row, :application_texts, []),
          clause = ApplicationClause.parse(text),
          do: {sid, text, clause}

    extent =
      (resolution.geo_extent || row.geo_extent) |> LiveStatus.regions()

    %{
      "regions" => ApplicationClause.resolve(Enum.map(clauses, &elem(&1, 2)), extent),
      "clauses" =>
        Enum.map(clauses, fn {sid, text, {kind, regions}} ->
          %{
            "section_id" => sid,
            "kind" => Atom.to_string(kind),
            "regions" => regions,
            "text" => String.slice(text, 0, 400)
          }
        end),
      "lat_hash" => Map.get(row, :lat_hash),
      "text_repealed" => text_repealed?(row)
    }
  end

  defp application(_row, _resolution), do: nil

  defp text_repealed?(%{substantive: n, dotted: d}) when is_integer(n) and n > 0,
    do: d / n >= @repealed_share

  defp text_repealed?(_row), do: false

  @doc "Load extent sources for UK laws (optionally only `names`)."
  @spec load_rows([String.t()] | nil) :: [map()]
  def load_rows(names \\ nil) do
    {filter, params} =
      if names, do: {"AND l.name = ANY($1)", [names]}, else: {"", []}

    %{rows: rows} =
      Repo.query!(
        """
        SELECT l.id, l.name, l.type_code, l.geo_extent, l.geo_region, l.geo_extent_source,
               l.md_restrict_extent, l.document_status,
               COALESCE(lat.codes, '{}'), COALESCE(lat.clauses, '{}'),
               COALESCE(lat.n, 0) > 0, COALESCE(lat.app, '[]'::jsonb), l.lat_hash, l.application_clause,
               COALESCE(lat.substantive, 0), COALESCE(lat.dotted, 0), COALESCE(lat.coded, 0)
        FROM legal_register l
        LEFT JOIN LATERAL (
          SELECT count(*) AS n,
                 count(*) FILTER (WHERE COALESCE(a.extent_code, '') <> '') AS coded,
                 count(*) FILTER (WHERE #{@substantive}) AS substantive,
                 count(*) FILTER (WHERE #{@substantive} AND a.text ~ '^[[:space:].…]+$') AS dotted,
                 array_agg(DISTINCT a.extent_code) FILTER (WHERE COALESCE(a.extent_code, '') <> '') AS codes,
                 array_agg(a.text) FILTER (WHERE a.text ~* '(this|these)\\s+\\w+\\s+extends?\\s+to') AS clauses,
                 jsonb_agg(jsonb_build_object('section_id', a.section_id, 'text', a.text) ORDER BY a.sort_key)
                   FILTER (WHERE a.text ~* '\\mappl(y|ies)\\s+(only\\s+)?(in\\s+relation\\s+to|as\\s+respects|to|in)\\M'
                             AND a.text ~* '(these|this|they)\\s') AS app
          FROM legal_articles a WHERE a.law_name = l.name
        ) lat ON true
        WHERE l.country = 'uk' #{filter}
        ORDER BY l.name
        """,
        params,
        timeout: :timer.minutes(10)
      )

    Enum.map(rows, fn [
                        id,
                        name,
                        type,
                        geo,
                        region,
                        source,
                        restrict,
                        status,
                        codes,
                        clauses,
                        has_lat,
                        app,
                        lat_hash,
                        stored_app,
                        substantive,
                        dotted,
                        coded
                      ] ->
      %{
        id: Ecto.UUID.cast!(id),
        name: name,
        type_code: type,
        geo_extent: geo,
        geo_region: region,
        geo_extent_source: source,
        md_restrict_extent: restrict,
        document_status: status,
        lat_extent_codes: codes,
        clause_texts: clauses,
        has_lat: has_lat,
        application_texts: app,
        lat_hash: lat_hash,
        application_clause: stored_app,
        substantive: substantive,
        dotted: dotted,
        lat_coded_provisions: coded
      }
    end)
  end

  @doc """
  Re-resolve one law's extent from its current sources and write any change.
  Called after LAT is persisted, so new provision extents take effect
  without waiting for a full backfill. Returns the number of rows written.
  """
  @spec refresh(String.t()) :: non_neg_integer()
  def refresh(law_name) do
    plans = [law_name] |> load_rows() |> Enum.map(&plan/1)
    n = apply!(plans)
    apply_application!(plans)
    LiveStatus.Recompute.refresh(law_name)
    n
  end

  @doc "Write planned application changes. Returns the number written."
  @spec apply_application!([map()]) :: non_neg_integer()
  def apply_application!(plans) do
    plans
    |> Enum.filter(& &1.application_change?)
    |> Enum.reduce(0, fn %{row: r, application: app}, n ->
      Repo.query!(
        "UPDATE legal_register SET application_clause = $2 WHERE id = $1 AND country = 'uk'",
        [Ecto.UUID.dump!(r.id), app]
      )

      n + 1
    end)
  end

  @doc "Write planned changes in batches of 1,000. Returns the number written."
  @spec apply!([map()]) :: non_neg_integer()
  def apply!(plans) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    plans
    |> Enum.filter(& &1.change?)
    |> Enum.chunk_every(1_000)
    |> Enum.reduce(0, fn batch, total ->
      payload =
        Enum.map(batch, fn %{row: r, resolution: res} ->
          %{
            id: r.id,
            geo_extent: res.geo_extent,
            regions: res.geo_region,
            source: res.source,
            entry: change_entry(r, res, now)
          }
        end)

      %{num_rows: n} =
        Repo.query!(
          """
          UPDATE legal_register l
          SET geo_extent = x.geo_extent,
              geo_region = ARRAY(SELECT jsonb_array_elements_text(x.regions)),
              geo_extent_source = x.source,
              record_change_log = array_append(COALESCE(l.record_change_log, '{}'::jsonb[]), x.entry)
          FROM jsonb_to_recordset($1::jsonb)
               AS x(id uuid, geo_extent text, regions jsonb, source text, entry jsonb)
          WHERE l.id = x.id AND l.country = 'uk'
          """,
          [payload]
        )

      total + n
    end)
  end

  defp change_entry(row, res, now) do
    %{
      "timestamp" => now,
      "source" => "extent",
      "changed_by" => "extent_backfill",
      "summary" => "Re-resolved extent (#162)",
      "reason" => "extent from #{res.source || "no source (unknown)"}",
      "changes" => %{
        "geo_extent" => %{"old" => row.geo_extent, "new" => res.geo_extent},
        "geo_extent_source" => %{"old" => row.geo_extent_source, "new" => res.source}
      }
    }
  end
end

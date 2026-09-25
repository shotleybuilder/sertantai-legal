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
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ExtentResolver

  @doc """
  Pure: the resolution for one row and whether it should be written.

  The row carries `lat_extent_codes` and `clause_texts` alongside the stored
  extent fields.
  """
  @spec plan(map()) :: %{row: map(), resolution: ExtentResolver.result(), change?: boolean()}
  def plan(row) do
    resolution =
      ExtentResolver.resolve(%{
        restrict_extent: row.md_restrict_extent,
        document_status: row.document_status,
        lat_extent_codes: row.lat_extent_codes,
        contents_item_extents: [],
        extent_clauses:
          row.clause_texts |> Enum.map(&ExtentResolver.extent_clause/1) |> Enum.reject(&is_nil/1),
        type_code: row.type_code
      })

    change? =
      ExtentResolver.overwrite?(row.geo_extent_source, resolution.source) and
        {row.geo_extent, row.geo_region || [], row.geo_extent_source} !=
          {resolution.geo_extent, resolution.geo_region, resolution.source}

    %{row: row, resolution: resolution, change?: change?}
  end

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
               COALESCE(lat.codes, '{}'), COALESCE(lat.clauses, '{}')
        FROM legal_register l
        LEFT JOIN LATERAL (
          SELECT array_agg(DISTINCT a.extent_code) FILTER (WHERE COALESCE(a.extent_code, '') <> '') AS codes,
                 array_agg(a.text) FILTER (WHERE a.text ~* '(this|these)\\s+\\w+\\s+extends?\\s+to') AS clauses
          FROM legal_articles a WHERE a.law_name = l.name
        ) lat ON true
        WHERE l.country = 'uk' #{filter}
        ORDER BY l.name
        """,
        params,
        timeout: :timer.minutes(10)
      )

    Enum.map(rows, fn [id, name, type, geo, region, source, restrict, status, codes, clauses] ->
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
        clause_texts: clauses
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
    [law_name] |> load_rows() |> Enum.map(&plan/1) |> apply!()
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

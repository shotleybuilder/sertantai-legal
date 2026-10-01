defmodule SertantaiLegal.Scraper.LatPersister do
  @moduledoc """
  Persists LAT rows per law in a transaction, **keeping provision enrichment**
  across re-parses (Gemini review 2026-09-26).

  The law's rows are replaced (DELETE + INSERT, which avoids UPSERT complexity
  against mismatched CSV-era citations), but first the existing rows are
  matched to the new parse (`LatMerge.plan/2`) and every non-parser column
  (fractalaw taxa, significance, embeddings, legacy_id…) is carried onto its
  match: same id + same text, or a rename by unique/ordered text. Renames move
  `control_mappings` / annotation references and are logged, with ambiguous
  and dropped ids, in `lat_section_id_renames` for fractalaw.

  Gate: if enriched rows would lose enrichment although their text still
  exists in the new parse, the write is refused and the old LAT kept, unless
  `force: true`. Enrichment on genuinely changed text is not carried (stale).

  ## Usage

      rows = LatParser.parse(xml, context)
      {:ok, result} = LatPersister.persist(rows, "UK_ukpga_1974_37")
      # result = %{inserted: 835, deleted: 234}
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ExtentBackfill, LatEvents, LatMerge, LatParser}
  alias SertantaiLegal.Scraper.LatPersister.Carry

  require Logger

  # insert_all batches are bounded by PostgreSQL's 65,535 bind parameters:
  # rows per batch = this budget / columns per row (~54 with carried columns).
  @param_budget 60_000

  # Transaction timeout scales with row count.
  # Base 30s covers DELETE + small inserts; each 1000 rows adds 10s.
  @base_timeout_ms 30_000
  @timeout_per_1000_rows 10_000

  @doc """
  Delete existing LAT rows for `law_name` and insert `rows` in a transaction.

  ## Parameters

    - `rows` — parsed rows from `LatParser.parse/2`
    - `law_name` — e.g. `"UK_ukpga_1974_37"`
    - `law_id` — UUID of the uk_lrt record (required FK)

  Options: `force: true` — persist even if the enrichment gate fails.

  Returns `{:ok, %{inserted, deleted, carried, renamed, changed, ambiguous,
  dropped, orphaned_mappings}}` on success, `{:error, reason}` on failure
  (including a failed gate, which leaves the existing LAT untouched).

  An empty `rows` list is refused (`{:error, "no LAT rows ..."}`) and the
  law's existing LAT is kept: an empty parse means the body XML had no
  content (e.g. a scanned-PDF-only law), not that the law has no provisions.
  """
  @spec persist([map()], String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, String.t()}
  def persist(rows, law_name, law_id, opts \\ [])

  def persist([], law_name, _law_id, _opts) when is_binary(law_name) do
    {:error, "no LAT rows to persist for #{law_name}; existing LAT kept"}
  end

  def persist(rows, law_name, law_id, opts) when is_list(rows) and is_binary(law_name) do
    insert_maps = LatParser.to_insert_maps(rows, law_id)
    row_count = length(insert_maps)
    timeout = @base_timeout_ms + div(row_count * @timeout_per_1000_rows, 1000)

    result =
      Repo.transaction(
        fn ->
          columns = Carry.carried_columns(Map.keys(hd(insert_maps)))
          existing = Carry.load_existing(law_name, columns)
          plan = LatMerge.plan(existing, insert_maps)
          gate!(plan, law_name, Keyword.get(opts, :force, false))
          insert_maps = carry_values(insert_maps, existing, plan, columns)

          # lat_events context (read by the legal_articles triggers): a merge
          # re-parse replaces rows, it does not discard the law's LAT.
          op_id = Ecto.UUID.generate()

          set_event_context(
            op_id: op_id,
            reason: "reparse",
            source: Keyword.get(opts, :source, "lat_persister"),
            actor: Keyword.get(opts, :actor),
            app_version: app_version()
          )

          # DELETE existing rows for this law
          {deleted, _} =
            Repo.query!(
              "DELETE FROM lat WHERE law_name = $1",
              [law_name]
            )
            |> then(fn %{num_rows: n} -> {n, nil} end)

          # INSERT in batches
          inserted =
            insert_maps
            |> Enum.chunk_every(max(1, div(@param_budget, map_size(hd(insert_maps)))))
            |> Enum.reduce(0, fn batch, acc ->
              {count, _} = Repo.insert_all("lat", batch)
              acc + count
            end)

          # Don't leak "reparse" into a caller's later deletes in the same transaction.
          clear_event_context()

          Carry.apply_renames(plan.renames)
          if existing != [], do: Carry.log_changes(law_name, plan, Ecto.UUID.generate())

          stats = %{
            # the parsed lat_event's op_key: LatCause.Apply records the cause on it (#167)
            op_id: op_id,
            # per-row changes of this parse, for the change log (#167 L8.5)
            plan: plan_summary(plan, existing, insert_maps),
            inserted: inserted,
            deleted: deleted,
            carried: map_size(plan.carry),
            renamed: Enum.count(plan.renames, &(&1.old != &1.new)),
            changed: length(plan.changed),
            ambiguous: length(plan.ambiguous),
            dropped: length(plan.removed),
            orphaned_mappings: Carry.orphaned_mappings(plan.ambiguous ++ plan.removed)
          }

          Logger.info(
            "[LatPersister] #{law_name}: deleted #{deleted}, inserted #{inserted}, carried #{stats.carried}, renamed #{stats.renamed}, changed #{stats.changed}, ambiguous #{stats.ambiguous}, dropped #{stats.dropped} (timeout #{timeout}ms)"
          )

          stats
        end,
        timeout: timeout
      )

    with {:ok, stats} <- result do
      refresh_extent(law_name)
      notify_committed(law_name, stats)
    end

    result
  rescue
    e ->
      Logger.error("[LatPersister] Failed for #{law_name}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  # Rows inserted are new ids that are neither held before nor rename targets.
  defp plan_summary(plan, existing, insert_maps) do
    known = MapSet.union(MapSet.new(existing, &row_id/1), MapSet.new(plan.renames, & &1.new))
    inserted = for m <- insert_maps, not MapSet.member?(known, m.section_id), do: m.section_id

    %{changed: plan.changed, removed: plan.removed, renames: plan.renames, inserted: inserted}
  end

  defp row_id(%{section_id: sid}), do: sid
  defp row_id(%{"section_id" => sid}), do: sid

  # After commit, so the event's lat_hash matches what the queryable serves
  # (fractalatai #62). Secondary to the write: failures are logged, not raised.
  defp notify_committed(law_name, stats) do
    LatEvents.notify(law_name, "persist", %{count: stats.inserted, renamed: stats.renamed})
  rescue
    e ->
      Logger.warning("[LatPersister] lat event failed for #{law_name}: #{Exception.message(e)}")
  end

  @doc """
  Set `lat_events` trigger context for the current transaction
  (`SET LOCAL sertantai.lat.<key>`). Keys: `op_id`, `reason`, `source`,
  `actor`, `archive_ref`, `app_version`; nil values are skipped.
  """
  @spec set_event_context(keyword()) :: :ok
  def set_event_context(context) do
    for {key, value} when not is_nil(value) <- context do
      Repo.query!("SELECT set_config($1, $2, true)", ["sertantai.lat.#{key}", to_string(value)])
    end

    :ok
  end

  @event_context_keys ~w(op_id reason source actor archive_ref app_version)

  @doc "Clear the `lat_events` trigger context for the rest of the transaction."
  @spec clear_event_context() :: :ok
  def clear_event_context do
    for key <- @event_context_keys do
      Repo.query!("SELECT set_config($1, '', true)", ["sertantai.lat.#{key}"])
    end

    :ok
  end

  defp app_version do
    Application.spec(:sertantai_legal, :vsn) |> to_string()
  end

  defp gate!(%LatMerge{lost_unchanged: []}, _law, _force), do: :ok
  defp gate!(_plan, _law, true), do: :ok

  defp gate!(%LatMerge{lost_unchanged: lost}, law_name, false) do
    Repo.rollback(
      "gate: #{length(lost)} enriched rows of #{law_name} would lose enrichment although their text is unchanged " <>
        "(e.g. #{lost |> Enum.take(3) |> Enum.join(", ")}); existing LAT kept — review, or re-run with force: true"
    )
  end

  # Every insert map gets every carried column (nil unless matched) so the
  # insert batches share one header.
  defp carry_values(insert_maps, existing, %LatMerge{carry: carry}, columns) do
    blank = Map.new(columns, &{String.to_atom(&1), nil})
    by_id = Map.new(existing, &{&1.section_id, &1.values})

    Enum.map(insert_maps, fn m ->
      carried = carry |> Map.get(m.section_id) |> then(&Map.get(by_id, &1, %{}))
      blank |> Map.merge(carried) |> Map.merge(m)
    end)
  end

  # New LAT brings provision extents: re-resolve geo_extent for this law (#162).
  # Extent is secondary to the LAT write, so failures are logged, not raised.
  defp refresh_extent(law_name) do
    ExtentBackfill.refresh(law_name)
  rescue
    e ->
      Logger.warning(
        "[LatPersister] Extent refresh failed for #{law_name}: #{Exception.message(e)}"
      )
  end
end

defmodule SertantaiLegal.Scraper.LatPersister do
  @moduledoc """
  Persists LAT rows to the database using DELETE + INSERT per law in a transaction.

  Strategy: for a given law_name, delete all existing LAT rows then insert the
  new rows. This is simple, idempotent, and avoids UPSERT complexity against
  potentially mismatched CSV-era citations.

  ## Usage

      rows = LatParser.parse(xml, context)
      {:ok, result} = LatPersister.persist(rows, "UK_ukpga_1974_37")
      # result = %{inserted: 835, deleted: 234}
  """

  alias SertantaiLegal.Scraper.ExtentBackfill
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Zenoh.ChangeNotifier

  require Logger

  # Batch size for insert_all. Larger batches = fewer round-trips.
  # 2000 rows per batch handles most laws in 1-3 batches.
  @batch_size 2000

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

  Returns `{:ok, %{inserted: N, deleted: N}}` on success, `{:error, reason}` on failure.

  An empty `rows` list is refused (`{:error, "no LAT rows ..."}`) and the
  law's existing LAT is kept: an empty parse means the body XML had no
  content (e.g. a scanned-PDF-only law), not that the law has no provisions.
  """
  @spec persist([map()], String.t(), String.t()) ::
          {:ok, %{inserted: non_neg_integer(), deleted: non_neg_integer()}}
          | {:error, String.t()}
  def persist([], law_name, _law_id) when is_binary(law_name) do
    {:error, "no LAT rows to persist for #{law_name}; existing LAT kept"}
  end

  def persist(rows, law_name, law_id) when is_list(rows) and is_binary(law_name) do
    insert_maps = LatParser.to_insert_maps(rows, law_id)
    row_count = length(insert_maps)
    timeout = @base_timeout_ms + div(row_count * @timeout_per_1000_rows, 1000)

    result =
      Repo.transaction(
        fn ->
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
            |> Enum.chunk_every(@batch_size)
            |> Enum.reduce(0, fn batch, acc ->
              {count, _} = Repo.insert_all("lat", batch)
              acc + count
            end)

          Logger.info(
            "[LatPersister] #{law_name}: deleted #{deleted}, inserted #{inserted} (#{row_count} rows, timeout #{timeout}ms)"
          )

          ChangeNotifier.notify("lat", "persist", %{law_name: law_name, count: inserted})

          %{inserted: inserted, deleted: deleted}
        end,
        timeout: timeout
      )

    with {:ok, _} <- result, do: refresh_extent(law_name)
    result
  rescue
    e ->
      Logger.error("[LatPersister] Failed for #{law_name}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
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

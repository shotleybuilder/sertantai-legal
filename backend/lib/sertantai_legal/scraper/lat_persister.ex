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

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatParser

  require Logger

  @batch_size 500

  @doc """
  Delete existing LAT rows for `law_name` and insert `rows` in a transaction.

  ## Parameters

    - `rows` — parsed rows from `LatParser.parse/2`
    - `law_name` — e.g. `"UK_ukpga_1974_37"`
    - `law_id` — UUID of the uk_lrt record (required FK)

  Returns `{:ok, %{inserted: N, deleted: N}}` on success, `{:error, reason}` on failure.
  """
  @spec persist([map()], String.t(), String.t()) ::
          {:ok, %{inserted: non_neg_integer(), deleted: non_neg_integer()}}
          | {:error, String.t()}
  def persist(rows, law_name, law_id) when is_list(rows) and is_binary(law_name) do
    insert_maps = LatParser.to_insert_maps(rows, law_id)

    Repo.transaction(fn ->
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

      Logger.info("[LatPersister] #{law_name}: deleted #{deleted}, inserted #{inserted}")

      %{inserted: inserted, deleted: deleted}
    end)
  rescue
    e ->
      Logger.error("[LatPersister] Failed for #{law_name}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end
end

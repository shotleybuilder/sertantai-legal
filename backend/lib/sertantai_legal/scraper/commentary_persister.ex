defmodule SertantaiLegal.Scraper.CommentaryPersister do
  @moduledoc """
  Persists amendment annotation rows parsed from body XML Commentaries.

  Strategy: DELETE + INSERT per law in a transaction (same as LatPersister).
  Only deletes annotations with `source = 'lat_parser'` — preserves CSV-imported data.

  ## Usage

      annotations = CommentaryParser.parse(xml, context, ref_to_sections)
      {:ok, result} = CommentaryPersister.persist(annotations, "UK_ukpga_1974_37", law_id)
  """

  alias SertantaiLegal.Repo

  require Logger

  @batch_size 500

  @doc """
  Delete existing parser-sourced annotations for `law_name` and insert new ones.

  ## Parameters

    - `annotations` — parsed annotation maps from `CommentaryParser.parse/3`
    - `law_name` — e.g. `"UK_ukpga_1974_37"`
    - `law_id` — UUID string of the uk_lrt record (required FK)

  Returns `{:ok, %{inserted: N, deleted: N}}` on success, `{:error, reason}` on failure.
  """
  @spec persist([map()], String.t(), String.t()) ::
          {:ok, %{inserted: non_neg_integer(), deleted: non_neg_integer()}}
          | {:error, String.t()}
  def persist(annotations, law_name, law_id)
      when is_list(annotations) and is_binary(law_name) do
    insert_maps = to_insert_maps(annotations, law_id)

    Repo.transaction(fn ->
      # DELETE existing parser-sourced annotations for this law
      {deleted, _} =
        Repo.query!(
          "DELETE FROM amendment_annotations WHERE law_name = $1 AND source = 'lat_parser'",
          [law_name]
        )
        |> then(fn %{num_rows: n} -> {n, nil} end)

      # INSERT in batches
      inserted =
        insert_maps
        |> Enum.chunk_every(@batch_size)
        |> Enum.reduce(0, fn batch, acc ->
          {count, _} = Repo.insert_all("amendment_annotations", batch)
          acc + count
        end)

      Logger.info("[CommentaryPersister] #{law_name}: deleted #{deleted}, inserted #{inserted}")

      %{inserted: inserted, deleted: deleted}
    end)
  rescue
    e ->
      Logger.error("[CommentaryPersister] Failed for #{law_name}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  # Convert parsed annotation maps to insert-ready maps with timestamps and binary UUID
  defp to_insert_maps(annotations, law_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, law_id_binary} = Ecto.UUID.dump(law_id)

    Enum.map(annotations, fn ann ->
      %{
        id: ann.id,
        law_name: ann.law_name,
        law_id: law_id_binary,
        code: ann.code,
        code_type: to_string(ann.code_type),
        source: ann.source,
        text: ann.text,
        affected_sections: ann.affected_sections,
        created_at: now,
        updated_at: now
      }
    end)
  end
end

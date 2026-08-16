defmodule SertantaiLegal.Scraper.DefinitionPersister do
  @moduledoc """
  Persists legislative definition rows parsed from body XML.

  Strategy: upsert per definition (ON CONFLICT on law_name + term + section_id).
  Unlike DELETE+INSERT, this preserves CSV-imported definitions for laws
  not currently being re-parsed, while updating definitions for laws
  that are being scraped.

  ## Usage

      definitions = DefinitionParser.parse(xml, context)
      {:ok, result} = DefinitionPersister.persist(definitions, "UK_uksi_1992_3004")
  """

  alias SertantaiLegal.Repo

  require Logger

  @batch_size 500

  @doc """
  Upsert definitions for a law. Existing definitions for the same
  (law_name, term, section_id) triple are updated; new ones are inserted.

  ## Parameters

    - `definitions` — parsed definition maps from `DefinitionParser.parse/2`
    - `law_name` — e.g. `"UK_uksi_1992_3004"`

  Returns `{:ok, %{upserted: N}}` on success, `{:error, reason}` on failure.
  """
  @spec persist([map()], String.t()) ::
          {:ok, %{upserted: non_neg_integer()}} | {:error, String.t()}
  def persist(definitions, law_name) when is_list(definitions) and is_binary(law_name) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # Deduplicate on (law_name, term, section_id) — last occurrence wins
    definitions =
      definitions
      |> Enum.reduce(%{}, fn d, acc -> Map.put(acc, {d.law_name, d.term, d.section_id}, d) end)
      |> Map.values()

    insert_maps =
      Enum.map(definitions, fn d ->
        %{
          id: Ecto.UUID.dump!(Ecto.UUID.generate()),
          law_name: d.law_name,
          term: d.term,
          term_welsh: d.term_welsh,
          definition: d.definition,
          section_id: d.section_id,
          scope: scope_to_string(d.scope),
          references_other_law: d.references_other_law,
          citation: d[:citation] || false,
          source: "parser",
          inserted_at: now,
          updated_at: now
        }
      end)

    upserted =
      insert_maps
      |> Enum.chunk_every(@batch_size)
      |> Enum.reduce(0, fn batch, acc ->
        {count, _} =
          Repo.insert_all(
            "legislative_definitions",
            batch,
            on_conflict:
              {:replace,
               [
                 :term_welsh,
                 :definition,
                 :section_id,
                 :scope,
                 :references_other_law,
                 :citation,
                 :source,
                 :updated_at
               ]},
            conflict_target: [:law_name, :term, :section_id]
          )

        acc + count
      end)

    Logger.info("[DefinitionPersister] #{law_name}: upserted #{upserted} definitions")

    {:ok, %{upserted: upserted}}
  rescue
    e ->
      Logger.error("[DefinitionPersister] Failed for #{law_name}: #{Exception.message(e)}")
      {:error, Exception.message(e)}
  end

  defp scope_to_string(:law), do: "law"
  defp scope_to_string(:part), do: "part"
  defp scope_to_string(:provision), do: "provision"
  defp scope_to_string(nil), do: nil
end

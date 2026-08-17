defmodule SertantaiLegal.Scraper.RootResolver.Persister do
  @moduledoc """
  Persists resolution results to the database.

  Handles two operations:
  - Updating `referenced_law_citation` on definition rows
  - Inserting links into the `definition_links` junction table

  Uses raw Ecto for batch performance (500-row transactions).
  """

  alias SertantaiLegal.Legal.{DefinitionLink, LegislativeDefinition}
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.RootResolver.Resolution

  import Ecto.Query

  @spec apply_updates([{Resolution.status(), Resolution.t()}]) :: :ok
  def apply_updates(results) do
    now = NaiveDateTime.utc_now()

    results
    |> Enum.chunk_every(500)
    |> Enum.each(fn batch ->
      Repo.transaction(fn ->
        Enum.each(batch, fn {_status, row} ->
          if row.citation do
            from(d in LegislativeDefinition, where: d.id == ^row.id)
            |> Repo.update_all(set: [referenced_law_citation: row.citation, updated_at: now])
          end

          Enum.each(row.root_ids, fn root_id ->
            Repo.insert_all(
              DefinitionLink,
              [%{child_definition_id: row.id, root_definition_id: root_id, inserted_at: now}],
              on_conflict: :nothing,
              conflict_target: [:child_definition_id, :root_definition_id]
            )
          end)
        end)
      end)
    end)

    :ok
  end

  @spec collect_missing_parents([{Resolution.status(), Resolution.t()}]) :: [String.t()]
  def collect_missing_parents(citation_only_results) do
    citation_only_results
    |> Enum.map(fn {_status, row} -> row.target_law end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end
end

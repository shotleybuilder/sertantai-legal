defmodule SertantaiLegal.Scraper.Amendment.PatternSource do
  @moduledoc """
  What the amendment catalogue reads (CV-S06): for the laws of a family
  (or listed), each amending law and, per law it amends, the provisions
  the read pass reads — the amendment notes' pointers and the changes
  feed's text effects' affecting provisions, deduplicated
  (`Amendment.ReadPass`'s pointers, here per amended law). Reads the
  database and the stored feed pages only.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Pointer
  alias SertantaiLegal.Scraper.Amendment.ReadLaw
  alias SertantaiLegal.Scraper.LatStagedParser

  @doc "The LAT laws of a family (`uk_lrt.family` containing `family`)."
  @spec family_laws(String.t()) :: [String.t()]
  def family_laws(family) do
    Repo.query!(
      """
      SELECT name FROM uk_lrt WHERE family LIKE '%' || $1 || '%'
        AND name IN (SELECT DISTINCT law_name FROM legal_articles) ORDER BY name
      """,
      [family]
    ).rows
    |> List.flatten()
  end

  @doc "Amending law → amended law → the pointers read, for `laws`."
  @spec pointers([String.t()]) :: %{String.t() => %{String.t() => [Pointer.ref()]}}
  def pointers(laws) do
    laws
    |> Enum.flat_map(&law_pointers/1)
    |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
    |> Map.new(fn {amending, rows} ->
      {amending,
       rows
       |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
       |> Map.new(fn {law, refs} -> {law, refs |> List.flatten() |> Enum.uniq()} end)}
    end)
  end

  defp law_pointers(law) do
    notes =
      Repo.query!(
        """
        SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
        WHERE code_type = 'amendment' AND law_name = $1
          AND coalesce(citation_law, changed_by) ~ '^UK_'
        """,
        [law]
      ).rows
      |> List.flatten()
      |> Enum.map(fn a -> {a, law, ReadLaw.note_refs(a, ReadLaw.notes(a, law))} end)

    feed =
      for e <- LatStagedParser.law_effects(law, store: :only) || [],
          is_binary(e.affecting) and e.affecting =~ ~r/^UK_/,
          ReadLaw.text_effect?(e),
          do: {e.affecting, law, Pointer.refs_in(e.affecting_provisions)}

    notes ++ feed
  end
end

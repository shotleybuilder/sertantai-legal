defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source do
  @moduledoc """
  What the measures read (change vocabulary CV-S10): the laws of a family
  or of the golden set, each law's stored changes, and the read pass's
  pointers the conflict report needs. One place, so every figure is
  computed from the same inputs (before CV-S10, `lat.vocabulary` gave the
  conflict report the read pass's pointers and the strata modules gave it
  none).

  DB and files; the measures themselves are pure (`Measures.Coverage`).
  """

  alias SertantaiLegal.Scraper.Amendment.{Index, PatternSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Conflicts, Store}

  @golden "test/fixtures/change_vocabulary/golden.exs"
  @golden_extended "test/fixtures/change_vocabulary/golden_extended.exs"

  @doc "A family's laws with LAT rows."
  @spec family_laws(String.t()) :: [String.t()]
  def family_laws(family), do: PatternSource.family_laws(family)

  @doc "The golden set's provisions; with `extended?`, `golden_extended.exs` too."
  @spec golden_cases(boolean()) :: [map()]
  def golden_cases(extended? \\ false) do
    files = if extended?, do: [@golden, @golden_extended], else: [@golden]
    Enum.flat_map(files, &elem(Code.eval_file(&1), 0))
  end

  @doc "The golden set's laws."
  @spec golden_laws(boolean()) :: [String.t()]
  def golden_laws(extended? \\ false),
    do: extended? |> golden_cases() |> Enum.map(& &1.law) |> Enum.uniq()

  @doc "A law's stored changes."
  @spec changes(String.t()) :: [Change.t()]
  def changes(law), do: Store.for_law(law)

  @doc """
  What the read pass read of each amending law behind `changes` (its
  index's pointers): the conflict report's `read` set.
  """
  @spec pointers([Change.t()]) :: %{String.t() => [String.t()]}
  def pointers(changes) do
    for l <- changes |> Enum.map(& &1.resolved.by) |> Enum.reject(&is_nil/1) |> Enum.uniq(),
        index = Index.get(l),
        index != nil,
        into: %{},
        do: {l, index["pointers"] || []}
  end

  @doc "The conflict report over a law's changes, with the read pass's pointers."
  @spec conflicts([Change.t()]) :: [map()]
  def conflicts(changes), do: Conflicts.report(changes, pointers(changes))
end

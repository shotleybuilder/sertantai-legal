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
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LatRef
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
  What the read pass read of each amending law behind `changes`: its
  index's pointers whose provision the text holds (`read_pointers/2`), the
  conflict report's `read` set. A pointer into text the store doesn't hold
  (a Schedule fetched without its body's Schedules) was never read
  (Maritime Safety: Measures, the hand check: 1,129 of 9,426 pointers).
  """
  @spec pointers([Change.t()]) :: %{String.t() => [String.t()]}
  def pointers(changes) do
    for l <- changes |> Enum.map(& &1.resolved.by) |> Enum.reject(&is_nil/1) |> Enum.uniq(),
        index = Index.get(l),
        index != nil,
        into: %{},
        do: {l, read_pointers(index["pointers"] || [], index["elements"] || [])}
  end

  @doc """
  The pointers whose provision, or one containing it, is among the text's
  element ids. An order's "art.N" pointer is matched as the element's
  "reg.N" ref (`Order.ref/1`), and is read in both spellings: the feed
  names an order's articles either way.
  """
  @spec read_pointers([String.t()], [String.t()]) :: [String.t()]
  def read_pointers(pointers, elements) do
    held = elements |> Enum.map(&Order.ref/1) |> Enum.reject(&is_nil/1) |> MapSet.new()

    pointers
    |> Enum.filter(fn p -> p |> containing() |> Enum.any?(&MapSet.member?(held, &1)) end)
    |> Enum.flat_map(&Enum.uniq([&1, as_reg(&1)]))
  end

  defp as_reg(pointer), do: String.replace(pointer, ~r/\Aart\./, "reg.")

  # "s.2(3)(b)" → s.2(3)(b), s.2(3), s.2; "sch.1.para.3(a)" → …, sch.1.para.3, sch.1
  defp containing(pointer) do
    ref = as_reg(pointer)
    bare = String.replace(ref, ~r/\(.*\z/, "")
    parts = String.split(bare, ".")

    dotted =
      for n <- 2..length(parts)//2, n < length(parts), do: parts |> Enum.take(n) |> Enum.join(".")

    LatRef.ancestors(ref) ++ dotted
  end

  @doc "The conflict report over a law's changes, with the read pass's pointers."
  @spec conflicts([Change.t()]) :: [map()]
  def conflicts(changes), do: Conflicts.report(changes, pointers(changes))
end

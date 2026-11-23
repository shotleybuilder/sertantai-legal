defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Subdivisions do
  @moduledoc """
  A provision less the subdivisions excepted from it, as its other
  subdivisions (Fire and OH&S: Extent reader, 2026-11-14): "Part 3 (with
  the exception of section 151(5))" in "The following provisions of this
  Act do not extend to Northern Ireland— …" (Energy Act 2004 s.198(4)) →
  s.151(1) to (4) and (6), each named in the law's text; s.151(5) keeps
  the default. A list that narrows names them one by one, since no list
  restores the default to a subdivision carried with its provision
  (Decision 3, 2026-11-09, read a widening list's whole). A provision
  with no subdivisions held, or an excepted one not found among them,
  stays withheld. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ItemExceptions
  alias SertantaiLegal.Scraper.Commencement.ClmlRef

  @doc """
  Each of `holding` (provisions holding an excepted subdivision) as its
  subdivisions less the `excepted`: `{the subdivisions, the provisions so
  read}`. A provision not read this way is in neither.
  """
  @spec less([String.t()], [String.t()], Doc.t()) :: {[String.t()], [String.t()]}
  def less([], _excepted, _doc), do: {[], []}

  def less(holding, excepted, %Doc{} = doc) do
    refs = for id <- doc.ids, r = ClmlRef.ref(id), r != nil, do: r

    read = for h <- holding, subs = rest(h, excepted, refs), subs != nil, do: {h, subs}

    {Enum.flat_map(read, &elem(&1, 1)), Enum.map(read, &elem(&1, 0))}
  end

  # the provision's subdivisions less the excepted; nil when it has none
  # held, or one of them can't be read less its own
  defp rest(ref, excepted, refs) do
    case Enum.filter(refs, &child?(&1, ref)) do
      [] -> nil
      children -> children |> Enum.map(&kept(&1, excepted, refs)) |> all()
    end
  end

  defp kept(child, excepted, refs) do
    case ItemExceptions.touched?(child, excepted) do
      :excepted -> []
      false -> [child]
      :holds -> rest(child, excepted, refs)
    end
  end

  defp all(kept), do: if(Enum.any?(kept, &is_nil/1), do: nil, else: Enum.concat(kept))

  # "s.151(5)" of "s.151": one level down
  defp child?(r, ref) do
    String.starts_with?(r, ref <> "(") and
      Regex.match?(~r/^\(\w+\)$/u, String.replace_prefix(r, ref, ""))
  end
end

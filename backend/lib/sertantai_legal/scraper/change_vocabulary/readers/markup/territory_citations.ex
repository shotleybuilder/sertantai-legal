defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.TerritoryCitations do
  @moduledoc """
  The instrument a note pairs with each territory.

  One note may record the same change made for two territories by two
  instruments: "S. 22(3) repealed (E.W.) (12.1.2010) by Marine and Coastal
  Access Act 2009 (c. 23), s. 324(3), Sch. 22 Pt. 5(A); S.I. 2009/3345,
  art. 2 …; and s. 22(3) repealed (S.) (24.2.2011) by Marine (Scotland)
  Act 2010 (asp 5), …" (the Wildlife and Countryside Act 1981). Each
  territory's instrument is the first linked Citation after that
  territory's "by" (the next is its commencement order), outside the date
  bracket (`NoteCitation`).

  A pointer for identity only: the territory is the change element's
  Extent, never the note's words. A note pairs territories only when it
  names two or more, and a territory it gives two instruments is left
  out. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.NoteCitation
  alias SertantaiLegal.Scraper.Territory

  @place "(?:E|W|S|N\\.?\\s?I)"
  # "(E.W.) (12.1.2010 for E., 15.3.2007 (being …) for W.) by", "(S.) by"
  @head Regex.compile!(
          "\\((#{@place}(?:\\.?\\s*#{@place})*)\\.?\\)\\s*" <>
            "(?:\\(\\s*\\d(?:[^()]|\\([^()]*\\))*\\)\\s*)?by\\b",
          "u"
        )

  @doc """
  `{territory, Citation}` for each territory a note's `Commentary` pairs
  with one instrument, in the note's order; `[]` unless it pairs two or
  more. The territory is a code as `Territory.normalize/1` gives it.
  """
  @spec pairs(tuple()) :: [{String.t(), tuple()}]
  def pairs(commentary) do
    pairs =
      commentary
      |> NoteCitation.linked()
      |> Enum.flat_map(&headed/1)
      |> Enum.uniq_by(fn {head, _territory, _el} -> head end)
      |> Enum.map(fn {_head, territory, el} -> {territory, el} end)
      |> single()

    if length(pairs) >= 2, do: pairs, else: []
  end

  # a Citation under the territory "by" last before it: where that "by"
  # ends, its territory, the Citation
  defp headed({el, before}) do
    with false <- NoteCitation.in_date_bracket?(before),
         [_ | _] = heads <- Regex.scan(@head, before, return: :index),
         [{start, len}, {at, size}] = List.last(heads),
         territory when is_binary(territory) <-
           before |> binary_part(at, size) |> Territory.normalize() do
      [{start + len, territory, el}]
    else
      _ -> []
    end
  end

  # the territories given one instrument
  defp single(pairs) do
    counts = Enum.frequencies_by(pairs, &elem(&1, 0))
    Enum.filter(pairs, fn {territory, _el} -> counts[territory] == 1 end)
  end
end

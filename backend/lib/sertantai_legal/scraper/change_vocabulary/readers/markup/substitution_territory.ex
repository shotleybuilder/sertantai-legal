defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.SubstitutionTerritory do
  @moduledoc """
  The Extent a change's markup states for where the change applies.

  A change's elements nearly always state one Extent, and the first stated
  is the change's. A substitution made for one territory with the old words
  kept for another states two: the retained Repeal's is where the old words
  stay, and its new words' (the Addition its SubstitutionRef names, under
  the same note) is where the change applies. The new words' is the
  change's — Childcare Act 2006 s.101(1)(a): Repeal `Extent="E"`, Addition
  `Extent="W"`, note "Words in s. 101(1)(a) substituted (W.)".

  New words under another change's note are not this change's (a
  mis-pointed SubstitutionRef: Waste and Emissions Trading Act 2003
  s.25(2)), and new words stating no Extent leave the Repeal's standing.
  Pure.
  """

  @typedoc "A change element's occurrence, as `Readers.Markup` reads it."
  @type occurrence :: %{
          required(:kind) => atom(),
          required(:change_id) => String.t(),
          required(:extent) => String.t() | nil,
          optional(atom()) => term()
        }

  @doc "The Extent as written (not normalised), or nil where none is stated."
  @spec extent([occurrence()]) :: String.t() | nil
  def extent(occurrences) do
    new_words(occurrences) || Enum.find_value(occurrences, & &1.extent)
  end

  # the Extent of the new words a retained Repeal of the change names
  defp new_words(occurrences) do
    occurrences
    |> Enum.filter(&(&1.kind == :Repeal and &1.retain and &1.substitution_ref != nil))
    |> Enum.find_value(fn repeal ->
      Enum.find_value(occurrences, &(own_new_words?(&1, repeal) && &1.extent))
    end)
  end

  defp own_new_words?(occurrence, repeal) do
    occurrence.kind == :Addition and occurrence.change_id == repeal.substitution_ref and
      occurrence.note != nil and occurrence.note == repeal.note
  end
end

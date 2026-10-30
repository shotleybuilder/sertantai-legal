defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Shared do
  @moduledoc """
  One effect placed on a provision and on places inside it (CV-S09 round
  6: SI 2008/960 art.8, "In section 16, for each reference to 'the
  Commission' substitute 'the Executive'" — the law's text and its
  commencement read on s.16, the feed and markup on each of s.16(1), (2),
  …): the law's text states the change in every place, so the places
  under the provision share its law-text and commencement claims. Only a
  words change ("each reference", "in each place it occurs"); only places
  with none of their own. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.LatRef

  @shared [:law_text, :commencement]

  @doc "The changes, each effect's places given its provision's law-text claims."
  @spec spread([Change.t()]) :: [Change.t()]
  def spread(changes) do
    changes
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {_key, group} -> spread_group(group) end)
  end

  defp spread_group([_] = group), do: group

  defp spread_group(group) do
    stating =
      Enum.filter(
        group,
        &(Change.value(&1, :law_text, :level) == :words and
            Change.values(&1, :law_text, :by) != [])
      )

    Enum.map(group, fn c ->
      with [] <- Change.values(c, :law_text, :by),
           %Change{} = s <- Enum.find(stating, &(&1.target in tl(LatRef.ancestors(c.target)))) do
        %{c | claims: c.claims ++ Enum.filter(s.claims, &(&1.source in @shared))}
      else
        _ -> c
      end
    end)
  end
end

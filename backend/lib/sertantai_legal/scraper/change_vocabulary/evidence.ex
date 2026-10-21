defmodule SertantaiLegal.Scraper.ChangeVocabulary.Evidence do
  @moduledoc """
  The evidence table (change vocabulary, CV-01 design): for each attribute
  of a change, which source's claim wins. One table replaces the pairwise
  reconciling rules (`EffectTerritory.claim`'s step order, rule 3's gate, J2).

  | Attribute | Order |
  |---|---|
  | operation | markup > feed |
  | level | markup > feed |
  | territory | feed application > markup Extent > feed effect extent narrower than the provision > the affecting law's territory (a removal whose text is retained, narrower than the provision) > none |
  | date | feed |
  | by | feed > the markup note's cited law |
  | retained | markup |

  `resolve/2` sets `Change.resolved` (each value with the source that won,
  under `:sources`). Slice: the attributes the slice's cases need. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.Territory

  @doc "The change with each attribute chosen; `extent` is the provision's extent."
  @spec resolve(Change.t(), String.t() | nil) :: Change.t()
  def resolve(%Change{} = c, extent) do
    {operation, op_src} = first(c, [{:markup, :operation}, {:feed, :operation}])
    {retained, _} = first(c, [{:markup, :retained}])

    {territory, t_src} =
      first(c, [
        {:feed, :territory},
        {:markup, :territory},
        {:feed, :effect_extent, &narrower(&1, extent)},
        {:law, :territory,
         &(operation == :repealed and retained == true and narrower(&1, extent))}
      ])

    {level, _} = first(c, [{:markup, :level}, {:feed, :level}])
    {date, _} = first(c, [{:feed, :date}])
    {by, _} = first(c, [{:feed, :by}, {:markup, :cited}])

    %{
      c
      | resolved: %{
          operation: operation,
          level: level || :provision,
          territory: territory,
          date: date,
          by: by,
          retained: retained == true,
          sources: %{operation: op_src, territory: t_src}
        }
    }
  end

  # the first source in order claiming the attribute (and passing its test)
  defp first(change, order) do
    Enum.find_value(order, {nil, nil}, fn
      {source, attribute} ->
        case Change.value(change, source, attribute) do
          nil -> nil
          v -> {v, source}
        end

      {source, attribute, ok?} ->
        case Change.value(change, source, attribute) do
          nil -> nil
          v -> if ok?.(v), do: {v, source}
        end
    end)
  end

  defp narrower(territory, extent), do: not Territory.covers?(territory, extent)
end

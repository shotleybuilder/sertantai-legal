defmodule SertantaiLegal.Scraper.ChangeVocabulary.Evidence do
  @moduledoc """
  The evidence table (change vocabulary, CV-01 design): for each attribute
  of a change, which source's claim wins. One table replaces the pairwise
  reconciling rules (`EffectTerritory.claim`'s step order, rule 3's gate, J2).

  `table/0` is the table as data: per attribute, the sources in order, each
  `{source, claim attribute}` or `{source, claim attribute, condition}`. A
  condition is a named test (`condition?/3`) on the claim's value, the
  provision and the change's own claims — stated in the table, never hidden
  in code. The first source in order with a claim that passes wins.
  `resolve/2` writes a `Resolved` struct, with the winning source of each
  attribute. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.Territory

  defmodule Resolved do
    @moduledoc "A change's chosen attributes, and the source each came from."
    @enforce_keys [:operation, :level, :territory, :date, :by, :retained, :sources]
    defstruct [:operation, :level, :territory, :date, :by, :retained, :sources]

    @type t :: %__MODULE__{
            operation: atom() | nil,
            level: :provision | :words,
            territory: String.t() | nil,
            date: Date.t() | nil,
            by: String.t() | nil,
            retained: boolean(),
            sources: %{atom() => atom() | nil}
          }
  end

  @table [
    operation: [{:markup, :operation}, {:feed, :operation}],
    level: [{:markup, :level}, {:feed, :level}],
    retained: [{:markup, :retained}],
    # where the change applies: the feed's application, the markup's Extent,
    # an effect extent narrower than the provision, then the affecting law's
    # territory — only for a removal whose text is retained (V1-04: an
    # insertion by a devolved law can apply across the border)
    territory: [
      {:feed, :territory},
      {:markup, :territory},
      {:feed, :effect_extent, :narrower_than_provision},
      {:law, :territory, :retained_removal_narrower}
    ],
    date: [{:feed, :date}],
    by: [{:feed, :by}, {:markup, :cited}]
  ]

  @doc "The evidence table: attribute → sources in order (with named conditions)."
  @spec table() :: keyword()
  def table, do: @table

  @doc "The change with each attribute chosen; `extent` is the provision's extent."
  @spec resolve(Change.t(), String.t() | nil) :: Change.t()
  def resolve(%Change{} = c, extent) do
    chosen = Map.new(@table, fn {attribute, order} -> {attribute, first(c, order, extent)} end)
    value = &elem(chosen[&1], 0)

    %{
      c
      | resolved: %Resolved{
          operation: value.(:operation),
          level: value.(:level) || :provision,
          territory: value.(:territory),
          date: value.(:date),
          by: value.(:by),
          retained: value.(:retained) == true,
          sources: Map.new(chosen, fn {attribute, {_v, source}} -> {attribute, source} end)
        }
    }
  end

  defp first(change, order, extent) do
    Enum.find_value(order, {nil, nil}, fn entry ->
      {source, attribute, condition} =
        case entry do
          {s, a} -> {s, a, nil}
          {s, a, cond} -> {s, a, cond}
        end

      case Change.value(change, source, attribute) do
        nil ->
          nil

        v ->
          if condition == nil or condition?(condition, v, %{change: change, extent: extent}),
            do: {v, source}
      end
    end)
  end

  @doc """
  The table's named conditions:
  - `:narrower_than_provision` — the territory doesn't cover the provision's extent
  - `:retained_removal_narrower` — the change removes text the markup retains
    (by the claims: markup or feed operation `:repealed`, markup `retained`),
    and the territory is narrower than the provision's extent
  """
  @spec condition?(atom(), term(), %{change: Change.t(), extent: String.t() | nil}) :: boolean()
  def condition?(:narrower_than_provision, territory, %{extent: extent}),
    do: not Territory.covers?(territory, extent)

  def condition?(:retained_removal_narrower, territory, %{change: c, extent: extent}) do
    operation = Change.value(c, :markup, :operation) || Change.value(c, :feed, :operation)

    operation == :repealed and Change.value(c, :markup, :retained) == true and
      not Territory.covers?(territory, extent)
  end
end

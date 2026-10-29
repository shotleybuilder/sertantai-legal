defmodule SertantaiLegal.Scraper.ChangeVocabulary.EvidenceStrata do
  @moduledoc """
  The evidence check's strata (change vocabulary CV-S08, Jason
  2026-10-29): each merged change in at most one of three —

  - `:V`, value conflicts: the law's text (or its commencement) and
    legislation.gov.uk differ on an attribute (`Resolved.conflicts`,
    `Conflicts.values/1`) — is each a real disagreement, like for like,
    and did the right side win?
  - `:D`, derived disagreements: legislation.gov.uk's markup and its feed
    differ on an attribute with no primary claim to settle it
    (`disagreements/1`) — not reported as conflicts (both derived), the
    table's order alone chooses: is its choice right?
  - `:A`, agreeing: two or more sources claim one of the table's
    attributes, with nothing flagged — is each chosen value right, and is
    no real disagreement left unreported?

  The rest (each attribute from one source alone) took no evidence
  decision: the readers' checks (CV-S02–S06) judged those values. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}

  @type stratum :: :V | :D | :A

  # the markup's claim that answers the feed's on one attribute: its note's
  # cited law answers the feed's affecting law
  @derived_pairs [operation: :operation, level: :level, territory: :territory, by: :cited]

  @doc "One law's changes in a stratum, each with it."
  @spec classify([Change.t()]) :: [{Change.t(), stratum()}]
  def classify(changes) do
    for c <- changes, s = stratum(c), s != nil, do: {c, s}
  end

  defp stratum(c) do
    cond do
      c.resolved != nil and c.resolved.conflicts != [] -> :V
      disagreements(c) != [] -> :D
      contested(c) != [] -> :A
      true -> nil
    end
  end

  @doc """
  The attributes on which the markup and the feed differ while no primary
  source claims them: each `{attribute, markup values, feed values}`.
  Values that share one are not a disagreement (a feed listing an effect
  twice).
  """
  @spec disagreements(Change.t()) :: [{atom(), [term()], [term()]}]
  def disagreements(%Change{} = c) do
    for {attribute, markup_attribute} <- @derived_pairs,
        primary(c, attribute) == [],
        # the feed's level speaks only where it placed the event
        attribute != :level or Evidence.placed_here?(c),
        m = Change.values(c, :markup, markup_attribute),
        f = Change.values(c, :feed, attribute),
        m != [] and f != [],
        MapSet.disjoint?(MapSet.new(m), MapSet.new(f)),
        do: {attribute, m, f}
  end

  @doc "The table's attributes two or more sources claim for the change."
  @spec contested(Change.t()) :: [atom()]
  def contested(%Change{} = c) do
    for {attribute, order} <- Evidence.table(),
        length(claimants(c, order)) >= 2,
        do: attribute
  end

  defp claimants(c, order),
    do: order |> Enum.map(&source(c, &1)) |> Enum.reject(&is_nil/1) |> Enum.uniq()

  # the entry's source when it claims the attribute (the law's inferred
  # territory, `:law`, is not a source of the change: never counted)
  defp source(_c, {:law, _}), do: nil
  defp source(_c, {:law, _, _}), do: nil
  defp source(c, {s, a}), do: if(Change.values(c, s, a) != [], do: s)
  defp source(c, {s, a, _}), do: source(c, {s, a})

  defp primary(c, attribute) do
    for {s, a} <- entries(attribute),
        Evidence.tier(s) == :primary,
        v <- Change.values(c, s, a),
        do: v
  end

  defp entries(attribute),
    do: Evidence.table() |> Keyword.get(attribute, []) |> Enum.map(&{elem(&1, 0), elem(&1, 1)})
end

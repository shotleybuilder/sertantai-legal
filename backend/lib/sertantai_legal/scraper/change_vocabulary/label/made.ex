defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Made do
  @moduledoc """
  A law made, not yet in force (LR-39, Jason; kept for the new labels
  CV-06, 2026-10-31): a provision its law commences itself exists from the
  law's making, prospective until its start.

  Only where nothing else dates the provision (as `LabelProjection` has
  it): the law's start is dated, the provision begins at it (no later
  insertion), no insertion of it reaches it on that day (an insertion of
  words in it is no evidence it began then: SI 1993/3138 reg.81 by SI
  1994/541, Maritime Safety: Label fold), and no commencement but its own
  law's clause reaches it (uksi 2017/469 art.1(1) and art.11).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

  @emptied %{in_force_from: nil, changed_by: nil, commenced_by: nil}

  @doc """
  `periods` with a prospective period from `provision.made` to the first
  period's start prepended, where the rule holds; else unchanged.
  `born` is the day the provision begins (`Label.Start.start/2`).
  """
  @spec from([map()], map(), Date.t(), [Change.t()]) :: [map()]
  def from([first | _] = periods, provision, born, reaching) do
    made = Map.get(provision, :made)

    if made != nil and Map.get(provision, :start_dated, false) and born == provision.start and
         Date.compare(made, first.valid_from) == :lt and
         not dated_otherwise?(reaching, Map.get(provision, :law), born) do
      prepend(periods, made)
    else
      periods
    end
  end

  def from([], _provision, _born, _reaching), do: []

  @doc """
  A law with no start held — commenced by an order (NISI 1997/1774, made
  1997-07-22, by SR 1998/235 from 1998-07-01: CV-06 round 2, S4) — begins
  at its making, prospective, where a dated commencement reaches the row
  later; `provision` unchanged otherwise (its start stays unknown: NISI
  1998/2795, whose order isn't held).
  """
  @spec by_order(map(), [Change.t()]) :: map()
  def by_order(%{start_dated: false, made: %Date{} = made} = provision, reaching) do
    if Map.get(provision, :law, "") |> String.starts_with?("UK_eu") or
         not Enum.any?(
           reaching,
           &(&1.resolved.operation == :commenced and &1.resolved.date != nil and
               Date.compare(&1.resolved.date, made) == :gt)
         ),
       do: provision,
       else: %{provision | start: made, start_dated: true}
  end

  def by_order(provision, _reaching), do: provision

  # a first period already prospective reaches back to the making
  defp prepend([%{status: :prospective} = first | rest], made),
    do: [%{first | valid_from: made} | rest]

  # the fields it empties have no tier (tier-per-field; the start's tiers
  # were copied: Maritime Safety: Label fold, the agent pass)
  defp prepend([first | _] = periods, made) do
    tiers = Map.merge(Map.get(first, :tiers, %{}), @emptied)

    [
      first
      |> Map.merge(%{
        valid_from: made,
        valid_to: first.valid_from,
        status: :prospective,
        in_force_from: nil,
        changed_by: [],
        commenced_by: []
      })
      |> Map.put(:tiers, tiers)
      | periods
    ]
  end

  defp dated_otherwise?(reaching, self, born) do
    Enum.any?(reaching, fn c ->
      case c.resolved.operation do
        :commenced ->
          not own_clause?(c, self)

        op when op in [:inserted, :added] ->
          c.resolved.level != :words and Date.compare(c.resolved.date, born) != :gt

        _ ->
          false
      end
    end)
  end

  defp own_clause?(_c, nil), do: false
  # the law's own clause, never an order read into the same record
  defp own_clause?(c, self),
    do:
      String.starts_with?(c.key, self <> ":commencement:") and
        c.resolved.commenced_by in [nil, self] and c.resolved.by in [nil, self]
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Made do
  @moduledoc """
  A law made, not yet in force (LR-39, Jason; kept for the new labels
  CV-06, 2026-10-31): a provision its law commences itself exists from the
  law's making, prospective until its start.

  Only where nothing else dates the provision (as `LabelProjection` has
  it): the law's start is dated, the provision begins at it (no later
  insertion), no insertion reaches it on that day, and no commencement but
  its own law's clause reaches it (uksi 2017/469 art.1(1) and art.11).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

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

  # a first period already prospective reaches back to the making
  defp prepend([%{status: :prospective} = first | rest], made),
    do: [%{first | valid_from: made} | rest]

  defp prepend([first | _] = periods, made) do
    [
      %{
        first
        | valid_from: made,
          valid_to: first.valid_from,
          status: :prospective,
          in_force_from: nil,
          changed_by: [],
          commenced_by: []
      }
      | periods
    ]
  end

  defp dated_otherwise?(reaching, self, born) do
    Enum.any?(reaching, fn c ->
      case c.resolved.operation do
        :commenced -> not own_clause?(c, self)
        op when op in [:inserted, :added] -> Date.compare(c.resolved.date, born) != :gt
        _ -> false
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

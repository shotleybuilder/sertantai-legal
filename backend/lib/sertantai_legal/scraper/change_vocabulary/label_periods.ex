defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelPeriods do
  @moduledoc """
  The label fold's periods (`Label.fold/3`) in the timeline's shape
  (`lat_label_timeline`, what compliance reads), so the timeline can be
  built from the merged changes (CV-05) beside the register's
  (`LabelProjection`):

  - `status` as its string;
  - `changed_by` one law, as compliance reads it today: the last the fold
    lists (the makers of the current text share its day);
    `changed_by_all` every law, `commenced_by` the commencing laws apart
    from them (Jason 2026-10-31: add, don't replace);
  - `territory` "nowhere" empty on a repeal (the table's meaning: empty
    with repealed is nowhere), kept with any other status;
  - `change_ids` the keys of the reaching changes dated on the period's
    first day.

  `violations/1` checks the table's rules (one period per row on any date,
  each period non-empty, the five statuses) before anything is written.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label}

  @repealed ~w(repealed repealed_saved)a
  @statuses ~w(in_force in_force_partial prospective repealed repealed_saved)

  @doc "A row's fold periods as timeline rows for `section_id` of `law`."
  @spec periods(String.t(), String.t(), [Label.period()], [Change.t()]) :: [map()]
  def periods(law, section_id, periods, reaching) do
    by_day = Enum.group_by(reaching, & &1.resolved.date, & &1.key)

    for p <- periods do
      %{
        law_name: law,
        section_id: section_id,
        valid_from: p.valid_from,
        valid_to: p.valid_to,
        status: Atom.to_string(p.status),
        in_force_from: p.in_force_from,
        changed_by: List.last(p.changed_by),
        changed_by_all: p.changed_by,
        commenced_by: Map.get(p, :commenced_by, []),
        territory: territory(p.status, p.territory),
        change_ids: by_day |> Map.get(p.valid_from, []) |> Enum.sort()
      }
    end
  end

  @doc """
  Timeline rows breaking the table's rules, as `{section_id, why}`:
  `:status` (not one of the five), `:empty` (it ends on or before its
  start), `:overlap` (two periods of one row share a date; an open period
  followed by another overlaps).
  """
  @spec violations([map()]) :: [{String.t(), :status | :empty | :overlap}]
  def violations(rows) do
    per_period =
      for r <- rows,
          why <- [
            if(r.status not in @statuses, do: :status),
            if(r.valid_to != nil and Date.compare(r.valid_to, r.valid_from) != :gt, do: :empty)
          ],
          why != nil,
          do: {r.section_id, why}

    overlaps =
      for {sid, rs} <- Enum.group_by(rows, & &1.section_id),
          rs = Enum.sort_by(rs, & &1.valid_from, Date),
          {a, b} <- Enum.zip(rs, tl(rs)),
          a.valid_to == nil or Date.compare(a.valid_to, b.valid_from) == :gt,
          do: {sid, :overlap}

    Enum.sort(per_period ++ overlaps)
  end

  defp territory(status, "nowhere") when status in @repealed, do: nil
  defp territory(_status, territory), do: territory
end

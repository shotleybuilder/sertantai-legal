defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelPeriods do
  @moduledoc """
  The label fold's periods (`Label.fold/3`) in the timeline's shape
  (`lat_label_timeline`, what compliance reads), so the timeline can be
  built from the merged changes (CV-05) beside the register's
  (`LabelProjection`):

  - `status` as its string;
  - `changed_by` one law, as compliance reads it today: the law that
    made the text, else the law that commenced it — the old labels'
    meaning (CV-06). Among several makers (they share the text's day),
    the principal one: never an amender of the amending law before it
    took effect, unless only those made it; then the latest made, by year
    and number (Maritime Safety: Labels side by side, Decision 1: REACH
    Art 127E is SI 2019/758's, not SI 2020/1577's);
    `changed_by_all` every law, `commenced_by` the commencing laws apart
    from them (Jason 2026-10-31: add, don't replace);
  - a repeal (repealed, repealed_saved) as the table records it (Jason
    2026-10-31, CV-06: keep the table's rule): `in_force_from` the day
    it took effect, `territory` empty (nowhere); "nowhere" with any
    other status is kept;
  - a law with no start (`undated_start/0`, the fold's placeholder): no
    period from it — before the first dated day the row is unknown, as
    the table has it (no row);
  - `change_ids` the keys of the reaching changes dated on the period's
    first day.

  `violations/1` checks the table's rules (one period per row on any date,
  each period non-empty, the five statuses) before anything is written.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts

  @repealed ~w(repealed repealed_saved)a
  @statuses ~w(in_force in_force_partial prospective repealed repealed_saved)

  @undated ~D[1900-01-01]

  @doc "The start a law with none is folded from (C10): a placeholder, never a label."
  @spec undated_start() :: Date.t()
  def undated_start, do: @undated

  @doc "A row's fold periods as timeline rows for `section_id` of `law`."
  @spec periods(String.t(), String.t(), [Label.period()], [Change.t()]) :: [map()]
  def periods(law, section_id, periods, reaching) do
    by_day = Enum.group_by(reaching, & &1.resolved.date, & &1.key)

    for p <- periods, p.valid_from != @undated do
      repeal? = p.status in @repealed

      %{
        law_name: law,
        section_id: section_id,
        valid_from: p.valid_from,
        valid_to: p.valid_to,
        status: Atom.to_string(p.status),
        in_force_from: if(repeal?, do: p.valid_from, else: p.in_force_from),
        changed_by: one_law(p.changed_by, reaching) || List.last(Map.get(p, :commenced_by, [])),
        changed_by_all: p.changed_by,
        commenced_by: Map.get(p, :commenced_by, []),
        territory: if(repeal?, do: nil, else: p.territory),
        change_ids: by_day |> Map.get(p.valid_from, []) |> Enum.sort()
      }
    end
  end

  # the principal maker, then the latest made (Decision 1)
  defp one_law([], _reaching), do: nil

  defp one_law(makers, reaching) do
    principal =
      Enum.filter(makers, fn law ->
        Enum.any?(reaching, &(&1.resolved.by == law and not Facts.earlier_amendment?(&1)))
      end)

    Enum.max_by(if(principal == [], do: makers, else: principal), &made/1)
  end

  # a law's year and number, e.g. UK_uksi_2019_858 → {2019, 858, name}
  defp made(law) do
    case Regex.run(~r/_(\d{4})_(\d+)$/, law) do
      [_, year, number] -> {String.to_integer(year), String.to_integer(number), law}
      nil -> {0, 0, law}
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
end

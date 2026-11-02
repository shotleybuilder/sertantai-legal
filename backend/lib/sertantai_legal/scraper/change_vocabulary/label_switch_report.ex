defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitchReport do
  @moduledoc """
  What a family's switch-over would write (CV-06 dry run): per law, the
  register's timeline beside the change vocabulary's — periods, rows whose
  periods differ, the rows kept (named known limits), and today's status
  counts each way. Pure.
  """

  @fields ~w(valid_from valid_to status in_force_from changed_by territory)a

  @type law_report :: %{
          law: String.t(),
          rows: non_neg_integer(),
          periods_old: non_neg_integer(),
          periods_new: non_neg_integer(),
          differ: non_neg_integer(),
          today_old: map(),
          today_new: map()
        }

  @doc "One law's comparison of `old` (register periods) and `new` (the rows to write), as at `today`."
  @spec law(String.t(), [map()], [map()], Date.t()) :: law_report()
  def law(law, old, new, today) do
    old = Enum.map(old, &plain/1)
    by = fn rows -> Enum.group_by(rows, & &1.section_id, &Map.take(&1, @fields)) end
    {o, n} = {by.(old), by.(new)}
    sids = MapSet.union(MapSet.new(Map.keys(o)), MapSet.new(Map.keys(n)))

    %{
      law: law,
      rows: MapSet.size(sids),
      periods_old: length(old),
      periods_new: length(new),
      differ: Enum.count(sids, &(sorted(o[&1]) != sorted(n[&1]))),
      today_old: today_counts(old, today),
      today_new: today_counts(new, today)
    }
  end

  @doc "The laws' reports summed."
  @spec total([law_report()]) :: map()
  def total(reports) do
    sum = fn k -> reports |> Enum.map(&Map.fetch!(&1, k)) |> Enum.sum() end

    merge = fn k ->
      Enum.reduce(reports, %{}, &Map.merge(&2, Map.fetch!(&1, k), fn _, a, b -> a + b end))
    end

    %{
      laws: length(reports),
      rows: sum.(:rows),
      periods_old: sum.(:periods_old),
      periods_new: sum.(:periods_new),
      differ: sum.(:differ),
      today_old: merge.(:today_old),
      today_new: merge.(:today_new)
    }
  end

  # each row's status as at `today` ("unknown": no period then)
  defp today_counts(rows, today) do
    rows
    |> Enum.group_by(& &1.section_id)
    |> Enum.map(fn {_, ps} ->
      Enum.find_value(ps, "unknown", fn p ->
        if Date.compare(p.valid_from, today) != :gt and
             (p.valid_to == nil or Date.compare(today, p.valid_to) == :lt),
           do: p.status
      end)
    end)
    |> Enum.frequencies()
  end

  defp sorted(nil), do: []
  defp sorted(ps), do: Enum.sort_by(ps, &Date.to_iso8601(&1.valid_from))

  defp plain(p) when is_struct(p), do: Map.from_struct(p)
  defp plain(p), do: p
end

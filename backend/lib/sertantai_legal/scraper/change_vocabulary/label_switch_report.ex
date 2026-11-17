defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitchReport do
  @moduledoc """
  What a family's switch-over would write (CV-06 dry run): per law, the
  register's timeline beside the change vocabulary's — periods, rows whose
  periods differ, the rows kept (named known limits), and today's status
  counts each way. After the apply, the same comparison against the stored
  timeline (`:written`) checks every field the switch writes. Pure.
  """

  @fields ~w(valid_from valid_to status in_force_from changed_by territory)a
  # what the switch writes beside them (the old register holds neither)
  @written @fields ++ ~w(changed_by_all commenced_by)a

  @type law_report :: %{
          law: String.t(),
          rows: non_neg_integer(),
          periods_old: non_neg_integer(),
          periods_new: non_neg_integer(),
          differ: non_neg_integer(),
          today_old: map(),
          today_new: map()
        }

  @doc """
  One law's comparison of `old` and `new` (the rows to write), as at
  `today`: `:register` compares the old register's fields (the dry run);
  `:written` every field the switch writes (`old` the stored timeline,
  `LabelSwitch.stored/1`: Environmental Protection, Switch-over).
  """
  @spec law(String.t(), [map()], [map()], Date.t(), :register | :written) :: law_report()
  def law(law, old, new, today, compared \\ :register) do
    fields = if compared == :written, do: @written, else: @fields
    old = Enum.map(old, &plain/1)
    by = fn rows -> Enum.group_by(rows, & &1.section_id, &Map.take(&1, fields)) end
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

  @type moved_row :: %{
          law: String.t(),
          section_id: String.t(),
          today_old: String.t(),
          today_new: String.t(),
          fields: [atom()],
          old: [map()],
          new: [map()]
        }

  @doc """
  The provisions whose periods differ between `old` and `new`, one each:
  today's status each way, the fields that differ (`:periods` when the
  periods' days differ; a field when its run of values differs, so an
  unchanged value split across new periods isn't named), and both
  periods, sorted (`lat.label_switch --rows`: Fire and OH&S, Labels side
  by side).
  """
  @spec rows(String.t(), [map()], [map()], Date.t(), :register | :written) :: [moved_row()]
  def rows(law, old, new, today, compared \\ :register) do
    fields = if compared == :written, do: @written, else: @fields
    by = fn rows -> Enum.group_by(rows, & &1.section_id, &Map.take(plain(&1), fields)) end
    {o, n} = {by.(old), by.(new)}

    (Map.keys(o) ++ Map.keys(n))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn sid ->
      {os, ns} = {sorted(o[sid]), sorted(n[sid])}
      if os == ns, do: [], else: [moved(law, sid, os, ns, fields, today)]
    end)
  end

  defp moved(law, sid, os, ns, fields, today) do
    days = fn ps -> Enum.map(ps, &{&1.valid_from, &1.valid_to}) end
    runs = fn ps, f -> ps |> Enum.map(&Map.get(&1, f)) |> Enum.dedup() end
    differ = for f <- fields -- [:valid_from, :valid_to], runs.(os, f) != runs.(ns, f), do: f

    %{
      law: law,
      section_id: sid,
      today_old: today_status(os, today),
      today_new: today_status(ns, today),
      fields: if(days.(os) != days.(ns), do: [:periods | differ], else: differ),
      old: os,
      new: ns
    }
  end

  @doc "Moved rows as tab-separated lines: law, provision, today's status old and new, fields, period counts, then each period old and new."
  @spec tsv([moved_row()]) :: String.t()
  def tsv(rows) do
    Enum.map_join(rows, fn r ->
      Enum.join(
        [
          r.law,
          r.section_id,
          r.today_old,
          r.today_new,
          Enum.map_join(r.fields, "+", &Atom.to_string/1),
          length(r.old),
          length(r.new),
          Enum.map_join(r.old, " | ", &period_text/1),
          Enum.map_join(r.new, " | ", &period_text/1)
        ],
        "\t"
      ) <> "\n"
    end)
  end

  defp period_text(p) do
    "#{p.valid_from}→#{p.valid_to || "…"} #{p.status} iff=#{p[:in_force_from]} " <>
      "ter=#{p[:territory]} by=#{p[:changed_by]} cb=#{Enum.join(p[:commenced_by] || [], ",")}"
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
    |> Enum.map(fn {_, ps} -> today_status(ps, today) end)
    |> Enum.frequencies()
  end

  defp today_status(ps, today) do
    Enum.find_value(ps, "unknown", fn p ->
      if Date.compare(p.valid_from, today) != :gt and
           (p.valid_to == nil or Date.compare(today, p.valid_to) == :lt),
         do: p.status
    end)
  end

  defp sorted(nil), do: []
  defp sorted(ps), do: Enum.sort_by(ps, &Date.to_iso8601(&1.valid_from))

  defp plain(p) when is_struct(p), do: Map.from_struct(p)
  defp plain(p), do: p
end

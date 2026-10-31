defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelShadow do
  @moduledoc """
  The switch-over's shadow comparison (CV-06): a row's new timeline rows
  (`LabelPeriods`) against its stored ones (`lat_label_timeline`), and the
  cause of the difference, so each cause can be checked on a sample
  (Jason 2026-10-31: "group, then sample").

  - **As at today** first: the first field that differs, in the order
    status, in_force_from, territory, changed_by; the cause names the old
    and new values' kind and the new side's evidence (the reaching change
    that decides it: its operation and sources).
  - **History** only when today agrees: the earliest period that differs.
  - `nil` when the two agree throughout.

  Compared as compliance reads them: `changed_by` agrees when the old law
  is one of the new laws; territory as `Territory.normalize/1` has it.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Windsor}
  alias SertantaiLegal.Scraper.Territory

  @fields [:status, :in_force_from, :territory, :changed_by]
  @removals ~w(repealed repealed_in_part)a
  @primary ~w(law law_text commencement)a

  @doc "The period of `periods` holding on `date`; nil when none (unknown)."
  @spec at([map()], Date.t()) :: map() | nil
  def at(periods, date) do
    Enum.find(periods, fn p ->
      Date.compare(p.valid_from, date) != :gt and
        (p.valid_to == nil or Date.compare(date, p.valid_to) == :lt)
    end)
  end

  @doc "The fields where `old` and `new` (one period each) differ, in order."
  @spec fields(map(), map()) :: [atom()]
  def fields(old, new), do: Enum.reject(@fields, &same?(&1, old, new))

  @doc "Why the row's new periods differ from its old ones; nil when they agree."
  @spec cause(String.t(), [map()], [map()], [Change.t()], Date.t()) :: String.t() | nil
  def cause(law, old, new, reaching, today) do
    case {at(old, today), at(new, today)} do
      {nil, nil} -> history(old, new)
      {nil, n} -> "today: old unknown, new #{n.status}"
      {o, nil} -> "today: new unknown, old #{o.status}"
      {o, n} -> today(law, o, n, reaching) || history(old, new)
    end
  end

  defp today(law, o, n, reaching) do
    case fields(o, n) do
      [] -> nil
      [field | _] -> "today: " <> why(field, law, o, n, reaching)
    end
  end

  defp why(:status, _law, o, n, reaching) do
    evidence =
      cond do
        n.status in ~w(repealed repealed_saved) -> deciding(reaching, n.valid_from, @removals)
        o.status in ~w(repealed repealed_saved) and not removed?(reaching) -> "no repeal held"
        o.status == "prospective" -> deciding(reaching, n.valid_from, [:commenced])
        true -> deciding(reaching, n.valid_from, nil)
      end

    "status #{o.status}→#{n.status} (#{evidence})"
  end

  defp why(:in_force_from, _law, o, n, reaching) do
    case {o.in_force_from, n.in_force_from} do
      {nil, d} -> "in_force_from old undated, new #{deciding(reaching, d, nil)}"
      {_, nil} -> "in_force_from new undated (#{n.status})"
      {a, b} -> "in_force_from new #{later(a, b)} (#{deciding(reaching, b, nil)})"
    end
  end

  defp why(:territory, law, o, n, _reaching) do
    cond do
      Windsor.listed?(law) -> "territory Windsor #{o.territory || "∅"}→#{n.territory || "∅"}"
      o.territory in [nil, ""] -> "territory old unknown, new #{n.territory}"
      true -> "territory #{o.territory}→#{n.territory || "∅"}"
    end
  end

  defp why(:changed_by, _law, o, n, _reaching) do
    cond do
      o.changed_by in [nil, ""] -> "changed_by old none"
      n.changed_by_all == [] -> "changed_by new none"
      true -> "changed_by other law"
    end
  end

  defp history(old, new) do
    pairs = Enum.zip(old, new)

    case Enum.find(pairs, fn {o, n} -> o.valid_from != n.valid_from or fields(o, n) != [] end) do
      nil when length(old) == length(new) ->
        nil

      nil ->
        "history: #{if length(old) > length(new), do: "fewer", else: "more"} periods"

      {%{status: "prospective", valid_to: to}, %{valid_from: to}} when to != nil ->
        "history: old prospective from the law's making"

      {%{valid_from: from}, %{status: "prospective", valid_to: from}} ->
        "history: new prospective from the law's making"

      {o, n} when o.valid_from != n.valid_from ->
        "history: start #{later(o.valid_from, n.valid_from)}"

      {o, n} ->
        "history: #{o |> fields(n) |> hd()}"
    end
  end

  # the reaching change dated `date` that decides the new value: its
  # operation and sources ("commenced [commencement]"); "none dated" when
  # no change carries that day
  defp deciding(_reaching, nil, _ops), do: "undated"

  defp deciding(reaching, date, ops) do
    reaching
    |> Enum.filter(&(&1.resolved.date == date and (ops == nil or &1.resolved.operation in ops)))
    |> Enum.sort_by(&{&1.resolved.operation != :commenced, &1.key})
    |> case do
      [] -> "none dated"
      [c | _] -> "#{c.resolved.operation || "other"} [#{sources(c)}]"
    end
  end

  # the tier the change stands on: the law (its text, its own clause, an
  # order read) or legislation.gov.uk only (feed, markup)
  defp sources(c),
    do: if(Enum.any?(c.claims, &(&1.source in @primary)), do: "law", else: "lgu")

  defp removed?(reaching), do: Enum.any?(reaching, &(&1.resolved.operation in @removals))

  defp later(a, b), do: if(Date.compare(b, a) == :gt, do: "later", else: "earlier")

  defp same?(:status, o, n), do: to_string(o.status) == to_string(n.status)

  defp same?(:changed_by, o, n),
    do:
      o.changed_by == n.changed_by or o.changed_by in n.changed_by_all or
        (blank?(o.changed_by) and blank?(n.changed_by))

  defp same?(:territory, o, n), do: norm(o.territory) == norm(n.territory)
  defp same?(f, o, n), do: Map.get(o, f) == Map.get(n, f)

  defp blank?(v), do: v in [nil, ""]

  defp norm(t) when t in [nil, "", "nowhere"], do: nil
  defp norm(t), do: Territory.normalize(t)
end

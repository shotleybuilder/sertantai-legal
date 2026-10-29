defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelStrata do
  @moduledoc """
  The label check's strata (change vocabulary CV-S09), for one row: a
  provision with its folded label periods (`Label.fold/3`).

  - `shapes/3` (stratum S): the fold rules acting on the row — a status
    (prospective, partly in force, repealed), a territory taken out while
    it stays in force (C1, C12), a territorial version (C3), an
    application clause (C6), a renumbering (C4), a commencement through
    its parts, an ancestor's text change or repeal (not its commencement:
    routine), a text change, several laws in one
    day (C5), a commencement for one territory (`in_force_for`), and the
    gaps: a change no source dates, a start no source dates (C10). One
    rule acts the same way on all its rows, so a shape is judged whole.
  - `difference/2` (stratum T): where the periods differ from today's
    stored label (`lat_label_timeline`) — the current period's fields that
    differ, else `"history"`; `"no_today"` when today holds none. Today
    holds one `changed_by`: one of the fold's several laws (C5) agrees.
  - `draw/3`: a reproducible random draw of rows for a seed.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label}
  alias SertantaiLegal.Scraper.Territory

  @text_changes [:substituted, :inserted, :renumbered]
  @fields ~w(status in_force_from changed_by territory)a

  @doc "The fold rules acting on row `id`, from its periods and the changes reaching it."
  @spec shapes(String.t(), [Label.period()], [Change.t()]) :: [atom()]
  def shapes(id, periods, reaching) do
    base = String.replace(id, ~r/\[[^\]]+\]$/, "")
    statuses = MapSet.new(periods, & &1.status)
    ops = fn op -> Enum.any?(reaching, &(&1.resolved.operation == op)) end
    first = List.first(periods)

    [
      prospective: :prospective in statuses,
      partial: :in_force_partial in statuses,
      repealed: :repealed in statuses or :repealed_saved in statuses,
      territory_narrowed:
        first != nil and
          Enum.any?(periods, fn p ->
            p.status in [:in_force, :in_force_partial] and p.territory != first.territory and
              p.territory not in [nil, "nowhere"]
          end),
      version: base != id,
      applied: ops.(:applied),
      renumbered: ops.(:renumbered),
      parts: Enum.any?(reaching, &String.starts_with?(&1.key, "parts:")),
      ancestor:
        Enum.any?(
          reaching,
          &(&1.target != base and &1.resolved.operation in [:repealed | @text_changes])
        ),
      text_change:
        Enum.any?(reaching, &(&1.resolved.operation in @text_changes and &1.resolved.date != nil)),
      several_laws: Enum.any?(periods, &(length(&1.changed_by) > 1)),
      in_force_for:
        Enum.any?(
          reaching,
          &(&1.resolved.operation == :commenced and Change.value(&1, :feed, :in_force_for) != nil)
        ),
      undated_change: Enum.any?(reaching, &(&1.resolved.date == nil)),
      undated_start: first != nil and first.status == :in_force and first.in_force_from == nil
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  @doc "How the fold's periods differ from today's stored ones; nil when they agree."
  @spec difference([Label.period()], [map()]) :: String.t() | nil
  def difference(_ours, []), do: "no_today"

  def difference(ours, today) do
    ours = Enum.map(ours, &norm/1)
    today = Enum.map(today, &norm/1)

    current =
      Enum.reject(@fields, fn f ->
        same?(f, Map.get(List.last(ours), f), Map.get(List.last(today), f))
      end)

    cond do
      current != [] -> Enum.map_join(current, "+", &to_string/1)
      not same_history?(ours, today) -> "history"
      true -> nil
    end
  end

  defp same_history?(ours, today),
    do:
      length(ours) == length(today) and
        Enum.all?(Enum.zip(ours, today), fn {a, b} ->
          a.valid_from == b.valid_from and
            Enum.all?(@fields, &same?(&1, Map.get(a, &1), Map.get(b, &1)))
        end)

  # today's one law is one of the fold's several (C5)
  defp same?(:changed_by, ours, [theirs]) when length(ours) > 1, do: theirs in ours
  defp same?(:changed_by, ours, theirs), do: Enum.sort(ours) == Enum.sort(theirs)
  defp same?(_f, a, b), do: a == b

  defp norm(p),
    do: %{
      valid_from: p.valid_from,
      status: to_string(p.status),
      in_force_from: p.in_force_from,
      changed_by: p.changed_by |> List.wrap() |> Enum.reject(&(&1 in [nil, ""])),
      territory: territory(p.territory)
    }

  defp territory(nil), do: nil
  defp territory("nowhere"), do: "nowhere"
  defp territory(t), do: Territory.normalize(t)

  @doc "A reproducible random draw of `n` rows (`{law, id}`) for `seed`."
  @spec draw([{String.t(), String.t()}], non_neg_integer(), integer()) :: [
          {String.t(), String.t()}
        ]
  def draw(rows, n, seed) do
    :rand.seed(:exsss, {seed, 9, 9})
    rows |> Enum.sort() |> Enum.shuffle() |> Enum.take(n)
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Containers do
  @moduledoc """
  A Part, Chapter or Title row once every row it holds is gone (Jason
  2026-10-30, CV-S09 round 6: NISR 1997/248 Pt IV, its regulations 13–17
  revoked 2006, had stayed in force): repealed on the day its last child
  was — repealed_saved if any child was saved, where they were saved — and
  credited to the laws that repealed them. An exception to C9 for
  containers only: a provision's own children never reach it. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Label
  alias SertantaiLegal.Scraper.Territory

  @gone [:repealed, :repealed_saved]

  @doc """
  `labels` (row id → periods) with each container row closed by its
  children's repeals; `containers` gives each row the containers holding
  it (`Label.containers/2`), nearest first.
  """
  @spec close(%{String.t() => [Label.period()]}, %{String.t() => [String.t()]}) ::
          %{String.t() => [Label.period()]}
  def close(labels, containers) do
    children =
      for {id, held_by} <- containers, c <- held_by, reduce: %{} do
        acc -> Map.update(acc, c, [id], &[id | &1])
      end

    Map.new(labels, fn {id, periods} ->
      case Map.get(children, id) do
        nil -> {id, periods}
        kids -> {id, closed(periods, Enum.map(kids, &List.last(Map.get(labels, &1, []))))}
      end
    end)
  end

  defp closed([], _lasts), do: []

  defp closed(periods, lasts) do
    current = List.last(periods)

    cond do
      current.status in @gone -> periods
      Enum.any?(lasts, &(is_nil(&1) or &1.status not in @gone)) -> periods
      true -> close_on(periods, current, lasts)
    end
  end

  defp close_on(periods, current, lasts) do
    date = lasts |> Enum.map(& &1.valid_from) |> Enum.max(Date)
    saved = Enum.filter(lasts, &(&1.status == :repealed_saved))

    if Date.compare(date, current.valid_from) == :gt do
      gone = %{
        current
        | valid_from: date,
          valid_to: nil,
          status: if(saved == [], do: :repealed, else: :repealed_saved),
          territory:
            if(saved == [],
              do: "nowhere",
              else: saved |> Enum.map(& &1.territory) |> Enum.reject(&is_nil/1) |> union()
            ),
          in_force_from: nil,
          changed_by: lasts |> Enum.flat_map(& &1.changed_by) |> Enum.uniq() |> Enum.sort(),
          commenced_by: [],
          tiers: tiers(lasts)
      }

      List.replace_at(periods, -1, %{current | valid_to: date}) ++ [gone]
    else
      periods
    end
  end

  defp union([]), do: nil
  defp union(ts), do: Territory.union(ts)

  # derived when any child's repeal rests on legislation.gov.uk
  defp tiers(lasts) do
    Map.new(~w(status territory changed_by)a, fn f ->
      ts = Enum.map(lasts, &get_in(&1, [:tiers, f]))

      {f,
       cond do
         :derived in ts -> :derived
         :primary in ts -> :primary
         true -> nil
       end}
    end)
  end
end

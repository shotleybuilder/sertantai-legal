defmodule SertantaiLegal.Scraper.ChangeCollector.Compact do
  @moduledoc """
  Compact change log targets (lat-refactor LR-23 D3): a change written once
  per run of consecutive rows it reaches, not once per row. A range or a
  Part-wide change ("s. 48-106 (Pt. 3) applied", about 690 rows) becomes one
  record from its first row (`section_id`) to its last (`section_id_to`).

  A run is consecutive in document order (the law's rows in order), and only
  merges records of the same change — every field but the rows (`key/1`;
  CR-06: one clause dates consecutive rows differently) — so
  `expand/2` gives back exactly the rows and joins it was made from: the
  fidelity gate. Records with no row pass through. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record

  @doc "Merge per-row records into runs over `order` (the law's section_ids in document order)."
  @spec compact([Record.t()], [String.t()]) :: [Record.t()]
  def compact(records, order) do
    index = order |> Enum.with_index() |> Map.new()
    {placed, loose} = Enum.split_with(records, &Map.has_key?(index, &1.section_id))

    runs =
      placed
      |> Enum.group_by(&key/1)
      |> Enum.flat_map(fn {_key, recs} ->
        recs
        |> Enum.sort_by(&index[&1.section_id])
        |> Enum.uniq_by(& &1.section_id)
        |> Enum.chunk_while([], &extend(&1, &2, index), &finish/1)
        |> Enum.map(fn [last | _] = run ->
          first = List.last(run)
          %{first | section_id_to: if(last == first, do: nil, else: last.section_id)}
        end)
      end)
      |> Enum.sort_by(&{&1.evidence, index[&1.section_id]})

    runs ++ loose
  end

  @doc "A change's identity: every field but the rows it reaches."
  @spec key(Record.t()) :: map()
  def key(%Record{} = r), do: r |> Map.from_struct() |> Map.drop([:section_id, :section_id_to])

  defp extend(rec, [], _index), do: {:cont, [rec]}

  defp extend(rec, [prev | _] = run, index) do
    if index[rec.section_id] == index[prev.section_id] + 1,
      do: {:cont, [rec | run]},
      else: {:cont, run, [rec]}
  end

  defp finish([]), do: {:cont, []}
  defp finish(run), do: {:cont, run, []}

  @doc "Per-row records from compact ones over `order` (as the `lat_change_log_rows` view does)."
  @spec expand([Record.t()], [String.t()]) :: [Record.t()]
  def expand(records, order) do
    index = order |> Enum.with_index() |> Map.new()

    Enum.flat_map(records, fn
      %Record{section_id_to: nil} = r ->
        [r]

      %Record{section_id: from, section_id_to: to} = r ->
        for sid <- Enum.slice(order, index[from]..index[to]//1),
            do: %{r | section_id: sid, section_id_to: nil}
    end)
  end
end

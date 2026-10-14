defmodule SertantaiLegal.Scraper.LatParser.SortKey do
  @moduledoc """
  Document-order repair of a law's parsed rows' `sort_key`s, the last step of
  every parse (`LatParser.parse/2`). `Transforms.build_sort_key/2` can't
  express some numbering (58Z1, (z10), (vic)), legislation.gov.uk markup
  that closes a level early, or contradictory insert orders (68A before
  68ZA in one law, 16ZZA before 16ZA in another), so a row's key can sort
  before its predecessor's. Such a row takes its predecessor's structural
  prefix with its own position, so every law's keys ascend with position.
  The repaired rows' segments are borrowed, not their own numbering: keys
  are for ordering only. Pure.

  Moved from `Legal.Lat.SortKeyRewrite` (lat-refactor LR-28), whose in-place
  rewrite of stored keys was a one-off repair, now deleted.
  """

  @doc """
  Document-order repair: process rows by `position`, keep the longest
  increasing subsequence of `sort_key`s unchanged, and give every other row
  its predecessor's structural prefix (segments 0–21) with its own position
  segment and extent suffix — so one too-high key is repaired rather than
  every row after it. Rows before the first kept row take the first kept
  row's prefix. Returned by position; keys ascend with position.
  """
  @spec monotonic([%{section_id: String.t(), position: integer(), sort_key: String.t()}]) ::
          [map()]
  def monotonic(rows) do
    sorted = Enum.sort_by(rows, & &1.position)
    keep = lis_indices(Enum.map(sorted, & &1.sort_key))

    first_kept =
      case Enum.find_index(0..(length(sorted) - 1)//1, &MapSet.member?(keep, &1)) do
        nil -> nil
        i -> Enum.at(sorted, i).sort_key
      end

    sorted
    |> Enum.with_index()
    |> Enum.map_reduce(nil, fn {row, i}, prev ->
      row =
        cond do
          MapSet.member?(keep, i) -> row
          prev -> %{row | sort_key: inherit(prev, row.sort_key)}
          true -> %{row | sort_key: inherit(first_kept, row.sort_key)}
        end

      {row, row.sort_key}
    end)
    |> elem(0)
  end

  # Indices of one longest strictly increasing subsequence (patience sorting).
  defp lis_indices([]), do: MapSet.new()

  defp lis_indices(keys) do
    arr = List.to_tuple(keys)
    n = tuple_size(arr)

    {tails, parents} =
      Enum.reduce(0..(n - 1), {[], %{}}, fn i, {tails, parents} ->
        k = elem(arr, i)
        pos = lower_bound(tails, k, arr)
        parent = if pos > 0, do: Enum.at(tails, pos - 1), else: nil
        tails = if pos == length(tails), do: tails ++ [i], else: List.replace_at(tails, pos, i)
        {tails, Map.put(parents, i, parent)}
      end)

    Stream.unfold(List.last(tails), fn
      nil -> nil
      i -> {i, parents[i]}
    end)
    |> MapSet.new()
  end

  # First position in `tails` whose key is >= k (binary search).
  defp lower_bound(tails, k, arr) do
    t = List.to_tuple(tails)
    do_lower_bound(t, k, arr, 0, tuple_size(t))
  end

  defp do_lower_bound(_t, _k, _arr, lo, hi) when lo >= hi, do: lo

  defp do_lower_bound(t, k, arr, lo, hi) do
    mid = div(lo + hi, 2)

    if elem(arr, elem(t, mid)) < k,
      do: do_lower_bound(t, k, arr, mid + 1, hi),
      else: do_lower_bound(t, k, arr, lo, mid)
  end

  defp inherit(prev_key, own_key) do
    [prev_body | _] = String.split(prev_key, "~", parts: 2)

    [own_body, own_extent] =
      own_key |> String.split("~", parts: 2) |> then(&(&1 ++ [""])) |> Enum.take(2)

    prefix = prev_body |> String.split(".") |> Enum.drop(-1)
    own_pos = own_body |> String.split(".") |> List.last()
    Enum.join(prefix ++ [own_pos], ".") <> "~" <> own_extent
  end
end

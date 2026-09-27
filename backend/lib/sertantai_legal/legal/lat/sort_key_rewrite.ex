defmodule SertantaiLegal.Legal.Lat.SortKeyRewrite do
  @moduledoc """
  Pure in-place correction of stored `sort_key`s for the two
  `Transforms.build_sort_key/2` fixes of 2026-09-26, without re-parsing (a
  re-parse would DELETE+INSERT the law's LAT and lose fractalaw's provision
  enrichment):

  - the part (1–3) and chapter (4–6) segments are recomputed, so labelled
    values ("CHAPTER III", "PART7A") sort by their number
  - the provision segment (10–12) is recomputed, so EU-style numbers
    ("Article 12A") sort by their number rather than the letters "AR"
  - the P3 paragraph segment (16–18) is recomputed letters-only, so
    (c), (d), (i), (l), (m), (v), (x) are no longer read as Roman numerals,
    and "(c)" sorts as c
  - an unscheduled `signed` row gets part segment 999 (segments 1–3), so it
    sorts after the body and before the schedules

  - the position segment (22) is re-padded to 6 digits from the row's
    position (4 digits broke order past row 9,999)

  `monotonic/1` then repairs, in document order (position), any row whose
  key still sorts before its predecessor's — numbering the key cannot
  express (58Z1, (z10), (vic)), legislation.gov.uk markup that closes a
  level early, contradictory insert orders (68A before 68ZA in one law,
  16ZZA before 16ZA in another). Such a row takes its predecessor's
  structural prefix with its own position, so every law's keys ascend with
  position. `LatParser` applies the same repair, so parse and rewrite agree.

  Only current-format keys (23 dot-separated segments, `~extent` suffix) are
  rewritten; older-generation formats return `:skip` and need a re-parse.
  """

  alias SertantaiLegal.Legal.Lat.Transforms

  @segments 23
  @chapter 4..6
  @provision 10..12
  @paragraph 16..18
  @part 1..3
  @position 22

  @type row :: %{
          section_type: String.t(),
          part: String.t() | nil,
          chapter: String.t() | nil,
          provision: String.t() | nil,
          paragraph: String.t() | nil,
          schedule: String.t() | nil
        }

  @doc "Corrected sort_key for a stored row, or `:skip` for an older key format."
  @spec rewrite(String.t(), row()) :: {:ok, String.t()} | :skip
  def rewrite(sort_key, row) do
    [body, extent] =
      case String.split(sort_key, "~", parts: 2) do
        [b, e] -> [b, e]
        [b] -> [b, ""]
      end

    segs = String.split(body, ".")

    if length(segs) == @segments and String.contains?(sort_key, "~") do
      segs =
        segs
        |> put_number(row.part, @part)
        |> put_number(row.chapter, @chapter)
        |> put_number(row.provision, @provision)
        |> put_paragraph(row.paragraph)
        |> put_signed_part(row.section_type, row.schedule)
        |> put_position(Map.get(row, :position))

      {:ok, Enum.join(segs, ".") <> "~" <> extent}
    else
      :skip
    end
  end

  defp put_position(segs, nil), do: segs

  defp put_position(segs, pos),
    do: List.replace_at(segs, @position, String.pad_leading(Integer.to_string(pos), 6, "0"))

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

  defp put_number(segs, nil, _range), do: segs
  defp put_number(segs, "", _range), do: segs

  defp put_number(segs, value, range) do
    value
    |> Transforms.normalize_provision_to_sort_key()
    |> String.split(".")
    |> replace(segs, range)
  end

  defp put_paragraph(segs, nil), do: segs
  defp put_paragraph(segs, ""), do: segs

  defp put_paragraph(segs, paragraph) do
    paragraph
    |> Transforms.normalize_provision_to_sort_key(roman: false)
    |> String.split(".")
    |> replace(segs, @paragraph)
  end

  defp put_signed_part(segs, "signed", nil) do
    "999"
    |> Transforms.normalize_provision_to_sort_key()
    |> String.split(".")
    |> replace(segs, @part)
  end

  defp put_signed_part(segs, _type, _schedule), do: segs

  defp replace(values, segs, range) do
    Enum.zip(range, values)
    |> Enum.reduce(segs, fn {i, v}, acc -> List.replace_at(acc, i, v) end)
  end
end

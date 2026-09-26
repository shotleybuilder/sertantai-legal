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

  Only current-format keys (23 dot-separated segments, `~extent` suffix) are
  rewritten; older-generation formats return `:skip` and need a re-parse.
  """

  alias SertantaiLegal.Legal.Lat.Transforms

  @segments 23
  @chapter 4..6
  @provision 10..12
  @paragraph 16..18
  @part 1..3

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

      {:ok, Enum.join(segs, ".") <> "~" <> extent}
    else
      :skip
    end
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

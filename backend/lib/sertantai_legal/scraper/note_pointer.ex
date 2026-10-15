defmodule SertantaiLegal.Scraper.NotePointer do
  @moduledoc """
  What a legislation.gov.uk note points to (lat-refactor LR-25; replaces
  `AmendmentNote`). Notes are pointers, never facts (LR-20, Jason
  2026-10-15: "we use leg.gov.uk notes as helpers/pointers not as data we
  need to store. The data comes from law or effects"): nothing here reads an
  effect, a date or a status from a note.

  - `law/2`: the instrument the note names after "by" (or, in a
    citation-only note, the instrument it cites), as a law name — where the
    collector looks for the change (`coalesce(citation_law, changed_by)`;
    the note's Citation URI, `citation_law`, comes first). "Water Act 2003
    (c. 37)" → UK_ukpga_2003_37; "S.I. 2002/324 (W. 37)" → UK_wsi_2002_324;
    "(N.I. 7)" → nisi; S.S.I. → ssi; S.R. → nisr; asp / asc / anaw / nia /
    mwa. The first citation is the amending instrument; a later S.I. is
    usually its commencement order.
  - `change_id/2`: the note's stable id.
  - `same_law?/2`: one instrument under its Welsh / UK SI names.

  Pure.
  """

  # {regex, kind}; the earliest match after "by" wins (to_law/2).
  @citations [
    # Church Measure "Measure 2018 (No. 3)"; an SI cited by title
    # "… Order 2013 (No. 755)" (LH-06)
    {~r/Measure (\d{4}) \(No\. ?(\d+)\)/, :ukcm},
    {~r/(?:Order|Regulations|Rules|Scheme|Byelaws|Directions?)(?: \([^)]*\))? (\d{4}) \(No\. ?(\d+)\)/,
     :si_title},
    {~r/W\.S\.I\. (\d{4})\/(\d+)/, :wsi},
    {~r/S\.S\.I\. (\d{4})\/(\d+)/, :ssi},
    {~r/S\.R\. (\d{4})\/(\d+)/, :nisr},
    {~r/S\.I\. (\d{4})\/(\d+)(?: \((W|N\.I)\.)?/, :si},
    {~r/(\d{4}) \((c|asp|asc|anaw|nia|mwa)\.? ?(\d+)/, :act},
    {~r/\b(\d{4}) c\. ?(\d+)\b/, :ukpga}
  ]

  @doc "The law a note points to, or nil. `code_type` is the annotation's."
  @spec law(String.t() | nil, String.t() | nil) :: String.t() | nil
  def law(text, code_type) do
    text = normalise(text || "")
    {_before, after_by} = split_at_by(text)
    note_changed_by(after_by, text, code_type)
  end

  defp to_law(:si_title, [year, number]), do: law(:uksi, year, number)

  defp to_law(kind, [year, number]) when kind in [:wsi, :ssi, :nisr, :ukpga, :ukcm],
    do: law(kind, year, number)

  defp to_law(:si, [year, number, "W"]), do: law(:wsi, year, number)
  defp to_law(:si, [year, number, "N.I"]), do: law(:nisi, year, number)
  defp to_law(:si, [year, number | _]), do: law(:uksi, year, number)
  defp to_law(:act, [year, "c", number]), do: law(:ukpga, year, number)
  defp to_law(:act, [year, type, number]), do: law(type, year, number)

  defp law(type, year, number), do: "UK_#{type}_#{year}_#{number}"

  @doc """
  The same instrument: equal names, or a Welsh SI and its `UK_uksi_…` name
  (one number series; a Welsh SI cited as plain "S.I." reads as uksi).
  """
  @spec same_law?(String.t(), String.t()) :: boolean()
  def same_law?(a, b), do: twin(a) == twin(b)

  defp twin("UK_wsi_" <> rest), do: "UK_uksi_" <> rest
  defp twin(name), do: name

  defp normalise(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  # Text before the first " by " (or ", see" in commencement notes) and after it.
  defp split_at_by(text) do
    case String.split(text, " by ", parts: 2) do
      [before, rest] -> {before, rest}
      [_] -> {text |> String.split(", see", parts: 2) |> hd(), nil}
    end
  end

  # Citation-only amendment notes ("F7 F7 S.I. 1965/1536") have no "by":
  # scan it all. An editorial note without "by" (a marginal citation,
  # "1906 c. 14.") only refers to a law; it names no changing instrument.
  defp note_changed_by(nil, _text, "extent_editorial"), do: nil
  defp note_changed_by(nil, text, _code_type), do: changed_by(text)
  defp note_changed_by(after_by, _text, _code_type), do: changed_by(after_by)

  defp changed_by(after_by) do
    @citations
    |> Enum.flat_map(fn {re, kind} ->
      case Regex.run(re, after_by, return: :index) do
        [{pos, _} | _] ->
          [{pos, kind, to_law(kind, Regex.run(re, after_by, capture: :all_but_first))}]

        nil ->
          []
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
    |> case do
      nil -> nil
      {pos, kind, law} -> welsh_title(law, kind, after_by, pos)
    end
  end

  # A UK-numbered SI whose title (in the same citation) says "(Wales)" is a
  # Welsh SI: "The Water Supply (Wales) Regulations 2017 (S.I. 2017/544)".
  # "(England and Wales)" is not.
  defp welsh_title("UK_uksi_" <> rest = law, kind, text, pos) when kind in [:si, :si_title] do
    title = text |> binary_part(0, pos) |> String.split(~r/[;,]/) |> List.last()
    if String.contains?(title, "(Wales)"), do: "UK_wsi_" <> rest, else: law
  end

  defp welsh_title(law, _kind, _text, _pos), do: law

  @doc """
  The note's change id: first 32 hex of SHA-256(law_name LF normalised
  text), stable across re-parses, unlike the F-number, which renumbers when
  notes are added. An id, not a fact.
  """
  @spec change_id(String.t(), String.t() | nil) :: String.t()
  def change_id(law_name, text) do
    text = normalise(text || "")

    :crypto.hash(:sha256, [law_name, ?\n, text])
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end
end

defmodule SertantaiLegal.Scraper.AmendmentNote do
  @moduledoc """
  Structured reading of a legislation.gov.uk commentary note (sertantai-legal
  #167, L8.2): what the change did, when it took effect, which instrument made
  it, and a stable id for the change.

  Pure: `parse/3` takes the note text, its `code_type` and the law it belongs
  to. Notes read like

      S. 52(6) substituted (1.4.2006) by , ; Water Act 2003 (c. 37) ss. 22(5) S.I. 2006/984 art. 2(l)
      S. 6 in force at 20.1.2009 for specified purposes by , S.I. 2009/39 art. 2(1)(e)

  - `effect`: the first verb before "by" — substituted | inserted | repealed
    (repealed/revoked/omitted) | renumbered | amended | commenced (in force /
    in operation) | modified (modified/applied/excluded/extended) | other
  - `effective_dates`: every valid d.m.yyyy date **before** "by" (or ", see"),
    so dates in instrument titles don't count; `effective_from` is the latest
    (a compound "31.1.2017 for specified purposes, 2.5.2017 …" note took full
    effect on the later date)
  - `changed_by`: the first instrument cited after "by", as a law name
    ("Water Act 2003 (c. 37)" → UK_ukpga_2003_37; "S.I. 2002/324 (W. 37)" →
    UK_wsi_2002_324; "(N.I. 7)" → nisi; S.S.I. → ssi; S.R. → nisr; asp / asc /
    anaw / nia / mwa). The first citation is the amending instrument; a later
    S.I. is usually its commencement order.
  - `change_id`: first 32 hex of SHA-256(law_name LF normalised text) — stable
    across re-parses, unlike the F-number, which renumbers when notes are added
  """

  @enforce_keys [:effect, :effective_dates, :effective_from, :changed_by, :change_id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          effect: String.t(),
          effective_dates: [Date.t()],
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          change_id: String.t()
        }

  @effects [
    {~r/\bsubstituted\b/i, "substituted"},
    {~r/\b(inserted|added)\b/i, "inserted"},
    {~r/\b(repealed|revoked|omitted|ceased to have effect)\b/i, "repealed"},
    {~r/\brenumbered\b/i, "renumbered"},
    {~r/\b(in force|in operation)\b/i, "commenced"},
    {~r/\b(modified|applied|excluded|extended|continued)\b/i, "modified"},
    {~r/\bamended\b/i, "amended"}
  ]

  @date ~r/\b(\d{1,2})\.(\d{1,2})\.(\d{4})\b/

  # {regex, kind}; the earliest match after "by" wins (to_law/2).
  @citations [
    {~r/S\.S\.I\. (\d{4})\/(\d+)/, :ssi},
    {~r/S\.R\. (\d{4})\/(\d+)/, :nisr},
    {~r/S\.I\. (\d{4})\/(\d+)(?: \((W|N\.I)\.)?/, :si},
    {~r/(\d{4}) \((c|asp|asc|anaw|nia|mwa)\.? ?(\d+)/, :act},
    {~r/\b(\d{4}) c\. ?(\d+)\b/, :ukpga}
  ]

  @doc "Parse one note. `code_type` is the annotation's (amendment | commencement | modification | …)."
  @spec parse(String.t() | nil, String.t() | nil, String.t()) :: t()
  def parse(text, code_type, law_name) do
    text = normalise(text || "")
    {before, after_by} = split_at_by(text)

    dates =
      @date
      |> Regex.scan(before, capture: :all_but_first)
      |> Enum.flat_map(fn [d, m, y] ->
        case Date.new(String.to_integer(y), String.to_integer(m), String.to_integer(d)) do
          {:ok, date} -> [date]
          _ -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.sort(Date)

    %__MODULE__{
      effect: effect(before, code_type),
      effective_dates: dates,
      effective_from: List.last(dates),
      # citation-only notes ("F7 F7 S.I. 1965/1536") have no "by": scan it all
      changed_by: changed_by(after_by || text),
      change_id: change_id(law_name, text)
    }
  end

  @doc """
  A provision's `{effective_from, changed_by}` from the notes that apply to it:
  the latest dated amendment/commencement note; else the first undated one's
  instrument. Modification notes are about application, not the text.
  """
  @spec row_effective([t()]) :: {Date.t() | nil, String.t() | nil}
  def row_effective(notes) do
    # Sorted into a total order first: notes come from the DB in no fixed
    # order, and same-date notes must give the same answer every time.
    relevant =
      notes
      |> Enum.reject(&(&1.effect == "modified"))
      |> Enum.sort_by(&{&1.changed_by || "", &1.change_id})

    case Enum.filter(relevant, & &1.effective_from) do
      [] ->
        {nil, Enum.find_value(relevant, & &1.changed_by)}

      dated ->
        latest = dated |> Enum.sort_by(& &1.effective_from, Date) |> List.last()
        {latest.effective_from, latest.changed_by}
    end
  end

  defp to_law(kind, [year, number]) when kind in [:ssi, :nisr, :ukpga],
    do: law(kind, year, number)

  defp to_law(:si, [year, number, "W"]), do: law(:wsi, year, number)
  defp to_law(:si, [year, number, "N.I"]), do: law(:nisi, year, number)
  defp to_law(:si, [year, number | _]), do: law(:uksi, year, number)
  defp to_law(:act, [year, "c", number]), do: law(:ukpga, year, number)
  defp to_law(:act, [year, type, number]), do: law(type, year, number)

  defp law(type, year, number), do: "UK_#{type}_#{year}_#{number}"

  defp normalise(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  # Text before the first " by " (or ", see" in commencement notes) and after it.
  defp split_at_by(text) do
    case String.split(text, " by ", parts: 2) do
      [before, rest] -> {before, rest}
      [_] -> {text |> String.split(", see", parts: 2) |> hd(), nil}
    end
  end

  defp effect(before, code_type) do
    found =
      @effects
      |> Enum.flat_map(fn {re, name} ->
        case Regex.run(re, before, return: :index) do
          [{pos, _} | _] -> [{pos, name}]
          nil -> []
        end
      end)
      |> Enum.min_by(&elem(&1, 0), fn -> nil end)

    case {found, code_type} do
      {{_, name}, _} -> name
      {nil, "commencement"} -> "commenced"
      {nil, "modification"} -> "modified"
      _ -> "other"
    end
  end

  defp changed_by(after_by) do
    @citations
    |> Enum.flat_map(fn {re, kind} ->
      case Regex.run(re, after_by, return: :index) do
        [{pos, _} | _] ->
          [{pos, to_law(kind, Regex.run(re, after_by, capture: :all_but_first))}]

        nil ->
          []
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> {nil, nil} end)
    |> elem(1)
  end

  defp change_id(law_name, text) do
    :crypto.hash(:sha256, [law_name, ?\n, text])
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end
end

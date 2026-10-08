defmodule SertantaiLegal.Scraper.Territory do
  @moduledoc """
  UK territories in LAT extent codes ("E+W+S+NI", as `extent_code`) — for
  retained repeals (LAT parser coverage II): text repealed in some
  territories but kept for the others.

  Pure: `from_note/1` reads the territory a commentary note's change applies
  to ("Regulations revoked (S.) (1.11.2025) by …" → "S"); `covers?/2`,
  `subtract/2` and `union/1` work on codes. A nil row extent is the UK.
  """

  @order ~w(E W S NI)

  # "(S.)", "(E.W.)", "(E. and W.)", "(N.I.)", "(in relation to W.)"
  @note_territory ~r/\((?:in relation to )?((?:(?:E|W|S|N\.I)\.(?:,?\s*(?:and\s+)?)?)+)\)/

  @doc "The territory of a note's change, from the first territory parenthesis before \" by \"."
  @spec from_note(String.t() | nil) :: String.t() | nil
  def from_note(nil), do: nil

  def from_note(text) do
    head = text |> String.split(" by ", parts: 2) |> hd()

    case Regex.run(@note_territory, head) do
      [_, letters] ->
        ~r/N\.I|[EWS]/
        |> Regex.scan(letters)
        |> List.flatten()
        |> Enum.map(&String.replace(&1, "N.I", "NI"))
        |> union()

      nil ->
        nil
    end
  end

  @doc "True when `repealed` includes every territory of `row_extent` (nil = UK)."
  @spec covers?(String.t(), String.t() | nil) :: boolean()
  def covers?(repealed, row_extent),
    do: MapSet.subset?(set(row_extent), set(repealed))

  @doc "The territories of `row_extent` (nil = UK) outside `repealed`; nil when none."
  @spec subtract(String.t() | nil, String.t()) :: String.t() | nil
  def subtract(row_extent, repealed),
    do: row_extent |> set() |> MapSet.difference(set(repealed)) |> format()

  @doc "Union of extent codes in canonical order; nil for none."
  @spec union([String.t()]) :: String.t() | nil
  def union(codes),
    do: codes |> Enum.flat_map(&MapSet.to_list(set(&1))) |> MapSet.new() |> format()

  defp set(nil), do: MapSet.new(@order)

  defp set(code) do
    code |> String.replace("N.I.", "NI") |> String.split("+", trim: true) |> MapSet.new()
  end

  defp format(set) do
    case Enum.filter(@order, &MapSet.member?(set, &1)) do
      [] -> nil
      parts -> Enum.join(parts, "+")
    end
  end
end

defmodule SertantaiLegal.Scraper.Territory do
  @moduledoc """
  UK territories as LAT extent codes ("E+W+S+NI", as `extent_code`).

  Pure set operations on codes: `normalize/1` (attribute notations),
  `covers?/2`, `subtract/2`, `disjoint?/2`, `union/1`. A nil extent is the
  UK.
  """

  @order ~w(E W S NI)

  @doc """
  An extent attribute as a code: "E+W", "E.W.", "E.W.S.", "N.I." → "E+W",
  "E+W", "E+W+S", "NI"; nil for blank.
  """
  @spec normalize(String.t() | nil) :: String.t() | nil
  def normalize(nil), do: nil

  def normalize(code),
    do:
      code
      |> String.replace("N.I", "NI")
      |> then(&Regex.scan(~r/NI|[EWS]/, &1))
      |> List.flatten()
      |> union()

  @doc "True when `repealed` includes every territory of `row_extent` (nil = UK)."
  @spec covers?(String.t(), String.t() | nil) :: boolean()
  def covers?(repealed, row_extent),
    do: MapSet.subset?(set(row_extent), set(repealed))

  @doc "The territories of `row_extent` (nil = UK) outside `repealed`; nil when none."
  @spec subtract(String.t() | nil, String.t()) :: String.t() | nil
  def subtract(row_extent, repealed),
    do: row_extent |> set() |> MapSet.difference(set(repealed)) |> format()

  @doc "True when the two codes share no territory."
  @spec disjoint?(String.t(), String.t()) :: boolean()
  def disjoint?(a, b), do: MapSet.disjoint?(set(a), set(b))

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

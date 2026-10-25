defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Places do
  @moduledoc """
  The places an extent clause names, and their territory codes (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): "England and
  Wales and Scotland" → "E+W+S". `place_list/0` is the pattern of a list of
  places the extent forms interpolate (`Extent.Forms`). Pure.
  """

  alias SertantaiLegal.Scraper.Territory

  @places "England and Wales|Great Britain|the United Kingdom|United Kingdom|England|Wales|Scotland|Northern Ireland"
  @codes %{
    "england and wales" => "E+W",
    "great britain" => "E+W+S",
    "the united kingdom" => "E+W+S+NI",
    "united kingdom" => "E+W+S+NI",
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI"
  }

  # "England and Wales and Scotland", "England and Wales, Scotland and
  # Northern Ireland"
  # ("… to England and Wales, and Scotland": a comma before the "and", CV-S05)
  # ("… to Scotland or Northern Ireland": CV-S05 B)
  @place_list "(?:#{@places})(?:\\s*,\\s*(?:#{@places}))*(?:\\s*,?\\s+(?:and|or|as\\s+well\\s+as)\\s+(?:to\\s+)?(?:#{@places}))*"

  @doc "The alternation of single places (a regex source string)."
  @spec place_names() :: String.t()
  def place_names, do: @places

  @doc "A list of places, as a regex source string to interpolate."
  @spec place_list() :: String.t()
  def place_list, do: @place_list

  @doc "The places named in `list`, as one territory code (\"E+W+S\")."
  @spec places(String.t()) :: String.t() | nil
  def places(list) do
    Regex.scan(~r/#{@places}/iu, list)
    |> List.flatten()
    |> Enum.map(&@codes[String.downcase(&1)])
    |> Territory.union()
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.Versions do
  @moduledoc """
  A provision's territorial versions from the CLML (C3): each element
  whose `DocumentURI` ends in its territory (".../regulation/14/1/
  england+wales+scotland"), grouped under its base provision, with the day
  each version starts — the `RestrictStartDate` of the concurrent group
  holding it (`<P1group Concurrent="true" RestrictStartDate="2020-12-31">`:
  SI 2008/1597's [NI] versions).

  A later version's ids carry a number after the provision's
  (`section-28n2-7-a`, HSWA s.28(7)(a)'s NI version): it is the same base
  provision, s.28(7)(a) (CV-S09 round 1: the base took only the first
  version's territory, so its history lost S and NI). Pure.
  """

  import SweetXml, only: [sigil_x: 2, xpath: 2]

  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
  alias SertantaiLegal.Scraper.Territory

  @places %{
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "ni" => "NI",
    "northern-ireland" => "NI"
  }

  @doc """
  `%{ref => %{versions: [territory], version_starts: %{territory => date}}}`
  for the parsed document.
  """
  @spec facts(tuple(), String.t() | nil) :: %{String.t() => map()}
  def facts(doc, law_name) do
    starts = starts(doc)

    for el <- xpath(doc, ~x"//*[@id][@DocumentURI]"l),
        territory = el |> xpath(~x"./@DocumentURI"s) |> territory(),
        territory != nil,
        id = xpath(el, ~x"./@id"s),
        ref = id |> base_id() |> Ref.from_clml(law_name),
        ref != nil do
      {ref, territory, Map.get(starts, id)}
    end
    |> Enum.group_by(&elem(&1, 0))
    |> Map.new(fn {ref, vs} ->
      {ref,
       %{
         versions: vs |> Enum.map(&elem(&1, 1)) |> Enum.uniq(),
         version_starts: for({_, t, %Date{} = d} <- vs, into: %{}, do: {t, d})
       }}
    end)
  end

  # each versioned element's start: the concurrent group holding it (a
  # nested group, later in document order, overrides its parent's). xmerl
  # elements keep no ancestors, so the groups are walked downwards
  defp starts(doc) do
    for group <- xpath(doc, ~x"//*[@Concurrent='true'][@RestrictStartDate]"l),
        date = group |> xpath(~x"./@RestrictStartDate"s) |> date(),
        date != nil,
        id <- xpath(group, ~x"./descendant-or-self::*[@DocumentURI]/@id"ls),
        reduce: %{} do
      acc -> Map.put(acc, id, date)
    end
  end

  defp date(d) do
    case Date.from_iso8601(d) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  @doc "A version's CLML id as its base provision's: `section-28n2-7-a` → `section-28-7-a`."
  @spec base_id(String.t()) :: String.t()
  def base_id(id), do: String.replace(id, ~r/^([a-z]+-\d+[A-Z]*)n\d+(?=-|$)/, "\\1")

  # ".../regulation/14/1/england+wales+scotland" → "E+W+S"; nil for an
  # unversioned URI
  defp territory(uri) do
    parts = uri |> String.split("/") |> List.last() |> to_string() |> String.split("+")

    if parts != [] and Enum.all?(parts, &Map.has_key?(@places, &1)),
      do: parts |> Enum.map(&@places[&1]) |> Territory.union()
  end
end

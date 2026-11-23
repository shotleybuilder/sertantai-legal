defmodule SertantaiLegal.Scraper.Commencement.Order.Territory do
  @moduledoc """
  Where a commencement order brings provisions into force, as a territory
  code ("E", "E+W", "NI"): from a line's words, the order's title, or the
  instrument's type. Pure text.
  """

  alias SertantaiLegal.Scraper.Commencement.Text.Asides

  @places %{
    "england and wales" => "E+W",
    "great britain" => "E+W+S",
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI"
  }

  @territory ~r/\b(?:in relation to|in|as respects|extends? to)\s+(England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\b(?!\s+(?:Act|Order|Regulations))/i

  # "Except to the extent that they extend to Scotland" names the place
  # left out, never the place (SI 2005/1521 art.3(3))
  @extent_excepted ~r/\bexcept\s+(?:to\s+the\s+extent\s+that|(?:in\s*)?so\s*far\s+as|insofar\s+as)\s+(?:it|they)\s+extends?\s+to\s+(?:England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\b/i

  @own_acts %{"wsi" => ~w(anaw asc mwa), "ssi" => ~w(asp), "nisr" => ~w(nia)}
  @type_territories %{"wsi" => "W", "ssi" => "S", "nisr" => "NI"}

  @title_place ~S"(?:England|Wales|Scotland|Northern Ireland)"
  @title_places ~r/\((#{@title_place}(?:(?:,\s+|\s+and\s+)#{@title_place})*)\)\s+(?:Order|Regulations)\b/

  @doc """
  The first place `line` names ("in relation to Wales" → "W"); nil when it
  names none.
  """
  @spec of(String.t()) :: String.t() | nil
  def of(line) do
    # (never a bracketed heading's place: "section 41 (disputes about …:
    # premises in Wales)": WSI 2015/1786)
    words = line |> Asides.drop_headings() |> String.replace(@extent_excepted, "")

    case Regex.run(@territory, words) do
      [_, place] -> Map.get(@places, String.downcase(place))
      nil -> nil
    end
  end

  @completing ~r/\s*,?\s*\(?\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+relates?\s+to\s+(England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\s+and\s+(?:has|have|is|are)\s+not\s+(?:already|previously|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+(?:force|operation)|in\s+(?:force|operation)|come\s+into\s+(?:force|operation))\)?/i

  @doc """
  A line's completing start for one place: "Schedule 8 in so far as it
  relates to England and Wales and has not already been commenced" (SI
  1992/2984 Sch.2) is the rest of Schedule 8, there — `{"Schedule 8",
  "E+W"}`. `{line, nil}` for any other line: relating to a place alone is a
  purpose, never the whole.
  """
  @spec completing(String.t()) :: {String.t(), String.t() | nil}
  def completing(line) do
    case Regex.run(@completing, line) do
      [words, place] ->
        {String.replace(line, words, ""), Map.get(@places, String.downcase(place))}

      nil ->
        {line, nil}
    end
  end

  @doc "Every place `text` names outside its provisions' bracketed headings, each once."
  @spec all(String.t()) :: [String.t()]
  def all(text) do
    for [_, place] <- Regex.scan(@territory, Asides.drop_headings(text)),
        uniq: true,
        do: Map.get(@places, String.downcase(place))
  end

  @doc """
  The one place `texts` name between them: "The provisions … specified in
  the Schedule to this Order … shall come into force in England and Wales …
  on 6th June 1988" (SI 1988/818 art.2); a place two of them name is one
  place. Nil where they name none, or more than one.
  """
  @spec only([String.t()]) :: String.t() | nil
  def only(texts) do
    case texts |> Enum.flat_map(&all/1) |> Enum.uniq() do
      [place] -> place
      _ -> nil
    end
  end

  @doc """
  The territory an order's title names: "… (Commencement No. 16 …) (England)
  Order 2000" (SI 2000/340) → "E"; "(England and Scotland) Order" (SI
  2004/2304) → "E+S". Nil for a title naming none, or no title.
  """
  @spec of_title(String.t() | nil) :: String.t() | nil
  def of_title(title) do
    case Regex.run(@title_places, title || "") do
      [_, places] -> codes(places)
      nil -> nil
    end
  end

  @application Regex.compile!(
                 "^\\W*(?:\\d+\\s+)*This\\s+(?:Order|Regulations)\\s+(?:applies|apply)\\s+(?:only\\s+)?(?:in\\s+relation\\s+)?to\\s+(#{@title_place}(?:(?:,\\s+|\\s+and\\s+)#{@title_place})*)(?:\\s+only)?\\s*\\.?\\s*$",
                 "u"
               )

  @doc """
  The territory an order's application clause names: "This Order applies
  in relation to England only." (SI 2010/975 art.1(2)) → "E". Nil for any
  other sentence — one with an exception names no one place ("… England
  only except article 2(d) which extends to Scotland only": SI 2009/359);
  the order's extent is never where it applies ("This Order extends to
  England and Wales": SI 2024/35).
  """
  @spec of_application(String.t()) :: String.t() | nil
  def of_application(text) do
    case Regex.run(@application, text) do
      [_, places] -> codes(places)
      nil -> nil
    end
  end

  @doc """
  The territory of a devolved instrument's type (a Welsh order: "W") — nil
  for its own legislature's Act, which it commences wherever that extends
  (WSI 2023/1149 on a Senedd Act extending to England and Wales), and for
  any other instrument.
  """
  @spec of_type(String.t(), String.t()) :: String.t() | nil
  def of_type(order, act) do
    if own_legislature?(order, act), do: nil, else: @type_territories[law_type(order)]
  end

  @doc "Whether `order` is a devolved instrument on its own legislature's Act (a Welsh order on a Measure or Senedd Act)."
  @spec own_legislature?(String.t(), String.t()) :: boolean()
  def own_legislature?(order, act), do: law_type(act) in Map.get(@own_acts, law_type(order), [])

  defp law_type(law_name), do: law_name |> String.split("_") |> Enum.at(1)

  # "England and Scotland" → "E+S", in the codes' own order
  defp codes(places) do
    named = places |> String.split(~r/,\s+|\s+and\s+/) |> Enum.map(&@places[String.downcase(&1)])
    ~w(E W S NI) |> Enum.filter(&(&1 in named)) |> Enum.join("+")
  end
end

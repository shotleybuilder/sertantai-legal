defmodule SertantaiLegal.Scraper.LawStart.Territorial do
  @moduledoc """
  The country a commencement statement is for, where a country is all that
  qualifies it:

  - `only/1`: "in relation to England, in accordance with provision made by
    order" (CNEA 2005 s.108(1)(a)), "in relation to premises in Wales, on
    such day as …" (2021 c.24 s.4(2)(b)), "The following provisions, as
    they apply in Wales, come into force on whatever day … the Welsh
    Ministers appoint by order" (2014 c.12 s.185(3)) → the country; nil where the
    statement has another qualifier ("for the purpose of making
    regulations"), names two countries, or none;
  - `by_application/1`: "Part II of this Act, in its application to England
    and Wales, shall come into operation on such day as … jointly appoint,
    and in its application to Scotland on such day as …" (1969 c.10
    s.38(3)) → the subject and each country with its tail.

  Pure: the words only; what a country's commencement means is the
  evaluator's.
  """

  @place ~S"(England\s+and\s+Wales|Great\s+Britain|England|Wales|Scotland|Northern\s+Ireland)"
  @for_place Regex.compile!(
               "\\b(?:in\\s+relation\\s+to|as\\s+respects|in\\s+its\\s+application\\s+to|as\\s+(?:it|they)\\s+appl(?:y|ies)\\s+(?:in|to))\\s+(?:premises\\s+in\\s+)?#{@place}\\b",
               "i"
             )
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes)\b/i

  @by_application Regex.compile!(
                    "^(.+?),\\s*in\\s+its\\s+application\\s+to\\s+#{@place},\\s*(?:shall\\s+)?comes?\\s+into\\s+(?:force|operation)\\s+(.+?),?\\s+and\\s+in\\s+its\\s+application\\s+to\\s+#{@place}\\s+(.+?)\\.?\\s*$",
                    "is"
                  )

  @doc "The one country that alone qualifies `statement`, as written; else nil."
  @spec only(String.t()) :: String.t() | nil
  def only(statement) do
    places =
      @for_place
      |> Regex.scan(statement)
      |> Enum.map(&(&1 |> List.last() |> squash()))
      |> Enum.uniq()

    case places do
      [place] -> if Regex.replace(@for_place, statement, "") =~ @qualified, do: nil, else: place
      _ -> nil
    end
  end

  @doc """
  A statement commencing its subject country by country: `{subject,
  [{country, tail}]}`, the tails as they follow "into force"; else nil.
  """
  @spec by_application(String.t()) :: {String.t(), [{String.t(), String.t()}]} | nil
  def by_application(statement) do
    case Regex.run(@by_application, statement) do
      [_, subject, first, tail, second, later] ->
        {subject, [{squash(first), tail}, {squash(second), later}]}

      nil ->
        nil
    end
  end

  defp squash(s), do: String.replace(s, ~r/\s+/, " ")
end

defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Places do
  @moduledoc """
  The places a text names, as a code ("E+W+S"), with law titles masked
  so "the Water (Scotland) Act 1980" names no place (`finder.py`'s
  `PLACES`, `TITLE`, `place_code`; #192). Shares no code with the extent
  reader.
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.Re

  @places [
    {~r/\A(?:(?:the\s+)?United\s+Kingdom)\z/u, ~w(E W S NI)},
    {~r/\A(?:Great\s+Britain)\z/u, ~w(E W S)},
    {~r/\A(?:Northern\s+Ireland)\z/u, ~w(NI)},
    {~r/\A(?:England)\z/u, ~w(E)},
    {~r/\A(?:Wales)\z/u, ~w(W)},
    {~r/\A(?:Scotland)\z/u, ~w(S)}
  ]

  @place_re ~r/(?:(?:the\s+)?United\s+Kingdom)|(?:Great\s+Britain)|(?:Northern\s+Ireland)|(?:England)|(?:Wales)|(?:Scotland)/u

  @title ~r/(?<=\bthe\s)(?!(?:Parts?|Chapters?|Schedules?|Sections?|Regulations?|Articles?|Paragraphs?)\b)[A-Z](?:(?!\bof\s+the\b)[A-Za-z(),'’ .&-])*?\b(?:Act|Regulations|Order|Rules|Measure)(?:\s+\(Northern\s+Ireland\))?(?:\s+\d{4})?\b(?!\s+(?:extends?|appl|shall|does|do\b))/u

  @doc "`PLACE_RE`: any place word."
  @spec place_re() :: Regex.t()
  def place_re, do: @place_re

  @doc "`TITLE.sub(repl, text)`: each law title replaced."
  @spec mask_titles(String.t(), String.t()) :: String.t()
  def mask_titles(text, repl), do: Regex.replace(@title, text, fn _ -> repl end)

  @doc "The places `text` names, as a code (\"E+W+S\"), or nil."
  @spec code(String.t()) :: String.t() | nil
  def code(text) do
    t = mask_titles(text, "TITLE")

    found =
      for [cap] <- Re.all(@place_re, t), reduce: MapSet.new() do
        acc -> MapSet.union(acc, MapSet.new(codes(Re.group([cap], t, 0))))
      end

    case Enum.filter(~w(E W S NI), &MapSet.member?(found, &1)) do
      [] -> nil
      cs -> Enum.join(cs, "+")
    end
  end

  defp codes(word) do
    Enum.find_value(@places, [], fn {re, cs} -> if Regex.match?(re, word), do: cs end)
  end
end

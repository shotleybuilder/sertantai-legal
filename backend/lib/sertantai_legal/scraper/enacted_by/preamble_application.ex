defmodule SertantaiLegal.Scraper.EnactedBy.PreambleApplication do
  @moduledoc """
  An SI's application from its preamble's maker clause: "The Secretary of
  State …, as respects England, and the Secretary of State for Wales, as
  respects Wales, in exercise of the powers conferred by …" → E+W. Positive
  evidence of where the law itself applies (unlike extent ceilings), read
  from the enacting text the LRT enacted_by stage already fetches.

  Pure. Only the maker clause counts (before "in exercise of" / "powers
  conferred"). A nation must follow "as respects" or "in relation to"
  directly — "in relation to the regulation and control of …" (an ECA
  designation) is not territorial. Makers acting jointly are not read as
  application.
  """

  @nation "(England and Wales|Great Britain|Northern Ireland|England|Wales|Scotland)"
  @phrase Regex.compile!("\\b(?:as\\s+respects|in\\s+relation\\s+to)\\s+#{@nation}\\b", "iu")
  @codes %{
    "england and wales" => ~w(E W),
    "great britain" => ~w(E W S),
    "northern ireland" => ~w(NI),
    "england" => ~w(E),
    "wales" => ~w(W),
    "scotland" => ~w(S)
  }
  @order ~w(E W S NI)

  @doc "Regions (E/W/S/NI) the makers act as respects, or nil."
  @spec parse(String.t() | nil) :: [String.t()] | nil
  def parse(nil), do: nil

  def parse(text) do
    maker =
      text
      |> String.split(~r/in\s+(?:the\s+)?exercise\s+of|powers\s+conferred/iu, parts: 2)
      |> hd()

    @phrase
    |> Regex.scan(maker)
    |> Enum.flat_map(fn [_, n] -> Map.fetch!(@codes, String.downcase(n)) end)
    |> then(fn regions -> Enum.filter(@order, &(&1 in regions)) end)
    |> case do
      [] -> nil
      regions -> regions
    end
  end
end

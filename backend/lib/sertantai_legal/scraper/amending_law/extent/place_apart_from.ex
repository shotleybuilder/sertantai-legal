defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PlaceApartFrom do
  @moduledoc """
  A place stated with a provision carved out of it, made plain: "This Act
  extends to England and Wales and (apart from section 212A(6)) to
  Scotland." (Trade Union and Labour Relations (Consolidation) Act 1992
  s.301(1)) → "This Act extends to England and Wales and Scotland. Section
  212A(6) does not extend to Scotland." The default is every place named,
  the provision taken out of the one it is carved from (Waste, Water and
  Climate: Extent reader, Decision 3, 2026-11-26). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Places

  @places Places.place_names()

  @form Regex.compile!(
          "\\b(extends?\\s+to\\s+(?:#{@places}))\\s+and\\s+\\(\\s*(?:apart\\s+from|except(?:\\s+for)?)\\s+((?:sections?|regulations?|articles?|Schedules?|Parts?)\\s+[^()]*?(?:\\([^()]*\\)[^()]*?)*)\\s*\\)\\s+to\\s+(#{@places})\\s*\\.",
          "u"
        )

  @doc "The text with each carved-out place made two plain statements."
  @spec resolve(String.t()) :: String.t()
  def resolve(text) do
    Regex.replace(@form, text, fn _, verb, provisions, place ->
      "#{verb} and #{place}. #{capitalise(provisions)} does not extend to #{place}."
    end)
  end

  defp capitalise(<<c::utf8, rest::binary>>), do: String.upcase(<<c::utf8>>) <> rest
end

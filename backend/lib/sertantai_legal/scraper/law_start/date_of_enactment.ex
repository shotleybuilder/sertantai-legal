defmodule SertantaiLegal.Scraper.LawStart.DateOfEnactment do
  @moduledoc """
  An Act's Royal Assent date (a Welsh Measure's approval by Her Majesty in
  Council) as its own introduction states it
  (`<DateOfEnactment><DateText>{6 July 2015}</DateText>`): what a clause
  counting from Royal Assent counts from where neither the register nor
  the CLML's metadata gives the date (Planning (Wales) Act 2015). Where the
  text is empty, the introduction's own metadata (`ukm:EnactmentDate`: 2019
  c.16, c.26). Pure.
  """

  @months ~w(january february march april may june july august september october november december)

  @element ~r/<DateOfEnactment>\s*<DateText>([^<]*)<\/DateText>/
  @date ~r/(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})/

  @meta ~r/<ukm:EnactmentDate Date="(\d{4}-\d{2}-\d{2})"/

  @doc "The enactment date in an introduction's CLML; nil when it states none."
  @spec parse(String.t() | nil) :: Date.t() | nil
  def parse(nil), do: nil
  def parse(xml), do: stated(xml) || metadata(xml) || approved(xml)

  # a Welsh Measure's enacting words: "This Measure, passed by the National
  # Assembly for Wales on 2 November 2010 and approved by Her Majesty in
  # Council on 15 December 2010, enacts …" (MWA 2010/8) — its approval is
  # its making
  @approved ~r/\bapproved\s+by\s+Her\s+Majesty\s+in\s+Council\s+on\s+(\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]+\s+\d{4})/

  defp approved(xml) do
    with [_, text] <- Regex.run(@approved, xml), do: date_of(text), else: (_ -> nil)
  end

  defp date_of(text) do
    with [_, day, month, year] <- Regex.run(@date, text),
         index when is_integer(index) <-
           Enum.find_index(@months, &(&1 == String.downcase(month))),
         {:ok, date} <-
           Date.new(String.to_integer(year), index + 1, String.to_integer(day)) do
      date
    else
      _ -> nil
    end
  end

  defp metadata(xml) do
    with [_, d] <- Regex.run(@meta, xml), {:ok, date} <- Date.from_iso8601(d) do
      date
    else
      _ -> nil
    end
  end

  defp stated(xml) do
    with [_, text] <- Regex.run(@element, xml), do: date_of(text), else: (_ -> nil)
  end
end

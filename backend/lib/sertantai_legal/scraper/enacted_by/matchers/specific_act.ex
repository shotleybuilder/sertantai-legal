defmodule SertantaiLegal.Scraper.EnactedBy.Matchers.SpecificAct do
  @moduledoc """
  Matcher for specific Act patterns.

  These patterns match exact Act names in the text and return a fixed law ID.
  For example, "Health and Safety at Work etc. Act 1974" → "ukpga/1974/37"

  This is the highest priority matcher (priority 100) because specific Act
  references are unambiguous and should take precedence over generic patterns.
  """

  @behaviour SertantaiLegal.Scraper.EnactedBy.Matcher

  @impl true
  def pattern_type, do: :specific_act

  @impl true
  def match(pattern, text, _context) do
    if Regex.match?(pattern.pattern, text) do
      {:match, [pattern.output], %{matched_text: extract_match(pattern.pattern, text)}}
    else
      :no_match
    end
  end

  # Extract the actual matched text for metadata/debugging
  defp extract_match(regex, text) do
    case Regex.run(regex, text) do
      [match | _] -> match
      nil -> nil
    end
  end
end

defmodule SertantaiLegal.Scraper.EnactedBy.Matchers.FootnoteFallback do
  @moduledoc """
  Fallback matcher that extracts all footnotes and filters by year mentions.

  This is the last resort matcher (priority 10) used when no specific Act
  or powers clause patterns matched. It:

  1. Extracts all footnote references from the text (e.g., "f00001")
  2. Looks up URLs for each footnote
  3. Filters URLs to those containing years mentioned in the text
  4. Extracts law IDs from the filtered URLs

  The year filtering helps reduce false positives by only including
  references that correspond to years actually mentioned in the enacting text.
  """

  @behaviour SertantaiLegal.Scraper.EnactedBy.Matcher

  alias SertantaiLegal.Scraper.IdField

  @impl true
  def pattern_type, do: :footnote_fallback

  @impl true
  def match(pattern, text, context) do
    urls = Map.get(context, :urls, %{})

    # Find all footnote refs in text
    footnote_refs =
      Regex.scan(pattern.pattern, text)
      |> Enum.map(fn [ref] -> ref end)
      |> Enum.uniq()

    if footnote_refs == [] do
      :no_match
    else
      # Extract years mentioned in text for filtering
      years =
        Regex.scan(~r/\b(\d{4})\b/, text)
        |> Enum.map(fn [_full, year] -> year end)
        |> Enum.uniq()

      # Look up URLs and filter by year mentions
      law_ids =
        footnote_refs
        |> Enum.flat_map(fn ref ->
          urls_for_ref = Map.get(urls, ref, [])

          # Filter to URLs matching years in text
          Enum.filter(urls_for_ref, fn url ->
            Enum.any?(years, fn year -> String.contains?(url, year) end)
          end)
        end)
        |> Enum.map(&extract_law_id_from_url/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      if law_ids == [] do
        :no_match
      else
        {:match, law_ids,
         %{
           footnote_refs: footnote_refs,
           years_in_text: years,
           is_fallback: true
         }}
      end
    end
  end

  # Extract law ID from legislation.gov.uk URL
  defp extract_law_id_from_url(url) when is_binary(url) do
    cond do
      # Standard UK law URL (with or without full domain)
      Regex.match?(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url) ->
        [_, type, year, number] =
          Regex.run(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url)

        IdField.build_name(type, year, number)

      # EU directive URL
      Regex.match?(~r/european\/directive\/(\d{4})\/(\d+)/, url) ->
        [_, year, number] = Regex.run(~r/european\/directive\/(\d{4})\/(\d+)/, url)
        IdField.build_name("eudr", year, number)

      true ->
        nil
    end
  end

  defp extract_law_id_from_url(_), do: nil
end

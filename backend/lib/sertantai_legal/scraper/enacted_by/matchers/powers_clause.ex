defmodule SertantaiLegal.Scraper.EnactedBy.Matchers.PowersClause do
  @moduledoc """
  Matcher for "powers conferred by" style patterns.

  These patterns match phrases like:
  - "powers conferred by [footnote]"
  - "powers under [footnote]"
  - "in exercise of the powers [footnote]"

  The pattern captures a footnote reference (e.g., "f00001") which is then
  looked up in the context's URL map to find the actual law reference.

  This is a medium priority matcher (priority 50) - used when no specific
  Act pattern matched but before the fallback.
  """

  @behaviour SertantaiLegal.Scraper.EnactedBy.Matcher

  alias SertantaiLegal.Scraper.IdField

  @impl true
  def pattern_type, do: :powers_clause

  @impl true
  def match(pattern, text, context) do
    urls = Map.get(context, :urls, %{})

    case Regex.scan(pattern.pattern, text) do
      [] ->
        :no_match

      matches ->
        # Extract footnote refs from matches
        footnote_refs =
          matches
          |> Enum.map(fn [_full | captures] -> List.first(captures) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        # Look up URLs for footnote refs and extract law IDs
        law_ids =
          footnote_refs
          |> Enum.flat_map(fn ref -> Map.get(urls, ref, []) end)
          |> Enum.map(&extract_law_id_from_url/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        if law_ids == [] do
          :no_match
        else
          {:match, law_ids, %{footnote_refs: footnote_refs, matched_count: length(matches)}}
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

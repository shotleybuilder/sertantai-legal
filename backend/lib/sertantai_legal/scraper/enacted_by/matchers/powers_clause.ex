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

    # First check if the pattern matches at all
    case Regex.run(pattern.pattern, text) do
      nil ->
        :no_match

      [matched_text | _] ->
        # Found a "powers conferred by" clause - now extract the full enacting sentence
        # The enacting clause typically ends at the first period followed by a capital letter
        # or at "The Secretary of State—" pattern
        enacting_clause = extract_enacting_clause(text, matched_text)

        # Extract ALL footnote/citation refs from the enacting clause
        footnote_refs =
          Regex.scan(~r/[fc]\d{5}/, enacting_clause)
          |> List.flatten()
          |> Enum.uniq()

        # Look up URLs for footnote refs and extract law IDs
        # Filter to only primary legislation and EU law - SIs can't "enact" other SIs
        law_ids =
          footnote_refs
          |> Enum.flat_map(fn ref -> Map.get(urls, ref, []) end)
          |> Enum.map(&extract_law_id_from_url/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&is_enabling_legislation?/1)
          |> Enum.uniq()

        if law_ids == [] do
          :no_match
        else
          {:match, law_ids, %{footnote_refs: footnote_refs, enacting_clause: enacting_clause}}
        end
    end
  end

  # Extract the enacting clause from the text
  # Starts from "powers conferred" and ends at the first sentence boundary
  defp extract_enacting_clause(text, matched_text) do
    # Find where the matched text starts
    case :binary.match(text, matched_text) do
      {start_pos, _} ->
        # Get text from start of match to end
        remaining = String.slice(text, start_pos, String.length(text) - start_pos)

        # Find the end of the enacting clause - typically ends with:
        # - A period followed by space and capital letter (new sentence)
        # - "The Secretary of State" starting a new clause
        case Regex.run(~r/^(.*?)\.\s+(?:[A-Z]|The Secretary)/, remaining, capture: :all) do
          [_, clause] -> clause <> "."
          nil -> String.slice(remaining, 0, 500)
        end

      :nomatch ->
        matched_text
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

      # EU regulation URL
      Regex.match?(~r/european\/regulation\/(\d{4})\/(\d+)/, url) ->
        [_, year, number] = Regex.run(~r/european\/regulation\/(\d{4})\/(\d+)/, url)
        IdField.build_name("eur", year, number)

      # EU directive URL
      Regex.match?(~r/european\/directive\/(\d{4})\/(\d+)/, url) ->
        [_, year, number] = Regex.run(~r/european\/directive\/(\d{4})\/(\d+)/, url)
        IdField.build_name("eudr", year, number)

      true ->
        nil
    end
  end

  defp extract_law_id_from_url(_), do: nil

  # Filter to only legislation types that can "enact" other legislation
  # Primary legislation (Acts) and EU retained law can enable SIs
  # But SIs cannot enable other SIs (those are just amendment references)
  @enabling_types ~w[ukpga anaw asp nia apni ukla eur eudr eut]
  defp is_enabling_legislation?(law_id) when is_binary(law_id) do
    case String.split(law_id, "/") do
      [type_code | _] -> type_code in @enabling_types
      _ -> false
    end
  end

  defp is_enabling_legislation?(_), do: false
end

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
        # Found a "powers conferred by" clause - extract the full enacting SENTENCE
        # not just the text after "powers conferred". The enabling Act may be referenced
        # earlier in the same sentence via back-references like "the said section 2(2)"
        # e.g. "Minister designated f00001 for...section 2(2) of the ECA f00002...
        #        in exercise of the powers conferred by the said section 2(2)"
        enacting_sentence = extract_enacting_sentence(text, matched_text)

        # Extract citation refs (c00001) and footnote refs (f00001) separately
        # Inline citations point directly to enabling Acts
        # Footnotes may contain amendment history (multiple Acts that touched the section)
        citation_refs =
          Regex.scan(~r/c\d{5}/, enacting_sentence)
          |> List.flatten()
          |> Enum.uniq()

        footnote_refs =
          Regex.scan(~r/f\d{5}/, enacting_sentence)
          |> List.flatten()
          |> Enum.uniq()

        # Prefer inline citations - they point directly to the enabling Act
        # Only use footnotes if no inline citations found
        # Footnotes often include amendment history (Acts that modified the section)
        refs_to_use =
          if citation_refs != [] do
            citation_refs
          else
            # For footnotes, only take the FIRST URL from each footnote
            # The first URL is typically the primary enabling Act
            # Subsequent URLs are Acts that amended that section
            footnote_refs
          end

        # Look up URLs for refs and extract law IDs
        # For footnotes, only take the first URL (primary enabling Act)
        # Filter to only primary legislation and EU law - SIs can't "enact" other SIs
        law_ids =
          refs_to_use
          |> Enum.flat_map(fn ref ->
            case {String.starts_with?(ref, "c"), Map.get(urls, ref, [])} do
              # Inline citations - use all URLs (typically just one)
              {true, ref_urls} -> ref_urls
              # Footnotes - only use first URL (primary enabling Act)
              {false, [first_url | _]} -> [first_url]
              {false, []} -> []
            end
          end)
          |> Enum.map(&extract_law_id_from_url/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&is_enabling_legislation?/1)
          |> Enum.uniq()

        if law_ids == [] do
          :no_match
        else
          {:match, law_ids,
           %{
             citation_refs: citation_refs,
             footnote_refs: footnote_refs,
             refs_used: refs_to_use,
             enacting_clause: enacting_sentence
           }}
        end
    end
  end

  # Extract the full enacting SENTENCE containing the "powers conferred" phrase.
  # Scans backwards to the sentence start (previous ". " + capital, or start of text)
  # and forwards to the sentence end. This captures footnote refs that appear before
  # the "powers conferred" phrase — needed for back-reference patterns like:
  #   "Minister designated f00001 for...the ECA f00002...
  #    in exercise of the powers conferred by the said section 2(2)"
  defp extract_enacting_sentence(text, matched_text) do
    case :binary.match(text, matched_text) do
      {match_pos, _} ->
        # Find sentence start: scan backwards for ". [A-Z]" or start of text
        before = String.slice(text, 0, match_pos)

        sentence_start =
          case Regex.scan(~r/\.\s+[A-Z]/, before, return: :index) do
            [] ->
              0

            matches ->
              # Take the last match (closest to our position)
              [{pos, len}] = List.last(matches)
              pos + len
          end

        # Find sentence end: scan forwards from match for ". [A-Z]" or end of text
        remaining = String.slice(text, match_pos, String.length(text) - match_pos)

        sentence_end =
          case Regex.run(~r/^(.*?)\.\s*(?:[A-Z]|$)/, remaining, capture: :all) do
            [_, clause] -> match_pos + String.length(clause) + 1
            nil -> String.length(text)
          end

        String.slice(text, sentence_start, sentence_end - sentence_start)

      :nomatch ->
        matched_text
    end
  end

  # Extract law ID from legislation.gov.uk URL
  # Handles both /id/ style URLs and direct URLs
  defp extract_law_id_from_url(url) when is_binary(url) do
    cond do
      # Standard UK law URL with /id/ path (from footnotes)
      # e.g., http://www.legislation.gov.uk/id/ukpga/1996/18
      Regex.match?(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url) ->
        [_, type, year, number] =
          Regex.run(~r/\/id\/([a-z]+)\/(\d{4})\/(\d+)/, url)

        IdField.build_name(type, year, number)

      # Direct UK law URL without /id/ (from inline citations)
      # e.g., https://www.legislation.gov.uk/ukpga/1996/18
      Regex.match?(~r/legislation\.gov\.uk\/([a-z]+)\/(\d{4})\/(\d+)/, url) ->
        [_, type, year, number] =
          Regex.run(~r/legislation\.gov\.uk\/([a-z]+)\/(\d{4})\/(\d+)/, url)

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

  # Filter to only legislation types that can "enact" other legislation.
  # Only domestic primary legislation can confer regulation-making powers.
  # EU regulations/directives (eur, eudr, eut) are referenced for definitions
  # but don't confer domestic powers — authority comes from ECA s.2(2) or
  # EU Withdrawal Act, not from the EU instrument itself.
  @enabling_types ~w[ukpga anaw asp nia apni ukla]
  defp is_enabling_legislation?(law_id) when is_binary(law_id) do
    case String.split(law_id, "/") do
      [type_code | _] -> type_code in @enabling_types
      _ -> false
    end
  end

  defp is_enabling_legislation?(_), do: false
end

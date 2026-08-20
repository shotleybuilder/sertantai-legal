defmodule SertantaiLegal.Scraper.RootResolver.CitationExtractor do
  @moduledoc """
  Pure functions for extracting law citations from definition text.

  Handles several citation patterns found in UK legislation:
  - Named laws: "the Scotland Act 1998"
  - Short names: "the 2016 Regulations"
  - Abbreviations: "the Waste Directive" (resolved via citation index)
  - Statute initials: "TCPA 1990", "EA 1989" (curated static map)
  - EU directives/regulations: "Directive 2008/98/EC"
  - Section references: "section 126(1)", "regulation 3"

  All functions are pure — no DB access, no side effects.
  """

  # Anchors on "Act|Regulations|Order YYYY" and captures up to 120 chars before it.
  # 120 handles compound titles like "Health and Safety (Enforcing Authority for
  # Railways and Other Guided Transport Systems) Regulations" (88 chars).
  # Negative lookahead (?!\/) prevents matching "Regulation 2017/625" as "Regulation 2017"
  @law_type_year_re ~r/([A-Z][^\n]{0,120}?(?:Act|Regulations?|Order|Rules?|Directive|Measure))\s+(\d{4})(?!\/)/u

  # Short name: "the 1991 Act", "the 2003 Regulations"
  @short_name_re ~r/(?:the\s+)?(\d{4})\s+(Act|Regulations?|Order|Rules?)/u

  # Year-prefix named SI: "the 2014 Acetylene Regulations", "the 1996 Safety Case Regulations"
  @year_prefix_re ~r/(?:the\s+)?(\d{4})\s+([A-Z][A-Za-z\s&]+?)\s+(Regulations?|Order|Rules?|Act)/u

  # Section reference: "section 126(1)", "regulation 3", "article 2(1)"
  @section_re ~r/(section|regulation|article|paragraph|rule|part)\s+([\d]+(?:\([\d]+\))?(?:\([a-z]\))?)/iu

  # Abbreviation: "the Waste Directive", "the Basel Convention"
  @abbreviation_re ~r/\bthe\s+([A-Z]\w*(?:\s+[A-Z]\w*)*\s+(?:Directive|Convention|Treaty|Code))\b/u

  # Statute abbreviation: "TCPA 1990", "EA 1989" — uppercase initials + year
  @initials_re ~r/\b(?:the\s+)?([A-Z]{2,6})\s+(\d{4})\b/u

  # Curated map of known UK statute abbreviations → full law titles.
  # Only ~10 canonical statutes are referenced by initials in the corpus.
  # Add new entries here as they are discovered.
  @statute_abbreviations %{
    "tcpa" => "Town and Country Planning Act",
    "mcaa" => "Marine and Coastal Access Act",
    "ea" => "Electricity Act",
    "cra" => "Consumer Rights Act",
    "cta" => "Corporation Tax Act",
    "ita" => "Income Tax Act",
    "tcga" => "Taxation of Chargeable Gains Act",
    "frs" => "Fire and Rescue Services Act",
    "ggetsr" => "Greenhouse Gas Emissions Trading Scheme Regulations",
    "tswr" => "Territorial Sea (Welsh Region) Regulations"
  }

  # EU Regulation short-form: "Regulation 853/2004", "Regulation (EC) No 178/2002"
  # Captures the full regulation reference for downstream extract_eu_law_name resolution
  @eu_reg_short_re ~r/Regulation\s+(?:\((?:EC|EU|EEC)\)\s+)?(?:No\.?\s*)?\d+\/\d+/iu

  # Internal reference: "given by section 3" without external law name
  # Also matches "has the meaning given in regulation 4", "construed in accordance with schedule 2"
  # Plural forms (paragraphs, subsections) and parenthesized numbers ((2)) are supported
  @internal_ref_re ~r/(?:given|specified|set out|provided|defined|construed|assigned)\s+(?:by|in|to\s+it\s+by)\s+(?:accordance\s+with\s+)?(?:sections?|regulations?|articles?|paragraphs?|rules?|schedules?|parts?|subsections?)\s+\(?\d/iu

  # Extended internal ref: "has the meaning given in regulation 4", ") has the meaning given in section 5"
  @internal_ref_has_meaning_re ~r/(?:has|have)\s+the\s+(?:same\s+)?meanings?\s+(?:given|assigned|provided)\s+(?:by|in|to\s+it\s+by)\s+(?:sections?|regulations?|articles?|paragraphs?|rules?|schedules?|parts?|subsections?)\s+\(?\d/iu

  @spec extract_citation(String.t(), String.t(), map()) :: String.t() | nil
  def extract_citation(definition, law_name, citation_index) do
    case extract_named_law(definition) do
      {:ok, title, _year} ->
        expanded = expand_abbreviation_in_title(title) || title
        section = extract_section(definition)
        if section, do: "#{expanded} #{section}", else: expanded

      :no_match ->
        case extract_year_prefix_citation(definition) do
          {:ok, citation} ->
            citation

          :no_match ->
            case extract_eu_regulation_citation(definition) do
              {:ok, citation} ->
                citation

              :no_match ->
                case Regex.run(@short_name_re, definition) do
                  [_full, year, type] ->
                    short_key = {law_name, String.downcase("#{year} #{type}")}
                    full_title = Map.get(citation_index, short_key)

                    raw = full_title || "the #{year} #{type}"
                    section = extract_section(definition)
                    if section, do: "#{raw} #{section}", else: raw

                  nil ->
                    extract_abbreviation_citation(definition, law_name, citation_index) ||
                      extract_initials_citation(definition)
                end
            end
        end
    end
  end

  @spec extract_named_law(String.t()) :: {:ok, String.t(), String.t()} | :no_match
  def extract_named_law(definition) do
    case Regex.run(@law_type_year_re, definition) do
      [_full, raw_title, year] ->
        title =
          raw_title
          |> String.replace(~r/^.*\b(?:of|in|as|under|by|from)\s+the\s+/i, "")
          |> String.replace(~r/^.*\bthe\s+/i, "")
          |> String.trim()
          |> String.trim_trailing(",")
          |> String.trim_trailing(";")

        # Reject if title starts with "Article" — this is an EU article reference
        # mismatched by the law_type_year regex, not a law title
        if String.match?(title, ~r/^Article\s/i) do
          :no_match
        else
          {:ok, "#{title} #{year}", year}
        end

      nil ->
        :no_match
    end
  end

  @spec extract_section(String.t()) :: String.t() | nil
  def extract_section(definition) do
    case Regex.run(@section_re, definition) do
      [_full, type, num] -> "#{String.downcase(type)} #{num}"
      nil -> nil
    end
  end

  # International convention/treaty keywords — SOLAS, UNCLOS, Chicago Convention, etc.
  @convention_re ~r/\b(?:SOLAS|UNCLOS|MLC|ICAO|MARPOL|the\s+(?:Chicago|Geneva|Vienna|Hague|Warsaw|Montreal|Berne|Paris)\s+Convention|Convention\s+(?:on|for|concerning)\b)/u

  @spec international_convention?(String.t()) :: boolean()
  def international_convention?(definition) do
    Regex.match?(@convention_re, definition) and
      not Regex.match?(@law_type_year_re, definition)
  end

  @spec internal_ref?(String.t()) :: boolean()
  def internal_ref?(definition) do
    clean = String.replace(definition, ~r/\A\)\s*/, "")

    (Regex.match?(@internal_ref_re, clean) or Regex.match?(@internal_ref_has_meaning_re, clean)) and
      not Regex.match?(@law_type_year_re, clean) and
      not Regex.match?(@short_name_re, clean) and
      not Regex.match?(~r/\bDirective\b/, clean)
  end

  @spec normalise_title(String.t()) :: String.t()
  def normalise_title(title) do
    title
    |> String.replace(~r/\s*\((?:c\.\s*\d+|asp\s+\d+)\)/i, "")
    |> String.replace(~r/(?<=\s)\(NI\)/i, "(Northern Ireland)")
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.replace(~r/[^\w\s]/, "")
    |> String.trim()
    |> String.replace(~r/^the\s+/, "")
  end

  @spec extract_eu_law_name(String.t() | nil) :: String.t() | nil
  def extract_eu_law_name(nil), do: nil

  def extract_eu_law_name(citation) do
    cond do
      match = Regex.run(~r/Directive.*?(\d{4})\/(\d+)/i, citation) ->
        [_, year, number] = match
        "UK_eudr_#{year}_#{number}"

      match = Regex.run(~r/Directive.*?(\d{2})\/(\d+)\/E/i, citation) ->
        [_, short_year, number] = match

        year =
          if String.to_integer(short_year) > 50, do: "19#{short_year}", else: "20#{short_year}"

        "UK_eudr_#{year}_#{number}"

      match = Regex.run(~r/Regulation.*?No\.?\s*(\d+)\/(\d{4})/i, citation) ->
        [_, number, year] = match
        "UK_eur_#{year}_#{number}"

      match = Regex.run(~r/Regulation.*?(\d+)\/((?:19|20)\d{2})/i, citation) ->
        [_, number, year] = match
        "UK_eur_#{year}_#{number}"

      match = Regex.run(~r/Regulation.*?((?:19|20)\d{2})\/(\d+)/i, citation) ->
        [_, year, number] = match
        "UK_eur_#{year}_#{number}"

      true ->
        nil
    end
  end

  @spec extract_year_prefix_citation(String.t()) :: {:ok, String.t()} | :no_match
  def extract_year_prefix_citation(definition) do
    case Regex.run(@year_prefix_re, definition) do
      [_full, year, name, type] ->
        title = "#{String.trim(name)} #{type} #{year}"
        section = extract_section(definition)
        citation = if section, do: "#{title} #{section}", else: title
        {:ok, citation}

      nil ->
        :no_match
    end
  end

  @spec extract_eu_regulation_citation(String.t()) :: {:ok, String.t()} | :no_match
  def extract_eu_regulation_citation(definition) do
    case Regex.run(@eu_reg_short_re, definition) do
      [regulation] -> {:ok, regulation}
      nil -> :no_match
    end
  end

  @spec extract_initials_citation(String.t()) :: String.t() | nil
  def extract_initials_citation(definition) do
    case Regex.run(@initials_re, definition) do
      [_full, initials, year] ->
        case Map.get(@statute_abbreviations, String.downcase(initials)) do
          nil ->
            nil

          full_title ->
            citation = "#{full_title} #{year}"
            section = extract_section(definition)
            if section, do: "#{citation} #{section}", else: citation
        end

      nil ->
        nil
    end
  end

  @spec extract_abbreviation_citation(String.t(), String.t(), map()) :: String.t() | nil
  def extract_abbreviation_citation(definition, law_name, citation_index) do
    case Regex.run(@abbreviation_re, definition) do
      [_full, abbrev] ->
        key = {law_name, String.downcase(abbrev)}
        Map.get(citation_index, key)

      nil ->
        nil
    end
  end

  # Expand known abbreviation initials in extracted law titles.
  # "FRS Act 2004" → "Fire and Rescue Services Act 2004"
  # The full_name already contains the law type (Act/Regulations), so we replace
  # "ABBREV Type" with "Full Name" to avoid "Full Name Type" duplication.
  @spec expand_abbreviation_in_title(String.t()) :: String.t() | nil
  defp expand_abbreviation_in_title(title) do
    Enum.find_value(@statute_abbreviations, fn {abbrev, full_name} ->
      upper = String.upcase(abbrev)

      if String.starts_with?(title, upper <> " ") do
        # Replace "FRS Act" with "Fire and Rescue Services Act" (not just "FRS")
        abbrev_with_type =
          ~r/^#{Regex.escape(upper)}\s+(?:Act|Regulations?|Order|Rules?)/

        if Regex.match?(abbrev_with_type, title) do
          String.replace(title, abbrev_with_type, full_name)
        else
          String.replace(title, upper, full_name, global: false)
        end
      end
    end)
  end
end

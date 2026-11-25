defmodule SertantaiLegal.Scraper.EnactedBy.IntroductionXml do
  @moduledoc """
  An SI's introduction XML parsed to its introductory and enacting text,
  with footnote and inline citation markers kept in the text and their URLs
  (`parse/1`). Split from `EnactedBy` (the Extent reader stamps session) so
  the powers parser's stamp (`EnablingCache.ParserVersion`) holds this parse
  and not the register's enacted-by matchers beside it. Pure.
  """

  import SweetXml

  @doc """
  Parse introduction XML to extract enacting text and footnote URLs.

  The text extraction includes FootnoteRef elements inline (e.g., "Act 1984 f00001")
  so that patterns can match the footnote references.
  """
  @spec parse(String.t()) :: map()
  def parse(xml) when is_binary(xml) do
    try do
      # First verify it's valid XML
      _ = SweetXml.parse(xml)

      # Extract introductory text WITH footnote refs and citation IDs inline
      intro_text = extract_text_with_footnote_refs(xml, "IntroductoryText")

      # Extract enacting text WITH footnote refs and citation IDs inline
      enacting_text = extract_text_with_footnote_refs(xml, "EnactingText")

      # Extract footnote references (f00001 -> URL mapping)
      footnotes =
        xml
        |> xpath(
          ~x"//Footnote"l,
          id: ~x"./@id"s,
          urls: ~x".//Citation/@URI"ls
        )
        |> Enum.reduce(%{}, fn %{id: id, urls: urls}, acc ->
          if id != "" and urls != [] do
            Map.put(acc, id, urls)
          else
            acc
          end
        end)

      # Extract inline Citation elements from IntroductoryText/EnactingText (c00001 -> URL)
      inline_citations = extract_inline_citations(xml)

      # Merge footnotes and inline citations into single URL map
      all_urls = Map.merge(footnotes, inline_citations)

      %{
        introductory_text: intro_text,
        enacting_text: enacting_text,
        text: "#{intro_text} #{enacting_text}" |> String.trim(),
        urls: all_urls
      }
    rescue
      _ -> %{introductory_text: "", enacting_text: "", text: "", urls: %{}}
    catch
      :exit, _ -> %{introductory_text: "", enacting_text: "", text: "", urls: %{}}
    end
  end

  # Extract text content including FootnoteRef and inline Citation IDs as markers
  # e.g., "Act 1984<FootnoteRef Ref="f00001"/>" becomes "Act 1984 f00001"
  # e.g., "<Citation URI="..." id="c00001">Reg 528/2012</Citation>" becomes "c00001 Reg 528/2012"
  defp extract_text_with_footnote_refs(xml, section_name) do
    # Get the raw XML for the section
    section_pattern = ~r/<#{section_name}[^>]*>(.*?)<\/#{section_name}>/s

    case Regex.run(section_pattern, xml) do
      [_, section_xml] ->
        section_xml
        # Replace FootnoteRef elements with their Ref value
        |> String.replace(~r/<FootnoteRef[^>]*Ref="([^"]+)"[^>]*\/>/, " \\1 ")
        # Replace inline Citation elements with their id value (keep text content)
        # <Citation URI="..." id="c00001">text</Citation> -> " c00001 text"
        |> String.replace(~r/<Citation[^>]*\bid="([^"]+)"[^>]*>/, " \\1 ")
        # Strip all other XML tags (including </Citation>)
        |> String.replace(~r/<[^>]+>/, " ")
        # Normalize whitespace
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      _ ->
        ""
    end
  end

  # Extract inline Citation URIs from IntroductoryText and EnactingText
  # Returns map like %{"c00001" => ["http://..."]}
  defp extract_inline_citations(xml) do
    # Find all Citation elements with both id and URI attributes
    Regex.scan(
      ~r/<Citation[^>]*\bURI="([^"]+)"[^>]*\bid="([^"]+)"[^>]*>|<Citation[^>]*\bid="([^"]+)"[^>]*\bURI="([^"]+)"[^>]*>/,
      xml
    )
    |> Enum.reduce(%{}, fn match, acc ->
      # Handle both attribute orders (URI before id, or id before URI)
      {id, uri} =
        case match do
          [_, uri, id] when uri != "" and id != "" -> {id, uri}
          [_, _, _, id, uri] when uri != "" and id != "" -> {id, uri}
          _ -> {nil, nil}
        end

      if id && uri do
        Map.update(acc, id, [uri], fn urls -> [uri | urls] end)
      else
        acc
      end
    end)
  end
end

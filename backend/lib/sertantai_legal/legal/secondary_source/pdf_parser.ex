defmodule SertantaiLegal.Legal.SecondarySource.PdfParser do
  @moduledoc """
  Parses a PDF document into structured provisions using pdf_elixide.

  Uses font size, bold/italic flags, and numbering patterns to classify
  text lines into a provision hierarchy. Designed for UK government
  compliance documents (JSPs, ACoPs, HSE guidance) which follow
  predictable formatting conventions.

  ## Font size hierarchy (typical JSP/ACoP pattern)

  - 24pt bold → chapter title / part heading
  - 14-16pt bold → section heading
  - 12pt bold → sub-section heading / label
  - 12pt regular → body paragraph
  - ≤11pt → table content / footnotes / annexes

  ## Usage

      provisions = PdfParser.parse(pdf_path, source)

  Returns a list of provision maps ready for `SecondarySourceProvision.upsert`.
  """

  alias PdfElixide.Document

  @type_prefix_map %{
    acop: "ACOP",
    guidance: "HSG",
    standard: "STD",
    jsp: "JSP",
    industry_code: "IND"
  }

  @doc """
  Parse a PDF file into a list of provision maps.

  `source` is a `SecondarySource` struct (needs source_id, source_type, issuer, edition).
  Returns `{:ok, provisions}` or `{:error, reason}`.
  """
  def parse(pdf_path, source) do
    with {:ok, doc} <- Document.open(pdf_path) do
      page_count = Document.page_count!(doc)

      raw_lines =
        for page_idx <- 0..(page_count - 1), reduce: [] do
          acc ->
            lines = Document.text_lines!(doc, page_idx)

            page_lines =
              Enum.map(lines, fn line ->
                words = line.words
                first_word = List.first(words)

                %{
                  text: Enum.map_join(words, " ", & &1.text) |> String.trim(),
                  font_size: first_word && Float.round(first_word.font_size, 1),
                  bold: first_word && first_word.bold?,
                  italic: first_word && first_word.italic?,
                  font: first_word && first_word.font,
                  page: page_idx + 1,
                  x: first_word && Float.round(first_word.bbox.x, 1)
                }
              end)
              |> Enum.reject(&(&1.text == "" or &1.font_size == nil))

            acc ++ page_lines
        end

      provisions = classify_and_group(raw_lines, source)
      {:ok, provisions}
    end
  end

  # ---------------------------------------------------------------------------
  # Classification
  # ---------------------------------------------------------------------------

  defp classify_and_group(lines, source) do
    # First pass: classify each line
    classified =
      lines
      |> Enum.map(&classify_line/1)
      |> Enum.reject(&(&1.role == :skip))

    # Second pass: merge consecutive same-role lines (multi-line headings)
    heading_merged = merge_same_role_lines(classified)

    # Third pass: merge body/continuation lines into paragraphs
    merged = merge_body_lines(heading_merged)

    # Fourth pass: build provisions with section_ids and hierarchy
    build_provisions(merged, source)
  end

  defp classify_line(line) do
    role = determine_role(line)
    Map.put(line, :role, role)
  end

  defp determine_role(%{font_size: sz, bold: true, text: text}) when sz >= 20.0 do
    if page_header?(text), do: :skip, else: :chapter_title
  end

  defp determine_role(%{font_size: sz, bold: true, text: text}) when sz >= 14.0 do
    if page_header?(text), do: :skip, else: :section_heading
  end

  defp determine_role(%{font_size: sz, bold: true, text: text}) when sz >= 12.0 do
    cond do
      page_header?(text) -> :skip
      bold_continuation?(text) -> :body
      true -> :sub_heading
    end
  end

  defp determine_role(%{font_size: sz, bold: false, text: text}) when sz >= 12.0 do
    cond do
      page_header?(text) -> :skip
      numbered_paragraph?(text) -> :numbered_para
      true -> :body
    end
  end

  defp determine_role(%{font_size: sz}) when sz <= 8.0, do: :footnote
  defp determine_role(%{font_size: sz, bold: false}) when sz < 12.0, do: :minor_text
  defp determine_role(%{font_size: sz, bold: true}) when sz < 12.0, do: :minor_heading
  defp determine_role(_), do: :body

  # Page headers/footers — "JSP 375 Vol 1 Chapter 8 (V1.7 Jun 25)"
  defp page_header?(text) do
    Regex.match?(~r/^\s*\d+\s+JSP\s+375/i, text) or
      Regex.match?(~r/^JSP\s+375.*Chapter/i, text)
  end

  # Bold continuation lines — start lowercase or with common continuation words.
  # These are body text that happens to be bold, not structural headings.
  defp bold_continuation?(text) do
    first_char = String.first(text)

    starts_lowercase =
      first_char != nil and first_char == String.downcase(first_char) and
        first_char != String.upcase(first_char)

    starts_with_continuation =
      Regex.match?(
        ~r/^(must|and|or|the|with|to|from|for|that|which|where|when|if|as|by|in|on|of|their|its|this|these|followed|control|necessary)\b/i,
        text
      ) and starts_lowercase

    starts_lowercase or starts_with_continuation
  end

  defp numbered_paragraph?(text) do
    Regex.match?(~r/^\d+\.\s/, text)
  end

  # ---------------------------------------------------------------------------
  # Merge consecutive same-role lines (multi-line headings)
  #
  # A chapter title split across two lines ("8 Safety risk assessment and safe"
  # / "systems of work") should be one provision, not two.
  # ---------------------------------------------------------------------------

  defp merge_same_role_lines(lines) do
    lines
    |> Enum.chunk_while(
      nil,
      fn line, acc ->
        cond do
          acc == nil ->
            {:cont, line}

          acc.role == line.role and
              acc.role in [:chapter_title, :section_heading, :sub_heading] ->
            {:cont, %{acc | text: acc.text <> " " <> line.text}}

          true ->
            {:cont, acc, line}
        end
      end,
      fn
        nil -> {:cont, []}
        acc -> {:cont, acc, []}
      end
    )
    |> List.flatten()
    |> Enum.reject(&is_list/1)
  end

  # ---------------------------------------------------------------------------
  # Merge consecutive body/continuation lines
  # ---------------------------------------------------------------------------

  defp merge_body_lines(lines) do
    lines
    |> Enum.chunk_while(
      nil,
      fn line, acc ->
        cond do
          # Start new chunk for structural elements
          line.role in [:chapter_title, :section_heading, :sub_heading, :numbered_para] ->
            if acc, do: {:cont, acc, line}, else: {:cont, line}

          # Body/continuation lines merge into the current chunk
          line.role in [:body, :minor_text, :footnote, :minor_heading] and acc != nil and
              acc.role in [:body, :numbered_para] ->
            merged = %{acc | text: acc.text <> " " <> line.text}
            {:cont, merged}

          # Everything else starts a new chunk
          true ->
            if acc, do: {:cont, acc, line}, else: {:cont, line}
        end
      end,
      fn
        nil -> {:cont, []}
        acc -> {:cont, acc, []}
      end
    )
    |> List.flatten()
    |> Enum.reject(&is_list/1)
  end

  # ---------------------------------------------------------------------------
  # Build provisions
  # ---------------------------------------------------------------------------

  defp build_provisions(lines, source) do
    prefix = section_id_prefix(source)

    {provisions, _state} =
      Enum.reduce(
        lines,
        {[], %{position: 0, path: [], current_chapter: nil, current_section: nil}},
        fn line, {provs, state} ->
          case line.role do
            :chapter_title ->
              slug = slugify_heading(line.text)

              state = %{
                state
                | position: state.position + 1,
                  current_chapter: slug,
                  current_section: nil,
                  path: [slug]
              }

              prov = %{
                section_id: "#{prefix}:#{slug}",
                secondary_source_id: source.id,
                source_id: source.source_id,
                sort_key: String.pad_leading("#{state.position}", 5, "0"),
                position: state.position,
                section_type: infer_chapter_type(line.text),
                depth: 0,
                hierarchy_path: "/#{slug}",
                heading: String.trim(line.text),
                text: nil,
                text_source: :heading_only
              }

              {[prov | provs], state}

            :section_heading ->
              slug = slugify_heading(line.text)

              state = %{
                state
                | position: state.position + 1,
                  current_section: slug,
                  path: [state.current_chapter, slug] |> Enum.reject(&is_nil/1)
              }

              path = Enum.join(state.path, "/")

              prov = %{
                section_id: "#{prefix}:#{path}",
                secondary_source_id: source.id,
                source_id: source.source_id,
                sort_key: String.pad_leading("#{state.position}", 5, "0"),
                position: state.position,
                section_type: :section,
                depth: 1,
                hierarchy_path: "/#{path}",
                heading: String.trim(line.text),
                text: nil,
                text_source: :heading_only
              }

              {[prov | provs], state}

            :sub_heading ->
              slug = slugify_heading(line.text)
              state = %{state | position: state.position + 1}
              parent_path = state.path |> Enum.join("/")
              full_path = if parent_path == "", do: slug, else: "#{parent_path}/#{slug}"

              prov = %{
                section_id: "#{prefix}:#{full_path}",
                secondary_source_id: source.id,
                source_id: source.source_id,
                sort_key: String.pad_leading("#{state.position}", 5, "0"),
                position: state.position,
                section_type: :heading,
                depth: 2,
                hierarchy_path: "/#{full_path}",
                heading: String.trim(line.text),
                text: nil,
                text_source: :heading_only
              }

              {[prov | provs], state}

            :numbered_para ->
              para_num = extract_para_number(line.text)
              state = %{state | position: state.position + 1}
              parent_path = state.path |> Enum.join("/")

              locator =
                if parent_path == "",
                  do: "para.#{para_num}",
                  else: "#{parent_path}.para.#{para_num}"

              prov = %{
                section_id: "#{prefix}:#{locator}",
                secondary_source_id: source.id,
                source_id: source.source_id,
                sort_key: String.pad_leading("#{state.position}", 5, "0"),
                position: state.position,
                section_type: :paragraph,
                depth: if(parent_path == "", do: 1, else: length(state.path) + 1),
                hierarchy_path: "/#{locator}",
                heading: nil,
                text: String.trim(line.text),
                text_source: :full_text
              }

              {[prov | provs], state}

            _other ->
              # Skip unclassified lines (footnotes, minor text not attached to a paragraph)
              {provs, state}
          end
        end
      )

    Enum.reverse(provisions)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp section_id_prefix(source) do
    type_prefix = Map.get(@type_prefix_map, source.source_type, "SEC")
    issuer = source.issuer |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "")
    year = extract_source_year(source)
    id = source.source_id |> String.replace(~r/[^a-zA-Z0-9]/, "")
    "#{type_prefix}_#{issuer}_#{year}_#{id}"
  end

  defp extract_source_year(source) do
    extract_year_from_string(source.edition) ||
      extract_year_from_date(source.effective_date) ||
      to_string(Date.utc_today().year)
  end

  defp extract_year_from_string(nil), do: nil

  defp extract_year_from_string(text) do
    case Regex.run(~r/(\d{4})/, text) do
      [_, year] -> year
      _ -> nil
    end
  end

  defp extract_year_from_date(nil), do: nil
  defp extract_year_from_date(%Date{year: y}), do: to_string(y)

  defp slugify_heading(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.slice(0, 50)
  end

  defp infer_chapter_type(text) do
    text_lower = String.downcase(text)

    cond do
      String.contains?(text_lower, "volume") -> :volume
      String.contains?(text_lower, "part") -> :part
      String.contains?(text_lower, "chapter") -> :chapter
      String.contains?(text_lower, "annex") -> :annex
      String.contains?(text_lower, "schedule") -> :schedule
      true -> :chapter
    end
  end

  defp extract_para_number(text) do
    case Regex.run(~r/^(\d+)\./, text) do
      [_, num] -> num
      _ -> "0"
    end
  end
end

defmodule SertantaiLegal.Legal.SecondarySource.PdfParser do
  @moduledoc """
  Parses a PDF document into structured provisions using pdf_elixide.

  Uses publisher-specific profiles to classify text lines into a provision
  hierarchy. Each profile encapsulates font thresholds, numbering patterns,
  and skip rules for a document type.

  ## Profiles

  - `:mod_jsp` — MoD Joint Service Publications (12pt body, "N." numbering)
  - `:hse_acop` — HSE Approved Codes of Practice (10pt body, "N" numbering)

  Profile is auto-detected from font analysis + publisher heuristics, or
  can be overridden via the `--profile` flag on `mix secondary.parse`.

  ## Usage

      {:ok, provisions, profile} = PdfParser.parse(pdf_path, source)
      {:ok, provisions, profile} = PdfParser.parse(pdf_path, source, profile: :hse_acop)
  """

  alias PdfElixide.Document
  alias SertantaiLegal.Legal.SecondarySource.ParserProfile

  @type_prefix_map %{
    acop: "ACOP",
    guidance: "HSG",
    standard: "STD",
    jsp: "JSP",
    industry_code: "IND"
  }

  @doc """
  Classify raw extracted lines into provisions using the given profile.

  This is the pure logic pipeline — no PDF I/O. Used by tests to verify
  classification without needing PDF fixtures.
  """
  def classify_lines(raw_lines, source, profile) do
    provisions = classify_and_group(raw_lines, source, profile)
    {:ok, provisions}
  end

  @doc """
  Parse a PDF file into a list of provision maps.

  Options:
  - `:profile` — force a specific profile (`:mod_jsp`, `:hse_acop`)
  """
  def parse(pdf_path, source, opts \\ []) do
    with {:ok, doc} <- Document.open(pdf_path) do
      page_count = Document.page_count!(doc)

      raw_lines = extract_lines(doc, page_count)

      profile =
        case Keyword.get(opts, :profile) do
          nil -> ParserProfile.detect(raw_lines, source)
          name -> ParserProfile.build(name, detect_body_size(raw_lines))
        end

      provisions = classify_and_group(raw_lines, source, profile)
      {:ok, provisions, profile}
    end
  end

  defp extract_lines(doc, page_count) do
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
  end

  defp detect_body_size(lines) do
    lines
    |> Enum.filter(&(&1.bold == false and &1.font_size != nil))
    |> Enum.frequencies_by(& &1.font_size)
    |> Enum.max_by(fn {_size, count} -> count end, fn -> {12.0, 0} end)
    |> elem(0)
  end

  # ---------------------------------------------------------------------------
  # Classification pipeline
  # ---------------------------------------------------------------------------

  defp classify_and_group(lines, source, profile) do
    classified =
      lines
      |> Enum.map(&classify_line(&1, profile))
      |> Enum.reject(&(&1.role == :skip))

    classified
    |> merge_same_role_lines()
    |> merge_body_lines()
    |> build_provisions(source)
  end

  defp classify_line(line, profile) do
    role = determine_role(profile.name, line, profile.fonts)
    Map.put(line, :role, role)
  end

  # ===========================================================================
  # Profile-specific classification via pattern matching
  #
  # Each profile has its own set of determine_role/3 clauses. Adding a new
  # profile means adding new clauses — no changes to existing profiles.
  # ===========================================================================

  # --- MoD JSP profile ---

  defp determine_role(:mod_jsp, %{text: text, font_size: sz}, fonts)
       when sz >= fonts.title_min do
    if skip_header?(text, :mod_jsp), do: :skip, else: :chapter_title
  end

  defp determine_role(:mod_jsp, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.section_min do
    if skip_header?(text, :mod_jsp), do: :skip, else: :section_heading
  end

  defp determine_role(:mod_jsp, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    cond do
      skip_header?(text, :mod_jsp) -> :skip
      bold_continuation?(text) -> :body
      true -> :sub_heading
    end
  end

  defp determine_role(:mod_jsp, %{text: text, bold: false, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    cond do
      skip_header?(text, :mod_jsp) -> :skip
      jsp_numbered?(text) -> :numbered_para
      true -> :body
    end
  end

  defp determine_role(:mod_jsp, %{font_size: sz}, fonts)
       when sz <= fonts.footnote_max,
       do: :footnote

  defp determine_role(:mod_jsp, %{bold: false}, _fonts), do: :minor_text
  defp determine_role(:mod_jsp, %{bold: true}, _fonts), do: :minor_heading

  # --- HSE ACoP profile ---

  defp determine_role(:hse_acop, %{font_size: sz}, fonts)
       when sz >= fonts.title_min do
    :chapter_title
  end

  defp determine_role(:hse_acop, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.section_min do
    if skip_header?(text, :hse_acop), do: :skip, else: :section_heading
  end

  defp determine_role(:hse_acop, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    cond do
      skip_header?(text, :hse_acop) -> :skip
      bold_continuation?(text) -> :body
      true -> :sub_heading
    end
  end

  defp determine_role(:hse_acop, %{text: text, bold: false, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    if acop_numbered?(text), do: :numbered_para, else: :body
  end

  defp determine_role(:hse_acop, %{font_size: sz}, fonts)
       when sz <= fonts.footnote_max,
       do: :footnote

  defp determine_role(:hse_acop, %{bold: false}, _fonts), do: :minor_text
  defp determine_role(:hse_acop, %{bold: true}, _fonts), do: :minor_heading

  # --- HSE Guidance profile ---
  # Like :hse_acop but captures unnumbered prose body text as provisions.

  defp determine_role(:hse_guidance, %{font_size: sz}, fonts)
       when sz >= fonts.title_min do
    :chapter_title
  end

  defp determine_role(:hse_guidance, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.section_min do
    if skip_header?(text, :hse_acop), do: :skip, else: :section_heading
  end

  defp determine_role(:hse_guidance, %{text: text, bold: true, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    cond do
      skip_header?(text, :hse_acop) -> :skip
      bold_continuation?(text) -> :body
      true -> :sub_heading
    end
  end

  defp determine_role(:hse_guidance, %{text: text, bold: false, font_size: sz}, fonts)
       when sz >= fonts.sub_heading_min do
    cond do
      acop_numbered?(text) -> :numbered_para
      String.length(text) > 20 -> :prose_body
      true -> :body
    end
  end

  defp determine_role(:hse_guidance, %{font_size: sz}, fonts)
       when sz <= fonts.footnote_max,
       do: :footnote

  defp determine_role(:hse_guidance, %{bold: false}, _fonts), do: :minor_text
  defp determine_role(:hse_guidance, %{bold: true}, _fonts), do: :minor_heading

  # --- Fallback (unknown profile) ---

  defp determine_role(_profile, _line, _fonts), do: :body

  # ===========================================================================
  # Profile-specific helpers
  # ===========================================================================

  # JSP numbering: "1. Text" or "10. Text" (dot required)
  defp jsp_numbered?(text), do: Regex.match?(~r/^\d+\.\s/, text)

  # ACoP numbering: "13 Text" (no dot, capital letter follows)
  defp acop_numbered?(text), do: Regex.match?(~r/^\d+\s+[A-Z]/, text)

  # Extract paragraph number — handles both "N." and "N " styles
  defp extract_para_number(text) do
    case Regex.run(~r/^(\d+)\.?\s/, text) do
      [_, num] -> num
      _ -> "0"
    end
  end

  # Page headers/footers by profile
  defp skip_header?(text, :mod_jsp) do
    Regex.match?(~r/^\s*\d+\s+JSP\s+/i, text) or
      Regex.match?(~r/^JSP\s+\d+.*(?:Chapter|Element|Vol)/i, text)
  end

  defp skip_header?(text, :hse_acop) do
    Regex.match?(~r/^Page\s+\d+\s+of\s+\d+/i, text)
  end

  defp skip_header?(_text, _profile), do: false

  # Bold continuation — common across all profiles
  defp bold_continuation?(text) do
    first_char = String.first(text)

    first_char != nil and
      first_char == String.downcase(first_char) and
      first_char != String.upcase(first_char)
  end

  # ---------------------------------------------------------------------------
  # Merge passes (shared across all profiles)
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

  defp merge_body_lines(lines) do
    lines
    |> Enum.chunk_while(
      nil,
      fn line, acc ->
        cond do
          line.role in [:chapter_title, :section_heading, :sub_heading, :numbered_para] ->
            if acc, do: {:cont, acc, line}, else: {:cont, line}

          # Prose body starts a new chunk (each prose block → one provision)
          line.role == :prose_body and (acc == nil or acc.role != :prose_body) ->
            if acc, do: {:cont, acc, line}, else: {:cont, line}

          # Consecutive prose body lines merge
          line.role == :prose_body and acc != nil and acc.role == :prose_body ->
            {:cont, %{acc | text: acc.text <> " " <> line.text}}

          line.role in [:body, :minor_text, :footnote, :minor_heading] and acc != nil and
              acc.role in [:body, :numbered_para, :prose_body] ->
            {:cont, %{acc | text: acc.text <> " " <> line.text}}

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
  # Build provisions (shared across all profiles)
  # ---------------------------------------------------------------------------

  defp build_provisions(lines, source) do
    prefix = section_id_prefix(source)

    {provisions, _state} =
      Enum.reduce(
        lines,
        {[],
         %{
           position: 0,
           path: [],
           current_chapter: nil,
           current_section: nil,
           seen_ids: MapSet.new(),
           prose_counter: 0
         }},
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

              {prov, state} = dedup_provision(prov, state)
              {[prov | provs], state}

            :section_heading ->
              slug = slugify_heading(line.text)

              state = %{
                state
                | position: state.position + 1,
                  current_section: slug,
                  path: [state.current_chapter, slug] |> Enum.reject(&is_nil/1),
                  prose_counter: 0
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

              {prov, state} = dedup_provision(prov, state)
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

              {prov, state} = dedup_provision(prov, state)
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

              {prov, state} = dedup_provision(prov, state)
              {[prov | provs], state}

            :prose_body ->
              prose_num = state.prose_counter + 1
              state = %{state | position: state.position + 1, prose_counter: prose_num}
              parent_path = state.path |> Enum.join("/")

              locator =
                if parent_path == "",
                  do: "prose.#{prose_num}",
                  else: "#{parent_path}.prose.#{prose_num}"

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

              {prov, state} = dedup_provision(prov, state)
              {[prov | provs], state}

            _other ->
              {provs, state}
          end
        end
      )

    Enum.reverse(provisions)
  end

  # ---------------------------------------------------------------------------
  # Dedup, helpers
  # ---------------------------------------------------------------------------

  defp dedup_provision(prov, state) do
    {unique_id, seen} = dedup_id(prov.section_id, state.seen_ids)
    prov = %{prov | section_id: unique_id}
    state = %{state | seen_ids: MapSet.put(seen, unique_id)}
    {prov, state}
  end

  defp dedup_id(id, seen) do
    if MapSet.member?(seen, id) do
      suffix =
        Stream.iterate(2, &(&1 + 1))
        |> Enum.find(fn n -> not MapSet.member?(seen, "#{id}-#{n}") end)

      {"#{id}-#{suffix}", seen}
    else
      {id, seen}
    end
  end

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
end

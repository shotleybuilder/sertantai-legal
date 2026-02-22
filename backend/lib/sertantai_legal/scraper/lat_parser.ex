defmodule SertantaiLegal.Scraper.LatParser do
  @moduledoc """
  Parses legislation.gov.uk body XML into LAT (Legal Articles Table) rows.

  Pure function module — takes body XML string + law context, returns a list
  of LAT row maps ready for persistence. No HTTP calls, no side effects.

  ## Usage

      rows = LatParser.parse(xml_string, %{
        law_name: "UK_ukpga_1974_37",
        type_code: "ukpga"
      })

  ## XML Element Mapping

  | XML Element     | section_type              |
  |-----------------|---------------------------|
  | Part            | part                      |
  | Chapter         | chapter                   |
  | Pblock          | heading                   |
  | P1              | section (Acts) / article  |
  | P2              | sub_section / sub_article |
  | P3              | paragraph                 |
  | P4              | sub_paragraph             |
  | Schedule        | schedule                  |
  | SignedSection    | signed                    |
  | Tabular         | table                     |
  | Figure          | note                      |
  """

  import SweetXml

  alias SertantaiLegal.Legal.Lat.Transforms

  @act_type_codes ~w(ukpga anaw asp nia apni aep)
  @container_elements ~w(Legislation Primary Secondary Body Schedules ScheduleBody
                         P1para P2para P3para P4para P1group P2group P3group
                         ScheduleBody FragmentBody)

  # Elements to skip entirely — contain embedded P1/P2/P3 from OTHER laws or
  # alternative territorial versions that duplicate the primary text
  @skip_elements ~w(BlockAmendment AppendText BlockExtract
                    Versions Version Commentaries Commentary Contents)

  @doc """
  Parse body XML into a list of LAT row maps.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk `/body/data.xml`
    - `context` — map with `:law_name` and `:type_code`

  ## Returns

  List of maps with keys matching LAT table columns.
  """
  @spec parse(String.t(), map()) :: [map()]
  def parse(xml, context) when is_binary(xml) do
    mode = provision_mode(context.type_code)
    law_name = context.law_name

    initial_ctx = %{
      part: nil,
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: nil,
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      default_extent: extract_root_extent(xml),
      mode: mode
    }

    raw_rows =
      xml
      |> parse_xml()
      |> walk_children(initial_ctx)

    raw_rows
    |> assign_positions()
    |> build_row_fields(law_name, mode)
    |> detect_and_qualify_parallels()
    |> disambiguate_section_ids()
  end

  # ── XML Parsing ──────────────────────────────────────────────────

  defp parse_xml(xml) do
    SweetXml.parse(xml, quiet: true)
  end

  defp extract_root_extent(xml) do
    xml
    |> parse_xml()
    |> xpath(~x"/*/@RestrictExtent"so)
    |> case do
      nil -> nil
      "" -> nil
      val -> Transforms.normalize_xml_extent(to_string(val))
    end
  end

  # ── Recursive Walker ─────────────────────────────────────────────

  defp walk_children(node, ctx) do
    node
    |> xpath(~x"./*"l)
    |> Enum.flat_map(&walk_element(&1, ctx))
  end

  defp walk_element(node, ctx) do
    name = element_name(node)
    extent = element_extent(node) || ctx.default_extent

    cond do
      name in @skip_elements ->
        # Amendment/extract text embeds P1/P2/P3 from OTHER laws — skip entirely
        []

      name in @container_elements ->
        walk_children(node, ctx)

      name == "Part" ->
        part_num = extract_number(node, "Part")
        new_ctx = %{ctx | part: part_num, chapter: nil, heading_group: nil}
        row = emit_row("Part", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "Chapter" ->
        chapter_num = extract_number(node, "Chapter")
        new_ctx = %{ctx | chapter: chapter_num, heading_group: nil}
        row = emit_row("Chapter", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "Pblock" ->
        heading_text = extract_title(node)
        # Pblock heading_group gets the provision number of its first P1 child
        first_p1_num = extract_first_p1_number(node)
        new_ctx = %{ctx | heading_group: first_p1_num}
        row = emit_heading_row(new_ctx, node, extent, heading_text)
        [row | walk_children(node, new_ctx)]

      name == "P1" ->
        provision = extract_pnumber(node)
        new_ctx = %{ctx | provision: provision, sub: nil, paragraph: nil, sub_paragraph: nil}
        row = emit_row("P1", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "P2" ->
        sub = extract_pnumber(node)
        new_ctx = %{ctx | sub: sub, paragraph: nil, sub_paragraph: nil}
        row = emit_row("P2", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "P3" ->
        paragraph = extract_pnumber(node)
        new_ctx = %{ctx | paragraph: paragraph, sub_paragraph: nil}
        row = emit_row("P3", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "P4" ->
        sub_paragraph = extract_pnumber(node)
        new_ctx = %{ctx | sub_paragraph: sub_paragraph}
        row = emit_row("P4", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "Schedule" ->
        schedule_num = extract_number(node, "Schedule")

        new_ctx = %{
          ctx
          | schedule: schedule_num,
            part: nil,
            chapter: nil,
            heading_group: nil,
            provision: nil,
            sub: nil,
            paragraph: nil,
            sub_paragraph: nil
        }

        row = emit_row("Schedule", new_ctx, node, extent)
        [row | walk_children(node, new_ctx)]

      name == "SignedSection" ->
        row = emit_row("SignedSection", ctx, node, extent)
        [row | walk_children(node, ctx)]

      name == "Tabular" ->
        [emit_row("Tabular", ctx, node, extent)]

      name == "Figure" ->
        [emit_row("Figure", ctx, node, extent)]

      true ->
        # Unknown element — recurse into children looking for known elements
        walk_children(node, ctx)
    end
  end

  # ── Row Emission ─────────────────────────────────────────────────

  defp emit_row(element, ctx, node, extent) do
    text = extract_element_text(node)
    commentary_counts = count_commentary_refs(node)

    %{
      element: element,
      part: ctx.part,
      chapter: ctx.chapter,
      heading_group: ctx.heading_group,
      schedule: ctx.schedule,
      provision: ctx.provision,
      sub: ctx.sub,
      paragraph: ctx.paragraph,
      sub_paragraph: ctx.sub_paragraph,
      extent_code: extent,
      text: text,
      amendment_count: Map.get(commentary_counts, :f),
      modification_count: Map.get(commentary_counts, :c),
      commencement_count: Map.get(commentary_counts, :i),
      extent_count: Map.get(commentary_counts, :e)
    }
  end

  defp emit_heading_row(ctx, node, extent, heading_text) do
    commentary_counts = count_commentary_refs(node)

    %{
      element: "Pblock",
      part: ctx.part,
      chapter: ctx.chapter,
      heading_group: ctx.heading_group,
      schedule: ctx.schedule,
      provision: nil,
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: extent,
      text: heading_text,
      amendment_count: Map.get(commentary_counts, :f),
      modification_count: Map.get(commentary_counts, :c),
      commencement_count: Map.get(commentary_counts, :i),
      extent_count: Map.get(commentary_counts, :e)
    }
  end

  # ── Element Extraction Helpers ───────────────────────────────────

  defp element_name(node) do
    xpath(node, ~x"name(.)"s)
  end

  defp element_extent(node) do
    case xpath(node, ~x"./@RestrictExtent"so) do
      nil -> nil
      "" -> nil
      val -> Transforms.normalize_xml_extent(to_string(val))
    end
  end

  defp extract_pnumber(node) do
    # Use //text() to reach through nested Addition/Repeal/Substitution wrappers
    case xpath(node, ~x"./Pnumber//text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join("")
        |> String.trim()
        |> case do
          "" -> nil
          v -> v
        end
    end
  end

  defp extract_number(node, prefix) do
    raw =
      case xpath(node, ~x"./Number//text()"ls) do
        nil -> []
        texts -> texts
      end
      |> Enum.map(&to_string/1)
      |> Enum.join("")
      |> String.trim()

    # Strip the prefix word: "Part I" → "I", "SCHEDULE 1" → "1"
    raw
    |> String.replace(~r/^(?:#{prefix}|#{String.upcase(prefix)})\s+/i, "")
    |> String.replace(~r/^\s*<[^>]+>\s*/, "")
    |> String.trim()
    |> case do
      "" -> nil
      v -> v
    end
  end

  defp extract_title(node) do
    case xpath(node, ~x"./Title//text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join(" ")
        |> String.trim()
        |> case do
          "" -> nil
          v -> v
        end
    end
  end

  defp extract_first_p1_number(node) do
    case xpath(node, ~x".//P1[1]/Pnumber//text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join("")
        |> String.trim()
        |> case do
          "" -> nil
          v -> v
        end
    end
  end

  defp extract_element_text(node) do
    texts =
      (safe_xpath_texts(node, ~x".//Para//text()"ls) ++
         safe_xpath_texts(node, ~x".//Text//text()"ls))
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
      |> Enum.join(" ")

    texts
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> nil
      t -> t
    end
  end

  defp safe_xpath_texts(node, path) do
    case xpath(node, path) do
      nil -> []
      texts when is_list(texts) -> Enum.map(texts, &to_string/1)
      text -> [to_string(text)]
    end
  end

  # ── Commentary Counting ──────────────────────────────────────────

  defp count_commentary_refs(node) do
    refs =
      case xpath(node, ~x".//CommentaryRef/@Ref"ls) do
        nil -> []
        list -> Enum.map(list, &to_string/1)
      end

    %{
      f: count_prefix(refs, "F") |> nil_if_zero(),
      c: count_prefix(refs, "C") |> nil_if_zero(),
      i: count_prefix(refs, "I") |> nil_if_zero(),
      e: count_prefix(refs, "E") |> nil_if_zero()
    }
  end

  defp count_prefix(refs, prefix) do
    # Match refs like "c7806021" (starts with lowercase letter) — these are commentary IDs, not codes
    # Match refs like "F3", "C1", "I2", "E5" — uppercase letter followed by digit(s)
    Enum.count(refs, fn ref ->
      String.match?(ref, ~r/^#{prefix}\d/)
    end)
  end

  defp nil_if_zero(0), do: nil
  defp nil_if_zero(n), do: n

  # ── Position Assignment ──────────────────────────────────────────

  defp assign_positions(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, position} -> Map.put(row, :position, position) end)
  end

  # ── Field Building (citations, sort_keys, hierarchy, depth) ─────

  defp build_row_fields(rows, law_name, mode) do
    Enum.map(rows, fn row ->
      section_type = Transforms.xml_element_to_section_type(row.element, mode)
      class = if mode == :article, do: "Regulation", else: nil

      # For P3/P4 inside sections (not schedules), cite as section extension: s.1(1)(a)
      # For P3/P4 inside schedules (no provision), cite as schedule paragraph: sch.2.para.3
      citation_type = citation_type_for(section_type, row, mode)

      citation =
        Transforms.build_citation(citation_type,
          provision: row.provision,
          sub: row.sub,
          paragraph: row.paragraph,
          sub_paragraph: row.sub_paragraph,
          schedule: row.schedule,
          heading_group: row.heading_group,
          part: row.part,
          chapter: row.chapter,
          position: row.position,
          class: class
        )

      sort_key =
        Transforms.build_sort_key(section_type,
          provision: row.provision,
          heading_group: row.heading_group,
          paragraph: row.paragraph,
          extent: nil
        )

      hierarchy_path =
        Transforms.build_hierarchy_path(
          schedule: row.schedule,
          part: row.part,
          chapter: row.chapter,
          heading_group: row.heading_group,
          provision: row.provision,
          sub: row.sub,
          paragraph: row.paragraph
        )

      depth =
        Transforms.calculate_depth(
          schedule: row.schedule,
          part: row.part,
          chapter: row.chapter,
          heading_group: row.heading_group,
          provision: row.provision,
          sub: row.sub,
          paragraph: row.paragraph
        )

      row
      |> Map.put(:law_name, law_name)
      |> Map.put(:section_type, section_type)
      |> Map.put(:section_id, "#{law_name}:#{citation}")
      |> Map.put(:citation, citation)
      |> Map.put(:sort_key, sort_key)
      |> Map.put(:hierarchy_path, hierarchy_path)
      |> Map.put(:depth, depth)
    end)
  end

  # P3/P4 inside body sections cite as section extensions: s.1(1)(a), s.1(1)(a)(i)
  # P3/P4 inside schedules (no provision) cite as schedule paragraphs: sch.2.para.3
  defp citation_type_for("paragraph", %{provision: prov}, mode) when not is_nil(prov) do
    if mode == :article, do: "article", else: "section"
  end

  defp citation_type_for("sub_paragraph", %{provision: prov}, mode) when not is_nil(prov) do
    if mode == :article, do: "article", else: "section"
  end

  defp citation_type_for(section_type, _row, _mode), do: section_type

  # ── Parallel Provision Detection & Qualification ─────────────────

  defp detect_and_qualify_parallels(rows) do
    provision_extent_pairs =
      rows
      |> Enum.filter(fn r -> r.section_type in ~w(section sub_section article sub_article) end)
      |> Enum.map(fn r -> {r.provision, r.extent_code} end)

    parallel_set = Transforms.detect_parallel_provisions(provision_extent_pairs)

    if MapSet.size(parallel_set) == 0 do
      rows
    else
      Enum.map(rows, fn row ->
        if row.provision && MapSet.member?(parallel_set, row.provision) && row.extent_code do
          qualifier = "[#{row.extent_code}]"
          new_id = "#{row.section_id}#{qualifier}"
          new_sort_key = String.replace(row.sort_key, ~r/~.*$/, "~#{row.extent_code}")
          %{row | section_id: new_id, sort_key: new_sort_key}
        else
          row
        end
      end)
    end
  end

  # ── Section ID Disambiguation ────────────────────────────────────

  defp disambiguate_section_ids(rows) do
    # Find duplicate section_ids
    id_counts =
      rows
      |> Enum.map(& &1.section_id)
      |> Enum.frequencies()

    duplicated_ids =
      id_counts
      |> Enum.filter(fn {_id, count} -> count > 1 end)
      |> Enum.map(fn {id, _} -> id end)
      |> MapSet.new()

    if MapSet.size(duplicated_ids) == 0 do
      rows
    else
      # Track occurrence count per duplicated ID
      {rows, _counters} =
        Enum.map_reduce(rows, %{}, fn row, counters ->
          if MapSet.member?(duplicated_ids, row.section_id) do
            count = Map.get(counters, row.section_id, 0) + 1
            new_id = "#{row.section_id}##{row.position}"
            {%{row | section_id: new_id}, Map.put(counters, row.section_id, count)}
          else
            {row, counters}
          end
        end)

      rows
    end
  end

  # ── Provision Mode ───────────────────────────────────────────────

  defp provision_mode(type_code) when type_code in @act_type_codes, do: :section
  defp provision_mode(_type_code), do: :article

  # ── Public Helpers ───────────────────────────────────────────────

  @doc """
  Convert parsed rows to maps suitable for `Repo.insert_all("lat", rows)`.

  Strips internal fields (`:element`, `:citation`) and adds timestamps.

  ## Parameters

    - `rows` — list of parsed row maps from `parse/2`
    - `law_id` — UUID of the uk_lrt record (required FK)
  """
  @spec to_insert_maps([map()], String.t()) :: [map()]
  def to_insert_maps(rows, law_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, law_id_binary} = Ecto.UUID.dump(law_id)

    Enum.map(rows, fn row ->
      %{
        section_id: row.section_id,
        law_name: row.law_name,
        law_id: law_id_binary,
        section_type: row.section_type,
        part: row.part,
        chapter: row.chapter,
        heading_group: row.heading_group,
        schedule: row.schedule,
        provision: row.provision,
        paragraph: row.paragraph,
        sub_paragraph: row.sub_paragraph,
        extent_code: row.extent_code,
        sort_key: row.sort_key,
        position: row.position,
        depth: row.depth,
        hierarchy_path: row.hierarchy_path,
        text: row.text || "",
        language: "en",
        amendment_count: row.amendment_count,
        modification_count: row.modification_count,
        commencement_count: row.commencement_count,
        extent_count: row.extent_count,
        editorial_count: nil,
        created_at: now,
        updated_at: now
      }
    end)
  end
end

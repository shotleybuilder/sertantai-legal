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

  alias SertantaiLegal.Legal.Lat.SortKeyRewrite
  alias SertantaiLegal.Legal.Lat.Transforms

  alias SertantaiLegal.Scraper.{
    EffectIndex,
    LatSegments,
    LatStatus,
    LatTerritory,
    Territory
  }

  # Acts (sections); everything else is an instrument (regulations/articles).
  # asc (Acts of Senedd Cymru), mwa (Welsh Measures) and the local / church /
  # pre-Union Acts number sections too (LH-02).
  @act_type_codes ~w(ukpga anaw asp asc mwa nia apni aep ukla ukcm aosp aip apgb gbla)
  @container_elements ~w(Legislation Primary Secondary Body Schedules ScheduleBody
                         P1para P2para P3para P4para P1group P2group P3group
                         ScheduleBody FragmentBody
                         EURetained EUBody)

  # Elements to skip entirely — contain embedded P1/P2/P3 from OTHER laws or
  # alternative territorial versions that duplicate the primary text
  @skip_elements ~w(BlockAmendment AppendText BlockExtract
                    Versions Version Commentaries Commentary Contents)

  # Elements emitted as rows of their own: structural text stops at them.
  @row_elements ~w(Part EUTitle Chapter EUChapter Pblock P1 P2 P3 P4 Schedule
                   SignedSection Tabular Figure)

  # Provision rows that can take sibling content that follows them (#174)
  @provision_rows ~w(P1 P2 P3 P4)

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
    doc = parse_xml(xml)

    initial_ctx = %{
      part: nil,
      chapter: nil,
      heading_group: nil,
      group_title: nil,
      group_refs: [],
      schedule: nil,
      provision: nil,
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      p2_is_wrapper: false,
      trailing: [],
      default_extent: extract_root_extent(xml),
      prospective: false,
      mode: mode,
      ref_type_lookup: build_ref_type_lookup(doc),
      versions: build_versions_lookup(doc),
      from_version: false,
      version_extent: nil,
      # LR-03: the law's effects (EffectIndex; empty = markup only) and the
      # whole-provision changes (rule 3) inherited by descendant rows
      effects: effect_index(Map.get(context, :effects), doc, law_extent(xml, context)),
      law_extent: law_extent(xml, context),
      provision_changes: []
    }

    raw_rows = walk_children(doc, initial_ctx)

    raw_rows
    |> drop_repeated_versions()
    |> assign_positions()
    |> build_row_fields(law_name, mode, context.type_code)
    |> mark_repealed_provisions(mode)
    |> assign_status()
    |> detect_and_qualify_parallels()
    |> disambiguate_section_ids()
    # Keys must ascend with document order even where the numbering or the
    # source markup defeats the hierarchical encoding.
    |> SortKeyRewrite.monotonic()
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
      val -> Territory.normalize(to_string(val))
    end
  end

  # Build a lookup from CommentaryRef ID → type letter (F/C/I/E) by parsing
  # the <Commentaries> block in the same XML document. This handles hash-style
  # IDs (c7375871, key-abc123) where the type can't be inferred from the ID.
  defp build_ref_type_lookup(doc) do
    case xpath(doc, ~x"//Commentary"l) do
      nil ->
        %{}

      commentaries ->
        Map.new(commentaries, fn c ->
          id = xpath(c, ~x"./@id"s) |> to_string()
          type = xpath(c, ~x"./@Type"s) |> to_string() |> String.upcase()
          {id, type}
        end)
    end
  end

  # Version id → Version element, for provision versions only (figures and
  # images stay out, #177).
  @version_content ~w(P1group P1 P2group P2 P3 P4 Pblock Part Chapter Schedule)

  defp build_versions_lookup(doc) do
    for version <- xpath(doc, ~x"//Versions/Version"l),
        first = xpath(version, ~x"./*[1]"o),
        first != nil and element_name(first) in @version_content,
        into: %{},
        do: {to_string(xpath(version, ~x"./@id"s)), version}
  end

  # ── Recursive Walker ─────────────────────────────────────────────

  # #174: content that follows an open child provision as a sibling (a
  # definition list, a BlockText of closing words) is that child's — it's
  # passed down as ctx.trailing and appended to the child's row text.
  defp walk_children(node, ctx) do
    ctx = %{ctx | trailing: []}
    children = xpath(node, ~x"./*"l)

    children
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, i} ->
      trailing = trailing_content(child, Enum.drop(children, i + 1))
      walk_element(child, %{ctx | trailing: trailing})
    end)
  end

  # The sibling content an open child provision takes: the content elements
  # after it, up to the next row element; [] unless the child's lead-in is open.
  defp trailing_content(child, rest) do
    if element_name(child) in @provision_rows do
      content = Enum.take_while(rest, &(element_name(&1) not in @row_elements))
      if content != [] and open_lead_in?(child), do: content, else: []
    else
      []
    end
  end

  # A provision's lead-in — its first text block — ends in a dash or colon:
  # what follows continues it (its own list may sit in between, as in
  # PUWER 1998 reg.2(1) "…otherwise requires— [definitions]").
  defp open_lead_in?(node) do
    case node
         |> text_blocks(:structural)
         |> Enum.find(&(is_list(&1) and not LatSegments.blank?(&1))) do
      nil -> false
      lead -> lead |> LatSegments.plain() |> String.match?(~r/[—–:-]\s*$/u)
    end
  end

  # An element with AltVersionRefs is followed by its territorial
  # alternatives (Versions/Version, e.g. the Scottish text of a regulation),
  # walked in the same context; parallel detection then qualifies both ids
  # with their extents. Each version is used once.
  defp walk_element(node, ctx) do
    rows = walk_own(node, ctx)

    case alt_versions(node, ctx.versions) do
      [] ->
        rows

      versions ->
        ctx = %{ctx | versions: Map.drop(ctx.versions, Enum.map(versions, &elem(&1, 0)))}
        ctx = %{ctx | from_version: true}

        rows ++
          Enum.flat_map(versions, fn {_id, version} ->
            walk_children(version, %{ctx | version_extent: version_extent(version)})
          end)
    end
  end

  # A version's extent: its root element's (e.g. the P1group of the Welsh
  # version). Inner extents that contradict it don't label its rows: uksi
  # 2010/2214's Welsh reg.36 holds a P1 marked E (LH-02).
  defp version_extent(version) do
    case xpath(version, ~x"./*[1]"o) do
      nil -> nil
      root -> element_extent(root)
    end
  end

  defp version_governed(extent, nil), do: extent
  defp version_governed(nil, version), do: version

  defp version_governed(extent, version),
    do: if(Territory.covers?(version, extent), do: extent, else: version)

  defp alt_versions(_node, versions) when map_size(versions) == 0, do: []

  defp alt_versions(node, versions) do
    node
    |> xpath(~x"./@AltVersionRefs"s)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(fn id ->
      case Map.fetch(versions, id) do
        {:ok, version} -> [{id, version}]
        :error -> []
      end
    end)
  end

  defp walk_own(node, ctx) do
    name = element_name(node)
    extent = version_governed(element_extent(node) || ctx.default_extent, ctx.version_extent)
    # Children inherit this element's effective extent (a Part's RestrictExtent
    # covers its sections), not the document root's. Status="Prospective" (on
    # P1group / Pblock wrappers) is inherited the same way (#167).
    ctx = %{ctx | default_extent: extent, prospective: ctx.prospective or prospective?(node)}
    ctx = with_whole_provision_effects(ctx, node)

    cond do
      name in @skip_elements ->
        # Amendment/extract text embeds P1/P2/P3 from OTHER laws — skip entirely
        []

      name in ~w(P1group P2group P3group) ->
        # The group's Title is the heading of the P1 / P2 / P3 it wraps
        # and the notes its Title cites are about them
        walk_children(node, %{
          ctx
          | group_title: heading_title(node),
            group_refs: placement_refs(node, "./Title")
        })

      name in @container_elements ->
        walk_children(node, ctx)

      name == "Part" ->
        part_num = extract_number(node, "Part")
        new_ctx = %{ctx | part: part_num, chapter: nil, heading_group: nil}

        row =
          "Part"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> number_titled(node, "Part")

        [row | walk_children(node, new_ctx)]

      name == "EUTitle" ->
        # EU Title (e.g. "TITLE I: GENERAL ISSUES") — maps to Part in the hierarchy
        part_num = extract_number(node, "Title")
        new_ctx = %{ctx | part: part_num, chapter: nil, heading_group: nil}

        row =
          "Part"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> number_titled(node, "Title")

        [row | walk_children(node, new_ctx)]

      name == "Chapter" ->
        chapter_num = extract_number(node, "Chapter")
        new_ctx = %{ctx | chapter: chapter_num, heading_group: nil}

        row =
          "Chapter"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> number_titled(node, "Chapter")

        [row | walk_children(node, new_ctx)]

      name == "EUChapter" ->
        # EU Chapter — same semantics as UK Chapter
        chapter_num = extract_number(node, "Chapter")
        new_ctx = %{ctx | chapter: chapter_num, heading_group: nil}

        row =
          "Chapter"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> number_titled(node, "Chapter")

        [row | walk_children(node, new_ctx)]

      name == "Pblock" ->
        heading_text = extract_title(node)
        # Pblock heading_group gets the provision number of its first P1 child
        first_p1_num = extract_first_p1_number(node)
        new_ctx = %{ctx | heading_group: first_p1_num}
        row = new_ctx |> emit_heading_row(node, extent, heading_text) |> titled(node)
        [row | walk_children(node, new_ctx)]

      name == "P1" ->
        provision = extract_pnumber(node)
        wrapper = p2_is_wrapper?(node, provision)

        new_ctx = %{
          ctx
          | provision: provision,
            sub: nil,
            paragraph: nil,
            sub_paragraph: nil,
            p2_is_wrapper: wrapper,
            # consumed here: provisions nested in this P1 are not the group's
            group_title: nil,
            group_refs: []
        }

        row = emit_structural_row("P1", new_ctx, node, extent)

        row = %{
          row
          | title: ctx.group_title,
            commentary_refs: Enum.uniq(ctx.group_refs ++ row.commentary_refs)
        }

        [row | walk_children(node, new_ctx)]

      name == "P2" ->
        sub = extract_pnumber(node)
        # If P2 is a structural wrapper (single P2 with same number as P1),
        # nil out sub to avoid doubled citations like reg.30(30)
        # and skip emitting a row (the wrapper has no distinct identity)
        if ctx.p2_is_wrapper and sub == ctx.provision do
          new_ctx = %{ctx | sub: nil, paragraph: nil, sub_paragraph: nil}
          walk_children(node, new_ctx)
        else
          new_ctx = %{ctx | sub: sub, paragraph: nil, sub_paragraph: nil}
          row = "P2" |> emit_structural_row(ungrouped(new_ctx), node, extent) |> grouped(ctx)
          [row | walk_children(node, ungrouped(new_ctx))]
        end

      name == "P3" ->
        paragraph = extract_pnumber(node)
        new_ctx = %{ctx | paragraph: paragraph, sub_paragraph: nil}
        row = "P3" |> emit_structural_row(ungrouped(new_ctx), node, extent) |> grouped(ctx)
        [row | walk_children(node, ungrouped(new_ctx))]

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

        row = "Schedule" |> emit_structural_row(new_ctx, node, extent) |> titled(node)
        [row | walk_children(node, new_ctx)]

      name == "SignedSection" ->
        row = emit_row("SignedSection", ctx, node, extent)
        [row | walk_children(node, ctx)]

      name == "Tabular" ->
        ["Tabular" |> emit_row(ctx, node, extent) |> titled(node)]

      name == "Figure" ->
        [emit_row("Figure", ctx, node, extent)]

      true ->
        # Unknown element — recurse into children looking for known elements
        walk_children(node, ctx)
    end
  end

  # ── Row Emission ─────────────────────────────────────────────────

  defp emit_row(element, ctx, node, extent) do
    {repealed, whole} = excluded_extent(node, extent || ctx.law_extent, ctx)

    segments =
      node
      |> extract_element_text()
      |> with_trailing(ctx.trailing, node)
      |> row_segments(ctx, extent || ctx.law_extent)

    text = LatTerritory.render(segments, extent || ctx.law_extent, repealed)

    {commentary_counts, commentary_refs} = collect_commentary_refs(node, ctx.ref_type_lookup)

    %{
      element: element,
      xml_id: extract_xml_id(node),
      part: ctx.part,
      chapter: ctx.chapter,
      heading_group: ctx.heading_group,
      schedule: ctx.schedule,
      provision: ctx.provision,
      sub: ctx.sub,
      paragraph: ctx.paragraph,
      sub_paragraph: ctx.sub_paragraph,
      extent_code: extent,
      prospective: ctx.prospective,
      text: text,
      title: nil,
      amendment_count: Map.get(commentary_counts, :f),
      modification_count: Map.get(commentary_counts, :c),
      commencement_count: Map.get(commentary_counts, :i),
      extent_count: Map.get(commentary_counts, :e),
      commentary_refs: commentary_refs,
      excluded_extent: repealed,
      territory_provenance:
        Enum.uniq(LatTerritory.provenance(segments) ++ LatTerritory.provenance(whole)),
      from_version: ctx.from_version
    }
  end

  defp emit_structural_row(element, ctx, node, extent) do
    {repealed, whole} = excluded_extent(node, extent || ctx.law_extent, ctx)

    segments =
      node
      |> extract_structural_text()
      |> with_trailing(ctx.trailing, node)
      |> row_segments(ctx, extent || ctx.law_extent)

    text = LatTerritory.render(segments, extent || ctx.law_extent, repealed)

    {commentary_counts, commentary_refs} = collect_commentary_refs(node, ctx.ref_type_lookup)

    %{
      element: element,
      xml_id: extract_xml_id(node),
      part: ctx.part,
      chapter: ctx.chapter,
      heading_group: ctx.heading_group,
      schedule: ctx.schedule,
      provision: ctx.provision,
      sub: ctx.sub,
      paragraph: ctx.paragraph,
      sub_paragraph: ctx.sub_paragraph,
      extent_code: extent,
      prospective: ctx.prospective,
      text: text,
      title: nil,
      amendment_count: Map.get(commentary_counts, :f),
      modification_count: Map.get(commentary_counts, :c),
      commencement_count: Map.get(commentary_counts, :i),
      extent_count: Map.get(commentary_counts, :e),
      commentary_refs: commentary_refs,
      excluded_extent: repealed,
      territory_provenance:
        Enum.uniq(LatTerritory.provenance(segments) ++ LatTerritory.provenance(whole)),
      from_version: ctx.from_version
    }
  end

  defp emit_heading_row(ctx, node, extent, heading_text) do
    {commentary_counts, commentary_refs} = collect_commentary_refs(node, ctx.ref_type_lookup)

    %{
      element: "Pblock",
      xml_id: extract_xml_id(node),
      part: ctx.part,
      chapter: ctx.chapter,
      heading_group: ctx.heading_group,
      schedule: ctx.schedule,
      provision: nil,
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: extent,
      prospective: ctx.prospective,
      text: heading_text,
      title: nil,
      amendment_count: Map.get(commentary_counts, :f),
      modification_count: Map.get(commentary_counts, :c),
      commencement_count: Map.get(commentary_counts, :i),
      extent_count: Map.get(commentary_counts, :e),
      commentary_refs: commentary_refs,
      excluded_extent: node |> excluded_extent(extent || ctx.law_extent, ctx) |> elem(0),
      territory_provenance:
        node
        |> excluded_extent(extent || ctx.law_extent, ctx)
        |> elem(1)
        |> LatTerritory.provenance(),
      from_version: ctx.from_version
    }
  end

  # ── Whole-row territory ──────────────────────────────────────────

  # excluded_extent (LatTerritory.excluded/3) from the same segments the
  # text is built from: the row's own text decides (its children are rows of
  # their own); the whole subtree only when the row has no text of its own.
  # Numbers and titles never count (not text).
  defp excluded_extent(node, row_extent, ctx) do
    own = node |> text_blocks(:structural) |> join_blocks()

    segments =
      if(LatSegments.blank?(own), do: node |> text_blocks(:leaf) |> join_blocks(), else: own)
      |> row_segments(ctx, row_extent)

    {LatTerritory.excluded(segments, row_extent), segments}
  end

  # The law's effects (`context.effects`: a list of ChangesFeed effects, or an
  # EffectIndex), indexed against this document's ids in order (ranges).
  defp effect_index(nil, _doc, _law_extent), do: EffectIndex.empty()
  defp effect_index(%{by_id: _, by_ref: _} = index, _doc, _law_extent), do: index

  defp effect_index(effects, doc, law_extent) when is_list(effects),
    do: EffectIndex.new(effects, doc |> xpath(~x"//@id"ls) |> Enum.map(&to_string/1), law_extent)

  # The law's own extent for territory (not stored on rows): the document's
  # RestrictExtent, else its type's — a devolved instrument extends only
  # there (LR-03: an SSI amended by an SSI is not "narrower than the UK").
  @type_extent %{
    "ssi" => "S",
    "asp" => "S",
    "aosp" => "S",
    "nisr" => "NI",
    "nisi" => "NI",
    "nia" => "NI",
    "apni" => "NI",
    "mnia" => "NI",
    "wsi" => "E+W",
    "anaw" => "E+W",
    "asc" => "E+W",
    "mwa" => "E+W"
  }

  defp law_extent(xml, context),
    do: extract_root_extent(xml) || Map.get(@type_extent, Map.get(context, :type_code))

  # A row's segments with territory resolved from the effects layer
  # (LatTerritory.resolve/2), inside any whole-provision changes it inherits.
  defp row_segments(segments, ctx, extent) do
    ctx.provision_changes
    |> Enum.reduce(segments, fn change, inner -> [{:words, change, inner}] end)
    |> LatTerritory.resolve(ctx.effects, extent)
  end

  # Rule 3 (LR-03): an applied effect repealing or inserting this whole
  # provision, when the provision carries no change markup at all (modern or
  # legacy), is an outermost change on it and its descendants
  # (1974/40 s.101 "repealed (S.)": no Repeal element).
  defp with_whole_provision_effects(ctx, node) do
    case EffectIndex.whole_provision(ctx.effects, extract_xml_id(node)) do
      [] ->
        ctx

      effects ->
        if change_markup?(node) do
          ctx
        else
          held = MapSet.new(ctx.provision_changes, & &1.effect_id)

          changes =
            for e <- effects, not MapSet.member?(held, e.effect_id) do
              kind = if e.type in ~w(inserted added), do: :ins, else: :keep
              %LatTerritory.Change{kind: kind, effect_id: e.effect_id}
            end

          %{ctx | provision_changes: ctx.provision_changes ++ changes}
        end
    end
  end

  defp change_markup?(node),
    do: xpath(node, ~x"(.//Addition | .//Substitution | .//Repeal)[1]"o) != nil

  # ── Element Extraction Helpers ───────────────────────────────────

  defp element_name(node) do
    xpath(node, ~x"name(.)"s)
  end

  defp prospective?(node), do: xpath(node, ~x"./@Status"so) |> to_string() == "Prospective"

  defp element_extent(node) do
    case xpath(node, ~x"./@RestrictExtent"so) do
      nil -> nil
      "" -> nil
      val -> Territory.normalize(to_string(val))
    end
  end

  # Extract the XML id attribute from a node (e.g. id="section-1-1-a").
  # Used as a stable join key for section_id migration — these are assigned by
  # legislation.gov.uk and don't change regardless of how we parse P2 wrappers.
  defp extract_xml_id(node) do
    case xpath(node, ~x"./@id"s) do
      nil -> nil
      "" -> nil
      id -> to_string(id)
    end
  end

  # Detect if a P1 node's P2 children are structural wrappers.
  # True when there is exactly one P2 child and its Pnumber matches the P1 provision.
  # In this case the P2 is a container, not a true subsection.
  defp p2_is_wrapper?(p1_node, provision) do
    p2_numbers =
      p1_node
      |> xpath(~x".//P2"l)
      |> Enum.map(&extract_pnumber/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    p2_numbers == [provision]
  end

  defp extract_pnumber(node) do
    # descendant::text() reaches through nested Addition/Repeal/Substitution
    # wrappers in document order (xmerl's //text() puts direct text first)
    case xpath(node, ~x"./Pnumber/descendant::text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join("")
        |> String.trim()
        # "6." (EU paragraph numbering) is number 6: no "(6.)" in ids
        |> String.trim_trailing(".")
        |> case do
          "" -> nil
          v -> v
        end
    end
  end

  defp extract_number(node, prefix), do: node |> number_parts(prefix) |> elem(0)

  # A Number's number and any heading joined to it by a dash: "Part III.—
  # Administration of Law" → {"III", "Administration of Law"}; "PART 3 —" →
  # {"3", nil} (LH-06).
  defp number_parts(node, prefix) do
    raw =
      node
      |> xpath(~x"./Number/descendant::text()"ls)
      |> Enum.map_join("", &to_string/1)
      |> String.trim()
      # Strip the prefix word: "Part I" → "I", "SCHEDULE 1" → "1"
      |> String.replace(~r/^(?:#{prefix}|#{String.upcase(prefix)})\s+/i, "")
      |> String.replace(~r/^\s*<[^>]+>\s*/, "")
      |> String.trim()

    case String.split(raw, ~r/\.?\s*[—–]\s*/u, parts: 2) do
      [number, heading] -> {blank_to_nil(String.trim(number)), blank_to_nil(String.trim(heading))}
      [number] -> {blank_to_nil(number), nil}
    end
  end

  # A structural row with no Title takes the heading its Number carries.
  defp number_titled(%{title: nil} = row, node, prefix) do
    case number_parts(node, prefix) do
      {_, nil} ->
        row

      {_, heading} ->
        %{row | title: heading, text: if(row.text in [nil, ""], do: heading, else: row.text)}
    end
  end

  defp number_titled(row, _node, _prefix), do: row

  defp extract_title(node) do
    # a Schedule's heading is in its TitleBlock (#165)
    case xpath(node, ~x"./Title"l) do
      [] -> node |> xpath(~x"./TitleBlock/Title"l) |> titles_text() |> blank_to_nil()
      titles -> titles |> titles_text() |> blank_to_nil()
    end
  end

  # A heading's text in document order (xmerl's //text() puts direct text
  # before descendants' text), inline markup joined without spaces
  # ("Re<Emphasis>gulators</Emphasis>", "CO<Sub>2</Sub>"), whitespace collapsed.
  # A retained territorial Repeal stays apart from the replacement that
  # follows it ("Powers of Entry Enforcement"; LAT parser coverage II item 3
  # renders those properly).
  # Some headings are split across Title elements ("International Oil
  # Pollution" + "Compensation Fund"): joined with a space.
  defp titles_text(titles), do: titles |> Enum.map_join(" ", &heading_text/1) |> String.trim()

  defp heading_text(element) do
    element |> inline_text() |> String.replace(~r/\s+/u, " ") |> String.trim()
  end

  defp inline_text(element) do
    {parts, _} =
      element
      |> elem(8)
      |> Enum.map_reduce(nil, fn child, prev ->
        case elem(child, 0) do
          :xmlText ->
            {to_string(elem(child, 4)), nil}

          :xmlElement ->
            sep = if prev && territorial_pair?(prev, child), do: " ", else: ""
            {sep <> inline_text(child), child}

          _ ->
            {"", prev}
        end
      end)

    Enum.join(parts)
  end

  # <Repeal RetainText="true" SubstitutionRef="X">old</Repeal><Addition ChangeId="X">new</Addition>:
  # the old words kept for another territory, then their replacement.
  defp territorial_pair?(prev, next) do
    elem(prev, 1) == :Repeal and xpath(prev, ~x"./@RetainText"s) == "true" and
      xpath(prev, ~x"./@SubstitutionRef"s) not in ["", nil] and
      xpath(prev, ~x"./@SubstitutionRef"s) == xpath(next, ~x"./@ChangeId"s)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(text), do: text

  defp titled(row, node), do: %{row | title: heading_title(node)}

  # A P2group/P3group's Title and note refs on the P2/P3 row it wraps
  # (consumed there, like a P1group's on its P1).
  defp grouped(row, %{group_title: nil, group_refs: []}), do: row

  defp grouped(row, ctx) do
    %{
      row
      | title: row.title || ctx.group_title,
        commentary_refs: Enum.uniq(ctx.group_refs ++ row.commentary_refs)
    }
  end

  defp ungrouped(ctx), do: %{ctx | group_title: nil, group_refs: []}

  # The `title` column: a heading as written (Title, or a Schedule's
  # TitleBlock/Title), inline markup joined without spaces. Dots-only titles
  # (repealed headings) are nil. Row text keeps its own heading handling.
  @dots_title ~r/\A[\s.…]*\z/u

  defp heading_title(node) do
    title =
      case xpath(node, ~x"./Title"l) do
        [] -> node |> xpath(~x"./TitleBlock/Title"l) |> titles_text()
        titles -> titles_text(titles)
      end

    if Regex.match?(@dots_title, title), do: nil, else: title
  end

  defp extract_first_p1_number(node) do
    case xpath(node, ~x".//P1[1]/Pnumber/descendant::text()"ls) do
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

  # Leaf text: every Text in document order, each once, separated by a space
  # (inline fragments within one Text are joined without extra spaces —
  # they're split by markup like <Term>, <Addition>). Lists, nested lists and
  # text after a list keep their order (2026-10-07: the old Para-then-Text
  # build moved chapeaux to the end and repeated nested list items).
  defp extract_element_text(node) do
    node |> text_blocks(:leaf) |> join_blocks()
  end

  # Never text: numbers, titles (read by extract_title), reference markers.
  @no_text_elements ~w(Pnumber Number Title TitleBlock Reference CommentaryRef
                       FootnoteRef Footnotes Commentaries)

  # Text another law gets (BlockAmendment, AppendText) or quoted material
  # (BlockExtract): one block, «…», with its provision numbers and titles —
  # the amending text is used to update records legislation.gov.uk applies
  # late (Jason, 2026-10-08). Its provisions are never rows of this law.
  @quoted_elements ~w(BlockAmendment AppendText BlockExtract)

  defp quoted_text(element) do
    case element |> quoted_parts() |> LatSegments.join(" ") do
      [] -> []
      segments -> LatSegments.mark("«") ++ LatSegments.trim(segments) ++ LatSegments.mark("»")
    end
  end

  defp quoted_parts(element) do
    parent = elem(element, 1)

    element
    |> elem(8)
    |> Enum.flat_map(fn child ->
      case elem(child, 0) do
        :xmlElement -> quoted_child(child, parent)
        _ -> []
      end
    end)
  end

  defp quoted_child(child, parent) do
    case to_string(elem(child, 1)) do
      "Pnumber" ->
        # numbers and titles show but never count as the row's own words
        [
          child
          |> inline_plain()
          |> quoted_number(parent)
          |> LatSegments.text()
          |> LatSegments.aside()
        ]

      "Title" ->
        [child |> extract_inline_text() |> LatSegments.aside()]

      "Text" ->
        [extract_inline_text(child)]

      # "Schedule 4A", "Part 1", "Section 25"
      name when name in ~w(Number Reference) ->
        [child |> extract_inline_text() |> LatSegments.aside()]

      name when name in ~w(OrderedList UnorderedList) ->
        child |> list_blocks(:leaf) |> Enum.filter(&is_list/1)

      "Tabular" ->
        child |> elements_named("table") |> Enum.map(&table_text/1)

      name when name in ~w(CommentaryRef FootnoteRef Commentaries Footnotes) ->
        []

      _ ->
        quoted_parts(child)
    end
  end

  # An (XHTML) table's cells: " | " between cells, "; " between rows.
  # Elements may be prefixed (xhtml:tr): matched by local name. A cell's
  # block content (paragraphs, lists) reads as text blocks.
  defp table_text(table) do
    table
    |> elements_named("tr")
    |> Enum.map(fn tr ->
      tr
      |> elem(8)
      |> Enum.filter(&(elem(&1, 0) == :xmlElement and local_name(elem(&1, 1)) in ~w(td th)))
      |> Enum.map(&cell_text/1)
      # empty cells keep their place
      |> Enum.intersperse(LatSegments.mark(" | "))
      |> Enum.concat()
    end)
    |> Enum.reject(&(&1 |> LatSegments.plain() |> String.replace(~r/[\s|]/u, "") == ""))
    |> LatSegments.join("; ")
  end

  defp cell_text(cell) do
    segments = cell |> text_blocks(:leaf) |> join_blocks()
    if LatSegments.blank?(segments), do: extract_inline_text(cell), else: segments
  end

  # Descendant elements with a local name, in document order.
  defp elements_named(element, local) do
    element
    |> elem(8)
    |> Enum.flat_map(fn
      child when elem(child, 0) == :xmlElement ->
        if local_name(elem(child, 1)) == local,
          do: [child],
          else: elements_named(child, local)

      _ ->
        []
    end)
  end

  # "xhtml:td" (element atom) or "{http://www.w3.org/1999/xhtml}td" (XPath
  # name()) → "td"
  defp local_name(name),
    do: name |> to_string() |> String.replace(~r/\A(\{[^}]*\}|[^:{]*:)/, "")

  # A list's items as text blocks, each led by its number: NumberOverride,
  # else counted from an OrderedList's Type and Decoration ("(a)", "(i)").
  defp list_blocks(list, mode) do
    list
    |> elem(8)
    |> Enum.filter(&(elem(&1, 0) == :xmlElement and local_name(elem(&1, 1)) == "ListItem"))
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, i} ->
      case {item_label(item, list, i), text_blocks(item, mode)} do
        {nil, blocks} ->
          blocks

        {label, [first | rest]} when is_list(first) ->
          [LatSegments.mark(label <> " ") ++ first | rest]

        {label, blocks} ->
          [LatSegments.mark(label) | blocks]
      end
    end)
  end

  defp item_label(item, list, i) do
    decoration = xpath(list, ~x"./@Decoration"s)

    case xpath(item, ~x"./@NumberOverride"s) do
      "" ->
        # number only what the source numbers: an OrderedList with a Type
        type = xpath(list, ~x"./@Type"s)

        if elem(list, 1) == :OrderedList and type != "",
          do: decorate(list_number(i, type), decoration)

      override ->
        decorate(override, decoration)
    end
  end

  defp decorate(n, "none"), do: n
  defp decorate(n, "period"), do: n <> "."
  defp decorate(n, "parenRight"), do: n <> ")"
  defp decorate(n, "brackets"), do: "[" <> n <> "]"
  defp decorate(n, _parens), do: "(" <> n <> ")"

  defp list_number(i, "alpha"), do: alpha(i)
  defp list_number(i, "alphaUpper"), do: String.upcase(alpha(i))
  defp list_number(i, "roman"), do: roman(i)
  defp list_number(i, "romanUpper"), do: String.upcase(roman(i))
  defp list_number(i, _arabic), do: Integer.to_string(i)

  defp alpha(i) when i <= 26, do: <<?a + i - 1>>
  defp alpha(i), do: alpha(div(i - 1, 26)) <> alpha(rem(i - 1, 26) + 1)

  @romans [{10, "x"}, {9, "ix"}, {5, "v"}, {4, "iv"}, {1, "i"}]
  defp roman(0), do: ""

  defp roman(i),
    do: @romans |> Enum.find(fn {v, _} -> v <= i end) |> then(fn {v, r} -> r <> roman(i - v) end)

  # A signature: name, job title, address lines, date (its text, else @Date),
  # as segments, so a change around them (a retained repeal) keeps its
  # territory.
  defp signee_text(signee) do
    parts =
      for path <- [
            ~x"./PersonName"l,
            ~x"./JobTitle"l,
            ~x"./Department"l,
            ~x"./Address/AddressLine"l
          ],
          el <- xpath(signee, path),
          do: extract_inline_text(el)

    date =
      case xpath(signee, ~x"./DateSigned"o) do
        nil ->
          []

        d ->
          case extract_inline_text(d) do
            # from the attribute: added by the parser, not the row's own words
            [] -> d |> xpath(~x"./@Date"s) |> LatSegments.mark()
            segments -> segments
          end
      end

    (parts ++ [date])
    |> Enum.map(fn part ->
      part
      |> LatSegments.trim()
      |> LatSegments.update_last_text(&String.trim_trailing(&1, ","))
      |> LatSegments.trim()
    end)
    |> Enum.reject(&LatSegments.blank?/1)
    |> join_signee()
  end

  # ", " between parts — except after "… of the" (a job title running into
  # its department: "A senior officer of the Department of …")
  defp join_signee([]), do: []

  defp join_signee([first | rest]) do
    Enum.reduce(rest, first, fn part, acc ->
      sep =
        if Regex.match?(~r/\b(of|the|for|and)\z/i, LatSegments.plain(acc)), do: " ", else: ", "

      acc ++ LatSegments.mark(sep) ++ part
    end)
  end

  defp quoted_number("", _parent), do: ""
  defp quoted_number(n, :P1), do: n <> "."
  defp quoted_number(n, _parent), do: "(" <> n <> ")"

  # A node's text blocks in document order: each Text's inline text, and in
  # :structural mode a :gap where a child provision (its own row) sits.
  # :structural skips other laws' text (amendment blocks); :leaf keeps it,
  # as leaf rows always have.
  defp text_blocks(node, mode) do
    {blocks, _} =
      node
      |> xpath(~x"./*"l)
      |> Enum.flat_map_reduce(false, fn child, after_open_child? ->
        name = element_name(child)

        cond do
          name in @no_text_elements ->
            {[], after_open_child?}

          # tables and figures are rows of their own, in either mode
          name in ~w(Tabular Figure) and mode == :leaf ->
            {[], after_open_child?}

          mode == :structural and name in @quoted_elements and after_open_child? ->
            {[], true}

          # text appended to the amended provision (the quote's closing ".")
          name == "AppendText" ->
            {[{:append, extract_inline_text(child)}], after_open_child?}

          name in @quoted_elements ->
            {[quoted_text(child)], after_open_child?}

          local_name(name) == "table" ->
            {[table_text(child)], after_open_child?}

          name == "Signee" ->
            {[signee_text(child)], after_open_child?}

          mode == :structural and name in @row_elements ->
            # content after an open child provision is the child's (#174)
            {[:gap], name in @provision_rows and open_lead_in?(child)}

          mode == :structural and name in @skip_elements ->
            {[], after_open_child?}

          mode == :structural and after_open_child? ->
            {[], true}

          name == "Text" ->
            {[extract_inline_text(child)], after_open_child?}

          # after the open-child skip above: a list following an open child is its (#174)
          name in ~w(OrderedList UnorderedList) ->
            {list_blocks(child, mode), after_open_child?}

          # a change wrapping whole blocks (<Repeal RetainText><Text>…</Text></Repeal>):
          # each of its blocks is the changed words
          block_change(child) != nil ->
            change = block_change(child)

            {child |> text_blocks(mode) |> Enum.map(&changed_block(&1, change)),
             after_open_child?}

          true ->
            {text_blocks(child, mode), after_open_child?}
        end
      end)

    blocks
  end

  # Append the sibling content an open provision took (#174): after " … "
  # when the provision has its own child provisions in between.
  defp with_trailing(segments, [], _node), do: segments

  defp with_trailing(segments, trailing, node) do
    trailing_segments =
      trailing
      |> Enum.flat_map(fn el ->
        cond do
          element_name(el) == "Text" -> [extract_inline_text(el)]
          element_name(el) == "AppendText" -> [{:append, extract_inline_text(el)}]
          element_name(el) in @quoted_elements -> [quoted_text(el)]
          true -> text_blocks(el, :leaf)
        end
      end)
      |> join_blocks()

    separator = if child_provisions?(node), do: " … ", else: " "
    LatSegments.join([segments, trailing_segments], separator)
  end

  # Join blocks with spaces; a gap between text becomes " … " (the child
  # provisions sit there); leading/trailing gaps are dropped.
  defp join_blocks(blocks) do
    blocks
    |> attach_appends()
    |> Enum.reject(&(is_list(&1) and LatSegments.blank?(&1)))
    |> Enum.chunk_by(&(&1 == :gap))
    |> Enum.map(fn
      [:gap | _] -> :gap
      parts -> LatSegments.join(parts, " ")
    end)
    |> Enum.drop_while(&(&1 == :gap))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == :gap))
    |> Enum.reverse()
    |> Enum.map(fn
      :gap -> LatSegments.mark("…")
      segments -> segments
    end)
    |> LatSegments.join(" ")
    |> LatSegments.trim()
  end

  # AppendText joins the block before it, inside its closing "»".
  defp attach_appends(blocks) do
    blocks
    |> Enum.reduce([], fn
      {:append, appended}, [prev | rest] when is_list(prev) ->
        [LatSegments.append_in_quote(prev, appended) | rest]

      {:append, appended}, acc ->
        [appended | acc]

      block, acc ->
        [block | acc]
    end)
    |> Enum.reverse()
  end

  # An element's inline text as segments (LatSegments), in document order,
  # inline markup joined without extra spaces ("<Term>X</Term>" → "X").
  # Substitution halves anywhere in it are paired (LatTerritory.pair_up/1).
  defp extract_inline_text(element) do
    subrefs =
      element |> xpath(~x".//@SubstitutionRef"ls) |> Enum.map(&to_string/1) |> MapSet.new()

    element
    |> render_inline(subrefs)
    |> LatTerritory.pair_up()
    |> LatSegments.trim()
  end

  # An element's inline words as a plain string (numbers, signatures).
  defp inline_plain(element),
    do:
      element
      |> extract_inline_text()
      |> LatSegments.plain()
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

  # Inline segments. Changes become {:words, change, inner}: a retained
  # Repeal (:keep) or an Addition/Substitution (:ins); their territory is
  # decided per row (LatTerritory). A territorial substitution — <Repeal
  # RetainText SubstitutionRef="X">old</Repeal> … <Substitution
  # ChangeId="X">new</Substitution> — is a {:pair, …}: siblings here, else
  # its halves are marked for LatTerritory.pair_up/1 (`subrefs`: the
  # block's SubstitutionRefs).
  defp render_inline(element, subrefs) do
    siblings = elem(element, 8)
    content = Enum.with_index(siblings)

    partners =
      for {el, i} <- content,
          elem(el, 0) == :xmlElement,
          id = change_id(el),
          into: %{},
          do: {id, {el, i}}

    {parts, _skip_to} =
      Enum.map_reduce(content, -1, fn {child, i}, skip_to ->
        cond do
          i <= skip_to ->
            {[], skip_to}

          elem(child, 0) == :xmlElement ->
            render_child(child, i, siblings, partners, skip_to, subrefs)

          true ->
            {render_node(child, subrefs), skip_to}
        end
      end)

    Enum.concat(parts)
  end

  # A sibling pair renders where its first retained Repeal sits and takes
  # everything up to its partner as the old wording: it can be split across
  # Repeals sharing the SubstitutionRef and wrap or sit inside other markup
  # (a Term).
  defp render_child(child, i, siblings, partners, skip_to, subrefs) do
    ref = substitution_ref(child)

    case ref && Map.get(partners, ref) do
      {partner, j} when j > i ->
        old = siblings |> Enum.slice(i..(j - 1)//1) |> Enum.flat_map(&render_node(&1, subrefs))
        {[{:pair, pair_change(child, partner), render_inline(partner, subrefs), old}], j}

      _ ->
        inner = render_inline(child, subrefs)

        cond do
          ref != nil ->
            {[{:pair_old, ref, change(child, :keep), inner}], skip_to}

          MapSet.member?(subrefs, change_id(child)) ->
            {[{:pair_new, change_id(child), change(child, :ins), inner}], skip_to}

          retained_words?(child) ->
            {[{:words, change(child, :keep), inner}], skip_to}

          elem(child, 1) in [:Addition, :Substitution] ->
            {[{:words, change(child, :ins), inner}], skip_to}

          true ->
            {inner, skip_to}
        end
    end
  end

  # A change element around whole blocks: a retained Repeal or an insertion.
  defp block_change(el) do
    cond do
      elem(el, 1) == :Repeal and xpath(el, ~x"./@RetainText"s) == "true" -> change(el, :keep)
      elem(el, 1) in [:Addition, :Substitution] -> change(el, :ins)
      true -> nil
    end
  end

  defp changed_block(segments, change) when is_list(segments), do: [{:words, change, segments}]
  defp changed_block({:append, segments}, change), do: {:append, [{:words, change, segments}]}
  defp changed_block(block, _change), do: block

  # Words repealed (text kept) with no replacement.
  defp retained_words?(el) do
    elem(el, 1) == :Repeal and xpath(el, ~x"./@RetainText"s) == "true" and
      substitution_ref(el) == nil
  end

  defp change(el, kind) do
    %LatTerritory.Change{
      kind: kind,
      attribute: blank_to_nil(xpath(el, ~x"./@Extent"s)),
      ref: blank_to_nil(xpath(el, ~x"./@CommentaryRef"s)),
      change_id: change_id(el),
      substitution: elem(el, 1) == :Substitution
    }
  end

  # A pair's territory: the first Extent of its halves, and the old half's note.
  defp pair_change(repeal, partner) do
    attribute =
      [repeal, partner] |> Enum.map(&blank_to_nil(xpath(&1, ~x"./@Extent"s))) |> Enum.find(& &1)

    %LatTerritory.Change{
      kind: :pair,
      attribute: attribute,
      ref: blank_to_nil(xpath(repeal, ~x"./@CommentaryRef"s)),
      change_id: change_id(repeal)
    }
  end

  defp render_node(node, subrefs) do
    case elem(node, 0) do
      :xmlText -> node |> elem(4) |> to_string() |> LatSegments.text()
      # an element's content (a pair's old half renders as plain words)
      :xmlElement -> render_inline(node, subrefs)
      _ -> []
    end
  end

  defp change_id(element), do: blank_to_nil(xpath(element, ~x"./@ChangeId"s))

  defp substitution_ref(element) do
    if elem(element, 1) == :Repeal and xpath(element, ~x"./@RetainText"s) == "true",
      do: blank_to_nil(xpath(element, ~x"./@SubstitutionRef"s))
  end

  # Extract text without descending into child provision elements.
  # Used for any node that has children emitted as separate rows (Part, Chapter,
  # Schedule, P1, P2, P3). Extracts only direct Para/Text + Title content.
  # Falls back to full text extraction if no child provisions exist.
  defp child_provisions?(node) do
    xpath(node, ~x".//P1[1]"o) != nil ||
      xpath(node, ~x".//P2[1]"o) != nil ||
      xpath(node, ~x".//P3[1]"o) != nil ||
      xpath(node, ~x".//P4[1]"o) != nil ||
      xpath(node, ~x".//Pblock[1]"o) != nil
  end

  defp extract_structural_text(node) do
    if child_provisions?(node) do
      # Title/Number text for the structural header (if any)
      title = extract_title(node)

      # The node's own text in document order, stopping at child provisions
      # (their own rows): a chapeau, then " … " and any continuation text
      # after them.
      direct = node |> text_blocks(:structural) |> join_blocks()
      LatSegments.join([LatSegments.text(title), direct], " ")
    else
      # No child provisions — keep full text (leaf node)
      extract_element_text(node)
    end
  end

  # ── Commentary Ref Collection & Counting ──────────────────────────

  # Classify each CommentaryRef by looking up its type in the Commentaries block.
  # Falls back to ID prefix matching (F1→amendment) for backwards compatibility.
  defp collect_commentary_refs(node, ref_type_lookup) do
    refs =
      case xpath(node, ~x".//CommentaryRef/@Ref"ls) do
        nil -> []
        list -> Enum.map(list, &to_string/1)
      end

    counts =
      refs
      |> Enum.map(fn ref_id -> classify_ref(ref_id, ref_type_lookup) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    typed_counts = %{
      f: Map.get(counts, "F") |> nil_if_zero(),
      c: Map.get(counts, "C") |> nil_if_zero(),
      i: Map.get(counts, "I") |> nil_if_zero(),
      e: Map.get(counts, "E") |> nil_if_zero()
    }

    # Placement (affected_sections): the notes the row cites at its own level
    # (CommentaryRef elements and CommentaryRef attributes on
    # Addition/Substitution/Repeal), its child provisions' refs excluded —
    # they are rows of their own (LH-06). Counts stay subtree, element-only.
    {typed_counts, own_refs(node)}
  end

  # Refs in the element's own content: not inside a child row element,
  # except a P2 that only wraps its P1 (no row of its own) and anything
  # inside a quoted block (another law's provisions, never rows here).
  defp own_refs(node) do
    wrapper = elem(node, 1) == :P1 and p2_is_wrapper?(node, extract_pnumber(node))
    node |> refs_within(wrapper, false) |> Enum.uniq()
  end

  defp refs_within(element, wrapper, quoted) do
    attribute = blank_to_nil(xpath(element, ~x"./@CommentaryRef"s))

    from_children =
      element
      |> elem(8)
      |> Enum.flat_map(fn child ->
        if elem(child, 0) == :xmlElement, do: child_refs(child, wrapper, quoted), else: []
      end)

    List.wrap(attribute) ++ from_children
  end

  defp child_refs(child, wrapper, quoted) do
    name = to_string(elem(child, 1))

    cond do
      name == "CommentaryRef" ->
        List.wrap(blank_to_nil(xpath(child, ~x"./@Ref"s)))

      name in @quoted_elements ->
        refs_within(child, wrapper, true)

      quoted ->
        refs_within(child, wrapper, true)

      name == "P2" and wrapper ->
        refs_within(child, false, false)

      name in @row_elements ->
        []

      # a group's Title notes go to the provision it wraps (group_refs),
      # never to the heading or Part above it (QA run 3)
      name in ~w(P1group P2group P3group) ->
        []

      true ->
        refs_within(child, wrapper, quoted)
    end
  end

  # CommentaryRef elements' Ref and CommentaryRef attributes under `path`.
  defp placement_refs(node, path) do
    elements = xpath(node, ~x"#{path}/descendant::CommentaryRef/@Ref"ls)
    attributes = xpath(node, ~x"#{path}/descendant-or-self::*/@CommentaryRef"ls)
    (elements ++ attributes) |> Enum.map(&to_string/1) |> Enum.uniq()
  end

  # Classify a ref ID: first try the lookup (handles hash-style IDs),
  # then fall back to prefix matching (F1, C2, I3, E4).
  defp classify_ref(ref_id, lookup) do
    case Map.get(lookup, ref_id) do
      type when type in ["F", "C", "I", "E"] -> type
      _ -> classify_ref_by_prefix(ref_id)
    end
  end

  defp classify_ref_by_prefix(ref_id) do
    cond do
      String.match?(ref_id, ~r/^F\d/) -> "F"
      String.match?(ref_id, ~r/^C\d/) -> "C"
      String.match?(ref_id, ~r/^I\d/) -> "I"
      String.match?(ref_id, ~r/^E\d/) -> "E"
      true -> nil
    end
  end

  defp nil_if_zero(0), do: nil
  defp nil_if_zero(n), do: n

  # ── Position Assignment ──────────────────────────────────────────

  defp assign_positions(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, position} -> Map.put(row, :position, position) end)
  end

  # An alternative version can repeat its counterpart (uksi 2010/2214: the
  # Welsh version of reg.7 holds a P1 marked E): rows with the same place and
  # text as an earlier row add nothing.
  defp drop_repeated_versions(rows) do
    key = fn r ->
      {r.element, r.schedule, r.part, r.chapter, r.heading_group, r.provision, r.sub, r.paragraph,
       r.sub_paragraph, r.extent_code, r.text}
    end

    body = rows |> Enum.reject(& &1.from_version) |> MapSet.new(key)

    rows
    |> Enum.reject(&(&1.from_version and MapSet.member?(body, key.(&1))))
    |> Enum.map(&Map.delete(&1, :from_version))
  end

  # ── Field Building (citations, sort_keys, hierarchy, depth) ─────

  @eu_type_codes ~w(eur eudr eudn)

  defp build_row_fields(rows, law_name, mode, type_code) do
    Enum.map(rows, fn row ->
      section_type = Transforms.xml_element_to_section_type(row.element, mode)
      # UK SIs use "reg." prefix (Regulation 1, 2...), EU laws use "art." (Article 1, 2...)
      class = if mode == :article and type_code not in @eu_type_codes, do: "Regulation", else: nil

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
          schedule: row.schedule,
          part: row.part,
          chapter: row.chapter,
          heading_group: row.heading_group,
          provision: row.provision,
          sub: row.sub,
          paragraph: row.paragraph,
          sub_paragraph: row.sub_paragraph,
          position: row.position,
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

  # ── Repealed/Revoked Provision Markers ──────────────────────────

  # Detect provisions that have been repealed (Acts) or revoked (SIs) and
  # inject a helpful marker. Indicators:
  # - Empty/nil text with any commentary refs (F-prefix or hash-style IDs)
  # - Dots-only heading text (". . . . . .")
  @dots_pattern ~r/\A[\s.]+\z/

  defp mark_repealed_provisions(rows, mode) do
    marker = if mode == :section, do: "[Repealed]", else: "[Revoked]"
    indexed = Enum.with_index(rows)

    Enum.map(indexed, fn {row, idx} ->
      cond do
        # Empty provision with commentary refs AND no children → repealed/revoked.
        # If the next row has deeper depth, this row has active children
        # (empty text is from structural extraction, not repeal).
        (row.text == nil or row.text == "") and (row.commentary_refs || []) != [] and
            not has_children?(rows, idx) ->
          %{row | text: marker}

        # Dots-only heading (". . . . . .") → repealed heading group
        row.section_type == "heading" and row.text != nil and
            Regex.match?(@dots_pattern, row.text) ->
          %{row | text: marker}

        true ->
          row
      end
    end)
  end

  # Status from the parse alone (#167): the inherited Prospective flag, else
  # repealed text (dots / the markers above), else in force. Partial
  # commencement and savings come from the notes (LatStatus.Apply).
  defp assign_status(rows) do
    Enum.map(rows, fn row ->
      status =
        cond do
          Map.get(row, :prospective) -> "prospective"
          LatStatus.repealed_text?(row.text) -> "repealed"
          retained_everywhere?(row) -> "repealed_saved"
          true -> "in_force"
        end

      row |> Map.delete(:prospective) |> Map.put(:status, status)
    end)
  end

  # Repealed (text retained) in every territory the row extends to.
  defp retained_everywhere?(%{excluded_extent: nil}), do: false

  defp retained_everywhere?(%{excluded_extent: repealed, extent_code: extent}),
    do: Territory.covers?(repealed, extent)

  defp has_children?(rows, idx) do
    current_depth = Enum.at(rows, idx).depth
    next_row = Enum.at(rows, idx + 1)
    next_row != nil and next_row.depth > current_depth
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

  # Parallel (territorial) versions: the same provision position (e.g. s.10,
  # or s.10(2) when only a sub-provision has versions) occurring with
  # different extents. That position and its descendants are qualified
  # "[E+W]". A child with a narrower extent than its parent is not a version
  # (LH-02: it used to qualify the whole provision).
  defp detect_and_qualify_parallels(rows) do
    collisions =
      rows
      |> Enum.filter(& &1.provision)
      |> Enum.group_by(&{&1.section_type, position_key(&1)}, & &1.extent_code)
      |> Enum.filter(fn {_, extents} ->
        extents |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length() > 1
      end)
      |> MapSet.new(fn {{_type, key}, _} -> key end)

    if MapSet.size(collisions) == 0 do
      rows
    else
      Enum.map(rows, fn row ->
        if row.provision && row.extent_code && parallel?(row, collisions) do
          new_sort_key = String.replace(row.sort_key, ~r/~.*$/, "~#{row.extent_code}")
          %{row | section_id: "#{row.section_id}[#{row.extent_code}]", sort_key: new_sort_key}
        else
          row
        end
      end)
    end
  end

  # schedule, provision, sub, paragraph, sub_paragraph — trailing nils dropped
  # (a body reg. 1 and a schedule para. 1 are different provisions)
  defp position_key(row) do
    [row.schedule, row.provision, row.sub, row.paragraph, row.sub_paragraph]
    |> Enum.reverse()
    |> Enum.drop_while(&is_nil/1)
    |> Enum.reverse()
  end

  defp parallel?(row, collisions) do
    key = position_key(row)
    Enum.any?(2..length(key)//1, &MapSet.member?(collisions, Enum.take(key, &1)))
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
        title: Map.get(row, :title),
        excluded_extent: Map.get(row, :excluded_extent),
        territory_provenance: row |> Map.get(:territory_provenance, []) |> json_provenance(),
        schedule: row.schedule,
        provision: row.provision,
        sub_provision: row.sub,
        paragraph: row.paragraph,
        sub_paragraph: row.sub_paragraph,
        extent_code: row.extent_code,
        status: Map.get(row, :status),
        sort_key: row.sort_key,
        position: row.position,
        depth: row.depth,
        hierarchy_path: row.hierarchy_path,
        text: row.text || "",
        country: country_from_law_name(row.law_name),
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

  # LR-03: provenance claims as string-keyed maps (jsonb[]); nil when none
  defp json_provenance([]), do: nil
  defp json_provenance(entries), do: Enum.map(entries, &json_claim/1)

  defp json_claim(claim) do
    for {k, v} <- claim, v != nil, into: %{}, do: {to_string(k), json_value(v)}
  end

  defp json_value(v) when is_atom(v), do: Atom.to_string(v)
  defp json_value(v), do: v

  defp country_from_law_name(law_name) when is_binary(law_name) do
    case String.split(law_name, "_", parts: 2) do
      [prefix | _] -> String.downcase(prefix)
      _ -> "uk"
    end
  end
end

defmodule SertantaiLegal.Scraper.LatParser.Walker do
  @moduledoc """
  The LAT parser's walk over a CLML document (LR-04): one raw row per row
  element (Part, Chapter, Pblock heading, P1–P4, signature,
  table, figure), in document order, carrying its place in the hierarchy
  (`Ctx`), its extent (inherited; territorial alternative versions walked
  after their counterpart) and Prospective flag.

  Each row's text, territory, notes and effects come from `Text`, `Effects`
  and `Refs`; numbers and titles from `Ids`. Positions, ids and status are
  added after the walk (`Rows`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.{Effects, Ids, Refs, Text, Xml}
  alias SertantaiLegal.Scraper.{LatTerritory, Territory}

  defmodule Ctx do
    @moduledoc """
    The walk context: the current place in the hierarchy (part … sub
    paragraph, group title and refs), inherited extent and Prospective
    flag, the sibling content a provision takes (#174), and per-law
    lookups (note types, alternative versions, effects).
    """

    import SweetXml

    alias SertantaiLegal.Scraper.LatParser.{Effects, Refs, Xml}

    @enforce_keys [:ref_type_lookup, :versions, :effects, :law_extent]
    defstruct part: nil,
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
              default_extent: nil,
              prospective: false,
              ref_type_lookup: %{},
              versions: %{},
              from_version: false,
              version_extent: nil,
              # LR-03: the law's effects (EffectIndex; empty = markup only) and the
              # whole-provision changes (rule 3) inherited by descendant rows
              effects: nil,
              law_extent: nil,
              provision_changes: []

    @type t :: %__MODULE__{
            part: String.t() | nil,
            chapter: String.t() | nil,
            heading_group: String.t() | nil,
            group_title: String.t() | nil,
            group_refs: [String.t()],
            schedule: String.t() | nil,
            provision: String.t() | nil,
            sub: String.t() | nil,
            paragraph: String.t() | nil,
            sub_paragraph: String.t() | nil,
            p2_is_wrapper: boolean(),
            trailing: [tuple()],
            default_extent: String.t() | nil,
            prospective: boolean(),
            ref_type_lookup: %{String.t() => String.t()},
            versions: %{String.t() => tuple()},
            from_version: boolean(),
            version_extent: String.t() | nil,
            effects: SertantaiLegal.Scraper.EffectIndex.t(),
            law_extent: String.t() | nil,
            provision_changes: [SertantaiLegal.Scraper.LatTerritory.Change.t()]
          }

    @doc """
    The context at the document root: its RestrictExtent, the note type
    lookup, alternative versions and the law's effects (`context.effects`).
    """
    @spec new(tuple(), SertantaiLegal.Scraper.LatParser.context()) :: t()
    def new(doc, context) do
      law_extent = Effects.law_extent(doc, context)

      %__MODULE__{
        default_extent: Xml.root_extent(doc),
        ref_type_lookup: Refs.type_lookup(doc),
        versions: versions(doc),
        effects: Effects.index(Map.get(context, :effects), doc, law_extent),
        law_extent: law_extent
      }
    end

    # Version id → Version element, for provision versions only (figures and
    # images stay out, #177).
    @version_content ~w(P1group P1 P2group P2 P3 P4 Pblock Part Chapter)

    defp versions(doc) do
      for version <- xpath(doc, ~x"//Versions/Version"l),
          first = xpath(version, ~x"./*[1]"o),
          first != nil and Xml.element_name(first) in @version_content,
          into: %{},
          do: {to_string(xpath(version, ~x"./@id"s)), version}
    end
  end

  @doc """
  The raw rows of a node's children, in document order (`LatParser.Rows`
  finishes them).

  #174: content that follows an open child provision as a sibling (a
  definition list, a BlockText of closing words) is that child's — it's
  passed down as ctx.trailing and appended to the child's row text.
  """
  @spec walk(tuple(), Ctx.t()) :: [map()]
  def walk(node, ctx), do: walk_children(node, ctx)

  defp walk_children(node, ctx) do
    ctx = %{ctx | trailing: []}
    children = xpath(node, ~x"./*"l)
    parent_open? = Text.lead_in_before_children_open?(node)

    children
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, i} ->
      trailing = trailing_content(child, Enum.drop(children, i + 1), parent_open?)
      walk_element(child, %{ctx | trailing: trailing})
    end)
  end

  # The sibling content a child provision takes (`Text.takes_trailing?/2`):
  # the content elements after it, up to the next row element.
  defp trailing_content(child, rest, parent_open?) do
    if Xml.element_name(child) in Xml.provision_rows() do
      content = Enum.take_while(rest, &(Xml.element_name(&1) not in Xml.row_elements()))
      if content != [] and Text.takes_trailing?(child, parent_open?), do: content, else: []
    else
      []
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
      root -> Xml.element_extent(root)
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
    name = Xml.element_name(node)
    extent = version_governed(Xml.element_extent(node) || ctx.default_extent, ctx.version_extent)
    # Children inherit this element's effective extent (a Part's RestrictExtent
    # covers its sections), not the document root's. Status="Prospective" (on
    # P1group / Pblock wrappers) is inherited the same way (#167).
    ctx = %{ctx | default_extent: extent, prospective: ctx.prospective or Xml.prospective?(node)}
    ctx = Effects.with_whole_provision(ctx, node)

    cond do
      name in Xml.skip_elements() ->
        # Amendment/extract text embeds P1/P2/P3 from OTHER laws — skip entirely
        []

      name in Xml.schedule_elements() ->
        # No schedules in LAT (LR-10)
        []

      name in ~w(P1group P2group P3group) ->
        # The group's Title is the heading of the P1 / P2 / P3 it wraps
        # and the notes its Title cites are about them
        walk_children(node, %{
          ctx
          | group_title: Ids.heading_title(node),
            group_refs: Refs.placement(node, "./Title")
        })

      name in Xml.container_elements() ->
        walk_children(node, ctx)

      # an EU Title (e.g. "TITLE I: GENERAL ISSUES") is a Part in the hierarchy
      name in ~w(Part EUTitle) ->
        prefix = if name == "Part", do: "Part", else: "Title"
        new_ctx = %{ctx | part: Ids.number(node, prefix), chapter: nil, heading_group: nil}

        row =
          "Part"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> Ids.number_titled(node, prefix)

        [row | walk_children(node, new_ctx)]

      # an EU Chapter has the same semantics as a UK Chapter
      name in ~w(Chapter EUChapter) ->
        new_ctx = %{ctx | chapter: Ids.number(node, "Chapter"), heading_group: nil}

        row =
          "Chapter"
          |> emit_structural_row(new_ctx, node, extent)
          |> titled(node)
          |> Ids.number_titled(node, "Chapter")

        [row | walk_children(node, new_ctx)]

      name == "Pblock" ->
        heading_text = Ids.title(node)
        # Pblock heading_group gets the provision number of its first P1 child
        first_p1_num = Ids.first_p1_number(node)
        new_ctx = %{ctx | heading_group: first_p1_num}
        row = new_ctx |> emit_heading_row(node, extent, heading_text) |> titled(node)
        [row | walk_children(node, new_ctx)]

      name == "P1" ->
        provision = Ids.pnumber(node)
        wrapper = Ids.p2_wrapper?(node, provision)

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
        sub = Ids.pnumber(node)
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
        paragraph = Ids.pnumber(node)
        new_ctx = %{ctx | paragraph: paragraph, sub_paragraph: nil}
        row = "P3" |> emit_structural_row(ungrouped(new_ctx), node, extent) |> grouped(ctx)
        [row | walk_children(node, ungrouped(new_ctx))]

      name == "P4" ->
        sub_paragraph = Ids.pnumber(node)
        new_ctx = %{ctx | sub_paragraph: sub_paragraph}
        row = emit_row("P4", new_ctx, node, extent)
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

  defp emit_row(element, ctx, node, extent), do: emit(element, ctx, node, extent, &Text.leaf/1)

  defp emit_structural_row(element, ctx, node, extent),
    do: emit(element, ctx, node, extent, &Text.structural/1)

  # A row: its text (leaf, or structural: stopping at child rows) with the
  # sibling content it takes (#174), territory resolved from markup +
  # effects, its notes and its effects.
  defp emit(element, ctx, node, extent, text_of) do
    {repealed, whole} = Effects.excluded(node, extent || ctx.law_extent, ctx)

    segments =
      node
      |> text_of.()
      |> Text.with_trailing(ctx.trailing, node)
      |> Effects.row_segments(ctx, extent || ctx.law_extent, node)

    text = LatTerritory.render(segments, extent || ctx.law_extent, repealed)

    {commentary_counts, commentary_refs} = Refs.collect(node, ctx.ref_type_lookup)

    %{
      element: element,
      xml_id: Xml.xml_id(node),
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
      # LR-07: {commentary ref, effect id} per joined change in the row's text
      note_effects: LatTerritory.note_effects(segments),
      effect_ids: Effects.row_effect_ids(segments, whole, ctx, node),
      from_version: ctx.from_version
    }
  end

  defp emit_heading_row(ctx, node, extent, heading_text) do
    {commentary_counts, commentary_refs} = Refs.collect(node, ctx.ref_type_lookup)
    {repealed, whole} = Effects.excluded(node, extent || ctx.law_extent, ctx)

    %{
      element: "Pblock",
      xml_id: Xml.xml_id(node),
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
      excluded_extent: repealed,
      territory_provenance: LatTerritory.provenance(whole),
      from_version: ctx.from_version
    }
  end

  defp titled(row, node), do: %{row | title: Ids.heading_title(node)}

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
end

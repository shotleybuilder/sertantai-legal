defmodule SertantaiLegal.Scraper.LatParser.Rows do
  @moduledoc """
  The LAT parser's post-walk pipeline over row maps (LR-04), in order:
  drop alternative versions that repeat the body, positions, citation /
  section_id / sort_key / hierarchy / depth, [Repealed] / [Revoked] markers,
  the parse's status, parallel (territorial) provision qualification, and
  duplicate id disambiguation; then `to_insert_maps/2` for persistence.
  Rows stay maps (their shape is the persistence and test contract). Pure.
  """

  alias Ecto.UUID
  alias SertantaiLegal.Legal.Lat.Transforms
  alias SertantaiLegal.Scraper.{LatStatus, Territory}

  # Acts (sections); everything else is an instrument (regulations/articles).
  # asc (Acts of Senedd Cymru), mwa (Welsh Measures) and the local / church /
  # pre-Union Acts number sections too (LH-02).
  @act_type_codes ~w(ukpga anaw asp asc mwa nia apni aep ukla ukcm aosp aip apgb gbla)

  @doc "Each row's `position`: document order, from 1."
  @spec assign_positions([map()]) :: [map()]
  def assign_positions(rows) do
    rows
    |> Enum.with_index(1)
    |> Enum.map(fn {row, position} -> Map.put(row, :position, position) end)
  end

  @doc """
  An alternative version can repeat its counterpart (uksi 2010/2214: the
  Welsh version of reg.7 holds a P1 marked E): rows with the same place and
  text as an earlier row add nothing.
  """
  @spec drop_repeated_versions([map()]) :: [map()]
  def drop_repeated_versions(rows) do
    key = fn r ->
      {r.element, r.schedule, r.part, r.chapter, r.heading_group, r.provision, r.sub, r.paragraph,
       r.sub_paragraph, r.extent_code, r.text}
    end

    body = rows |> Enum.reject(& &1.from_version) |> MapSet.new(key)

    rows
    |> Enum.reject(&(&1.from_version and MapSet.member?(body, key.(&1))))
    |> Enum.map(&Map.delete(&1, :from_version))
  end

  @eu_type_codes ~w(eur eudr eudn)

  @doc """
  Each row's section_type, citation, section_id, sort_key, hierarchy_path
  and depth (`Transforms`). UK SIs cite `reg.`, EU law `art.`; P3/P4 in a
  section cite as its extensions (s.1(1)(a)), in a schedule as paragraphs.
  """
  @spec build_fields([map()], String.t(), :section | :article, String.t()) :: [map()]
  def build_fields(rows, law_name, mode, type_code) do
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

      citation = with_source_suffix(citation, Map.get(row, :xml_id))

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

  # legislation.gov.uk makes a recurring number unique with an "n1", "n2"
  # suffix on the element's id (section-70A-1n1, section-70A-1-an1): the
  # citation keeps it, whether or not anything collides today (LR-13).
  # A number already taken from the id (1965/57 "pt.1n1") has it.
  defp with_source_suffix(citation, xml_id) when is_binary(xml_id) do
    case Regex.run(~r/(n\d+)+$/, xml_id, capture: :first) do
      [suffix] -> if String.ends_with?(citation, suffix), do: citation, else: citation <> suffix
      nil -> citation
    end
  end

  defp with_source_suffix(citation, _xml_id), do: citation

  # Detect provisions that have been repealed (Acts) or revoked (SIs) and
  # inject a helpful marker. Indicators:
  # - Empty/nil text with any commentary refs (F-prefix or hash-style IDs)
  # - Dots-only heading text (". . . . . .")
  @dots_pattern ~r/\A[\s.]+\z/

  @doc """
  "[Repealed]" (Acts) / "[Revoked]" (instruments) for a provision with no
  text, notes and no children, and for a dots-only heading.
  """
  @spec mark_repealed([map()], :section | :article) :: [map()]
  def mark_repealed(rows, mode) do
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

  @doc """
  What the revised text shows (#167, LR-25 `markup_status`): the inherited
  Prospective flag, else repealed text (dots / the markers above), else
  retained and excluded everywhere it extends, else in force. The
  timeline's J2 input; status as a label is the timeline's.
  """
  @spec assign_status([map()]) :: [map()]
  def assign_status(rows) do
    Enum.map(rows, fn row ->
      status =
        cond do
          Map.get(row, :prospective) -> "prospective"
          LatStatus.repealed_text?(row.text) -> "repealed"
          retained_everywhere?(row) -> "repealed_saved"
          true -> "in_force"
        end

      row
      |> Map.delete(:prospective)
      |> Map.put(:status, status)
      |> Map.put(:markup_status, status)
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

  @doc """
  Parallel (territorial) versions: the same provision position (e.g. s.10,
  or s.10(2) when only a sub-provision has versions) occurring with
  different extents. That position and its descendants are qualified
  "[E+W]". A child with a narrower extent than its parent is not a version
  (LH-02: it used to qualify the whole provision).
  """
  @spec qualify_parallels([map()]) :: [map()]
  def qualify_parallels(rows) do
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

  @doc """
  Section ids that still repeat (a duplicate in the source's own markup, or
  an element with no id): the first occurrence keeps the id, later ones
  count `#2`, `#3` in document order (LR-13). Never the row's position,
  which shifts whenever an earlier row is added or removed.
  """
  @spec disambiguate([map()]) :: [map()]
  def disambiguate(rows) do
    {rows, _seen} =
      Enum.map_reduce(rows, %{}, fn row, seen ->
        case Map.get(seen, row.section_id, 0) + 1 do
          1 -> {row, Map.put(seen, row.section_id, 1)}
          n -> {%{row | section_id: "#{row.section_id}##{n}"}, Map.put(seen, row.section_id, n)}
        end
      end)

    rows
  end

  @doc "Acts number sections (:section); every other type regulations / articles (:article)."
  @spec mode(String.t()) :: :section | :article
  def mode(type_code) when type_code in @act_type_codes, do: :section
  def mode(_type_code), do: :article

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
    {:ok, law_id_binary} = UUID.dump(law_id)

    Enum.map(rows, fn row ->
      %{
        section_id: row.section_id,
        # LR-13: legislation.gov.uk's id of the element (matching on re-parse)
        source_xml_id: Map.get(row, :xml_id),
        law_name: row.law_name,
        law_id: law_id_binary,
        section_type: row.section_type,
        part: row.part,
        chapter: row.chapter,
        heading_group: row.heading_group,
        title: Map.get(row, :title),
        excluded_extent: Map.get(row, :excluded_extent),
        territory_provenance: row |> Map.get(:territory_provenance, []) |> json_provenance(),
        # LR-07: the effects on the row (nil: none)
        effect_ids:
          case Map.get(row, :effect_ids, []) do
            [] -> nil
            ids -> ids
          end,
        schedule: row.schedule,
        provision: row.provision,
        sub_provision: row.sub,
        paragraph: row.paragraph,
        sub_paragraph: row.sub_paragraph,
        extent_code: row.extent_code,
        status: Map.get(row, :status),
        markup_status: Map.get(row, :markup_status),
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

defmodule SertantaiLegal.Scraper.CommentaryParser do
  @moduledoc """
  Parses `<Commentaries>` block from legislation.gov.uk body XML into
  amendment_annotations rows.

  Pure function module — takes body XML string + law context + ref-to-section
  mapping, returns a list of annotation maps ready for persistence.

  ## XML Structure

      <Commentaries>
        <Commentary id="key-abc123" Type="F">
          <Para><Text>Words substituted by S.I. 2024/100</Text></Para>
        </Commentary>
      </Commentaries>

  ## Usage

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_1974_37"}, ref_to_sections)
  """

  import SweetXml

  alias SertantaiLegal.Scraper.{AmendmentNote, ChangeFacts, EffectIndex}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type_map %{
    "F" => :amendment,
    "C" => :modification,
    # marginal citation ("1906 c. 14."): a reference, not a modification
    "M" => :extent_editorial,
    "I" => :commencement,
    "E" => :extent_editorial,
    "X" => :extent_editorial
  }

  @doc """
  Parse body XML into a list of amendment annotation maps.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk body XML
    - `context` — map with `:law_name`
    - `ref_to_sections` — map of `%{commentary_ref_id => [section_id, ...]}`
      built from LatParser results

  ## Returns

  List of maps with keys matching amendment_annotations table columns.
  """
  @spec parse(String.t(), map(), map()) :: [map()]
  def parse(xml, %{law_name: law_name}, ref_to_sections \\ %{}) when is_binary(xml) do
    parsed = SweetXml.parse(xml, quiet: true)

    commentaries =
      case xpath(parsed, ~x"//Commentaries/Commentary"l) do
        nil -> []
        list -> list
      end

    # Group by code_type for sequential ID assignment
    commentaries
    |> Enum.map(&extract_commentary(&1, ref_to_sections))
    |> Enum.reject(&is_nil/1)
    |> assign_sequential_ids(law_name)
  end

  @doc """
  Build a ref_to_sections mapping from LatParser rows that include `:commentary_refs`.

  Each LAT row may have a list of CommentaryRef IDs. This inverts that
  to `%{ref_id => [section_id, ...]}`.
  """
  @spec build_ref_to_sections([map()]) :: map()
  def build_ref_to_sections(lat_rows) do
    lat_rows
    |> Enum.reduce(%{}, fn row, acc ->
      refs = Map.get(row, :commentary_refs, []) || []
      section_id = row.section_id

      Enum.reduce(refs, acc, fn ref, inner_acc ->
        Map.update(inner_acc, ref, [section_id], &[section_id | &1])
      end)
    end)
    |> Map.new(fn {ref, sections} -> {ref, Enum.reverse(sections) |> Enum.uniq()} end)
  end

  @doc """
  Each commentary's `{code_type, code, old_text, text}` in document order:
  the pre-2026-10-08 (scrambled) text beside the ordered one, so
  `mix lat.reorder_notes` can find stored notes by their old text. Remove
  with that task once the corpus is re-keyed.
  """
  @spec text_pairs(String.t()) :: [{String.t(), String.t(), String.t(), String.t()}]
  def text_pairs(xml) when is_binary(xml) do
    xml
    |> SweetXml.parse(quiet: true)
    |> xpath(~x"//Commentaries/Commentary"l)
    |> Enum.flat_map(fn node ->
      id = node |> xpath(~x"./@id"s) |> to_string()
      type_char = node |> xpath(~x"./@Type"s) |> to_string()
      code_type = Map.get(@type_map, type_char)

      if is_nil(code_type) or id == "" do
        []
      else
        [
          {to_string(code_type), derive_code(id, code_type, type_char),
           legacy_commentary_text(node) || "", extract_commentary_text(node) || ""}
        ]
      end
    end)
  end

  # ── Extract a single Commentary element ──────────────────────────

  defp extract_commentary(node, ref_to_sections) do
    id = xpath(node, ~x"./@id"s) |> to_string()
    type_char = xpath(node, ~x"./@Type"s) |> to_string()

    code_type = Map.get(@type_map, type_char)

    if is_nil(code_type) or id == "" do
      nil
    else
      text = extract_commentary_text(node)
      affected = Map.get(ref_to_sections, id, [])

      %{
        ref_id: id,
        type_char: type_char,
        code_type: code_type,
        text: text || "",
        affected_sections: if(affected == [], do: nil, else: affected),
        citation_law: citation_law(node, text || "")
      }
    end
  end

  # A Commentary's text: each Text block in document order, inline markup
  # (Citation, CitationSubRef) joined as written, blocks joined by a space.
  # descendant:: axes keep document order; xmerl's //text() returns direct
  # text before descendants' and scrambled every note with a citation
  # (LAT parser coverage II).
  defp extract_commentary_text(node) do
    case xpath(node, ~x"./descendant::Text"l) do
      [] -> [node]
      blocks -> blocks
    end
    |> Enum.map(&inline_text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
    |> case do
      "" -> nil
      t -> t
    end
  end

  # an instrument reference in running text: "2019/530", "c. 74", "asp 8"
  @instrument ~r"\d{4}/\d+|\bc\.\s*\d+|\b(?:asp|anaw|asc|nia|mwa)\s+\d+"

  @doc """
  Each Commentary's cited law (`citation_law/2`), by Commentary id: the
  law a change's note names, as a pointer to its effect (LR-19 D2).
  """
  @spec cited_laws(tuple()) :: %{String.t() => String.t()}
  def cited_laws(doc) do
    for node <- xpath(doc, ~x"//Commentaries/Commentary"l),
        law = citation_law(node, extract_commentary_text(node) || ""),
        law != nil,
        into: %{},
        do: {node |> xpath(~x"./@id"s) |> to_string(), law}
  end

  @doc """
  The law a note's first `<Citation>` after " by " names, from its URI
  (`…/id/{type}/{year}/{number}` → `UK_{type}_{year}_{number}`): what the
  note's text names as the changing instrument, but structured — a Welsh SI
  cited as plain "S.I. 2013/755" is `/id/wsi/2013/755`, an EU Regulation
  `/id/eur/2019/1243` (LR-05). Nil when there is no such citation.
  """
  @spec citation_law(tuple(), String.t()) :: String.t() | nil
  def citation_law(node, text) do
    with {by_at, _} <- :binary.match(text, " by "),
         {at, law} <- first_citation(node, text, by_at),
         # only when it is the first instrument named after " by ": one the
         # markup doesn't cite (nisi 2003/419 "by virtue of S.I. 2019/530 …
         # (as inserted by <Citation>…)") leaves the text to decide
         false <- Regex.match?(@instrument, binary_part(text, by_at, at - by_at)) do
      law
    else
      _ -> nil
    end
  end

  # the first Citation after " by ": {position, its law | nil (no usable URI)}
  defp first_citation(node, text, by_at) do
    node
    |> xpath(~x".//Citation"l)
    |> Enum.flat_map(fn c ->
      case citation_at(text, inline_text(c), by_at) do
        nil -> []
        at -> [{at, uri_law(xpath(c, ~x"./@URI"s) |> to_string())}]
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> nil end)
  end

  defp citation_at(_text, "", _by_at), do: nil

  defp citation_at(text, cite, by_at),
    do: Enum.find_value(:binary.matches(text, cite), fn {pos, _} -> if pos > by_at, do: pos end)

  defp uri_law(uri) do
    case Regex.run(~r"legislation\.gov\.uk/id/([a-z]+)/(\d{4})/(\d+)(?:/|$)", uri,
           capture: :all_but_first
         ) do
      [type, year, number] -> "UK_#{type}_#{year}_#{number}"
      nil -> nil
    end
  end

  # The old extraction (xmerl //text(): direct text first, then descendants').
  # Kept only to match stored notes during the re-key; remove afterwards.
  defp legacy_commentary_text(node) do
    (xpath(node, ~x".//Para//text()"ls) ++ xpath(node, ~x".//Text//text()"ls))
    |> Enum.map(&(&1 |> to_string() |> String.trim()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.join(" ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> nil
      t -> t
    end
  end

  defp inline_text(element) do
    element
    |> xpath(~x"./descendant::text()"ls)
    |> Enum.map_join("", &to_string/1)
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @doc """
  Merge annotations parsed from several documents of one law (scoped LAT
  fragments, #166): the same commentary (code type, code, text) once, with
  its affected sections combined, and sequential ids renumbered across the
  law ({law_name}:{code_type}:{seq}).
  """
  @spec renumber([map()], String.t()) :: [map()]
  def renumber(annotations, law_name) do
    key = &{&1.code_type, &1.code, &1.text}
    same = Enum.group_by(annotations, key)

    # first occurrences in document order (fragment order): the stable sort
    # below breaks ties between fragments' equal numbers by it, never by map
    # order (which follows the VM's atom table: ids changed run to run, LR-04)
    annotations
    |> Enum.uniq_by(key)
    |> Enum.map(fn first ->
      %{
        first
        | affected_sections:
            same[key.(first)] |> Enum.flat_map(&(&1.affected_sections || [])) |> Enum.uniq()
      }
    end)
    |> Enum.sort_by(
      &{&1.code_type, &1.id |> String.split(":") |> List.last() |> String.to_integer()}
    )
    |> by_code_type()
    |> Enum.flat_map(fn {code_type, items} ->
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, seq} -> %{item | id: "#{law_name}:#{code_type}:#{seq}"} end)
    end)
  end

  # Groups by code_type, in code_type name order: a map's atom keys come out
  # in atom-table order, which varies with module load order (LR-04)
  defp by_code_type(items),
    do: items |> Enum.group_by(& &1.code_type) |> Enum.sort_by(fn {t, _} -> to_string(t) end)

  @doc """
  Each annotation's `effect_ids` (LR-07): the effects joined by the change
  markup citing it (rows' `note_effects`), and its own id when that is an
  effect in the feed — commencement and modification notes sit on the
  provision, not on change markup.

  LR-19 D1: a note neither joins (a legacy note: a bare CommentaryRef, no
  change element) points to its effects — those on the provisions it sits
  on (exact refs and ranges), by the law it cites (its Citation, else the
  instrument its text names after " by "), of its kind, held by no other
  note. The facts come from those effects; the note only says where to
  look. Empty when none: the note stays a note.

  LR-23: also `effect_joins`, each effect with how the note reached it:
  `{id, :markup}` or `{id, :own}` (the note's placement carries it to every
  provision it sits on), or `{id, :cited, section_id}` (the pointer above:
  only the provision the effect was found on).

  `effects`: the law's changes-feed effects.
  """
  @spec with_effects([map()], [map()], [Effect.t()]) :: [map()]
  def with_effects(annotations, lat_rows, effects) do
    known = MapSet.new(for e <- effects, e.effect_id != nil, do: e.effect_id)

    by_ref =
      lat_rows
      |> Enum.flat_map(&(Map.get(&1, :note_effects) || []))
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    joined =
      Enum.map(annotations, fn a ->
        ref = a.code |> String.split(":", parts: 2) |> List.last()
        own = if MapSet.member?(known, ref), do: [{ref, :own}], else: []
        markup = for id <- Map.get(by_ref, ref, []), do: {id, :markup}
        with_joins(a, Enum.uniq_by(markup ++ own, &elem(&1, 0)))
      end)

    held = MapSet.new(for a <- joined, id <- a.effect_ids, do: id)
    xml_ids = Map.new(lat_rows, &{&1.section_id, row_xml_id(&1)})

    index =
      EffectIndex.new(effects, lat_rows |> Enum.map(&row_xml_id/1) |> Enum.reject(&is_nil/1))

    Enum.map(joined, fn
      %{effect_ids: []} = a ->
        with_joins(a, for({id, sid} <- pointed(a, index, xml_ids, held), do: {id, :cited, sid}))

      a ->
        a
    end)
  end

  # LR-23: `effect_joins` (the change log's `via`) and the flat `effect_ids`
  defp with_joins(a, joins),
    do:
      Map.merge(a, %{
        effect_joins: joins,
        effect_ids: joins |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
      })

  defp row_xml_id(row), do: Map.get(row, :xml_id) || Map.get(row, :source_xml_id)

  # the effect kinds (ChangeFacts.kind/2) a note of each type can point to
  @kinds %{
    "amendment" => ~w(substituted inserted repealed renumbered amended),
    "modification" => ~w(other),
    "commencement" => ~w(commenced)
  }

  defp pointed(a, index, xml_ids, held) do
    kinds = Map.get(@kinds, to_string(Map.get(a, :code_type)), [])
    law = cited_law(a)

    if law == nil or kinds == [] do
      []
    else
      for sid <- Map.get(a, :affected_sections) || [],
          e <- EffectIndex.on(index, xml_ids[sid]),
          e.effect_id != nil,
          not MapSet.member?(held, e.effect_id),
          e.affecting != nil and AmendmentNote.same_law?(e.affecting, law),
          ChangeFacts.kind(e.type, nil) in kinds,
          uniq: true,
          do: {e.effect_id, sid}
    end
  end

  # the law the note cites: its Citation's, else the instrument after " by "
  defp cited_law(%{citation_law: law}) when is_binary(law), do: law

  defp cited_law(a) do
    text = Map.get(a, :text) || ""

    if String.contains?(text, " by "),
      do: AmendmentNote.parse(text, a.code_type, Map.get(a, :law_name) || "").changed_by
  end

  # ── Sequential ID Assignment ─────────────────────────────────────

  # Assign sequential IDs per code_type: {law_name}:{code_type}:{seq}
  defp assign_sequential_ids(commentaries, law_name) do
    commentaries
    |> by_code_type()
    |> Enum.flat_map(fn {code_type, items} ->
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, seq} ->
        %{
          id: "#{law_name}:#{code_type}:#{seq}",
          law_name: law_name,
          code: derive_code(item.ref_id, code_type, item.type_char),
          code_type: code_type,
          source: "lat_parser",
          text: item.text,
          affected_sections: item.affected_sections,
          citation_law: item.citation_law
        }
      end)
    end)
  end

  # Derive a human-readable code from the ref_id
  # If ref_id looks like "F3", "C1" etc. use it directly
  # Otherwise generate from code_type + position (handled by seq in the ID)
  # A marginal citation (Type M) keeps an "M" code, so the note still says
  # it is a citation, not an editorial change (LH-06).
  defp derive_code(ref_id, code_type, type_char) do
    type_prefix = if type_char == "M", do: "M", else: code_type_to_prefix(code_type)

    if Regex.match?(~r/^[FCIMEX]\d+$/, ref_id) do
      ref_id
    else
      # Internal key like "key-abc123" or "c9625711" — use the ref_id as-is
      # since the actual F-code assignment from legislation.gov.uk uses these IDs
      "#{type_prefix}:#{ref_id}"
    end
  end

  defp code_type_to_prefix(:amendment), do: "F"
  defp code_type_to_prefix(:modification), do: "C"
  defp code_type_to_prefix(:commencement), do: "I"
  defp code_type_to_prefix(:extent_editorial), do: "E"
end

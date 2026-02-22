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

  @type_map %{
    "F" => :amendment,
    "C" => :modification,
    "M" => :modification,
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
        code_type: code_type,
        text: text || "",
        affected_sections: if(affected == [], do: nil, else: affected)
      }
    end
  end

  # Extract text from all Para/Text children of a Commentary, joining them
  defp extract_commentary_text(node) do
    texts =
      case xpath(node, ~x".//Para//text()"ls) do
        nil -> []
        list -> Enum.map(list, &to_string/1)
      end

    # Also get direct Text children (some Commentaries use Text without Para)
    more_texts =
      case xpath(node, ~x".//Text//text()"ls) do
        nil -> []
        list -> Enum.map(list, &to_string/1)
      end

    (texts ++ more_texts)
    |> Enum.map(&String.trim/1)
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

  # ── Sequential ID Assignment ─────────────────────────────────────

  # Assign sequential IDs per code_type: {law_name}:{code_type}:{seq}
  defp assign_sequential_ids(commentaries, law_name) do
    commentaries
    |> Enum.group_by(& &1.code_type)
    |> Enum.flat_map(fn {code_type, items} ->
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, seq} ->
        %{
          id: "#{law_name}:#{code_type}:#{seq}",
          law_name: law_name,
          code: derive_code(item.ref_id, code_type),
          code_type: code_type,
          source: "lat_parser",
          text: item.text,
          affected_sections: item.affected_sections
        }
      end)
    end)
  end

  # Derive a human-readable code from the ref_id
  # If ref_id looks like "F3", "C1" etc. use it directly
  # Otherwise generate from code_type + position (handled by seq in the ID)
  defp derive_code(ref_id, code_type) do
    type_prefix = code_type_to_prefix(code_type)

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

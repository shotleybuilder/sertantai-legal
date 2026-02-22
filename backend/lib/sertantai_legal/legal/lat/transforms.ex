defmodule SertantaiLegal.Legal.Lat.Transforms do
  @moduledoc """
  Pure transform functions for converting Airtable CSV rows into LAT schema rows.

  Implements the 16-step pipeline from `docs/LAT-TRANSFORMS-FOR-SERTANTAI.md`.
  All functions are pure (no DB access) so they can be tested independently
  and reused by the parser (Phase 3).
  """

  # ── 1. ID Normalisation (Acronym Stripping) ──────────────────────

  @doc """
  Strip acronym suffixes/prefixes from legacy Airtable law IDs.

  Three patterns:
    - UK_ACRO_type_year_num → UK_type_year_num
    - UK_type_year_num_ACRO → UK_type_year_num
    - UK_year_num_ACRO → UK_year_num

  Acronyms are UPPERCASE, type_codes are lowercase.
  """
  @spec normalize_law_name(String.t()) :: String.t()
  def normalize_law_name(name) when is_binary(name) do
    name = String.trim(name)

    cond do
      # Pattern 1: UK_ACRO_type_year_num (e.g., UK_CMCHA_ukpga_2007_19)
      Regex.match?(~r/^UK_[A-Z][A-Z0-9&-]+_[a-z]+_\d+_\d+/, name) ->
        case Regex.run(~r/^(UK)_[A-Z][A-Z0-9&-]+_([a-z]+_\d+_\d+.*)$/, name) do
          [_, prefix, rest] -> "#{prefix}_#{rest}"
          _ -> name
        end

      # Pattern 2: UK_type_year_num_ACRO (e.g., UK_ukpga_1974_37_HSWA)
      Regex.match?(~r/^UK_[a-z]+_\d+_\d+_[A-Z]/, name) ->
        case Regex.run(~r/^(UK_[a-z]+_\d+_\d+)_[A-Z][A-Z0-9&-]+$/, name) do
          [_, base] -> base
          _ -> name
        end

      # Pattern 3: UK_year_num_ACRO (e.g., UK_1988_819_CDWR)
      Regex.match?(~r/^UK_\d+_\d+_[A-Z]/, name) ->
        case Regex.run(~r/^(UK_\d+_\d+)_[A-Z][A-Z0-9&-]+$/, name) do
          [_, base] -> base
          _ -> name
        end

      true ->
        name
    end
  end

  def normalize_law_name(nil), do: nil

  # ── 2. Record_Type → section_type Mapping ────────────────────────

  @record_type_map %{
    "title" => "title",
    "part" => "part",
    "chapter" => "chapter",
    "heading" => "heading",
    "section" => "section",
    "sub-section" => "sub_section",
    "article" => "article",
    "article,heading" => "heading",
    "article,sub-article" => "sub_article",
    "sub-article" => "sub_article",
    "paragraph" => "paragraph",
    "sub-paragraph" => "sub_paragraph",
    "schedule" => "schedule",
    "annex" => "schedule",
    "table" => "table",
    "sub-table" => "table",
    "figure" => "note",
    "signed" => "signed",
    "commencement" => "commencement",
    "table,heading" => "heading"
  }

  @doc """
  Map CSV Record_Type to normalised section_type enum value.
  Returns nil for unrecognised types.
  """
  @spec map_section_type(String.t() | nil) :: String.t() | nil
  def map_section_type(nil), do: nil
  def map_section_type(""), do: nil

  def map_section_type(record_type) do
    Map.get(@record_type_map, String.trim(record_type))
  end

  # ── 3. Content Row Detection ─────────────────────────────────────

  @annotation_heading_types MapSet.new([
                              "commencement,heading",
                              "modification,heading",
                              "extent,heading",
                              "editorial,heading",
                              "subordinate,heading"
                            ])

  @doc """
  Returns true if the row is a content row (not an annotation).
  """
  @spec content_row?(String.t() | nil) :: boolean()
  def content_row?(nil), do: false
  def content_row?(""), do: false

  def content_row?(record_type) do
    rt = String.trim(record_type)

    not (rt == "" or
           String.ends_with?(rt, ",content") or
           String.starts_with?(rt, "amendment,") or
           String.starts_with?(rt, "subordinate,") or
           String.starts_with?(rt, "editorial,") or
           MapSet.member?(@annotation_heading_types, rt))
  end

  # ── 4. Provision Merging ─────────────────────────────────────────

  @doc """
  Extract provision from the combined Section||Regulation column.
  Returns the trimmed value or nil.
  """
  @spec merge_provision(String.t() | nil) :: String.t() | nil
  def merge_provision(nil), do: nil
  def merge_provision(""), do: nil
  def merge_provision(value), do: String.trim(value)

  # ── 6. Region → extent_code Mapping ──────────────────────────────

  @doc """
  Map CSV Region column to compact extent_code.
  """
  @spec map_extent_code(String.t() | nil) :: String.t() | nil
  def map_extent_code(nil), do: nil
  def map_extent_code(""), do: nil

  def map_extent_code(region) do
    region = String.trim(region)

    cond do
      region == "" -> nil
      has_all_four?(region) -> "E+W+S+NI"
      has_three_ews?(region) -> "E+W+S"
      has_ewni?(region) -> "E+W+NI"
      has_es?(region) -> "E+S"
      has_ew?(region) -> "E+W"
      has_eni?(region) -> "E+NI"
      region == "England" -> "E"
      region == "Wales" -> "W"
      region == "Scotland" -> "S"
      region == "Northern Ireland" -> "NI"
      String.starts_with?(region, "GB") -> "E+W+S"
      String.starts_with?(region, "UK") -> "E+W+S+NI"
      true -> region
    end
  end

  defp has_all_four?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Wales") and
        String.contains?(r, "Scotland") and String.contains?(r, "Northern Ireland")

  defp has_three_ews?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Wales") and
        String.contains?(r, "Scotland") and not String.contains?(r, "Northern Ireland")

  defp has_ewni?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Wales") and
        String.contains?(r, "Northern Ireland") and not String.contains?(r, "Scotland")

  defp has_es?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Scotland") and
        not String.contains?(r, "Wales") and not String.contains?(r, "Northern Ireland")

  defp has_ew?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Wales") and
        not String.contains?(r, "Scotland") and not String.contains?(r, "Northern Ireland")

  defp has_eni?(r),
    do:
      String.contains?(r, "England") and String.contains?(r, "Northern Ireland") and
        not String.contains?(r, "Wales") and not String.contains?(r, "Scotland")

  # ── 7. Build Citation ────────────────────────────────────────────

  @doc """
  Build the citation string from section_type and structural columns.

  Returns the citation portion of section_id (without law_name prefix).

  ## Parameters
    - `section_type` - normalised section_type string
    - `opts` - keyword list with structural values:
      - `:provision` - section/regulation number
      - `:sub` - sub-section/sub-article number
      - `:paragraph` - paragraph number
      - `:sub_paragraph` - sub-paragraph number
      - `:schedule` - schedule number
      - `:heading_group` - heading group value
      - `:part` - part number
      - `:chapter` - chapter number
      - `:position` - fallback position integer
      - `:class` - instrument class (for article prefix: "Regulation" vs other)
  """
  @spec build_citation(String.t(), keyword()) :: String.t()
  def build_citation(section_type, opts \\ []) do
    provision = Keyword.get(opts, :provision)
    sub = Keyword.get(opts, :sub)
    paragraph = Keyword.get(opts, :paragraph)
    sub_paragraph = Keyword.get(opts, :sub_paragraph)
    schedule = Keyword.get(opts, :schedule)
    heading_group = Keyword.get(opts, :heading_group)
    part = Keyword.get(opts, :part)
    chapter = Keyword.get(opts, :chapter)
    position = Keyword.get(opts, :position, 0)
    class = Keyword.get(opts, :class)

    schedule_prefix = if schedule, do: "sch.#{schedule}.", else: ""

    case section_type do
      t when t in ["section", "sub_section"] ->
        base = "s.#{provision || position}"
        base = if sub, do: "#{base}(#{sub})", else: base
        base = if paragraph, do: "#{base}(#{paragraph})", else: base
        base = if sub_paragraph, do: "#{base}(#{sub_paragraph})", else: base
        "#{schedule_prefix}#{base}"

      t when t in ["article", "sub_article"] ->
        prefix = if class == "Regulation", do: "reg.", else: "art."
        base = "#{prefix}#{provision || position}"
        base = if sub, do: "#{base}(#{sub})", else: base
        base = if paragraph, do: "#{base}(#{paragraph})", else: base
        base = if sub_paragraph, do: "#{base}(#{sub_paragraph})", else: base
        "#{schedule_prefix}#{base}"

      "schedule" ->
        "sch.#{schedule || position}"

      "part" ->
        "#{schedule_prefix}pt.#{part || position}"

      "chapter" ->
        "#{schedule_prefix}ch.#{chapter || position}"

      "heading" ->
        "#{schedule_prefix}h.#{heading_group || position}"

      "title" ->
        "title.#{position}"

      "signed" ->
        "signed.#{position}"

      "commencement" ->
        "commencement.#{position}"

      "paragraph" ->
        base = "para.#{paragraph || provision || position}"
        base = if sub_paragraph, do: "#{base}(#{sub_paragraph})", else: base
        "#{schedule_prefix}#{base}"

      "sub_paragraph" ->
        para = paragraph || provision || position
        sub_p = sub_paragraph || position
        "#{schedule_prefix}para.#{para}(#{sub_p})"

      "table" ->
        "#{schedule_prefix}table.#{position}"

      "note" ->
        "#{schedule_prefix}note.#{position}"

      _ ->
        "#{section_type}.#{position}"
    end
  end

  # ── 8. Build sort_key ────────────────────────────────────────────

  @doc """
  Normalise a provision number into a lexicographically-sortable sort key segment.

  ## Examples

      iex> normalize_provision_to_sort_key("3")
      "003.000.000"
      iex> normalize_provision_to_sort_key("3A")
      "003.010.000"
      iex> normalize_provision_to_sort_key("3ZA")
      "003.001.000"
      iex> normalize_provision_to_sort_key("19DZA")
      "019.040.001"
      iex> normalize_provision_to_sort_key("")
      "000.000.000"
  """
  @spec normalize_provision_to_sort_key(String.t() | nil) :: String.t()
  def normalize_provision_to_sort_key(nil), do: "000.000.000"
  def normalize_provision_to_sort_key(""), do: "000.000.000"

  def normalize_provision_to_sort_key(s) do
    s = s |> String.trim() |> String.upcase()

    if s == "" do
      "000.000.000"
    else
      {base_num, suffix} = extract_leading_digits(s)
      segments = [base_num | parse_letter_suffixes(suffix, [])]
      segments = pad_segments(segments, 3)

      segments
      |> Enum.map(&String.pad_leading(Integer.to_string(&1), 3, "0"))
      |> Enum.join(".")
    end
  end

  defp extract_leading_digits(s) do
    case Regex.run(~r/^(\d+)(.*)$/, s) do
      [_, digits, rest] -> {String.to_integer(digits), rest}
      _ -> {0, s}
    end
  end

  defp parse_letter_suffixes("", acc), do: Enum.reverse(acc)
  defp parse_letter_suffixes(_, acc) when length(acc) >= 2, do: Enum.reverse(acc)

  defp parse_letter_suffixes(<<"Z", ch, rest::binary>>, acc)
       when ch >= ?A and ch <= ?Z do
    # Z-prefix: ZA=1, ZB=2, ..., ZZ=26
    value = ch - ?A + 1
    parse_letter_suffixes(rest, [value | acc])
  end

  defp parse_letter_suffixes(<<ch, rest::binary>>, acc)
       when ch >= ?A and ch <= ?Z do
    # Plain letter: A=10, B=20, ..., Z=260
    value = (ch - ?A + 1) * 10
    parse_letter_suffixes(rest, [value | acc])
  end

  defp parse_letter_suffixes(_, acc), do: Enum.reverse(acc)

  defp pad_segments(segments, target) when length(segments) >= target, do: segments

  defp pad_segments(segments, target) do
    segments ++ List.duplicate(0, target - length(segments))
  end

  @doc """
  Build the full sort_key for a LAT row.

  The sort key depends on section_type:
  - section/article/sub_* rows: normalize the provision number
  - heading rows: normalize the heading_group value
  - structural rows (title, part, chapter, schedule, signed, etc.): "000.000.000"
  - paragraph/sub_paragraph: normalize the paragraph number

  Appends `~extent` suffix for parallel territorial provisions.
  """
  @spec build_sort_key(String.t(), keyword()) :: String.t()
  def build_sort_key(section_type, opts \\ []) do
    provision = Keyword.get(opts, :provision)
    heading_group = Keyword.get(opts, :heading_group)
    paragraph = Keyword.get(opts, :paragraph)
    extent = Keyword.get(opts, :extent)

    base =
      case section_type do
        t when t in ["section", "sub_section", "article", "sub_article"] ->
          normalize_provision_to_sort_key(provision)

        "heading" ->
          normalize_provision_to_sort_key(heading_group)

        t when t in ["paragraph", "sub_paragraph"] ->
          normalize_provision_to_sort_key(paragraph || provision)

        _ ->
          "000.000.000"
      end

    if extent do
      "#{base}~#{extent}"
    else
      "#{base}~"
    end
  end

  # ── 11. Hierarchy Path Construction ──────────────────────────────

  @doc """
  Build the hierarchy_path from structural columns.

  Returns a slash-separated path like `part.1/heading.18/provision.25A/sub.1`.
  Returns nil for root-level rows.
  """
  @spec build_hierarchy_path(keyword()) :: String.t() | nil
  def build_hierarchy_path(opts) do
    schedule = Keyword.get(opts, :schedule)
    part = Keyword.get(opts, :part)
    chapter = Keyword.get(opts, :chapter)
    heading_group = Keyword.get(opts, :heading_group)
    provision = Keyword.get(opts, :provision)
    sub = Keyword.get(opts, :sub)
    paragraph = Keyword.get(opts, :paragraph)

    segments =
      []
      |> maybe_add("schedule", schedule)
      |> maybe_add("part", part)
      |> maybe_add("chapter", chapter)
      |> maybe_add("heading", heading_group)
      |> maybe_add("provision", provision)
      |> maybe_add("sub", sub)
      |> maybe_add("para", paragraph)
      |> Enum.reverse()

    case segments do
      [] -> nil
      segs -> Enum.join(segs, "/")
    end
  end

  defp maybe_add(segments, _label, nil), do: segments
  defp maybe_add(segments, _label, ""), do: segments
  defp maybe_add(segments, label, value), do: ["#{label}.#{value}" | segments]

  # ── 12. Depth Calculation ────────────────────────────────────────

  @doc """
  Calculate depth as the count of populated structural hierarchy levels.
  """
  @spec calculate_depth(keyword()) :: non_neg_integer()
  def calculate_depth(opts) do
    [:schedule, :part, :chapter, :heading_group, :provision, :sub, :paragraph]
    |> Enum.count(fn key ->
      val = Keyword.get(opts, key)
      val != nil and val != ""
    end)
  end

  # ── 13. Amendment Annotation Counts ──────────────────────────────

  @doc """
  Count F-code amendments from the Changes column.

  The Changes column contains comma-separated annotation codes like "F3,F2,F1".
  Count codes starting with "F" for amendment_count.
  """
  @spec count_amendments(String.t() | nil) :: non_neg_integer() | nil
  def count_amendments(nil), do: nil
  def count_amendments(""), do: nil

  def count_amendments(changes) do
    count =
      changes
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.count(&String.starts_with?(&1, "F"))

    if count > 0, do: count, else: nil
  end

  # ── Detect schedule from flow column ─────────────────────────────

  @non_schedule_flows MapSet.new(["pre", "main", "post", "signed", ""])

  @doc """
  Extract schedule number from the flow column.

  Flow values: "pre", "main", "post", "signed" are NOT schedules.
  Numeric values like "1", "2", "3" indicate schedule numbers.
  """
  @spec schedule_from_flow(String.t() | nil) :: String.t() | nil
  def schedule_from_flow(nil), do: nil

  def schedule_from_flow(flow) do
    flow = String.trim(flow)

    if MapSet.member?(@non_schedule_flows, flow) do
      nil
    else
      flow
    end
  end

  # ── XML Element → section_type Mapping ─────────────────────────

  @doc """
  Map an XML element name to a section_type string.

  The `mode` argument distinguishes Acts (`:section`) from SIs (`:article`).
  Acts use section/sub_section, SIs use article/sub_article.

  ## Examples

      iex> xml_element_to_section_type("Part", :section)
      "part"
      iex> xml_element_to_section_type("P1", :section)
      "section"
      iex> xml_element_to_section_type("P1", :article)
      "article"
      iex> xml_element_to_section_type("P2", :section)
      "sub_section"
      iex> xml_element_to_section_type("P2", :article)
      "sub_article"
  """
  @spec xml_element_to_section_type(String.t(), :section | :article) :: String.t() | nil
  def xml_element_to_section_type(element, mode \\ :section)

  def xml_element_to_section_type("Part", _mode), do: "part"
  def xml_element_to_section_type("Chapter", _mode), do: "chapter"
  def xml_element_to_section_type("Pblock", _mode), do: "heading"
  def xml_element_to_section_type("P1", :section), do: "section"
  def xml_element_to_section_type("P1", :article), do: "article"
  def xml_element_to_section_type("P2", :section), do: "sub_section"
  def xml_element_to_section_type("P2", :article), do: "sub_article"
  def xml_element_to_section_type("P3", _mode), do: "paragraph"
  def xml_element_to_section_type("P4", _mode), do: "sub_paragraph"
  def xml_element_to_section_type("Schedule", _mode), do: "schedule"
  def xml_element_to_section_type("SignedSection", _mode), do: "signed"
  def xml_element_to_section_type("Tabular", _mode), do: "table"
  def xml_element_to_section_type("Figure", _mode), do: "note"
  def xml_element_to_section_type(_element, _mode), do: nil

  # ── XML Extent Normalisation ─────────────────────────────────────

  @doc """
  Normalise a raw XML `RestrictExtent` attribute value to our compact extent_code.

  XML uses `E+W+S+N.I.` format; we normalise to `E+W+S+NI`.
  Also handles partial extents like `E+W`, `S+N.I.`, etc.

  ## Examples

      iex> normalize_xml_extent("E+W+S+N.I.")
      "E+W+S+NI"
      iex> normalize_xml_extent("E+W+S")
      "E+W+S"
      iex> normalize_xml_extent("N.I.")
      "NI"
      iex> normalize_xml_extent(nil)
      nil
  """
  @spec normalize_xml_extent(String.t() | nil) :: String.t() | nil
  def normalize_xml_extent(nil), do: nil
  def normalize_xml_extent(""), do: nil

  def normalize_xml_extent(extent) do
    extent
    |> String.replace("N.I.", "NI")
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  # ── Detect parallel territorial provisions ───────────────────────

  @doc """
  Given a list of {provision, extent_code} tuples for a single law,
  returns a MapSet of provision values that have parallel territorial versions.
  """
  @spec detect_parallel_provisions([{String.t() | nil, String.t() | nil}]) :: MapSet.t()
  def detect_parallel_provisions(provision_extent_pairs) do
    provision_extent_pairs
    |> Enum.filter(fn {prov, ext} -> prov != nil and prov != "" and ext != nil and ext != "" end)
    |> Enum.group_by(fn {prov, _ext} -> prov end)
    |> Enum.filter(fn {_prov, pairs} ->
      pairs |> Enum.map(fn {_, ext} -> ext end) |> Enum.uniq() |> length() > 1
    end)
    |> Enum.map(fn {prov, _} -> prov end)
    |> MapSet.new()
  end
end

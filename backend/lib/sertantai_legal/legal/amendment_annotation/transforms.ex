defmodule SertantaiLegal.Legal.AmendmentAnnotation.Transforms do
  @moduledoc """
  Pure transform functions for converting Airtable amendment CSV rows
  into amendment_annotations schema rows.

  CSV columns: ID, UK (or "UK (from Articles)"), Articles, Ef Code, Text

  All functions are pure (no DB access) for independent testing.
  """

  alias SertantaiLegal.Legal.Lat.Transforms, as: LatTransforms

  # ── 1. Header Variant Detection ──────────────────────────────────

  @doc """
  Detect which column name holds the law reference in a CSV header list.

  Three variants across the 17 export files:
    - "UK" (most files)
    - "UK (from Articles)" (Environmental-Protection, Pollution)
    - nil (Climate-Change — no UK column at all)
  """
  @spec detect_uk_column([String.t()]) :: String.t() | nil
  def detect_uk_column(headers) when is_list(headers) do
    cond do
      "UK" in headers -> "UK"
      "UK (from Articles)" in headers -> "UK (from Articles)"
      true -> nil
    end
  end

  # ── 2. Law Name Extraction ───────────────────────────────────────

  @doc """
  Extract the normalised law_name from the UK column value.

  Delegates to `Lat.Transforms.normalize_law_name/1` which handles both
  acronym-prefix (UK_ACRO_type_year_num) and acronym-suffix (UK_type_year_num_ACRO) forms.

  Returns nil for nil/empty input or unrecognisable formats (e.g., pre-1900 regnal years).
  """
  @spec extract_law_name(String.t() | nil) :: String.t() | nil
  def extract_law_name(nil), do: nil
  def extract_law_name(""), do: nil

  def extract_law_name(uk_value) do
    normalised = LatTransforms.normalize_law_name(uk_value)

    if normalised == uk_value and not Regex.match?(~r/^UK_[a-z]+_\d+_\d+$/, uk_value) do
      # normalize_law_name returned unchanged and it doesn't match the base pattern —
      # unrecognisable format (e.g., regnal year, apostrophe in name)
      nil
    else
      normalised
    end
  end

  @doc """
  Derive law_name from the amendment ID when no UK column is available.

  ID format: `{UK_value}_{Ef_Code}` e.g. `UK_ukpga_2006_19_CCSEA_F1`
  Strip the trailing `_F\\d+` or `_C\\d+` etc., then normalize.

  Returns nil for broken IDs (e.g., `_F25`).
  """
  @spec derive_law_name_from_id(String.t()) :: String.t() | nil
  def derive_law_name_from_id(id) when is_binary(id) do
    case Regex.run(~r/^(.+)_[FCIE]\d+$/, id) do
      [_, uk_with_acronym] when byte_size(uk_with_acronym) > 2 ->
        extract_law_name(uk_with_acronym)

      _ ->
        nil
    end
  end

  def derive_law_name_from_id(_), do: nil

  # ── 3. Code Type Classification ──────────────────────────────────

  @doc """
  Classify an annotation code (e.g., "F1", "C42") into a code_type atom.
  """
  @spec classify_code_type(String.t()) :: atom() | nil
  def classify_code_type("F" <> _), do: :amendment
  def classify_code_type("C" <> _), do: :modification
  def classify_code_type("I" <> _), do: :commencement
  def classify_code_type("E" <> _), do: :extent_editorial
  def classify_code_type(_), do: nil

  # ── 4. Affected Sections Parsing ─────────────────────────────────

  @doc """
  Parse the comma-separated Articles column into a list of legacy_id strings.

  Returns nil for empty/nil input, a list of trimmed non-empty strings otherwise.
  """
  @spec parse_affected_legacy_ids(String.t() | nil) :: [String.t()] | nil
  def parse_affected_legacy_ids(nil), do: nil
  def parse_affected_legacy_ids(""), do: nil

  def parse_affected_legacy_ids(articles) do
    ids =
      articles
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if ids == [], do: nil, else: ids
  end

  # ── 5. Annotation ID Construction ───────────────────────────────

  @doc """
  Build the synthetic annotation ID.

  Format: `{law_name}:{code_type}:{seq}`
  Example: `UK_ukpga_1974_37:amendment:1`
  """
  @spec build_annotation_id(String.t(), atom(), pos_integer()) :: String.t()
  def build_annotation_id(law_name, code_type, seq)
      when is_binary(law_name) and is_atom(code_type) and is_integer(seq) do
    "#{law_name}:#{code_type}:#{seq}"
  end

  # ── 6. BOM Stripping ─────────────────────────────────────────────

  @doc """
  Strip UTF-8 BOM (\\xEF\\xBB\\xBF) from the beginning of a string.

  All Airtable exports have a BOM prefix.
  """
  @spec strip_bom(String.t()) :: String.t()
  def strip_bom(<<0xEF, 0xBB, 0xBF, rest::binary>>), do: rest
  def strip_bom(str), do: str
end

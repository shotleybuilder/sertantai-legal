defmodule SertantaiLegal.Scraper.ParsedLaw do
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Scraper.LegislationGovUk.Helpers

  @moduledoc """
  Canonical representation of a parsed UK law.

  All scraper modules should work with this struct internally.
  This provides:
  - Single source of truth for data shape
  - Type safety with compile-time key validation
  - Normalized keys (always lowercase atoms)
  - JSONB conversion only at persistence time

  ## Usage

      # Create from any map (normalizes keys)
      law = ParsedLaw.from_map(%{"Title_EN" => "...", "Year" => 2024})

      # Access fields directly
      law.title_en
      law.year

      # Convert to DB format (wraps JSONB fields)
      attrs = ParsedLaw.to_db_attrs(law)

  ## Field Categories

  1. **Credentials** - Identifiers (name, title, year, number, type)
  2. **Description** - Classification (family, si_code, tags, subjects)
  3. **Status** - Enforcement state (live, live_description)
  4. **Geographic** - Extent and regions
  5. **Metadata** - Dates and document stats
  6. **Function** - Relationships (enacted_by, amending, etc.)
  7. **Taxa** - Role classifications (duty_holder, rights_holder, etc.)
  8. **Stats** - Amendment statistics
  9. **Internal** - Parse metadata (not persisted)
  """

  # ============================================================================
  # Type Definitions
  # ============================================================================

  @type t :: %__MODULE__{
          # === CREDENTIALS ===
          name: String.t() | nil,
          title_en: String.t() | nil,
          year: integer() | nil,
          number: String.t() | nil,
          number_int: integer() | nil,
          type_code: String.t() | nil,
          type_desc: String.t() | nil,
          type_class: String.t() | nil,
          domain: [String.t()],
          acronym: String.t() | nil,
          old_style_number: String.t() | nil,

          # === DESCRIPTION ===
          family: String.t() | nil,
          family_ii: String.t() | nil,
          si_code: [String.t()],
          tags: [String.t()],
          md_description: String.t() | nil,
          md_subjects: [String.t()],

          # === STATUS ===
          live: String.t() | nil,
          live_description: String.t() | nil,
          live_source: atom() | nil,
          live_conflict: boolean() | nil,
          live_from_changes: String.t() | nil,
          live_from_metadata: String.t() | nil,
          live_conflict_detail: map() | nil,

          # === GEOGRAPHIC EXTENT ===
          geo_extent: String.t() | nil,
          geo_region: [String.t()],
          geo_detail: String.t() | nil,
          md_restrict_extent: String.t() | nil,

          # === METADATA (Dates) ===
          md_date: Date.t() | nil,
          md_made_date: Date.t() | nil,
          md_enactment_date: Date.t() | nil,
          md_coming_into_force_date: Date.t() | nil,
          md_dct_valid_date: Date.t() | nil,
          md_modified: Date.t() | nil,
          md_restrict_start_date: Date.t() | nil,
          latest_amend_date: Date.t() | nil,
          latest_change_date: Date.t() | nil,
          latest_rescind_date: Date.t() | nil,

          # === METADATA (Document Stats) ===
          md_total_paras: integer() | nil,
          md_body_paras: integer() | nil,
          md_schedule_paras: integer() | nil,
          md_attachment_paras: integer() | nil,
          md_images: integer() | nil,

          # === FUNCTION (Purpose) ===
          function: map() | nil,
          purpose: [String.t()],
          is_making: boolean() | nil,
          is_commencing: boolean() | nil,
          is_amending: boolean() | nil,
          is_rescinding: boolean() | nil,
          is_enacting: boolean() | nil,

          # === FUNCTION (Relationships - all as name lists) ===
          enacted_by: [String.t()],
          enacted_by_meta: [map()],
          enacting: [String.t()],
          amended_by: [String.t()],
          amending: [String.t()],
          rescinded_by: [String.t()],
          rescinding: [String.t()],

          # === FUNCTION (Linked - graph edges) ===
          linked_enacted_by: [String.t()],
          linked_amending: [String.t()],
          linked_amended_by: [String.t()],
          linked_rescinding: [String.t()],
          linked_rescinded_by: [String.t()],

          # === TAXA (Roles - lists internally, JSONB {key: true} in DB) ===
          role: [String.t()],
          role_gvt: [String.t()],
          duty_type: [String.t()],
          duty_holder: [String.t()],
          rights_holder: [String.t()],
          responsibility_holder: [String.t()],
          power_holder: [String.t()],
          popimar: [String.t()],

          # === TAXA (Article mappings) ===
          # Phase 4 Issue #16: Removed deprecated text columns - article_role, role_article
          duty_type_article: String.t() | nil,
          article_duty_type: String.t() | nil,
          # === TAXA (Consolidated JSONB holder fields - Phase 4) ===
          duties: map() | nil,
          rights: map() | nil,
          responsibilities: map() | nil,
          powers: map() | nil,
          # === TAXA (Consolidated JSONB POPIMAR field - Phase 2 Issue #15) ===
          popimar_details: map() | nil,
          # === TAXA (Consolidated JSONB Role fields - Phase 2 Issue #16) ===
          role_details: map() | nil,
          role_gvt_details: map() | nil,
          # Phase 4: Removed deprecated text columns - popimar_article, popimar_article_clause, article_popimar, article_popimar_clause

          # === STATS (Amendment) ===
          stats_self_affects_count: integer() | nil,
          stats_self_affects_count_per_law_detailed: String.t() | nil,
          amending_stats_affects_count: integer() | nil,
          amending_stats_affected_laws_count: integer() | nil,
          amended_by_stats_affected_by_count: integer() | nil,
          amended_by_stats_affected_by_laws_count: integer() | nil,
          rescinding_stats_rescinding_laws_count: integer() | nil,
          rescinded_by_stats_rescinded_by_laws_count: integer() | nil,
          # Legacy text columns removed - replaced by JSONB:
          # - amending_stats_affects_count_per_law, amending_stats_affects_count_per_law_detailed
          # - amended_by_stats_affected_by_count_per_law, amended_by_stats_affected_by_count_per_law_detailed
          # - rescinding_stats_rescinding_count_per_law, rescinding_stats_rescinding_count_per_law_detailed
          # - rescinded_by_stats_rescinded_by_count_per_law, rescinded_by_stats_rescinded_by_count_per_law_detailed

          # === STATS (Consolidated JSONB - replaces *_per_law and *_per_law_detailed pairs) ===
          affects_stats_per_law: map() | nil,
          rescinding_stats_per_law: map() | nil,
          affected_by_stats_per_law: map() | nil,
          rescinded_by_stats_per_law: map() | nil,

          # === CHANGE LOGS ===
          amending_change_log: String.t() | nil,
          amended_by_change_log: String.t() | nil,
          record_change_log: [map()] | nil,

          # === INTERNAL (Parse metadata - not persisted) ===
          parse_stages: map(),
          parse_errors: [String.t()]
        }

  # ============================================================================
  # Struct Definition
  # ============================================================================

  defstruct [
    # Credentials
    name: nil,
    title_en: nil,
    year: nil,
    number: nil,
    number_int: nil,
    type_code: nil,
    type_desc: nil,
    type_class: nil,
    domain: [],
    acronym: nil,
    old_style_number: nil,

    # Description
    family: nil,
    family_ii: nil,
    si_code: [],
    tags: [],
    md_description: nil,
    md_subjects: [],

    # Status
    live: nil,
    live_description: nil,
    live_source: nil,
    live_conflict: nil,
    live_from_changes: nil,
    live_from_metadata: nil,
    live_conflict_detail: nil,

    # Geographic Extent
    geo_extent: nil,
    geo_region: [],
    geo_detail: nil,
    md_restrict_extent: nil,

    # Metadata (Dates)
    md_date: nil,
    md_made_date: nil,
    md_enactment_date: nil,
    md_coming_into_force_date: nil,
    md_dct_valid_date: nil,
    md_modified: nil,
    md_restrict_start_date: nil,
    latest_amend_date: nil,
    latest_change_date: nil,
    latest_rescind_date: nil,

    # Metadata (Document Stats)
    md_total_paras: nil,
    md_body_paras: nil,
    md_schedule_paras: nil,
    md_attachment_paras: nil,
    md_images: nil,

    # Function (Purpose)
    function: nil,
    purpose: [],
    is_making: nil,
    is_commencing: nil,
    is_amending: nil,
    is_rescinding: nil,
    is_enacting: nil,

    # Function (Relationships)
    enacted_by: [],
    enacted_by_meta: [],
    enacting: [],
    amended_by: [],
    amending: [],
    rescinded_by: [],
    rescinding: [],

    # Function (Linked)
    linked_enacted_by: [],
    linked_amending: [],
    linked_amended_by: [],
    linked_rescinding: [],
    linked_rescinded_by: [],

    # Taxa (Roles)
    role: [],
    role_gvt: [],
    duty_type: [],
    duty_holder: [],
    rights_holder: [],
    responsibility_holder: [],
    power_holder: [],
    popimar: [],

    # Taxa (Article mappings)
    # Phase 4 Issue #16: Removed deprecated text columns - article_role, role_article
    duty_type_article: nil,
    article_duty_type: nil,
    # Taxa (Consolidated JSONB holder fields - Phase 4)
    duties: nil,
    rights: nil,
    responsibilities: nil,
    powers: nil,
    # Taxa (Consolidated JSONB POPIMAR field - Phase 2 Issue #15)
    popimar_details: nil,
    # Taxa (Consolidated JSONB Role fields - Phase 2 Issue #16)
    role_details: nil,
    role_gvt_details: nil,
    # Phase 4: Removed deprecated text columns

    # Stats (Amendment)
    stats_self_affects_count: nil,
    stats_self_affects_count_per_law_detailed: nil,
    amending_stats_affects_count: nil,
    amending_stats_affected_laws_count: nil,
    amended_by_stats_affected_by_count: nil,
    amended_by_stats_affected_by_laws_count: nil,
    rescinding_stats_rescinding_laws_count: nil,
    rescinded_by_stats_rescinded_by_laws_count: nil,
    # Legacy text columns removed - replaced by JSONB *_per_law fields

    # Stats (Consolidated JSONB)
    affects_stats_per_law: nil,
    rescinding_stats_per_law: nil,
    affected_by_stats_per_law: nil,
    rescinded_by_stats_per_law: nil,

    # Change Logs
    amending_change_log: nil,
    amended_by_change_log: nil,
    record_change_log: nil,

    # Internal (Parse metadata)
    parse_stages: %{},
    parse_errors: []
  ]

  # ============================================================================
  # Key Mappings (Capitalized → lowercase)
  # ============================================================================

  # Maps legacy capitalized keys to canonical lowercase keys
  @key_aliases %{
    # Credentials
    "Title_EN" => :title_en,
    :Title_EN => :title_en,
    "Year" => :year,
    :Year => :year,
    "Number" => :number,
    :Number => :number,
    "Name" => :name,
    :Name => :name,
    "Type" => :type_desc,
    :Type => :type_desc,
    "Acronym" => :acronym,
    :Acronym => :acronym,

    # Description
    "Family" => :family,
    :Family => :family,
    "SICode" => :si_code,
    :SICode => :si_code,
    "Tags" => :tags,
    :Tags => :tags,

    # Status
    "Live?" => :live,
    :Live? => :live,
    "Live?_description" => :live_description,
    :"Live?_description" => :live_description,

    # Geographic
    "Geo_Extent" => :geo_extent,
    :Geo_Extent => :geo_extent,
    "Geo_Region" => :geo_region,
    :Geo_Region => :geo_region,
    "Geo_Pan_Region" => :geo_detail,
    :Geo_Pan_Region => :geo_detail,

    # Relationships (donor field names)
    "Enacted_by" => :enacted_by,
    :Enacted_by => :enacted_by,
    "Enacting" => :enacting,
    :Enacting => :enacting,
    "Amending" => :amending,
    :Amending => :amending,
    "Amended_by" => :amended_by,
    :Amended_by => :amended_by,
    "Revoking" => :rescinding,
    :Revoking => :rescinding,
    "Revoked_by" => :rescinded_by,
    :Revoked_by => :rescinded_by,

    # Taxa (donor field names)
    "actor" => :role,
    :actor => :role,
    "actor_gvt" => :role_gvt,
    :actor_gvt => :role_gvt
  }

  # Fields that store lists internally but convert to {"values": [...]} JSONB in DB
  @values_jsonb_fields [:si_code, :md_subjects, :duty_type, :purpose]

  # Fields that store lists internally but convert to {key: true, ...} JSONB in DB
  @key_map_jsonb_fields [
    :role_gvt,
    :duty_holder,
    :rights_holder,
    :responsibility_holder,
    :power_holder,
    :popimar
  ]

  # Internal fields (not persisted to DB)
  @internal_fields [:parse_stages, :parse_errors]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Create a ParsedLaw from any map, normalizing keys.

  This is the ONLY way to create a ParsedLaw - ensures consistent format.
  Handles both capitalized (legacy) and lowercase keys.

  ## Examples

      iex> ParsedLaw.from_map(%{"Title_EN" => "Test Act", "Year" => 2024})
      %ParsedLaw{title_en: "Test Act", year: 2024, ...}

      iex> ParsedLaw.from_map(%{title_en: "Test Act", year: 2024})
      %ParsedLaw{title_en: "Test Act", year: 2024, ...}
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    # First, normalize all keys to canonical lowercase atoms
    normalized = normalize_keys(map)

    # Then build the struct with proper type coercion
    %__MODULE__{
      # Credentials
      name: get_name(normalized, :name),
      title_en: get_title(normalized, :title_en),
      year: get_integer(normalized, :year),
      number: get_string(normalized, :number),
      number_int: get_integer(normalized, :number_int),
      type_code: get_string(normalized, :type_code),
      type_desc: get_string(normalized, :type_desc),
      type_class: get_string(normalized, :type_class),
      domain: get_list(normalized, :domain),
      acronym: get_string(normalized, :acronym),
      old_style_number: get_string(normalized, :old_style_number),

      # Description
      family: get_string(normalized, :family),
      family_ii: get_string(normalized, :family_ii),
      si_code: get_list(normalized, :si_code),
      tags: get_list(normalized, :tags),
      md_description: get_string(normalized, :md_description),
      md_subjects: get_list(normalized, :md_subjects),

      # Status
      live: get_string(normalized, :live),
      live_description: get_string(normalized, :live_description),
      live_source: get_atom(normalized, :live_source),
      live_conflict: get_boolean(normalized, :live_conflict),
      live_from_changes: get_string(normalized, :live_from_changes),
      live_from_metadata: get_string(normalized, :live_from_metadata),
      live_conflict_detail: get_map(normalized, :live_conflict_detail),

      # Geographic Extent
      geo_extent: get_string(normalized, :geo_extent),
      geo_region: get_list(normalized, :geo_region),
      geo_detail: get_string(normalized, :geo_detail),
      md_restrict_extent: get_string(normalized, :md_restrict_extent),

      # Metadata (Dates)
      md_date: get_date(normalized, :md_date),
      md_made_date: get_date(normalized, :md_made_date),
      md_enactment_date: get_date(normalized, :md_enactment_date),
      md_coming_into_force_date: get_date(normalized, :md_coming_into_force_date),
      md_dct_valid_date: get_date(normalized, :md_dct_valid_date),
      md_modified: get_date(normalized, :md_modified),
      md_restrict_start_date: get_date(normalized, :md_restrict_start_date),
      latest_amend_date: get_date(normalized, :latest_amend_date),
      latest_change_date: get_date(normalized, :latest_change_date),
      latest_rescind_date: get_date(normalized, :latest_rescind_date),

      # Metadata (Document Stats)
      md_total_paras: get_integer(normalized, :md_total_paras),
      md_body_paras: get_integer(normalized, :md_body_paras),
      md_schedule_paras: get_integer(normalized, :md_schedule_paras),
      md_attachment_paras: get_integer(normalized, :md_attachment_paras),
      md_images: get_integer(normalized, :md_images),

      # Function (Purpose)
      function: get_map(normalized, :function),
      purpose: get_list(normalized, :purpose),
      is_making: get_boolean(normalized, :is_making),
      is_commencing: get_boolean(normalized, :is_commencing),
      is_amending: get_boolean(normalized, :is_amending),
      is_rescinding: get_boolean(normalized, :is_rescinding),
      is_enacting: get_boolean(normalized, :is_enacting),

      # Function (Relationships) - extract names from maps or pass through strings
      enacted_by: get_name_list(normalized, :enacted_by),
      enacted_by_meta: get_enacted_by_meta(normalized),
      enacting: get_name_list(normalized, :enacting),
      amended_by: get_name_list(normalized, :amended_by),
      amending: get_name_list(normalized, :amending),
      rescinded_by: get_name_list(normalized, :rescinded_by),
      rescinding: get_name_list(normalized, :rescinding),

      # Function (Linked)
      linked_enacted_by: get_list(normalized, :linked_enacted_by),
      linked_amending: get_list(normalized, :linked_amending),
      linked_amended_by: get_list(normalized, :linked_amended_by),
      linked_rescinding: get_list(normalized, :linked_rescinding),
      linked_rescinded_by: get_list(normalized, :linked_rescinded_by),

      # Taxa (Roles)
      role: get_list(normalized, :role),
      role_gvt: get_list(normalized, :role_gvt),
      duty_type: get_list(normalized, :duty_type),
      duty_holder: get_list(normalized, :duty_holder),
      rights_holder: get_list(normalized, :rights_holder),
      responsibility_holder: get_list(normalized, :responsibility_holder),
      power_holder: get_list(normalized, :power_holder),
      popimar: get_list(normalized, :popimar),

      # Taxa (Article mappings)
      # Phase 4 Issue #16: Removed deprecated text columns - article_role, role_article
      duty_type_article: get_string(normalized, :duty_type_article),
      article_duty_type: get_string(normalized, :article_duty_type),
      # Taxa (Consolidated JSONB holder fields - Phase 4)
      duties: get_map(normalized, :duties),
      rights: get_map(normalized, :rights),
      responsibilities: get_map(normalized, :responsibilities),
      powers: get_map(normalized, :powers),
      # Taxa (Consolidated JSONB POPIMAR field - Phase 2 Issue #15)
      popimar_details: get_map(normalized, :popimar_details),
      # Taxa (Consolidated JSONB Role fields - Phase 2 Issue #16)
      role_details: get_map(normalized, :role_details),
      role_gvt_details: get_map(normalized, :role_gvt_details),
      # Phase 4: Removed deprecated text columns

      # Stats (Amendment)
      stats_self_affects_count: get_integer(normalized, :stats_self_affects_count),
      stats_self_affects_count_per_law_detailed:
        get_string(normalized, :stats_self_affects_count_per_law_detailed),
      amending_stats_affects_count: get_integer(normalized, :amending_stats_affects_count),
      amending_stats_affected_laws_count:
        get_integer(normalized, :amending_stats_affected_laws_count),
      amended_by_stats_affected_by_count:
        get_integer(normalized, :amended_by_stats_affected_by_count),
      amended_by_stats_affected_by_laws_count:
        get_integer(normalized, :amended_by_stats_affected_by_laws_count),
      rescinding_stats_rescinding_laws_count:
        get_integer(normalized, :rescinding_stats_rescinding_laws_count),
      rescinded_by_stats_rescinded_by_laws_count:
        get_integer(normalized, :rescinded_by_stats_rescinded_by_laws_count),

      # Stats (Consolidated JSONB - replaced legacy text columns)
      affects_stats_per_law: get_map(normalized, :affects_stats_per_law),
      rescinding_stats_per_law: get_map(normalized, :rescinding_stats_per_law),
      affected_by_stats_per_law: get_map(normalized, :affected_by_stats_per_law),
      rescinded_by_stats_per_law: get_map(normalized, :rescinded_by_stats_per_law),

      # Change Logs
      amending_change_log: get_string(normalized, :amending_change_log),
      amended_by_change_log: get_string(normalized, :amended_by_change_log),
      record_change_log: get_list(normalized, :record_change_log),

      # Internal (Parse metadata)
      parse_stages: normalized[:parse_stages] || %{},
      parse_errors: normalized[:parse_errors] || []
    }
  end

  @doc """
  Merge new data into an existing ParsedLaw.

  Only updates fields that have non-nil, non-empty values in the new data.
  Useful for staged parsing where each stage adds new fields.

  ## Examples

      iex> law = ParsedLaw.from_map(%{title_en: "Test"})
      iex> ParsedLaw.merge(law, %{year: 2024, si_code: ["CODE"]})
      %ParsedLaw{title_en: "Test", year: 2024, si_code: ["CODE"], ...}
  """
  @spec merge(t(), map()) :: t()
  def merge(%__MODULE__{} = law, new_data) when is_map(new_data) do
    new_law = from_map(new_data)

    # Merge each field, keeping existing value if new is nil/empty
    struct_fields()
    |> Enum.reduce(law, fn field, acc ->
      new_value = Map.get(new_law, field)
      old_value = Map.get(acc, field)

      if should_update?(field, new_value, old_value) do
        Map.put(acc, field, new_value)
      else
        acc
      end
    end)
  end

  @doc """
  Convert to map format suitable for DB persistence.

  This is where JSONB wrapping happens:
  - si_code, md_subjects, duty_type → %{"values" => [...]}
  - role_gvt, duty_holder, etc. → %{key => true, ...}

  Excludes internal fields (parse_stages, parse_errors).
  """
  @spec to_db_attrs(t()) :: map()
  def to_db_attrs(%__MODULE__{} = law) do
    law
    |> derive_domain_from_family()
    |> Map.from_struct()
    |> Map.drop(@internal_fields)
    |> wrap_values_jsonb_fields()
    |> wrap_key_map_jsonb_fields()
    |> reject_nil_and_empty()
  end

  @doc """
  Convert to map format for diff comparison.

  Unlike to_db_attrs, this keeps lists as lists (no JSONB wrapping)
  so we can compare scraper output (lists) with unwrapped DB values.
  """
  @spec to_comparison_map(t()) :: map()
  def to_comparison_map(%__MODULE__{} = law) do
    law
    |> Map.from_struct()
    |> Map.drop(@internal_fields)
    |> reject_nil_and_empty()
  end

  @doc """
  Create a ParsedLaw from a UkLrt database record.

  Unwraps JSONB fields back to lists for internal use.
  """
  @spec from_db_record(map() | struct()) :: t()
  def from_db_record(%{__struct__: _} = record) do
    record
    |> Map.from_struct()
    |> Map.drop([
      :__meta__,
      :id,
      :inserted_at,
      :updated_at,
      :created_at,
      :calculations,
      :aggregates
    ])
    |> unwrap_jsonb_fields()
    |> from_map()
  end

  def from_db_record(map) when is_map(map) do
    map
    |> unwrap_jsonb_fields()
    |> from_map()
  end

  @doc """
  Get the list of all struct field names.
  """
  @spec struct_fields() :: [atom()]
  def struct_fields do
    __MODULE__.__struct__()
    |> Map.keys()
    |> List.delete(:__struct__)
  end

  # ============================================================================
  # Private Helpers - Key Normalization
  # ============================================================================

  defp normalize_keys(map) do
    map
    |> Enum.map(fn {key, value} ->
      canonical_key = normalize_key(key)
      {canonical_key, value}
    end)
    |> Enum.into(%{})
  end

  defp normalize_key(key) when is_atom(key) do
    case Map.get(@key_aliases, key) do
      nil -> key
      canonical -> canonical
    end
  end

  defp normalize_key(key) when is_binary(key) do
    # First check if it's an aliased key
    case Map.get(@key_aliases, key) do
      nil ->
        # Not aliased, convert to atom (snake_case assumed)
        key
        |> String.downcase()
        |> String.to_atom()

      canonical ->
        canonical
    end
  end

  defp normalize_key(key), do: key

  # ============================================================================
  # Private Helpers - Type Coercion
  # ============================================================================

  defp get_string(map, key) do
    case Map.get(map, key) do
      nil -> nil
      val when is_binary(val) -> if val == "", do: nil, else: val
      val -> to_string(val)
    end
  end

  # Title gets cleaned: removes "The " prefix, year suffix, "(repealed)", "(revoked)"
  defp get_title(map, key) do
    case Map.get(map, key) do
      nil -> nil
      val when is_binary(val) and val != "" -> Helpers.title_clean(val)
      _ -> nil
    end
  end

  # Name gets normalized to DB format: uksi/2025/622 -> UK_uksi_2025_622
  defp get_name(map, key) do
    case Map.get(map, key) do
      nil -> nil
      val when is_binary(val) and val != "" -> IdField.normalize_to_db_name(val)
      _ -> nil
    end
  end

  defp get_integer(map, key) do
    case Map.get(map, key) do
      nil -> nil
      val when is_integer(val) -> val
      val when is_binary(val) -> parse_integer(val)
      val when is_float(val) -> round(val)
      _ -> nil
    end
  end

  defp parse_integer(str) do
    case Integer.parse(str) do
      {int, ""} -> int
      {int, _} -> int
      :error -> nil
    end
  end

  defp get_boolean(map, key) do
    case Map.get(map, key) do
      nil -> nil
      true -> true
      false -> false
      "true" -> true
      "false" -> false
      1 -> true
      0 -> false
      x when x == 1.0 -> true
      x when x == 0.0 -> false
      _ -> nil
    end
  end

  defp get_atom(map, key) do
    case Map.get(map, key) do
      nil -> nil
      val when is_atom(val) -> val
      val when is_binary(val) -> String.to_existing_atom(val)
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp get_date(map, key) do
    case Map.get(map, key) do
      nil -> nil
      %Date{} = date -> date
      str when is_binary(str) -> parse_date(str)
      _ -> nil
    end
  end

  defp parse_date(""), do: nil

  defp parse_date(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp get_list(map, key) do
    case Map.get(map, key) do
      nil -> []
      list when is_list(list) -> list
      # Handle JSONB {"values": [...]} format from DB
      %{"values" => list} when is_list(list) -> list
      # Handle JSONB {key: true, ...} format from DB
      map when is_map(map) -> Map.keys(map)
      # Handle comma-separated string
      str when is_binary(str) -> parse_list_string(str)
      _ -> []
    end
  end

  defp parse_list_string(""), do: []

  defp parse_list_string(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # Get list of names from relationship fields (enacted_by, amending, etc.)
  # These may come as rich maps from StagedParser or simple strings from DB
  defp get_name_list(map, key) do
    case Map.get(map, key) do
      nil -> []
      list when is_list(list) -> extract_names(list)
      str when is_binary(str) -> [str]
      _ -> []
    end
  end

  # Extract name field from list of maps or pass through strings
  defp extract_names(list) do
    list
    |> Enum.map(fn
      %{name: name} when is_binary(name) -> name
      %{"name" => name} when is_binary(name) -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Get list of metadata maps from relationship fields
  # Filters to only include actual maps (not strings)
  defp get_meta_list(map, key) do
    case Map.get(map, key) do
      nil -> []
      list when is_list(list) -> extract_meta_maps(list)
      _ -> []
    end
  end

  # Extract only map entries, converting atom keys to string keys for JSONB
  defp extract_meta_maps(list) do
    list
    |> Enum.filter(&is_map/1)
    |> Enum.map(&stringify_keys/1)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  # Get enacted_by_meta: use explicit key if present, otherwise extract from enacted_by
  # This handles both cases:
  # 1. Input has enacted_by_meta already (from DB or explicit)
  # 2. Input has enacted_by as list of maps (from StagedParser) - extract metadata
  defp get_enacted_by_meta(map) do
    case Map.get(map, :enacted_by_meta) do
      list when is_list(list) and list != [] ->
        # Use explicit enacted_by_meta if present and non-empty
        extract_meta_maps(list)

      _ ->
        # Fall back to extracting from enacted_by field
        get_meta_list(map, :enacted_by)
    end
  end

  defp get_map(map, key) do
    case Map.get(map, key) do
      nil -> nil
      m when is_map(m) -> m
      _ -> nil
    end
  end

  # ============================================================================
  # Private Helpers - JSONB Conversion
  # ============================================================================

  defp wrap_values_jsonb_fields(map) do
    Enum.reduce(@values_jsonb_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        list when is_list(list) and list != [] ->
          Map.put(acc, field, %{"values" => list})

        _ ->
          acc
      end
    end)
  end

  defp wrap_key_map_jsonb_fields(map) do
    Enum.reduce(@key_map_jsonb_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        list when is_list(list) and list != [] ->
          key_map = Enum.reduce(list, %{}, fn item, m -> Map.put(m, item, true) end)
          Map.put(acc, field, key_map)

        _ ->
          acc
      end
    end)
  end

  defp unwrap_jsonb_fields(map) do
    map
    |> unwrap_values_jsonb()
    |> unwrap_key_map_jsonb()
  end

  defp unwrap_values_jsonb(map) do
    Enum.reduce(@values_jsonb_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        %{"values" => list} when is_list(list) -> Map.put(acc, field, list)
        _ -> acc
      end
    end)
  end

  defp unwrap_key_map_jsonb(map) do
    Enum.reduce(@key_map_jsonb_fields, map, fn field, acc ->
      case Map.get(acc, field) do
        m when is_map(m) and m != %{} -> Map.put(acc, field, Map.keys(m))
        _ -> acc
      end
    end)
  end

  # ============================================================================
  # Private Helpers - Merge Logic
  # ============================================================================

  defp should_update?(field, _new_value, _old_value) when field in @internal_fields do
    # Always update internal fields
    true
  end

  defp should_update?(_field, nil, _old_value), do: false
  defp should_update?(_field, [], _old_value), do: false
  defp should_update?(_field, "", _old_value), do: false
  defp should_update?(_field, map, _old_value) when is_map(map), do: map != %{}
  defp should_update?(_field, _new_value, _old_value), do: true

  defp reject_nil_and_empty(map) do
    map
    |> Enum.reject(fn {_k, v} ->
      is_nil(v) or v == [] or v == "" or v == %{}
    end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private Helpers - Domain Derivation
  # ============================================================================

  # Domain emoji mappings from family field
  @domain_emoji_map %{
    "💚" => "environment",
    "💙" => "health_safety",
    "🖤" => "governance",
    "💜" => "human_resources"
  }

  @doc false
  defp derive_domain_from_family(%__MODULE__{domain: domain} = law)
       when is_list(domain) and domain != [] do
    # Domain already set, don't override
    law
  end

  defp derive_domain_from_family(%__MODULE__{family: nil, family_ii: nil} = law) do
    # No family data to derive from
    law
  end

  defp derive_domain_from_family(%__MODULE__{family: family, family_ii: family_ii} = law) do
    # Derive domains from both family and family_ii
    domains =
      [family, family_ii]
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&extract_domain_from_family/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    %{law | domain: domains}
  end

  defp extract_domain_from_family(family_value) when is_binary(family_value) do
    # Check first character (emoji) against domain map
    case String.first(family_value) do
      nil -> nil
      first_char -> Map.get(@domain_emoji_map, first_char)
    end
  end

  defp extract_domain_from_family(_), do: nil
end

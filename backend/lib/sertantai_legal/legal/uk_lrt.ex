defmodule SertantaiLegal.Legal.UkLrt do
  @moduledoc """
  UK Legal Register Table (LRT) - Reference data for UK legislation.

  This resource stores metadata for UK laws, regulations, and statutory instruments.
  It is SHARED REFERENCE DATA - no organization_id (accessible to all tenants).

  ## Key Fields
  - `family` / `family_ii`: Primary/secondary classification (e.g., "Environment", "Health & Safety")
  - `function`: JSONB indicating law type - Making, Amending, Revoking, Commencing, Enacting
  - `duty_holder` / `power_holder` / `rights_holder`: JSONB fields for applicability screening
  - `geo_extent` / `geo_region`: Geographic scope of the law
  - `live` / `live_description`: Current enforcement status

  ## Data Source
  19,000+ records imported from legislation.gov.uk and enhanced with SertantAI metadata.

  ## Usage
  This data is used for:
  1. Legal applicability screening (matching laws to business activities)
  2. Compliance register generation
  3. Change tracking and amendment monitoring
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table("uk_lrt")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Core Identifiers
    attribute :family, :string do
      allow_nil?(true)
      description("Primary family classification (e.g., Environment, Health & Safety)")
    end

    attribute :family_ii, :string do
      allow_nil?(true)
      description("Secondary family classification")
    end

    attribute :name, :string do
      allow_nil?(true)
      description("Short reference name")
    end

    attribute :title_en, :string do
      allow_nil?(true)
      description("Full English title of the legislation")
    end

    attribute :year, :integer do
      allow_nil?(true)
      description("Year of enactment")
    end

    attribute :number, :string do
      allow_nil?(true)
      description("Legislation number (e.g., 'SI 2024/123')")
    end

    attribute :number_int, :integer do
      allow_nil?(true)
      writable?(false)
      description("Numeric legislation number - generated from number field")
    end

    attribute :acronym, :string do
      allow_nil?(true)
      description("Common acronym (e.g., 'COSHH', 'RIDDOR')")
    end

    attribute :old_style_number, :string do
      allow_nil?(true)
      description("Historical numbering format")
    end

    # Type Classification
    attribute :type_desc, :string do
      allow_nil?(true)
      description("Full type description (e.g., 'UK Public General Acts')")
    end

    attribute :type_code, :string do
      allow_nil?(true)
      description("Type code (e.g., 'ukpga', 'uksi')")
    end

    attribute :type_class, :string do
      allow_nil?(true)
      description("Type class (Primary, Secondary)")
    end

    attribute :domain, {:array, :string} do
      allow_nil?(true)
      description("Regulatory domain(s): environment, health_safety, human_resources")
    end

    # Status
    attribute :live, :string do
      allow_nil?(true)
      description("Enforcement status (e.g., '✔ In force', '✗ Revoked')")
    end

    attribute :live_description, :string do
      allow_nil?(true)
      description("Detailed status description")
    end

    attribute :live_source, :string do
      allow_nil?(true)
      description("Source of live status: 'metadata', 'changes', or 'both'")
    end

    attribute :live_conflict, :boolean do
      allow_nil?(true)
      description("Whether live status sources disagreed")
    end

    attribute :live_from_changes, :string do
      allow_nil?(true)
      description("Live status derived from /changes/affected endpoint")
    end

    attribute :live_from_metadata, :string do
      allow_nil?(true)
      description("Live status derived from /resources/data.xml endpoint")
    end

    attribute :live_conflict_detail, :map do
      allow_nil?(true)
      description("Details of live status conflict: reason, winner, severities (JSONB)")
    end

    # Geographic Scope
    attribute :geo_extent, :string do
      allow_nil?(true)
      description("Geographic extent (e.g., 'E+W+S+NI', 'E+W')")
    end

    attribute :geo_region, {:array, :string} do
      allow_nil?(true)
      description("Specific regions covered (e.g. England, Wales, Scotland, Northern Ireland)")
    end

    attribute :geo_detail, :string do
      allow_nil?(true)

      description(
        "Section-by-section extent breakdown (e.g., '🇬🇧 E+W+S+NI💚️section-1, section-2💚️🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿 E+W💚️section-61')"
      )
    end

    attribute :md_restrict_extent, :string do
      allow_nil?(true)
      description("Restriction extent from legislation.gov.uk")
    end

    # Holder Fields (for applicability screening)
    attribute :duty_holder, :map do
      allow_nil?(true)
      description("Entities with duties under this law (JSONB)")
    end

    attribute :power_holder, :map do
      allow_nil?(true)
      description("Entities granted powers by this law (JSONB)")
    end

    attribute :rights_holder, :map do
      allow_nil?(true)
      description("Entities granted rights by this law (JSONB)")
    end

    attribute :responsibility_holder, :map do
      allow_nil?(true)
      description("Entities with responsibilities under this law (JSONB)")
    end

    # Purpose and Function
    attribute :purpose, :map do
      allow_nil?(true)
      description("Legal purposes and objectives (JSONB)")
    end

    attribute :function, :map do
      allow_nil?(true)
      description("Function: Making, Amending, Revoking, Commencing, Enacting (JSONB)")
    end

    attribute :popimar, :map do
      allow_nil?(true)
      description("POPIMAR framework classification (JSONB)")
    end

    attribute :si_code, :map do
      allow_nil?(true)
      description("Statutory Instrument code classification (JSONB)")
    end

    attribute :md_subjects, :map do
      allow_nil?(true)
      description("Subject matter classification (JSONB)")
    end

    # Role and Government
    attribute :role, {:array, :string} do
      allow_nil?(true)
      description("Role classifications")
    end

    attribute :role_gvt, :map do
      allow_nil?(true)
      description("Government role classifications (JSONB)")
    end

    attribute :role_gvt_article, :string do
      allow_nil?(true)
      description("Role GVT to Article mapping")
    end

    attribute :article_role_gvt, :string do
      allow_nil?(true)
      description("Article to Role GVT mapping")
    end

    attribute :article_role, :string do
      allow_nil?(true)
      description("Article to Role mapping")
    end

    attribute :role_article, :string do
      allow_nil?(true)
      description("Role to Article mapping")
    end

    # Duty Type
    attribute :duty_type, :map do
      allow_nil?(true)
      description("Duty type classification as JSONB {values: [...]}")
    end

    attribute :duty_type_article, :string do
      allow_nil?(true)
      description("Duty Type to Article mapping")
    end

    attribute :article_duty_type, :string do
      allow_nil?(true)
      description("Article to Duty Type mapping")
    end

    # Duty Holder Article References
    attribute :duty_holder_article, :string do
      allow_nil?(true)
      description("Duty Holder to Article mapping")
    end

    attribute :duty_holder_article_clause, :string do
      allow_nil?(true)
      description("Duty Holder Article Clause details")
    end

    attribute :article_duty_holder, :string do
      allow_nil?(true)
      description("Article to Duty Holder mapping")
    end

    attribute :article_duty_holder_clause, :string do
      allow_nil?(true)
      description("Article Duty Holder Clause details")
    end

    # Power Holder Article References
    attribute :power_holder_article, :string do
      allow_nil?(true)
      description("Power Holder to Article mapping")
    end

    attribute :power_holder_article_clause, :string do
      allow_nil?(true)
      description("Power Holder Article Clause details")
    end

    attribute :article_power_holder, :string do
      allow_nil?(true)
      description("Article to Power Holder mapping")
    end

    attribute :article_power_holder_clause, :string do
      allow_nil?(true)
      description("Article Power Holder Clause details")
    end

    # Rights Holder Article References
    attribute :rights_holder_article, :string do
      allow_nil?(true)
      description("Rights Holder to Article mapping")
    end

    attribute :rights_holder_article_clause, :string do
      allow_nil?(true)
      description("Rights Holder Article Clause details")
    end

    attribute :article_rights_holder, :string do
      allow_nil?(true)
      description("Article to Rights Holder mapping")
    end

    attribute :article_rights_holder_clause, :string do
      allow_nil?(true)
      description("Article Rights Holder Clause details")
    end

    # Responsibility Holder Article References
    attribute :responsibility_holder_article, :string do
      allow_nil?(true)
      description("Responsibility Holder to Article mapping")
    end

    attribute :responsibility_holder_article_clause, :string do
      allow_nil?(true)
      description("Responsibility Holder Article Clause details")
    end

    attribute :article_responsibility_holder, :string do
      allow_nil?(true)
      description("Article to Responsibility Holder mapping")
    end

    attribute :article_responsibility_holder_clause, :string do
      allow_nil?(true)
      description("Article Responsibility Holder Clause details")
    end

    # Consolidated Holder JSONB columns (replace 16 text columns above)
    # Schema: {entries: [{holder, article, duty_type, clause}], holders: [], articles: []}
    attribute :duties, :map do
      allow_nil?(true)
      description("Consolidated duty holder/article/clause data as JSONB")
    end

    attribute :rights, :map do
      allow_nil?(true)
      description("Consolidated rights holder/article/clause data as JSONB")
    end

    attribute :responsibilities, :map do
      allow_nil?(true)
      description("Consolidated responsibility holder/article/clause data as JSONB")
    end

    attribute :powers, :map do
      allow_nil?(true)
      description("Consolidated power holder/article/clause data as JSONB")
    end

    # POPIMAR Article References
    attribute :popimar_article, :string do
      allow_nil?(true)
      description("POPIMAR to Article mapping")
    end

    attribute :popimar_article_clause, :string do
      allow_nil?(true)
      description("POPIMAR Article Clause details")
    end

    attribute :article_popimar, :string do
      allow_nil?(true)
      description("Article to POPIMAR mapping")
    end

    attribute :article_popimar_clause, :string do
      allow_nil?(true)
      description("Article POPIMAR Clause details")
    end

    attribute :tags, {:array, :string} do
      allow_nil?(true)
      description("Searchable tags")
    end

    # Description
    attribute :md_description, :string do
      allow_nil?(true)
      description("Markdown description of the legislation")
    end

    # Document Statistics (from legislation.gov.uk)
    attribute :md_total_paras, :integer do
      allow_nil?(true)
      description("Total paragraph count")
    end

    attribute :md_body_paras, :integer do
      allow_nil?(true)
      description("Body paragraph count")
    end

    attribute :md_schedule_paras, :integer do
      allow_nil?(true)
      description("Schedule paragraph count")
    end

    attribute :md_attachment_paras, :integer do
      allow_nil?(true)
      description("Attachment paragraph count")
    end

    attribute :md_images, :integer do
      allow_nil?(true)
      description("Image count in document")
    end

    # Amendment/Relationship Tracking
    attribute :amending, {:array, :string} do
      allow_nil?(true)
      description("Laws this legislation amends")
    end

    attribute :amended_by, {:array, :string} do
      allow_nil?(true)
      description("Laws that have amended this legislation")
    end

    attribute :rescinding, {:array, :string} do
      allow_nil?(true)
      description("Laws this legislation rescinds/revokes")
    end

    attribute :rescinded_by, {:array, :string} do
      allow_nil?(true)
      description("Laws that have rescinded this legislation")
    end

    attribute :enacting, {:array, :string} do
      allow_nil?(true)
      description("Laws this legislation enacts")
    end

    attribute :enacted_by, {:array, :string} do
      allow_nil?(true)
      description("Parent enabling legislation (names for self-referential links)")
    end

    attribute :enacted_by_meta, {:array, :map} do
      allow_nil?(true)
      description("Parent enabling legislation metadata (name, number, uri, year, type_code)")
    end

    # Linked Relationship Arrays (for graph visualization)
    attribute :linked_amending, {:array, :string} do
      allow_nil?(true)
      description("Linked laws this legislation amends (graph edges)")
    end

    attribute :linked_amended_by, {:array, :string} do
      allow_nil?(true)
      description("Linked laws that amended this (graph edges)")
    end

    attribute :linked_rescinding, {:array, :string} do
      allow_nil?(true)
      description("Linked laws this rescinds/revokes (graph edges)")
    end

    attribute :linked_rescinded_by, {:array, :string} do
      allow_nil?(true)
      description("Linked laws that rescinded this (graph edges)")
    end

    attribute :linked_enacted_by, {:array, :string} do
      allow_nil?(true)
      description("Linked parent enabling legislation (graph edges)")
    end

    # Boolean Flags
    attribute :is_amending, :boolean do
      allow_nil?(true)
      description("Whether this primarily amends other laws")
    end

    attribute :is_rescinding, :boolean do
      allow_nil?(true)
      description("Whether this primarily rescinds other laws")
    end

    attribute :is_enacting, :boolean do
      allow_nil?(true)
      description("Whether this is enabling legislation")
    end

    attribute :is_making, :boolean do
      allow_nil?(true)
      description("Making function flag (creates duties, used in screening)")
    end

    attribute :is_commencing, :boolean do
      allow_nil?(true)
      description("Commencing function flag (brings other laws into force)")
    end

    # Amendment Stats - Self-affects (shared across amending/amended_by)
    attribute(:stats_self_affects_count, :integer,
      source: :"🔺🔻_stats_self_affects_count",
      allow_nil?: true,
      description: "Number of amendments this law makes to itself"
    )

    attribute(:stats_self_affects_count_per_law_detailed, :string,
      source: :"🔺🔻_stats_self_affects_count_per_law_detailed",
      allow_nil?: true,
      description: "Detailed breakdown of self-amendments (coming into force provisions, etc.)"
    )

    # Amendment Stats - Amending (🔺 this law affects others)
    attribute(:amending_stats_affects_count, :integer,
      source: :"🔺_stats_affects_count",
      allow_nil?: true,
      description: "Total number of amendments made by this law"
    )

    attribute(:amending_stats_affected_laws_count, :integer,
      source: :"🔺_stats_affected_laws_count",
      allow_nil?: true,
      description: "Number of distinct laws amended by this law"
    )

    attribute(:amending_stats_affects_count_per_law, :string,
      source: :"🔺_stats_affects_count_per_law",
      allow_nil?: true,
      description: "Summary list of amendments per law"
    )

    attribute(:amending_stats_affects_count_per_law_detailed, :string,
      source: :"🔺_stats_affects_count_per_law_detailed",
      allow_nil?: true,
      description: "Detailed breakdown with sections"
    )

    # Amendment Stats - Amended_by (🔻 this law is affected by others)
    attribute(:amended_by_stats_affected_by_count, :integer,
      source: :"🔻_stats_affected_by_count",
      allow_nil?: true,
      description: "Total amendments made to this law"
    )

    attribute(:amended_by_stats_affected_by_laws_count, :integer,
      source: :"🔻_stats_affected_by_laws_count",
      allow_nil?: true,
      description: "Number of distinct laws amending this"
    )

    attribute(:amended_by_stats_affected_by_count_per_law, :string,
      source: :"🔻_stats_affected_by_count_per_law",
      allow_nil?: true,
      description: "Summary list of amending laws"
    )

    attribute(:amended_by_stats_affected_by_count_per_law_detailed, :string,
      source: :"🔻_stats_affected_by_count_per_law_detailed",
      allow_nil?: true,
      description: "Detailed breakdown with sections"
    )

    # Rescinding Stats (🔺 this law rescinds/revokes others)
    attribute(:rescinding_stats_rescinding_laws_count, :integer,
      source: :"🔺_stats_rescinding_laws_count",
      allow_nil?: true,
      description: "Number of distinct laws rescinded by this law"
    )

    attribute(:rescinding_stats_rescinding_count_per_law, :string,
      source: :"🔺_stats_rescinding_count_per_law",
      allow_nil?: true,
      description: "Summary list of rescinded laws"
    )

    attribute(:rescinding_stats_rescinding_count_per_law_detailed, :string,
      source: :"🔺_stats_rescinding_count_per_law_detailed",
      allow_nil?: true,
      description: "Detailed breakdown of rescissions"
    )

    # Rescinded_by Stats (🔻 this law is rescinded/revoked by others)
    attribute(:rescinded_by_stats_rescinded_by_laws_count, :integer,
      source: :"🔻_stats_rescinded_by_laws_count",
      allow_nil?: true,
      description: "Number of distinct laws rescinding this"
    )

    attribute(:rescinded_by_stats_rescinded_by_count_per_law, :string,
      source: :"🔻_stats_rescinded_by_count_per_law",
      allow_nil?: true,
      description: "Summary list of rescinding laws"
    )

    attribute(:rescinded_by_stats_rescinded_by_count_per_law_detailed, :string,
      source: :"🔻_stats_rescinded_by_count_per_law_detailed",
      allow_nil?: true,
      description: "Detailed breakdown of rescissions"
    )

    # ============================================================================
    # Consolidated Stats per Law (JSONB) - replaces summary + detailed text pairs
    # ============================================================================

    # 🔺 Outbound: This law affects others
    attribute(:affects_stats_per_law, :map,
      source: :"🔺_affects_stats_per_law",
      allow_nil?: true,
      description: "JSONB: Amendments this law makes to others, keyed by law name"
    )

    attribute(:rescinding_stats_per_law, :map,
      source: :"🔺_rescinding_stats_per_law",
      allow_nil?: true,
      description: "JSONB: Repeals/revokes this law makes to others, keyed by law name"
    )

    # 🔻 Inbound: Others affect this law
    attribute(:affected_by_stats_per_law, :map,
      source: :"🔻_affected_by_stats_per_law",
      allow_nil?: true,
      description: "JSONB: Amendments made to this law by others, keyed by law name"
    )

    attribute(:rescinded_by_stats_per_law, :map,
      source: :"🔻_rescinded_by_stats_per_law",
      allow_nil?: true,
      description: "JSONB: Repeals/revokes made to this law by others, keyed by law name"
    )

    # Change Logs (Legacy - text based)
    attribute :amending_change_log, :string do
      allow_nil?(true)
      description("History of amending field changes (legacy)")
    end

    attribute :amended_by_change_log, :string do
      allow_nil?(true)
      description("History of amended_by field changes (legacy)")
    end

    # Unified Change Log (JSONB - captures all field changes)
    attribute :record_change_log, {:array, :map} do
      allow_nil?(true)

      description(
        "Unified change log for all field changes. Array of entries with timestamp, changed_by, source, and changes map."
      )
    end

    # Key Dates
    create_timestamp :created_at do
      description("Record creation timestamp")
    end

    update_timestamp :updated_at do
      description("Record update timestamp")
    end

    attribute :md_date, :date do
      allow_nil?(true)
      description("Primary date from legislation")
    end

    attribute :md_made_date, :date do
      allow_nil?(true)
      description("Date made (for SIs)")
    end

    attribute :md_enactment_date, :date do
      allow_nil?(true)
      description("Date of enactment")
    end

    attribute :md_coming_into_force_date, :date do
      allow_nil?(true)
      description("Coming into force date")
    end

    attribute :md_dct_valid_date, :date do
      allow_nil?(true)
      description("DCT valid date from legislation.gov.uk")
    end

    attribute :md_modified, :date do
      allow_nil?(true)
      description("Last modified date from legislation.gov.uk")
    end

    attribute :md_restrict_start_date, :date do
      allow_nil?(true)
      description("Restriction start date from legislation.gov.uk")
    end

    attribute :latest_amend_date, :date do
      allow_nil?(true)
      description("Date of most recent amendment")
    end

    attribute :latest_change_date, :date do
      allow_nil?(true)
      description("Date of most recent change")
    end

    attribute :latest_rescind_date, :date do
      allow_nil?(true)
      description("Date of most recent rescission/revocation")
    end

    # External Reference (PostgreSQL generated column)
    attribute :leg_gov_uk_url, :string do
      allow_nil?(true)
      writable?(false)
      description("legislation.gov.uk URL - generated from type_code/year/number")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new UK LRT record")
      primary?(true)
      # Explicit accept list required in Ash 3 (accept :* only works for public attributes)
      accept([
        :name,
        :title_en,
        :type_code,
        :type_desc,
        :type_class,
        :year,
        :number,
        :family,
        :family_ii,
        :acronym,
        :old_style_number,
        :domain,
        :live,
        :live_description,
        :live_source,
        :live_conflict,
        :live_from_changes,
        :live_from_metadata,
        :live_conflict_detail,
        :geo_extent,
        :geo_region,
        :geo_detail,
        :md_restrict_extent,
        :md_restrict_start_date,
        :si_code,
        :md_subjects,
        :md_description,
        :md_total_paras,
        :md_body_paras,
        :md_schedule_paras,
        :md_attachment_paras,
        :md_images,
        :md_date,
        :md_enactment_date,
        :md_made_date,
        :md_coming_into_force_date,
        :md_dct_valid_date,
        :md_modified,
        :latest_amend_date,
        :latest_change_date,
        :latest_rescind_date,
        :amending,
        :amended_by,
        :rescinding,
        :rescinded_by,
        :enacting,
        :enacted_by,
        :enacted_by_meta,
        :linked_amending,
        :linked_amended_by,
        :linked_rescinding,
        :linked_rescinded_by,
        :linked_enacted_by,
        :is_amending,
        :is_rescinding,
        :is_enacting,
        :is_making,
        :is_commencing,
        :function,
        :purpose,
        :popimar,
        :duty_holder,
        :power_holder,
        :rights_holder,
        :responsibility_holder,
        :role,
        :role_gvt,
        :role_gvt_article,
        :article_role_gvt,
        :article_role,
        :role_article,
        :duty_type,
        :duty_type_article,
        :article_duty_type,
        :duty_holder_article,
        :duty_holder_article_clause,
        :article_duty_holder,
        :article_duty_holder_clause,
        :power_holder_article,
        :power_holder_article_clause,
        :article_power_holder,
        :article_power_holder_clause,
        :rights_holder_article,
        :rights_holder_article_clause,
        :article_rights_holder,
        :article_rights_holder_clause,
        :responsibility_holder_article,
        :responsibility_holder_article_clause,
        :article_responsibility_holder,
        :article_responsibility_holder_clause,
        :popimar_article,
        :popimar_article_clause,
        :article_popimar,
        :article_popimar_clause,
        :tags,
        :stats_self_affects_count,
        :stats_self_affects_count_per_law_detailed,
        :amending_stats_affects_count,
        :amending_stats_affected_laws_count,
        :amending_stats_affects_count_per_law,
        :amending_stats_affects_count_per_law_detailed,
        :amended_by_stats_affected_by_count,
        :amended_by_stats_affected_by_laws_count,
        :amended_by_stats_affected_by_count_per_law,
        :amended_by_stats_affected_by_count_per_law_detailed,
        :rescinding_stats_rescinding_laws_count,
        :rescinding_stats_rescinding_count_per_law,
        :rescinding_stats_rescinding_count_per_law_detailed,
        :rescinded_by_stats_rescinded_by_laws_count,
        :rescinded_by_stats_rescinded_by_count_per_law,
        :rescinded_by_stats_rescinded_by_count_per_law_detailed,
        # Consolidated JSONB stats
        :affects_stats_per_law,
        :rescinding_stats_per_law,
        :affected_by_stats_per_law,
        :rescinded_by_stats_per_law,
        :amending_change_log,
        :amended_by_change_log,
        :record_change_log
      ])
    end

    update :update do
      description("Update an existing UK LRT record")
      # Same explicit accept list for updates
      accept([
        :name,
        :title_en,
        :type_code,
        :type_desc,
        :type_class,
        :year,
        :number,
        :family,
        :family_ii,
        :acronym,
        :old_style_number,
        :domain,
        :live,
        :live_description,
        :live_source,
        :live_conflict,
        :live_from_changes,
        :live_from_metadata,
        :live_conflict_detail,
        :geo_extent,
        :geo_region,
        :geo_detail,
        :md_restrict_extent,
        :md_restrict_start_date,
        :si_code,
        :md_subjects,
        :md_description,
        :md_total_paras,
        :md_body_paras,
        :md_schedule_paras,
        :md_attachment_paras,
        :md_images,
        :md_date,
        :md_enactment_date,
        :md_made_date,
        :md_coming_into_force_date,
        :md_dct_valid_date,
        :md_modified,
        :latest_amend_date,
        :latest_change_date,
        :latest_rescind_date,
        :amending,
        :amended_by,
        :rescinding,
        :rescinded_by,
        :enacting,
        :enacted_by,
        :enacted_by_meta,
        :linked_amending,
        :linked_amended_by,
        :linked_rescinding,
        :linked_rescinded_by,
        :linked_enacted_by,
        :is_amending,
        :is_rescinding,
        :is_enacting,
        :is_making,
        :is_commencing,
        :function,
        :purpose,
        :popimar,
        :duty_holder,
        :power_holder,
        :rights_holder,
        :responsibility_holder,
        :role,
        :role_gvt,
        :role_gvt_article,
        :article_role_gvt,
        :article_role,
        :role_article,
        :duty_type,
        :duty_type_article,
        :article_duty_type,
        :duty_holder_article,
        :duty_holder_article_clause,
        :article_duty_holder,
        :article_duty_holder_clause,
        :power_holder_article,
        :power_holder_article_clause,
        :article_power_holder,
        :article_power_holder_clause,
        :rights_holder_article,
        :rights_holder_article_clause,
        :article_rights_holder,
        :article_rights_holder_clause,
        :responsibility_holder_article,
        :responsibility_holder_article_clause,
        :article_responsibility_holder,
        :article_responsibility_holder_clause,
        :popimar_article,
        :popimar_article_clause,
        :article_popimar,
        :article_popimar_clause,
        :tags,
        :stats_self_affects_count,
        :stats_self_affects_count_per_law_detailed,
        :amending_stats_affects_count,
        :amending_stats_affected_laws_count,
        :amending_stats_affects_count_per_law,
        :amending_stats_affects_count_per_law_detailed,
        :amended_by_stats_affected_by_count,
        :amended_by_stats_affected_by_laws_count,
        :amended_by_stats_affected_by_count_per_law,
        :amended_by_stats_affected_by_count_per_law_detailed,
        :rescinding_stats_rescinding_laws_count,
        :rescinding_stats_rescinding_count_per_law,
        :rescinding_stats_rescinding_count_per_law_detailed,
        :rescinded_by_stats_rescinded_by_laws_count,
        :rescinded_by_stats_rescinded_by_count_per_law,
        :rescinded_by_stats_rescinded_by_count_per_law_detailed,
        # Consolidated JSONB stats
        :affects_stats_per_law,
        :rescinding_stats_per_law,
        :affected_by_stats_per_law,
        :rescinded_by_stats_per_law,
        :amending_change_log,
        :amended_by_change_log,
        :record_change_log
      ])
    end

    update :update_enacting do
      description("Update enacting array and is_enacting flag")
      accept([:enacting, :is_enacting])
    end

    read :by_id do
      description("Get a single record by ID")
      get?(true)
      argument(:id, :uuid, allow_nil?: false)
      filter(expr(id == ^arg(:id)))
    end

    read :by_family do
      description("Filter records by family classification")
      argument(:family, :string, allow_nil?: false)
      filter(expr(family == ^arg(:family)))
      pagination(offset?: true, keyset?: true, default_limit: 50)
    end

    read :by_family_ii do
      description("Filter records by secondary family classification")
      argument(:family_ii, :string, allow_nil?: false)
      filter(expr(family_ii == ^arg(:family_ii)))
      pagination(offset?: true, keyset?: true, default_limit: 50)
    end

    read :by_families do
      description("Filter records by both family classifications")
      argument(:family, :string, allow_nil?: true)
      argument(:family_ii, :string, allow_nil?: true)

      filter(
        expr(
          if is_nil(^arg(:family)) do
            true
          else
            family == ^arg(:family)
          end and
            if is_nil(^arg(:family_ii)) do
              true
            else
              family_ii == ^arg(:family_ii)
            end
        )
      )

      pagination(offset?: true, keyset?: true, default_limit: 50)
    end

    read :paginated do
      description("Paginated read with optional filtering and search")
      argument(:family, :string, allow_nil?: true)
      argument(:year, :integer, allow_nil?: true)
      argument(:type_code, :string, allow_nil?: true)
      argument(:status, :string, allow_nil?: true)
      argument(:search, :string, allow_nil?: true)

      filter(
        expr(
          if is_nil(^arg(:family)) do
            true
          else
            family == ^arg(:family)
          end and
            if is_nil(^arg(:year)) do
              true
            else
              year == ^arg(:year)
            end and
            if is_nil(^arg(:type_code)) do
              true
            else
              type_code == ^arg(:type_code)
            end and
            if is_nil(^arg(:status)) do
              true
            else
              live == ^arg(:status)
            end and
            if is_nil(^arg(:search)) do
              true
            else
              fragment("? ILIKE ?", title_en, fragment("'%' || ? || '%'", ^arg(:search))) or
                fragment("? ILIKE ?", number, fragment("'%' || ? || '%'", ^arg(:search))) or
                fragment("? ILIKE ?", name, fragment("'%' || ? || '%'", ^arg(:search)))
            end
        )
      )

      pagination(offset?: true, keyset?: true, default_limit: 50)
    end

    read :for_applicability_screening do
      description("Get duty-creating laws for applicability screening (Making function only)")
      argument(:family, :string, allow_nil?: true)
      argument(:geo_extent, :string, allow_nil?: true)
      argument(:live_status, :string, default: "✔ In force")

      filter(
        expr(
          fragment("? \\? ?", function, "Making") and
            live == ^arg(:live_status) and
            if is_nil(^arg(:family)) do
              true
            else
              family == ^arg(:family)
            end and
            if is_nil(^arg(:geo_extent)) do
              true
            else
              geo_extent == ^arg(:geo_extent)
            end
        )
      )

      prepare(build(sort: [year: :desc, latest_amend_date: :desc]))
      pagination(offset?: true, default_limit: 100)
    end

    read :distinct_families do
      description("Get distinct family values")
      prepare(build(select: [:family], distinct: [:family]))
    end

    read :distinct_family_ii do
      description("Get distinct family_ii values")
      prepare(build(select: [:family_ii], distinct: [:family_ii]))
      filter(expr(not is_nil(family_ii)))
    end

    read :distinct_years do
      description("Get distinct year values")
      prepare(build(select: [:year], distinct: [:year]))
      filter(expr(not is_nil(year)))
    end

    read :distinct_type_codes do
      description("Get distinct type_code values")
      prepare(build(select: [:type_code], distinct: [:type_code]))
      filter(expr(not is_nil(type_code)))
    end

    read :distinct_statuses do
      description("Get distinct live status values")
      prepare(build(select: [:live], distinct: [:live]))
      filter(expr(not is_nil(live)))
    end

    read :in_force do
      description("Get all currently in-force legislation")
      filter(expr(live == "✔ In force"))
      pagination(offset?: true, keyset?: true, default_limit: 50)
    end

    read :recently_amended do
      description("Get legislation amended in the last year")

      filter(
        expr(
          not is_nil(latest_amend_date) and
            fragment("? > CURRENT_DATE - INTERVAL '1 year'", latest_amend_date)
        )
      )

      prepare(build(sort: [latest_amend_date: :desc]))
      pagination(offset?: true, default_limit: 50)
    end
  end

  calculations do
    calculate :display_name,
              :string,
              expr(coalesce(name, title_en, fragment("CONCAT('Record #', ?)", id))) do
      description("Best available display name")
    end

    calculate :title_with_year,
              :string,
              expr(fragment("CONCAT(?, ' (', ?, ')')", title_en, year)) do
      description("Title with year in parentheses")
    end
  end

  # JSON API configuration
  json_api do
    type("uk_lrt")

    routes do
      base("/api/uk-lrt")
      get(:by_id, route: "/:id")
      index(:read)
      index(:paginated, route: "/search")
      index(:for_applicability_screening, route: "/screening")
      index(:distinct_families, route: "/distinct/families")
      index(:distinct_years, route: "/distinct/years")
      index(:in_force, route: "/in-force")
      index(:recently_amended, route: "/recently-amended")
    end
  end

  # Code interface for programmatic access
  code_interface do
    domain(SertantaiLegal.Api)
    define(:read)
    define(:by_id, args: [:id])
    define(:by_family, args: [:family])
    define(:by_family_ii, args: [:family_ii])
    define(:by_families, args: [:family, :family_ii])
    define(:paginated, args: [:family, :year, :type_code, :status, :search])
    define(:for_applicability_screening, args: [:family, :geo_extent, :live_status])
    define(:distinct_families)
    define(:distinct_years)
    define(:in_force)
    define(:recently_amended)
  end
end

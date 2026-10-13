defmodule SertantaiLegal.Legal.LatChangeLog do
  @moduledoc """
  The change register (lat-refactor LR-22/LR-23): legal changes to provisions
  LAT holds, one row per change, source and target row, with its evidence.
  Row change labels on `legal_articles` are a projection of it (LR-24).

  Not `lat_changes` (`LatParseLog`): that logs how our copy changed between
  parses; this logs how the law changed.

  - `source`: `effect` (changes feed), `markup` (our CLML change markup),
    `law` (the amending or commencing law's text). Notes are never a source;
    a note's code may be the `pointer` that carried a join.
  - `via`: how the change reached the row, strongest first —
    `markup` | `whole` | `ref` | `note_markup` | `note_own` | `note_cited`;
    empty with `section_id` nil when it reached no row (a visible gap).
  - Compact (LR-23 D3): one record per run of consecutive rows a change
    reached (`section_id` … `section_id_to`, by `position`); the view
    `lat_change_log_rows` expands them to one row per LAT row.
  - Written per law by `ChangeCollector` (delete + insert per law and
    collector), so a law's records always match its latest parse.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("lat_change_log")
    repo(SertantaiLegal.Repo)

    custom_statements do
      # LR-23 D3: compact records expanded to one row per LAT row reached
      # (positions from section_id to section_id_to); unreached records kept
      statement :lat_change_log_rows do
        up("""
        CREATE VIEW lat_change_log_rows AS
        SELECT c.id AS change_log_id, c.law_name, a.section_id, c.via, c.pointer, c.source,
               c.evidence, c.affected_ref, c.affecting_law, c.affecting_ref, c.operation,
               c.effect_type, c.effective_from, c.in_force, c.prospective, c.applied, c.savings,
               c.affected_extent, c.effect_extent, c.territorial_application, c.dated_by_law,
               c.dated_by_ref, c.collector, c.collected_at
        FROM lat_change_log c
        JOIN legal_articles f ON f.law_name = c.law_name AND f.section_id = c.section_id
        LEFT JOIN legal_articles t ON t.law_name = c.law_name AND t.section_id = c.section_id_to
        JOIN legal_articles a ON a.law_name = c.law_name
         AND a.position BETWEEN f.position AND COALESCE(t.position, f.position)
        UNION ALL
        SELECT c.id, c.law_name, NULL, c.via, c.pointer, c.source, c.evidence, c.affected_ref,
               c.affecting_law, c.affecting_ref, c.operation, c.effect_type, c.effective_from,
               c.in_force, c.prospective, c.applied, c.savings, c.affected_extent,
               c.effect_extent, c.territorial_application, c.dated_by_law, c.dated_by_ref,
               c.collector, c.collected_at
        FROM lat_change_log c
        WHERE c.section_id IS NULL
        """)

        down("DROP VIEW IF EXISTS lat_change_log_rows")
      end
    end

    custom_indexes do
      index([:law_name, :section_id])
      index([:evidence])
      index([:affecting_law])
      index([:law_name, :collector])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:law_name, :string, allow_nil?: false, public?: true)

    attribute(:section_id, :string,
      public?: true,
      description: "first LAT row the change reached; nil when it reached none"
    )

    attribute(:section_id_to, :string,
      public?: true,
      description: "last row of a run of consecutive rows (by position); nil: one row"
    )

    attribute(:via, {:array, :string}, allow_nil?: false, default: [], public?: true)

    attribute(:pointer, :string,
      public?: true,
      description: "the note (code) whose placement carried the join"
    )

    attribute :source, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(effect|markup|law)$/)
    end

    attribute(:evidence, :string,
      allow_nil?: false,
      public?: true,
      description: "effect id | ChangeId | the provision read (ukpga/2000/27/section/60)"
    )

    attribute(:affected_ref, :string, public?: true)
    attribute(:affecting_law, :string, public?: true)
    attribute(:affecting_ref, :string, public?: true)

    attribute(:operation, :string,
      public?: true,
      description: "substituted | inserted | repealed | renumbered | amended | commenced | other"
    )

    attribute(:effect_type, :string, public?: true, description: "the source's own wording")
    attribute(:effective_from, :date, public?: true)
    attribute(:in_force, {:array, :map}, allow_nil?: false, default: [], public?: true)
    attribute(:prospective, :boolean, public?: true)
    attribute(:applied, :boolean, public?: true)
    attribute(:savings, {:array, :string}, allow_nil?: false, default: [], public?: true)
    attribute(:affected_extent, :string, public?: true)
    attribute(:effect_extent, :string, public?: true)
    attribute(:territorial_application, :string, public?: true)

    attribute(:dated_by_law, :string,
      public?: true,
      description: "the law fixing the date (the amending law, or its commencement order)"
    )

    attribute(:dated_by_ref, :string, public?: true)

    attribute(:collector, :string,
      allow_nil?: false,
      public?: true,
      description: "feed | markup | amending_law | commencing_law"
    )

    attribute :collected_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
    end
  end

  actions do
    defaults([:read])
  end
end

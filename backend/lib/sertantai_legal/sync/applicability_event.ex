defmodule SertantaiLegal.Sync.ApplicabilityEvent do
  @moduledoc """
  Insert-only audit log for applicability screening changes.

  One row per change — tracks when laws are added, removed, seeded,
  confirmed, or excluded from an org's legal register. Powers the
  activity feed, undo, and regulatory defensibility trail.

  ## Event types

  **Screening events** (user or screener actions):
  - `added`, `removed`, `excluded`, `seeded`, `confirmed`, `restored`, `bulk_seeded`

  **Change detection events** (system-generated after scrape/enrichment):
  - `law_status_changed` — repeal, part-revocation, commencement
  - `new_law_available` — new Making law matches org profile
  - `match_score_changed` — DRRP/fitness enrichment changed relevance

  **Decision events** (human response to change detection):
  - `change_reviewed` — user opened and assessed a flagged change
  - `change_kept` — user decided to keep a repealed/deprecated law
  - `change_archived` — user decided to archive a repealed law
  - `change_dismissed` — user dismissed a new law suggestion
  - `change_accepted` — user accepted a new law into register

  ## Materiality

  Auto-classified on change detection events:
  - `major` — full/part repeal, new Making law, duty holder change
  - `moderate` — DRRP actor change, family reclassification
  - `minor` — fitness change only, cosmetic status update
  - `informational` — metadata only (title, description)

  "SertantAI recommends; the duty holder decides."
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("applicability_events")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
    end

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :event, :string do
      allow_nil?(false)

      description("""
      Event type. Screening: added, removed, excluded, seeded, confirmed, restored, bulk_seeded.
      Change detection: law_status_changed, new_law_available, match_score_changed.
      Decision: change_reviewed, change_kept, change_archived, change_dismissed, change_accepted.
      """)
    end

    attribute :actor, :string do
      allow_nil?(false)
      description("User email or 'sertantai' for automated actions")
    end

    attribute :status_before, :string do
      description("Previous status (null for first event on a law)")
    end

    attribute :status_after, :string do
      allow_nil?(false)
      description("New status after this event")
    end

    attribute :source, :string do
      allow_nil?(false)
      description("manual, screener, enhesa_import, change_detection, enrichment")
    end

    attribute :metadata, :map do
      description("Extensible JSONB: match_reason, notes, profile_snapshot, undone_event_id")
    end

    # Change management fields (Phase A)

    attribute :materiality, :string do
      description(
        "Auto-classified: major, moderate, minor, informational. Null for screening events."
      )
    end

    attribute :decision, :string do
      description("Org decision: archive, keep, dismiss, add. Null until reviewed.")
    end

    attribute :decision_reason, :string do
      description(
        "Free text rationale for the decision. Required for major/moderate materiality."
      )
    end

    attribute :review_due_date, :date do
      description(
        "When this change should be revisited. Auto-set by materiality: major 30d, moderate 60d, minor 90d."
      )
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :log do
      accept([
        :organization_id,
        :law_name,
        :event,
        :actor,
        :status_before,
        :status_after,
        :source,
        :metadata,
        :materiality,
        :decision,
        :decision_reason,
        :review_due_date
      ])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_law do
      argument(:organization_id, :uuid, allow_nil?: false)
      argument(:law_name, :string, allow_nil?: false)

      filter(expr(organization_id == ^arg(:organization_id) and law_name == ^arg(:law_name)))

      prepare(build(sort: [inserted_at: :desc]))
    end

    read :most_recent do
      argument(:organization_id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(organization_id == ^arg(:organization_id)))
      prepare(build(sort: [inserted_at: :desc], limit: 1))
    end

    read :pending_changes do
      argument(:organization_id, :uuid, allow_nil?: false)

      filter(
        expr(
          organization_id == ^arg(:organization_id) and
            is_nil(decision) and
            event in [
              "law_status_changed",
              "new_law_available",
              "match_score_changed"
            ]
        )
      )

      prepare(build(sort: [materiality: :asc, inserted_at: :desc]))
    end

    read :overdue_reviews do
      argument(:organization_id, :uuid, allow_nil?: false)

      filter(
        expr(
          organization_id == ^arg(:organization_id) and
            is_nil(decision) and
            not is_nil(review_due_date) and
            review_due_date < ^Date.utc_today()
        )
      )

      prepare(build(sort: [review_due_date: :asc]))
    end
  end

  code_interface do
    define(:log)
    define(:by_organization, args: [:organization_id])
    define(:by_law, args: [:organization_id, :law_name])
    define(:most_recent, args: [:organization_id])
    define(:pending_changes, args: [:organization_id])
    define(:overdue_reviews, args: [:organization_id])
  end
end

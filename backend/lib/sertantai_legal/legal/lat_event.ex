defmodule SertantaiLegal.Legal.LatEvent do
  @moduledoc """
  Append-only history of a law's LAT (enrichment readiness, 2026-09-27):
  `parsed`, `enriched` and `discarded` events.

  LAT is kept only for Making laws, so a not-Making verdict is often reached by
  parsing (and perhaps enriching) LAT that is then deleted. These events keep
  that evidence after the rows are gone.

  - `parsed` / `discarded` are written by statement-level triggers on
    `legal_articles` (every write path, including raw SQL), with context
    from `SET LOCAL sertantai.lat.{source,actor,reason,archive_ref,app_version}`.
    A `discarded` event means the law's LAT is gone after the statement and the
    reason is not `reparse` (a merge re-parse replaces rows). A delete with no
    reason is recorded as `unknown`. One event per law per operation
    (`sertantai.lat.op_id`, else the transaction).
  - `enriched` events are written by the TaxaSubscriber, one per model family,
    with fractalaw's provenance when it sends it.
  - `archive_ref` points at the NAS copy of discarded LAT (`LatArchive`).

  Read `latest per law` via `(law_name, at DESC)`.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("lat_events")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:law_name, :at])
      index([:law_id, :at])
      index([:event])
      index([:enrichment_run_id])

      index([:law_id, :country, :event, :op_key],
        unique: true,
        where: "op_key IS NOT NULL",
        name: "lat_events_one_per_txn"
      )
    end
  end

  attributes do
    integer_primary_key(:id)

    attribute(:law_id, :uuid, allow_nil?: false, public?: true)
    attribute(:country, :string, allow_nil?: false, public?: true)
    attribute(:law_name, :string, allow_nil?: false, public?: true)

    attribute :event, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(parsed|enriched|discarded)$/)
      description("parsed | enriched | discarded")
    end

    attribute :family, :string do
      public?(true)
      description("enriched only: triage | taxa | fitness | significance")
    end

    attribute :at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
    end

    attribute(:source, :string, public?: true)
    attribute(:actor, :string, public?: true)
    attribute(:app_version, :string, public?: true)
    attribute(:lat_hash, :string, public?: true)
    attribute(:struct_hash, :string, public?: true)
    attribute(:row_count, :integer, public?: true)

    attribute :reason, :string do
      public?(true)

      description(
        "discarded: not_making | revoked | superseded | out_of_scope | admin_action | unknown"
      )
    end

    attribute :verdict, :string do
      public?(true)
      description("enriched: making | no_obligations | empowering")
    end

    attribute(:enrichment_run_id, :string, public?: true)
    attribute(:enrichment_version, :string, public?: true)

    attribute :provenance, :map do
      public?(true)

      description(
        "enriched: fractalaw per-family stages (method/model/version) and method counts"
      )
    end

    attribute(:archive_ref, :string, public?: true)

    attribute :op_key, :string do
      public?(true)

      description(
        "Operation key (sertantai.lat.op_id, else the transaction id): collapses a batched parse or delete to one event"
      )
    end
  end

  actions do
    defaults([:read])

    create :record do
      primary?(true)

      accept([
        :law_id,
        :country,
        :law_name,
        :event,
        :family,
        :at,
        :source,
        :actor,
        :app_version,
        :lat_hash,
        :struct_hash,
        :row_count,
        :reason,
        :verdict,
        :enrichment_run_id,
        :enrichment_version,
        :provenance,
        :archive_ref
      ])
    end
  end
end

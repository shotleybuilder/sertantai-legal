defmodule SertantaiLegal.Legal.LatLabelTimeline do
  @moduledoc """
  A provision's labels as a timeline (lat-refactor LR-24): one row per
  provision per period, built from the change register (`lat_change_log`)
  by `LabelProjection`. "As at T" is a lookup —
  `valid_from <= T AND (valid_to IS NULL OR T < valid_to)` — with T the UK
  date for today; no job keeps it current, because known future dates are
  already periods. The time machine is the same lookup with another T.

  - At most one row per `section_id` for any date (EXCLUDE constraint).
  - `valid_from` / `valid_to` are UK dates; `valid_to` is exclusive, nil
    = open. Before a provision's first period its state is unknown (no row).
  - `status`: in_force | in_force_partial | prospective | repealed |
    repealed_saved.
  - `territory` (LR-26): where the provision applies in the period, as an
    extent code ("E+W"). Empty with status repealed / repealed_saved means
    nowhere; empty otherwise means unknown (an earlier period whose
    exclusion can't be dated safely, or no extent known).
  - `in_force_from` empty with `in_force` means the text changed and no
    source dates it ("date unknown"); never an older date in its place.
  - No row for a date means unknown (implied; no "unknown" rows).
  - Rebuilt per law (delete + insert) after each change collection; UK only.

  Read by compliance (drill-down status badge, v0.1) through the delta sync.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("lat_label_timeline")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:law_name, :section_id, :valid_from])
    end

    custom_statements do
      # compliance (2026-10-13): never two rows for one provision on one date
      statement :lat_label_timeline_one_period do
        up("""
        ALTER TABLE lat_label_timeline ADD CONSTRAINT lat_label_timeline_one_period
          EXCLUDE USING gist (section_id WITH =, daterange(valid_from, valid_to) WITH &&)
        """)

        down(
          "ALTER TABLE lat_label_timeline DROP CONSTRAINT IF EXISTS lat_label_timeline_one_period"
        )
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:law_name, :string, allow_nil?: false, public?: true)
    attribute(:section_id, :string, allow_nil?: false, public?: true)
    attribute(:valid_from, :date, allow_nil?: false, public?: true)

    attribute(:valid_to, :date,
      public?: true,
      description: "exclusive; nil = open"
    )

    attribute :status, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(in_force|in_force_partial|prospective|repealed|repealed_saved)$/)
    end

    attribute(:in_force_from, :date,
      public?: true,
      description:
        "when the current text took effect. Empty: with status prospective / in_force_partial, not fully in force; with in_force, the text changed and no source dates it (\"date unknown\")"
    )

    attribute(:changed_by, :string, public?: true)

    attribute(:territory, :string,
      public?: true,
      description:
        "where it applies in the period (\"E+W\"); empty: nowhere when repealed, else unknown"
    )

    attribute(:change_ids, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      description: "lat_change_log evidence behind the period"
    )

    attribute(:code_version, :string, allow_nil?: false, public?: true)

    attribute :built_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
    end
  end

  actions do
    defaults([:read])
  end
end

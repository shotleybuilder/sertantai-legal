defmodule SertantaiLegal.Legal.AmendmentRule do
  @moduledoc """
  The amendment ruleset (amendment-rules AR-01): one row per amending
  provision read — what it changes (`amends`, `targets`, `operation`,
  `level`) and the provision it came from (`source_*`). The struct and its
  readable form are `SertantaiLegal.Scraper.Amendment.Rule` (`to_row/1`,
  `from_row/1`, `to_text/1`); `mix lat.amending --law X` prints a law's
  rules.

  Written per source document by the readers (delete + insert by
  `source_law`), so a source's rules always match its latest reading. No
  new text, no position: rows are labelled, text never rebuilt (Jason
  2026-10-19).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("amendment_rules")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:amends])
      index([:source_law])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:amends, :string, allow_nil?: false, public?: true, description: "the law changed")

    attribute(:targets, {:array, :string},
      allow_nil?: false,
      public?: true,
      description:
        "refs in LAT's section_id grammar, expanded at read time (\"reg.69\", \"s.148(3)(a)\"; a range \"s.41..s.43\")"
    )

    attribute :operation, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(inserted|substituted|repealed|renumbered)$/)
    end

    attribute :level, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(provision|words)$/)

      description(
        "provision: reaches the rows inside each target; words: the named provision only"
      )
    end

    attribute(:source_law, :string, allow_nil?: false, public?: true)
    attribute(:source_ref, :string, public?: true)

    attribute(:source_text, :string,
      public?: true,
      description: "the amending provision, verbatim"
    )

    attribute :treatment, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(instruction|repeal_table)$/)
    end

    attribute :read_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
    end
  end

  actions do
    defaults([:read])
  end
end

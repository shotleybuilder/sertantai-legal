defmodule SertantaiLegal.Legal.CommencementRule do
  @moduledoc """
  The commencement ruleset (commencement-rules CR-01): one row per
  commencement statement — what it brings into force (`commences`, `scope`,
  `except`), when (`when_*`), where (`territory`), how far (`purposes`) and
  the words it came from (`source_*`). The struct and its readable form are
  `SertantaiLegal.Scraper.Commencement.Rule` (`to_row/1`, `from_row/1`,
  `to_text/1`); `mix lat.commencement --law X` prints a law's rules.

  Written per source document by the readers (delete + insert by
  `source_law`), so a source's rules always match its latest reading.
  Bringing into force only: no expiry, no retrospective flag (Jason
  2026-10-18).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("commencement_rules")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:commences])
      index([:source_law])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:commences, :string,
      allow_nil?: false,
      public?: true,
      description: "the law whose provisions come into force"
    )

    attribute :scope_kind, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(all|rest|refs)$/)
    end

    attribute(:scope, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      description:
        "refs in LAT's section_id grammar (\"s.12(3)\", \"pt.6.ch.1\"); a range is \"s.1..s.5\""
    )

    attribute(:scope_except, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      description: "refs the scope leaves out (\"except\")"
    )

    attribute :when_kind, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(date|after|named_day|appointed|with|unread)$/)
    end

    attribute(:when_date, :date, public?: true)
    attribute(:when_basis, :string, public?: true, description: "after: made | passed")
    attribute(:when_offset, :string, public?: true, description: "after: \"1 day\", \"2 months\"")

    attribute(:when_detail, :string,
      public?: true,
      description: "named_day: exit_day | ip_completion_day; appointed: how; with: \"law:ref\""
    )

    attribute(:territory, :string, public?: true, description: "nil: wherever it extends")

    attribute :purposes, :string do
      public?(true)

      constraints(
        match: ~r/^(for_making_secondary_legislation|in_relation_to|for_specified_purposes)$/
      )

      description("nil: fully")
    end

    attribute(:source_law, :string, allow_nil?: false, public?: true)
    attribute(:source_ref, :string, public?: true)
    attribute(:source_text, :string, public?: true, description: "the statement, verbatim")
    attribute(:treatment, :string, allow_nil?: false, public?: true)

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

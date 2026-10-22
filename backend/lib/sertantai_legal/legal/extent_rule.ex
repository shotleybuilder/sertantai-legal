defmodule SertantaiLegal.Legal.ExtentRule do
  @moduledoc """
  An Act's own extent clause, as rules (change vocabulary CV-04): one row
  per statement — the default ("this Act extends to England and Wales
  only"), each list that widens, confines or defers it ("The following
  extend also to Scotland— …"), the corresponding-repeal sentence, and each
  Schedule's introducing section. The struct and its reading are
  `SertantaiLegal.Scraper.AmendingLaw.Extent` (`to_rows/2`, `from_rows/1`).

  The third ruleset beside `amendment_rules` and `commencement_rules`:
  written per source document by the read pass (delete + insert by
  `source_law`), so a source's rules always match its latest reading. An Act
  read with no clause holds one `none` row (read, nothing stated).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("extent_rules")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:source_law])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :kind, :string do
      allow_nil?(false)
      public?(true)
      constraints(match: ~r/^(default|also|only|same|corresponds|introduces|applies|none)$/)
    end

    attribute(:place, :string,
      public?: true,
      description: "default / also / only / applies: the territory code (\"E+W\", \"S\")"
    )

    attribute(:items, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      description: "the provisions listed (LAT grammar: \"s.1..s.54\", \"sch.10.pt.2\")"
    )

    attribute(:position, :integer,
      allow_nil?: false,
      default: 0,
      public?: true,
      description: "a list's order in the clause (the first naming a provision decides)"
    )

    attribute(:source_law, :string, allow_nil?: false, public?: true)

    attribute(:source_ref, :string,
      public?: true,
      description: "the extent section; introduces: the introducing section"
    )

    attribute(:source_text, :string, public?: true, description: "default: the clause, verbatim")

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

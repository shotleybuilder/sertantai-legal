defmodule SertantaiLegal.Legal.ProvisionChange do
  @moduledoc """
  The change register of the change vocabulary (CV-04): one legal change
  event on one provision, merged by identity from every source and
  resolved by the evidence table — what the label fold reads. The struct is
  `SertantaiLegal.Scraper.ChangeVocabulary.Change`; its claims are
  `provision_change_claims`.

  - `key`: the effect id when any source carries one, else a source's own
    id; `target`: the provision (LAT grammar, no law prefix; `"*"` the
    whole law). Unique per law.
  - The resolved attributes, and `sources`: the source each came from.
    Tiers and conflicts are not stored: both follow from the sources and
    the claims (`Evidence.tier/1`, `ChangeVocabulary.Conflicts`), so their
    rules can change without a rebuild.
  - Written per law (delete + insert, `ChangeVocabulary.Store`); each build
    is a `changes_built` lat_event with its inputs' fingerprints.

  Beside `lat_change_log` during the shadow runs; it replaces it at CV-06.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("provision_changes")
    repo(SertantaiLegal.Repo)

    custom_indexes do
      index([:law_name, :target])
      index([:by])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:law_name, :string, allow_nil?: false, public?: true)
    attribute(:key, :string, allow_nil?: false, public?: true)
    attribute(:target, :string, allow_nil?: false, public?: true)

    attribute(:aliases, {:array, :string},
      allow_nil?: false,
      default: [],
      public?: true,
      description: "every source id merged in"
    )

    attribute(:operation, :string, public?: true)
    attribute(:level, :string, public?: true, description: "words | provision")
    attribute(:territory, :string, public?: true)
    attribute(:date, :date, public?: true)
    attribute(:by, :string, public?: true, description: "the law making the change")

    attribute(:commenced_by, :string,
      public?: true,
      description: "the law bringing it into force, when not the law making it"
    )

    attribute(:retained, :boolean, allow_nil?: false, default: false, public?: true)
    attribute(:partial, :boolean, allow_nil?: false, default: false, public?: true)
    attribute(:saved, :boolean, allow_nil?: false, default: false, public?: true)

    attribute(:sources, :map,
      allow_nil?: false,
      default: %{},
      public?: true,
      description: "attribute => the source its value came from"
    )

    attribute(:code_version, :string, allow_nil?: false, public?: true)

    attribute :built_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
    end
  end

  identities do
    identity(:change, [:law_name, :key, :target])
  end

  relationships do
    has_many(:claims, SertantaiLegal.Legal.ProvisionChangeClaim,
      destination_attribute: :change_id
    )
  end

  actions do
    defaults([:read])
  end
end

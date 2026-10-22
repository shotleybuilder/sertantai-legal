defmodule SertantaiLegal.Legal.ProvisionChangeClaim do
  @moduledoc """
  One source's statement about one attribute of a change in
  `provision_changes` (change vocabulary CV-04): `source` (`law_text`,
  `commencement`, `markup`, `feed`, `law`), `attribute`, `value` and `ref`
  (where in the source it was read). The struct is
  `SertantaiLegal.Scraper.ChangeVocabulary.Claim`.

  `value` is type-tagged JSON (`ChangeVocabulary.Store.encode/1`) so dates,
  atoms and lists read back as written; `position` keeps the claims' order
  (the evidence table takes a source's first claim).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("provision_change_claims")
    repo(SertantaiLegal.Repo)

    references do
      reference(:change, on_delete: :delete)
    end

    custom_indexes do
      # a law's rewrite deletes its changes, cascading here; read back by change
      index([:change_id])
      index([:source, :attribute])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:position, :integer, allow_nil?: false, public?: true)
    attribute(:source, :string, allow_nil?: false, public?: true)
    attribute(:attribute, :string, allow_nil?: false, public?: true)
    attribute(:value, :map, allow_nil?: false, public?: true)
    attribute(:ref, :string, public?: true)
  end

  relationships do
    belongs_to(:change, SertantaiLegal.Legal.ProvisionChange,
      allow_nil?: false,
      attribute_writable?: true,
      public?: true
    )
  end

  actions do
    defaults([:read])
  end
end

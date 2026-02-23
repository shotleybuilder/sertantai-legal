defmodule SertantaiLegal.Accounts.UserIdentity do
  @moduledoc """
  UserIdentity resource for GitHub OAuth provider identities.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Accounts,
    extensions: [AshAuthentication.UserIdentity],
    data_layer: AshPostgres.DataLayer

  postgres do
    table("user_identities")
    repo(SertantaiLegal.Repo)
  end

  user_identity do
    domain(SertantaiLegal.Accounts)
    user_resource(SertantaiLegal.Accounts.User)
  end

  attributes do
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end
end

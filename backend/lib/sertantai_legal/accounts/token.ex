defmodule SertantaiLegal.Accounts.Token do
  @moduledoc """
  Token resource for Ash Authentication session management.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("auth_tokens")
    repo(SertantaiLegal.Repo)
  end

  token do
    domain(SertantaiLegal.Accounts)
  end
end

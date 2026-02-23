defmodule SertantaiLegal.Accounts do
  @moduledoc """
  The Accounts domain handles admin user authentication via GitHub OAuth.
  """

  use Ash.Domain

  resources do
    resource(SertantaiLegal.Accounts.User)
    resource(SertantaiLegal.Accounts.Token)
    resource(SertantaiLegal.Accounts.UserIdentity)
  end
end

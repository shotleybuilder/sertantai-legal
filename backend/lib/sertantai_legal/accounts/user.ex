defmodule SertantaiLegal.Accounts.User do
  @moduledoc """
  Admin user resource with GitHub OAuth authentication.

  Used for admin route access control. Separate from tenant users
  who authenticate via JWT from sertantai-auth.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("users")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false, public?: true)

    # GitHub OAuth fields
    attribute(:github_id, :string, allow_nil?: true)
    attribute(:github_login, :string, allow_nil?: true)
    attribute(:name, :string, allow_nil?: true)
    attribute(:avatar_url, :string, allow_nil?: true)
    attribute(:github_url, :string, allow_nil?: true)

    # Admin privilege management
    attribute(:is_admin, :boolean, default: false, public?: true)
    attribute(:admin_checked_at, :utc_datetime_usec, allow_nil?: true)
    attribute(:last_login_at, :utc_datetime_usec, allow_nil?: true)

    # OAuth provider tracking
    attribute(:primary_provider, :string, default: "github", public?: true)

    timestamps()
  end

  authentication do
    strategies do
      oauth2 :github do
        client_id(fn _, _ ->
          {:ok,
           System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_ID") ||
             System.get_env("GITHUB_CLIENT_ID", "")}
        end)

        client_secret(fn _, _ ->
          {:ok,
           System.get_env("SERTANTAI_LEGAL_GITHUB_CLIENT_SECRET") ||
             System.get_env("GITHUB_CLIENT_SECRET", "")}
        end)

        redirect_uri(fn _, _ ->
          {:ok,
           System.get_env(
             "GITHUB_REDIRECT_URI",
             "http://localhost:4003/auth/user/github/callback"
           )}
        end)

        base_url("https://github.com")
        authorize_url("/login/oauth/authorize")
        token_url("/login/oauth/access_token")
        user_url("https://api.github.com/user")
        authorization_params(scope: "user:email,read:org")
        identity_resource(SertantaiLegal.Accounts.UserIdentity)
      end
    end

    tokens do
      enabled?(true)
      token_resource(SertantaiLegal.Accounts.Token)

      signing_secret(fn _, _ ->
        Application.fetch_env(:sertantai_legal, :token_signing_secret)
      end)
    end

    session_identifier(:jti)
  end

  identities do
    identity(:unique_email, [:email])
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :email,
        :github_id,
        :github_login,
        :name,
        :avatar_url,
        :github_url,
        :is_admin,
        :admin_checked_at,
        :last_login_at,
        :primary_provider
      ])
    end

    update :update do
      accept([:email, :name, :avatar_url, :github_url, :last_login_at])
    end

    create :register_with_github do
      argument(:user_info, :map, allow_nil?: false)
      argument(:oauth_tokens, :map, allow_nil?: false)

      upsert?(true)
      upsert_identity(:unique_email)

      upsert_fields([
        :name,
        :avatar_url,
        :github_id,
        :github_login,
        :github_url,
        :primary_provider,
        :last_login_at,
        :is_admin,
        :admin_checked_at
      ])

      change(AshAuthentication.Strategy.OAuth2.IdentityChange)
      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        github_login = user_info["login"]

        # Check if user should be admin based on GITHUB_ALLOWED_USERS
        config = Application.get_env(:sertantai_legal, :github_admin, [])
        allowed_users = Keyword.get(config, :allowed_users, [])

        is_admin =
          is_list(allowed_users) and length(allowed_users) > 0 and github_login in allowed_users

        changeset
        |> Ash.Changeset.change_attribute(:email, downcase_email(user_info["email"]))
        |> Ash.Changeset.change_attribute(:github_id, to_string(user_info["id"]))
        |> Ash.Changeset.change_attribute(:github_login, github_login)
        |> Ash.Changeset.change_attribute(:name, user_info["name"])
        |> Ash.Changeset.change_attribute(:avatar_url, user_info["avatar_url"])
        |> Ash.Changeset.change_attribute(:github_url, user_info["html_url"])
        |> Ash.Changeset.change_attribute(:primary_provider, "github")
        |> Ash.Changeset.change_attribute(:last_login_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:is_admin, is_admin)
        |> Ash.Changeset.change_attribute(:admin_checked_at, DateTime.utc_now())
      end)
    end

    update :update_admin_status do
      require_atomic?(false)
      accept([:is_admin, :admin_checked_at])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :admin_checked_at, DateTime.utc_now())
      end)
    end

    read :by_github_login do
      argument(:github_login, :string, allow_nil?: false)
      filter(expr(github_login == ^arg(:github_login)))
    end

    read :admins do
      filter(expr(is_admin == true))
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(always())
    end

    policy action(:register_with_github) do
      authorize_if(always())
    end

    policy action(:create) do
      authorize_if(always())
    end

    policy action_type(:update) do
      authorize_if(expr(id == ^actor(:id)))
      authorize_if(actor_attribute_equals(:is_admin, true))
    end

    policy action(:update_admin_status) do
      authorize_if(always())
    end
  end

  relationships do
    has_many :user_identities, SertantaiLegal.Accounts.UserIdentity
  end

  code_interface do
    define(:update)
    define(:update_admin_status, args: [:is_admin])
    define(:by_github_login, args: [:github_login])
    define(:admins)
  end

  defp downcase_email(nil), do: nil
  defp downcase_email(email) when is_binary(email), do: String.downcase(email)
end

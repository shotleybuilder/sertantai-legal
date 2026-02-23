defmodule SertantaiLegal.Repo.Migrations.AddGithubAuthTables do
  @moduledoc """
  Creates tables for GitHub OAuth admin authentication.
  """

  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table("users", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :github_id, :text
      add :github_login, :text
      add :name, :text
      add :avatar_url, :text
      add :github_url, :text
      add :is_admin, :boolean, default: false, null: false
      add :admin_checked_at, :utc_datetime_usec
      add :last_login_at, :utc_datetime_usec
      add :primary_provider, :text, default: "github", null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("users", [:email])
    create index("users", [:github_id])
    create index("users", [:github_login])

    create table("auth_tokens", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :extra_data, :map
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime
      add :subject, :text, null: false
      add :jti, :text, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index("auth_tokens", [:jti])

    create table("user_identities", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references("users", type: :binary_id, on_delete: :delete_all), null: false
      add :uid, :text, null: false
      add :strategy, :text, null: false
      add :access_token, :text
      add :refresh_token, :text
      add :access_token_expires_at, :utc_datetime_usec
      add :user_info, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("user_identities", [:strategy, :uid, :user_id])
    create index("user_identities", [:user_id])
  end
end

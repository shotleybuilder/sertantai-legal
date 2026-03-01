defmodule SertantaiLegal.Repo.Migrations.RemoveLocalAuthTables do
  @moduledoc """
  Drop local auth tables (users, user_identities, auth_tokens).

  Authentication is now fully handled by sertantai-auth. This service
  validates JWTs from sertantai-auth via the JWKS endpoint — no local
  user or session storage needed.
  """
  use Ecto.Migration

  def up do
    # Drop in dependency order (foreign keys)
    drop_if_exists(table(:user_identities))
    drop_if_exists(table(:auth_tokens))
    drop_if_exists(table(:users))
  end

  def down do
    # Recreate tables for rollback (minimal schema)
    create table(:users, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:email, :citext, null: false)
      add(:github_id, :text)
      add(:github_login, :text)
      add(:name, :text)
      add(:avatar_url, :text)
      add(:github_url, :text)
      add(:is_admin, :boolean, default: false)
      add(:admin_checked_at, :utc_datetime_usec)
      add(:last_login_at, :utc_datetime_usec)
      add(:primary_provider, :text, default: "github")
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:users, [:email]))

    create table(:auth_tokens, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:jti, :text, null: false)
      add(:subject, :text, null: false)
      add(:expires_at, :utc_datetime, null: false)
      add(:purpose, :text, null: false)
      add(:extra_data, :map)
      add(:created_at, :utc_datetime_usec)
      add(:updated_at, :utc_datetime_usec)
    end

    create table(:user_identities, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:uid, :text, null: false)
      add(:strategy, :text, null: false)
      add(:access_token, :text)
      add(:refresh_token, :text)
      add(:access_token_expires_at, :utc_datetime_usec)
      add(:user_info, :map, default: %{})
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:user_identities, [:strategy, :uid, :user_id]))
  end
end

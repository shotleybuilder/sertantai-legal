defmodule SertantaiLegal.Repo.Migrations.FixAuthTokensAddUpdatedAt do
  @moduledoc """
  Adds missing updated_at column to auth_tokens table.

  The AshAuthentication.TokenResource expects both inserted_at and updated_at,
  but the original migration only created inserted_at.
  """

  use Ecto.Migration

  def up do
    # Rename inserted_at → created_at to match AshAuthentication.TokenResource schema
    rename(table(:auth_tokens), :inserted_at, to: :created_at)

    # Add missing updated_at column
    alter table(:auth_tokens) do
      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end
  end

  def down do
    alter table(:auth_tokens) do
      remove(:updated_at)
    end

    rename(table(:auth_tokens), :created_at, to: :inserted_at)
  end
end

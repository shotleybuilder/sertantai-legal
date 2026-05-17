defmodule SertantaiLegal.Repo.Migrations.AddMakingReview do
  @moduledoc """
  Add making_review and making_review_at columns to uk_lrt.

  These capture the human-AI review classification (Stage 2 of the making
  lifecycle), separate from the auto-detected making_classification (Stage 1)
  and the definitive is_making boolean (Stage 3, from taxa/full-text).
  """

  use Ecto.Migration

  def up do
    alter table(:uk_lrt) do
      add :making_review, :text
      add :making_review_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:uk_lrt) do
      remove :making_review_at
      remove :making_review
    end
  end
end

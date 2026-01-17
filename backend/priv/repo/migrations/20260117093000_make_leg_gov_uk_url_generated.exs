defmodule SertantaiLegal.Repo.Migrations.MakeLegGovUkUrlGenerated do
  use Ecto.Migration

  def up do
    # Drop the existing column
    alter table(:uk_lrt) do
      remove :leg_gov_uk_url
    end

    # Add as a generated column
    execute """
    ALTER TABLE uk_lrt
    ADD COLUMN leg_gov_uk_url text
    GENERATED ALWAYS AS (
      CASE
        WHEN type_code IS NOT NULL AND year IS NOT NULL AND number IS NOT NULL
        THEN 'https://www.legislation.gov.uk/' || type_code || '/' || year::text || '/' || number
        ELSE NULL
      END
    ) STORED
    """
  end

  def down do
    # Drop the generated column
    alter table(:uk_lrt) do
      remove :leg_gov_uk_url
    end

    # Add back as a regular column
    alter table(:uk_lrt) do
      add :leg_gov_uk_url, :string
    end
  end
end

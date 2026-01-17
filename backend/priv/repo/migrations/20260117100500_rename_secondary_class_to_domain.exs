defmodule SertantaiLegal.Repo.Migrations.RenameSecondaryClassToDomain do
  use Ecto.Migration

  def up do
    # Rename and convert to array type
    execute """
    ALTER TABLE uk_lrt 
    RENAME COLUMN secondary_class TO domain
    """

    execute """
    ALTER TABLE uk_lrt 
    ALTER COLUMN domain TYPE text[] 
    USING CASE 
      WHEN domain IS NULL THEN NULL 
      WHEN domain = '' THEN NULL
      ELSE ARRAY[domain]
    END
    """
  end

  def down do
    # Convert back to text (take first element)
    execute """
    ALTER TABLE uk_lrt 
    ALTER COLUMN domain TYPE text 
    USING domain[1]
    """

    execute """
    ALTER TABLE uk_lrt 
    RENAME COLUMN domain TO secondary_class
    """
  end
end

defmodule SertantaiLegal.Repo.Migrations.FixDoubleUnderscoreNames do
  @moduledoc """
  Fix 62 records with UK__YYYY_NNN name format (missing type_code in name).

  - 48 are duplicates of existing properly-named records — delete them
  - 14 are unique records — rename to UK_{type_code}_YYYY_NNN
  """
  use Ecto.Migration

  def up do
    # Delete 48 duplicates where a properly-named record already exists
    execute("""
    DELETE FROM uk_lrt
    WHERE name ~ '^UK__[0-9]'
      AND EXISTS (
        SELECT 1 FROM uk_lrt u2
        WHERE u2.name = 'UK_' || uk_lrt.type_code || '_' || SUBSTRING(uk_lrt.name FROM 5)
      )
    """)

    # Rename the remaining 14 unique records
    execute("""
    UPDATE uk_lrt
    SET name = 'UK_' || type_code || '_' || SUBSTRING(name FROM 5)
    WHERE name ~ '^UK__[0-9]'
    """)
  end

  def down do
    :ok
  end
end

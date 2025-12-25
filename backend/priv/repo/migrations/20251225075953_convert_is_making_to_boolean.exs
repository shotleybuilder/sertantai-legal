defmodule SertantaiLegal.Repo.Migrations.ConvertIsMakingToBoolean do
  @moduledoc """
  Convert is_making and is_commencing from decimal to boolean.

  These fields were imported from Airtable as decimal (1.0/0.0) but should be boolean.
  """

  use Ecto.Migration

  def up do
    # Convert decimal to boolean: 1.0 -> true, 0.0/NULL -> false/NULL
    execute """
    ALTER TABLE uk_lrt
    ALTER COLUMN is_making TYPE boolean
    USING CASE WHEN is_making > 0 THEN true ELSE false END
    """

    execute """
    ALTER TABLE uk_lrt
    ALTER COLUMN is_commencing TYPE boolean
    USING CASE WHEN is_commencing > 0 THEN true ELSE false END
    """
  end

  def down do
    # Convert boolean back to decimal: true -> 1.0, false/NULL -> 0.0/NULL
    execute """
    ALTER TABLE uk_lrt
    ALTER COLUMN is_making TYPE numeric(38,9)
    USING CASE WHEN is_making THEN 1.0 ELSE 0.0 END
    """

    execute """
    ALTER TABLE uk_lrt
    ALTER COLUMN is_commencing TYPE numeric(38,9)
    USING CASE WHEN is_commencing THEN 1.0 ELSE 0.0 END
    """
  end
end

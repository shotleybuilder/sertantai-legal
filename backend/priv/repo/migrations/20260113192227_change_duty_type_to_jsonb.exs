defmodule SertantaiLegal.Repo.Migrations.ChangeDutyTypeToJsonb do
  @moduledoc """
  Converts duty_type from CSV string to JSONB format.
  CSV like "Duty,Right" becomes {"values": ["Duty", "Right"]}
  """

  use Ecto.Migration

  def up do
    # Convert column type and data in one step using USING clause
    execute("""
    ALTER TABLE uk_lrt
    ALTER COLUMN duty_type TYPE jsonb
    USING CASE
      WHEN duty_type IS NULL OR duty_type = '' THEN NULL
      ELSE jsonb_build_object('values', string_to_array(duty_type, ','))
    END
    """)
  end

  def down do
    # Convert JSONB back to text CSV format
    execute("""
    ALTER TABLE uk_lrt
    ALTER COLUMN duty_type TYPE text
    USING CASE
      WHEN duty_type IS NULL THEN NULL
      ELSE array_to_string(ARRAY(SELECT jsonb_array_elements_text(duty_type->'values')), ',')
    END
    """)
  end
end

defmodule SertantaiLegal.Repo.Migrations.PopulateTypeCodesFromTypeDesc do
  use Ecto.Migration

  def up do
    execute(
      "UPDATE uk_lrt SET type_code = 'apni' WHERE name = 'UK__1957_25' AND type_code IS NULL"
    )

    execute(
      "UPDATE uk_lrt SET type_code = 'wsi' WHERE name = 'UK__2005_2929' AND type_code IS NULL"
    )
  end

  def down do
    :ok
  end
end

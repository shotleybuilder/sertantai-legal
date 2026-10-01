defmodule SertantaiLegal.Sync.Delta.ConfigTest do
  @moduledoc """
  The delta export writes `INSERT INTO uk_lrt (...)` on prod with every
  LegalRegister attribute not excluded by `Config`. A legal_register column
  missing from the uk_lrt view must be dev-only, or the apply fails.
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.Delta.{ColumnMapper, Config}

  test "every exported uk_lrt column exists in the uk_lrt view" do
    view_columns =
      Repo.query!(
        "SELECT column_name FROM information_schema.columns WHERE table_name = 'uk_lrt'"
      ).rows
      |> List.flatten()

    exported =
      SertantaiLegal.Legal.LegalRegister
      |> ColumnMapper.writable_columns(Config.excluded_columns("uk_lrt"))
      |> Enum.map(& &1.pg_name)

    assert exported -- view_columns == []
  end
end

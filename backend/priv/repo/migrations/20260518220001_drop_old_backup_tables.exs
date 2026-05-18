defmodule SertantaiLegal.Repo.Migrations.DropOldBackupTables do
  @moduledoc """
  Drop the _old backup tables created during the partition migration.

  These were kept as safety nets during the uk_lrt → legal_register transition.
  The partitioned tables are confirmed working. Views (uk_lrt, lat) are kept
  for backwards compatibility with ~70 raw SQL references.
  """

  use Ecto.Migration

  def up do
    execute "DROP TABLE IF EXISTS uk_lrt_old CASCADE;"
    execute "DROP TABLE IF EXISTS lat_old CASCADE;"
    execute "DROP TABLE IF EXISTS amendment_annotations_old CASCADE;"
    execute "DROP TABLE IF EXISTS law_edges_old CASCADE;"
    execute "DROP TABLE IF EXISTS si_code_families_old CASCADE;"
  end

  def down do
    # Cannot restore — data was in the old tables. Use NAS snapshot to recover if needed.
    :ok
  end
end

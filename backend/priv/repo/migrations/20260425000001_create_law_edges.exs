defmodule SertantaiLegal.Repo.Migrations.CreateLawEdges do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE law_edges (
      source_law TEXT NOT NULL,
      target_law TEXT NOT NULL,
      edge_type TEXT NOT NULL,
      source_family TEXT,
      target_family TEXT,
      PRIMARY KEY (source_law, target_law, edge_type)
    )
    """

    execute "CREATE INDEX idx_law_edges_target ON law_edges(target_law, edge_type)"
    execute "CREATE INDEX idx_law_edges_source_family ON law_edges(source_family)"
    execute "CREATE INDEX idx_law_edges_target_family ON law_edges(target_family)"
    execute "CREATE INDEX idx_law_edges_edge_type ON law_edges(edge_type)"
  end

  def down do
    execute "DROP TABLE IF EXISTS law_edges"
  end
end

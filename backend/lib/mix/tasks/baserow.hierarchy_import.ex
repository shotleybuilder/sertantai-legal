defmodule Mix.Tasks.Baserow.HierarchyImport do
  @shortdoc "Import hierarchy nodes from CSV into Baserow Hierarchy table"

  @moduledoc """
  Import hierarchy nodes from a CSV file into the Baserow Hierarchy table.

  Reads a CSV with columns: name, type, parent, hierarchy_type, description.
  Creates rows in the Hierarchy table, resolving parent references by name.
  Idempotent — skips rows that already exist (matched by Name).

  ## Usage

      mix baserow.hierarchy_import path/to/sites.csv
      mix baserow.hierarchy_import path/to/sites.csv --config UUID
      mix baserow.hierarchy_import --dry-run path/to/sites.csv

  ## CSV Schema

      name,type,parent,hierarchy_type,description
      UK,Country,,geo,United Kingdom
      England,Region,UK,geo,
      Aberdeen,Site,England,geo,Offshore support base

  - **name** (required): Node name, becomes Hierarchy primary field
  - **type** (required): Must match Hierarchy Type options (Site, Region, etc.)
  - **parent** (optional): Parent node name. Empty = root node
  - **hierarchy_type** (optional): Defaults to "geo". Options: org, geo, finance, reporting
  - **description** (optional): Free text

  CSV must be ordered parents-before-children (topological order).
  """

  use Mix.Task

  NimbleCSV.define(HierarchyCSV, separator: ",", escape: "\"")

  alias SertantaiLegal.Baserow.Client
  alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
  alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [config: :string, dry_run: :boolean],
        aliases: [c: :config, n: :dry_run]
      )

    csv_path = List.first(positional)

    unless csv_path && File.exists?(csv_path) do
      Mix.shell().error("Usage: mix baserow.hierarchy_import <csv_path> [--config UUID] [--dry-run]")
      System.halt(1)
    end

    Mix.Task.run("app.start")

    rows = parse_csv(csv_path)
    Mix.shell().info("Parsed #{length(rows)} rows from #{csv_path}")

    if opts[:dry_run] do
      dry_run(rows)
    else
      config_id = opts[:config] || find_default_config()

      unless config_id do
        Mix.shell().error("No sync configuration found. Provide a config UUID.")
        System.halt(1)
      end

      authed_config = authenticate(config_id)
      import_rows(authed_config, rows)
    end
  end

  defp authenticate(config_id) do
    sync_config = SertantaiLegal.Repo.get!(SyncConfiguration, config_id)
    creds = Credentials.decrypt(sync_config.encrypted_credentials, sync_config.credentials_iv)

    {:ok, authed_config} =
      BaserowProvider.authenticate(%{
        "base_url" => sync_config.target_config["base_url"],
        "credentials" => creds
      })

    authed_config = Map.merge(authed_config, sync_config.target_config)
    Mix.shell().info("Authenticated with Baserow")

    hierarchy_table_id = Client.table_id(authed_config, :hierarchy)

    unless hierarchy_table_id do
      Mix.shell().error("No hierarchy table in sync config. Run mix templates.apply first.")
      System.halt(1)
    end

    Mix.shell().info("Hierarchy table: #{hierarchy_table_id}")
    authed_config
  end

  defp parse_csv(path) do
    content =
      path
      |> File.read!()
      |> String.replace_prefix("\uFEFF", "")

    [header_line | data_lines] = String.split(content, ~r/\r?\n/, trim: true)
    [headers] = HierarchyCSV.parse_string(header_line <> "\n", skip_headers: false)
    headers = Enum.map(headers, &String.trim/1)

    col = fn name -> Enum.find_index(headers, &(&1 == name)) end
    name_idx = col.("name")
    type_idx = col.("type")
    parent_idx = col.("parent")
    ht_idx = col.("hierarchy_type")
    desc_idx = col.("description")

    unless name_idx && type_idx do
      Mix.shell().error("CSV must have 'name' and 'type' columns")
      System.halt(1)
    end

    data_lines
    |> Enum.join("\n")
    |> Kernel.<>("\n")
    |> HierarchyCSV.parse_string(skip_headers: false)
    |> Enum.map(fn fields ->
      at = fn idx -> if idx, do: Enum.at(fields, idx, "") |> String.trim(), else: "" end

      %{
        name: at.(name_idx),
        type: at.(type_idx),
        parent: at.(parent_idx),
        hierarchy_type: if(at.(ht_idx) == "", do: "geo", else: at.(ht_idx)),
        description: at.(desc_idx)
      }
    end)
    |> Enum.reject(fn row -> row.name == "" end)
  end

  defp dry_run(rows) do
    Mix.shell().info("\n=== Dry Run ===")

    Enum.each(rows, fn row ->
      parent_info = if row.parent == "", do: "(root)", else: "→ #{row.parent}"
      Mix.shell().info("  #{row.name} [#{row.type}] #{parent_info} (#{row.hierarchy_type})")
    end)

    names = MapSet.new(rows, & &1.name)

    missing =
      rows
      |> Enum.filter(fn row -> row.parent != "" and row.parent not in names end)
      |> Enum.map(& &1.parent)
      |> Enum.uniq()

    if missing != [] do
      Mix.shell().info(
        "\n  ⚠ Parent refs not in CSV (must exist in Baserow): #{Enum.join(missing, ", ")}"
      )
    end

    Mix.shell().info("\n#{length(rows)} rows would be created")
  end

  defp import_rows(config, rows) do
    {:ok, existing} = Client.list_all_rows(config, :hierarchy)
    existing_names = Map.keys(existing)
    Mix.shell().info("Existing hierarchy nodes: #{length(existing_names)}")

    {to_create, skipped} =
      Enum.split_with(rows, fn row -> row.name not in existing_names end)

    if skipped != [] do
      Mix.shell().info(
        "Skipping #{length(skipped)} existing: #{skipped |> Enum.map(& &1.name) |> Enum.join(", ")}"
      )
    end

    if to_create == [] do
      Mix.shell().info("Nothing to import — all rows already exist")
    else
      do_create(config, to_create)
    end
  end

  defp do_create(config, to_create) do
    # Create one-by-one in CSV order to ensure parents exist before children.
    # Parent link_row resolves by text match on the Hierarchy Name primary field.
    Mix.shell().info("Creating #{length(to_create)} nodes...\n")

    {created, errors} =
      Enum.reduce(to_create, {0, []}, fn row, {count, errs} ->
        baserow_row = build_row(row)

        case Client.batch_create(config, :hierarchy, [baserow_row]) do
          {:ok, _} ->
            parent_info = if row.parent == "", do: "(root)", else: "→ #{row.parent}"
            Mix.shell().info("  ✓ #{row.name} [#{row.type}] #{parent_info}")
            {count + 1, errs}

          {:error, reason} ->
            Mix.shell().error("  ✗ #{row.name}: #{inspect(reason)}")
            {count, [row.name | errs]}
        end
      end)

    Mix.shell().info("\n=== Import Complete ===")
    Mix.shell().info("Created: #{created}")

    if errors != [] do
      Mix.shell().error(
        "Errors: #{length(errors)} — #{Enum.join(Enum.reverse(errors), ", ")}"
      )
    end
  end

  defp build_row(row) do
    base = %{
      "Name" => row.name,
      "Type" => row.type,
      "Hierarchy_Type" => row.hierarchy_type
    }

    base = if row.description != "", do: Map.put(base, "Description", row.description), else: base
    if row.parent != "", do: Map.put(base, "Parent", row.parent), else: base
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end
end

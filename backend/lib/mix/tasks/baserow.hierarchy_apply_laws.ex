defmodule Mix.Tasks.Baserow.HierarchyApplyLaws do
  @shortdoc "Link laws to hierarchy nodes from CSV or JSON mapping data"

  @moduledoc """
  Populate the Hierarchy link_row field on Legal Register rows by reading
  law-to-site mapping data from CSV or JSON files.

  ## Usage

      # JSON: directory of matched.json files (QQ format — subdirs named by site code)
      mix baserow.hierarchy_apply_laws --json data/imports/qq/

      # CSV: explicit mapping file
      mix baserow.hierarchy_apply_laws --csv data/imports/qq/law_mappings.csv

      # Options
      mix baserow.hierarchy_apply_laws --json data/imports/qq/ --dry-run
      mix baserow.hierarchy_apply_laws --json data/imports/qq/ --config UUID

  ## JSON format (per site directory)

  Each subdirectory is named by hierarchy node (site code). Contains matched.json:

      qq/ABE/matched.json → {"matched": [{"lrt_name": "UK_uksi_2004_3391", ...}, ...]}

  ## CSV format

      hierarchy_node,lrt_name
      ABE,UK_uksi_2004_3391
      ABE,UK_uksi_2005_1140
      MAN,UK_uksi_2004_3391
  """

  use Mix.Task

  NimbleCSV.define(LawMappingCSV, separator: ",", escape: "\"")

  alias SertantaiLegal.Baserow.Client
  alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
  alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

  @impl Mix.Task
  def run(args) do
    {opts, _positional, _} =
      OptionParser.parse(args,
        strict: [config: :string, json: :string, csv: :string, dry_run: :boolean],
        aliases: [c: :config, j: :json, n: :dry_run]
      )

    unless opts[:json] || opts[:csv] do
      Mix.shell().error("Provide --json <dir> or --csv <file>")
      System.halt(1)
    end

    Mix.Task.run("app.start")

    # Build lrt_name → [hierarchy_node_name] from input
    law_to_nodes =
      cond do
        opts[:json] -> load_json(opts[:json])
        opts[:csv] -> load_csv(opts[:csv])
      end

    total_mappings = law_to_nodes |> Map.values() |> List.flatten() |> length()
    Mix.shell().info("Loaded #{map_size(law_to_nodes)} laws → #{total_mappings} mappings")

    if opts[:dry_run] do
      dry_run(law_to_nodes)
    else
      config = authenticate(opts[:config] || find_default_config())
      apply_mappings(config, law_to_nodes)
    end
  end

  # ── JSON loader (QQ format: subdirs with matched.json) ──

  defp load_json(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(fn entry ->
      Path.join(dir, entry) |> File.dir?() &&
        Path.join([dir, entry, "matched.json"]) |> File.exists?()
    end)
    |> Enum.reduce(%{}, fn site_dir, acc ->
      node_name = String.upcase(site_dir)
      matched_path = Path.join([dir, site_dir, "matched.json"])

      case Jason.decode!(File.read!(matched_path)) do
        %{"matched" => entries} ->
          Enum.reduce(entries, acc, fn entry, inner_acc ->
            lrt_name = entry["lrt_name"]

            if lrt_name && entry["match_status"] == "matched" do
              Map.update(inner_acc, lrt_name, [node_name], fn nodes ->
                if node_name in nodes, do: nodes, else: [node_name | nodes]
              end)
            else
              inner_acc
            end
          end)

        _ ->
          acc
      end
    end)
  end

  # ── CSV loader ──

  defp load_csv(path) do
    content =
      path
      |> File.read!()
      |> String.replace_prefix("\uFEFF", "")

    [header_line | data_lines] = String.split(content, ~r/\r?\n/, trim: true)
    [headers] = LawMappingCSV.parse_string(header_line <> "\n", skip_headers: false)
    headers = Enum.map(headers, &String.trim/1)

    node_idx = Enum.find_index(headers, &(&1 == "hierarchy_node"))
    lrt_idx = Enum.find_index(headers, &(&1 == "lrt_name"))

    unless node_idx && lrt_idx do
      Mix.shell().error("CSV must have 'hierarchy_node' and 'lrt_name' columns")
      System.halt(1)
    end

    data_lines
    |> Enum.join("\n")
    |> Kernel.<>("\n")
    |> LawMappingCSV.parse_string(skip_headers: false)
    |> Enum.reduce(%{}, fn fields, acc ->
      node = fields |> Enum.at(node_idx, "") |> String.trim()
      lrt_name = fields |> Enum.at(lrt_idx, "") |> String.trim()

      if node != "" && lrt_name != "" do
        Map.update(acc, lrt_name, [node], fn nodes ->
          if node in nodes, do: nodes, else: [node | nodes]
        end)
      else
        acc
      end
    end)
  end

  # ── Dry run ──

  defp dry_run(law_to_nodes) do
    Mix.shell().info("\n=== Dry Run ===")

    # Show sample
    law_to_nodes
    |> Enum.take(10)
    |> Enum.each(fn {lrt_name, nodes} ->
      Mix.shell().info("  #{lrt_name} → #{Enum.join(nodes, ", ")}")
    end)

    if map_size(law_to_nodes) > 10 do
      Mix.shell().info("  ... and #{map_size(law_to_nodes) - 10} more")
    end

    # Stats
    node_counts =
      law_to_nodes
      |> Map.values()
      |> Enum.map(&length/1)

    Mix.shell().info("\nLaws: #{map_size(law_to_nodes)}")
    Mix.shell().info("Min sites per law: #{Enum.min(node_counts)}")
    Mix.shell().info("Max sites per law: #{Enum.max(node_counts)}")

    Mix.shell().info(
      "Avg sites per law: #{Float.round(Enum.sum(node_counts) / length(node_counts), 1)}"
    )
  end

  # ── Apply mappings ──

  defp apply_mappings(config, law_to_nodes) do
    # Resolve hierarchy node names → row IDs
    {:ok, hierarchy_rows} = Client.list_all_rows(config, :hierarchy)

    node_id_map =
      Enum.reduce(hierarchy_rows, %{}, fn {name, ids}, acc ->
        Map.put(acc, name, hd(ids))
      end)

    Mix.shell().info("Hierarchy nodes: #{map_size(node_id_map)}")

    # Resolve lrt_names → row IDs
    {:ok, lrt_rows} = Client.list_all_rows(config, :lrt)
    Mix.shell().info("LRT rows: #{map_size(lrt_rows)}")

    # Build update rows: for each law, resolve node names → row IDs
    {updates, skipped_laws, missing_nodes} =
      Enum.reduce(law_to_nodes, {[], 0, MapSet.new()}, fn {lrt_name, node_names},
                                                          {upd, skip, miss} ->
        case Map.get(lrt_rows, lrt_name) do
          nil ->
            {upd, skip + 1, miss}

          [lrt_row_id | _] ->
            {resolved_ids, new_miss} =
              Enum.reduce(node_names, {[], miss}, fn node_name, {ids, m} ->
                case Map.get(node_id_map, node_name) do
                  nil -> {ids, MapSet.put(m, node_name)}
                  id -> {[id | ids], m}
                end
              end)

            if resolved_ids == [] do
              {upd, skip, new_miss}
            else
              update = %{"id" => lrt_row_id, "Hierarchy" => resolved_ids}
              {[update | upd], skip, new_miss}
            end
        end
      end)

    if skipped_laws > 0 do
      Mix.shell().info("Skipped #{skipped_laws} laws not found in LRT")
    end

    if MapSet.size(missing_nodes) > 0 do
      Mix.shell().info(
        "Missing hierarchy nodes: #{missing_nodes |> MapSet.to_list() |> Enum.join(", ")}"
      )
    end

    if updates == [] do
      Mix.shell().info("No updates to apply")
    else
      Mix.shell().info("Updating #{length(updates)} LRT rows with hierarchy links...")

      case Client.batch_update(config, :lrt, updates) do
        {:ok, count} ->
          Mix.shell().info("\n=== Complete ===")
          Mix.shell().info("Updated: #{count} LRT rows")

        {:error, reason} ->
          Mix.shell().error("Update failed: #{inspect(reason)}")
          System.halt(1)
      end
    end
  end

  # ── Auth ──

  defp authenticate(config_id) do
    unless config_id do
      Mix.shell().error("No sync configuration found. Provide --config UUID.")
      System.halt(1)
    end

    sync_config = SertantaiLegal.Repo.get!(SyncConfiguration, config_id)
    creds = Credentials.decrypt(sync_config.encrypted_credentials, sync_config.credentials_iv)

    {:ok, authed_config} =
      BaserowProvider.authenticate(%{
        "base_url" => sync_config.target_config["base_url"],
        "credentials" => creds
      })

    authed_config = Map.merge(authed_config, sync_config.target_config)
    Mix.shell().info("Authenticated with Baserow")
    authed_config
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end
end

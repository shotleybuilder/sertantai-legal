defmodule SertantaiLegal.Sync.Engine do
  @moduledoc """
  Orchestrates a sync execution: loads config, queries data, pushes to provider,
  and records the job result.

  Uses a map-based CUD algorithm:
  1. Fetch all Baserow rows for a table → Name → row_id map
  2. Format Postgres rows and split into creates/updates by checking Name against the map
  3. Delete reconciliation: Baserow Names not in Postgres set → deletes
  4. Batch creates, updates, deletes via provider
  """

  require Logger

  alias SertantaiLegal.Sync.{
    ActorTupleSync,
    Credentials,
    ProfileQuery,
    Providers.Baserow
  }

  @doc """
  Execute a full sync for the given sync configuration.
  Creates a job record, runs the sync, and updates job status.
  """
  def run(sync_config_id) do
    with {:ok, sync_config} <- load_sync_config(sync_config_id),
         {:ok, profile} <- load_profile(sync_config.sync_profile_id),
         {:ok, entitlement} <- load_entitlement(sync_config.organization_id),
         :ok <- validate_profile_against_entitlement(profile, entitlement),
         {:ok, job} <- create_job(sync_config),
         {:ok, job} <- start_job(job) do
      execute_sync(sync_config, profile, entitlement, job)
    end
  end

  @doc """
  Delete all synced rows from the provider and clear row mappings.
  Used by --clean flag and "clean" Oban operation.
  """
  def clean(sync_config_id) do
    with {:ok, sync_config} <- load_sync_config(sync_config_id) do
      credentials = decrypt_credentials(sync_config)
      provider_config = build_provider_config(sync_config, credentials)

      with {:ok, provider_config} <-
             authenticate_provider(sync_config.provider, provider_config) do
        provider = provider_module(sync_config.provider)

        tables =
          [
            {:lrt, provider_config["lrt_table_id"]},
            {:lat, provider_config["lat_table_id"]},
            {:actor_tuples, provider_config["actor_tuples_table_id"]},
            {:controls, provider_config["controls_table_id"]},
            {:control_mappings, provider_config["control_mappings_table_id"]}
          ]
          |> Enum.reject(fn {_, id} -> is_nil(id) end)

        total_deleted =
          Enum.reduce(tables, 0, fn {label, table_id}, acc ->
            case clean_table(provider, provider_config, table_id) do
              {:ok, count} ->
                Logger.info("[Sync] Cleaned #{label}: deleted #{count} rows")
                acc + count

              {:error, reason} ->
                Logger.warning("[Sync] Failed to clean #{label}: #{reason}")
                acc
            end
          end)

        # Clear all row mappings for this config
        {:ok, bin} = Ecto.UUID.dump(sync_config_id)

        SertantaiLegal.Repo.query!(
          "DELETE FROM sync_row_mappings WHERE sync_configuration_id = $1",
          [bin]
        )

        Logger.info("[Sync] Row mappings cleared for config #{sync_config_id}")

        # Clear per-table last_synced_at timestamps
        update_target_config(sync_config, Map.delete(sync_config.target_config, "last_synced_at"))

        {:ok, %{tables_cleaned: length(tables), rows_deleted: total_deleted}}
      end
    end
  end

  defp clean_table(_provider, provider_config, table_id) do
    # List all row IDs via direct API, then batch-delete via direct API
    # (We bypass the provider's batch_delete because we need the raw table_id,
    # not a table_key like :lrt/:lat)
    base_url = provider_config["base_url"]
    jwt = provider_config["jwt"]

    headers = [
      {"Authorization", "JWT #{jwt}"},
      {"Content-Type", "application/json"}
    ]

    with {:ok, %{body: %{"count" => count}}} <-
           Req.get("#{base_url}/api/database/rows/table/#{table_id}/?size=1",
             headers: headers,
             receive_timeout: 30_000
           ) do
      if count == 0 do
        {:ok, 0}
      else
        pages = max(ceil(count / 200), 1)

        ids =
          Enum.flat_map(1..pages, fn page ->
            {:ok, %{body: %{"results" => results}}} =
              Req.get(
                "#{base_url}/api/database/rows/table/#{table_id}/?size=200&page=#{page}&fields=",
                headers: headers,
                receive_timeout: 30_000
              )

            Enum.map(results, & &1["id"])
          end)

        ids
        |> Enum.chunk_every(200)
        |> Enum.each(fn chunk ->
          Req.post!(
            "#{base_url}/api/database/rows/table/#{table_id}/batch-delete/",
            headers: headers,
            json: %{"items" => chunk},
            receive_timeout: 120_000
          )
        end)

        {:ok, length(ids)}
      end
    end
  end

  # ── Execution ─────────────────────────────────────────────────────

  defp execute_sync(sync_config, profile, entitlement, job) do
    credentials = decrypt_credentials(sync_config)
    provider_config = build_provider_config(sync_config, credentials)
    field_tier = entitlement.field_tier
    start_time = System.monotonic_time()

    with {:ok, provider_config} <- authenticate_provider(sync_config.provider, provider_config),
         :ok <- validate_workspace(provider_config, sync_config),
         :ok <- prepare_tables(sync_config.provider, provider_config, sync_config),
         {:ok, lrt_rows} <-
           ProfileQuery.query_lrt(profile, field_tier,
             organization_id: sync_config.organization_id
           ),
         {:ok, job} <-
           sync_lrt(provider_config, lrt_rows, field_tier, sync_config, job),
         {:ok, job} <-
           maybe_sync_lat(
             provider_config,
             lrt_rows,
             profile,
             entitlement,
             sync_config,
             job
           ),
         {:ok, job} <-
           maybe_sync_actor_tuples(provider_config, sync_config, job),
         {:ok, job} <-
           maybe_sync_controls(provider_config, lrt_rows, sync_config, job),
         {:ok, job} <-
           maybe_sync_control_mappings(provider_config, sync_config, job) do
      checkpoint = max_updated_at(lrt_rows)

      {:ok, job} =
        complete_job(job, %{
          law_count: length(lrt_rows),
          sync_checkpoint: checkpoint
        })

      update_sync_config_status(sync_config, :completed, job)

      duration = System.monotonic_time() - start_time

      :telemetry.execute([:sync, :job, :complete], %{duration: duration}, %{
        sync_config_id: sync_config.id,
        organization_id: sync_config.organization_id,
        status: :completed,
        law_count: job.law_count,
        rows_created: Map.get(job, :rows_created, 0),
        rows_updated: Map.get(job, :rows_updated, 0),
        rows_deleted: Map.get(job, :rows_deleted, 0)
      })

      {:ok, job}
    else
      {:error, reason} ->
        fail_job(job, reason)
        update_sync_config_status(sync_config, :failed, nil)

        duration = System.monotonic_time() - start_time

        :telemetry.execute([:sync, :job, :complete], %{duration: duration}, %{
          sync_config_id: sync_config.id,
          organization_id: sync_config.organization_id,
          status: :failed,
          error: inspect(reason)
        })

        {:error, reason}
    end
  end

  # ── Generic sync_table ───────────────────────────────────────────

  @doc false
  defp sync_table(
         provider,
         provider_config,
         table_key,
         formatted_rows,
         postgres_names,
         sync_config
       ) do
    sync_start_time = DateTime.utc_now()

    # 1. Fetch Baserow Name → row_id map
    with {:ok, remote_map} <- provider.list_all_rows(provider_config, table_key) do
      # 2. Split formatted rows into creates and updates
      {creates, updates} = split_cud(formatted_rows, remote_map)

      # 3. Delete reconciliation
      deletes = find_deletes(remote_map, postgres_names)

      Logger.info(
        "[Sync] #{table_key} CUD: #{length(creates)} create, #{length(updates)} update, " <>
          "#{length(deletes)} delete"
      )

      # 4. Execute creates
      created_count =
        if creates != [] do
          case provider.batch_create(provider_config, table_key, creates) do
            {:ok, mappings} ->
              length(mappings)

            {:error, reason} ->
              Logger.error("[Sync] #{table_key} create failed: #{inspect(reason)}")
              0
          end
        else
          0
        end

      # 5. Execute updates
      updated_count =
        if updates != [] do
          case provider.batch_update(provider_config, table_key, updates) do
            {:ok, count} ->
              count

            {:error, reason} ->
              Logger.warning("[Sync] #{table_key} update failed: #{inspect(reason)}")
              0
          end
        else
          0
        end

      # 6. Execute deletes
      deleted_count =
        if deletes != [] do
          policy = sync_config.on_filter_change || :delete

          case policy do
            :delete ->
              ext_ids = Enum.map(deletes, fn {_name, row_id} -> row_id end)

              case provider.batch_delete(provider_config, table_key, ext_ids) do
                {:ok, count} ->
                  count

                {:error, reason} ->
                  Logger.warning("[Sync] #{table_key} delete failed: #{inspect(reason)}")
                  0
              end

            _ ->
              Logger.info("[Sync] #{length(deletes)} orphaned rows (policy: #{policy})")
              0
          end
        else
          0
        end

      # 7. Update per-table last_synced_at
      update_table_synced_at(sync_config, table_key, sync_start_time)

      {:ok, %{created: created_count, updated: updated_count, deleted: deleted_count}, remote_map}
    end
  end

  # Split formatted rows into creates and updates by checking Name against remote_map.
  # Updates get "id" injected (the Baserow row_id).
  defp split_cud(formatted_rows, remote_map) do
    Enum.reduce(formatted_rows, {[], []}, fn row, {creates, updates} ->
      name = row["Name"]

      case Map.get(remote_map, name) do
        nil ->
          {[row | creates], updates}

        row_id ->
          updated_row = Map.put(row, "id", row_id)
          {creates, [updated_row | updates]}
      end
    end)
    |> then(fn {creates, updates} -> {Enum.reverse(creates), Enum.reverse(updates)} end)
  end

  # Find Baserow names that are NOT in the Postgres set → delete candidates.
  # Returns list of {name, row_id} tuples.
  defp find_deletes(remote_map, postgres_names) do
    postgres_name_set = MapSet.new(postgres_names)

    remote_map
    |> Enum.reject(fn {name, _row_id} -> MapSet.member?(postgres_name_set, name) end)
    |> Enum.map(fn {name, row_id} -> {name, row_id} end)
  end

  # ── LRT Sync ─────────────────────────────────────────────────────

  defp sync_lrt(provider_config, lrt_rows, field_tier, sync_config, job) do
    provider = provider_module(sync_config.provider)

    # Validate holder vocabulary — warn on drift but don't block sync.
    case provider.validate_holder_vocabulary(lrt_rows) do
      :ok ->
        :ok

      {:error, unknown} ->
        Logger.warning(
          "[Sync] #{length(unknown)} actor labels not in dictionary (will sync as-is): #{inspect(unknown)}"
        )
    end

    # Format rows for the provider
    formatted =
      Enum.map(lrt_rows, fn row ->
        provider.format_lrt_row(row, field_tier)
      end)

    # Collect all Postgres Names for delete reconciliation
    postgres_names = Enum.map(formatted, fn row -> row["Name"] end) |> Enum.reject(&is_nil/1)

    case sync_table(provider, provider_config, :lrt, formatted, postgres_names, sync_config) do
      {:ok, %{created: c, updated: u, deleted: d}, _remote_map} ->
        {:ok, %{job | rows_created: c, rows_updated: u, rows_deleted: d}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── LAT Sync ─────────────────────────────────────────────────────

  defp maybe_sync_lat(_config, _lrt_rows, %{include_lat: false}, _ent, _sc, job) do
    {:ok, job}
  end

  defp maybe_sync_lat(_config, _lrt_rows, _profile, %{data_tier: :lrt_only}, _sc, job) do
    {:ok, job}
  end

  defp maybe_sync_lat(
         provider_config,
         lrt_rows,
         _profile,
         _entitlement,
         sync_config,
         job
       ) do
    # Check LAT table is configured
    lat_table_id = get_in(sync_config.target_config, ["lat_table_id"])

    if is_nil(lat_table_id) do
      Logger.warning("LAT sync requested but no lat_table_id configured")
      {:ok, job}
    else
      # Only query LAT for in-force laws (exclude revoked from duty table)
      in_force_lrt =
        Enum.reject(lrt_rows, fn row ->
          live = Map.get(row, :live) || Map.get(row, "live")

          is_binary(live) and
            (String.contains?(live, "Revoked") or String.contains?(live, "Repealed") or
               String.contains?(live, "Abolished"))
        end)

      lrt_ids = Enum.map(in_force_lrt, & &1.id)
      provider = provider_module(sync_config.provider)

      lat_section_types = get_in(sync_config.target_config, ["lat_section_types"])
      lat_drrp_types = get_in(sync_config.target_config, ["lat_drrp_types"])
      lat_aggregated = get_in(sync_config.target_config, ["lat_aggregated"]) == true

      lat_governed_only =
        get_in(sync_config.target_config, ["lat_governed_only"]) == true

      lat_min_significance =
        get_in(sync_config.target_config, ["lat_min_provision_significance"])

      lat_query_fn =
        if lat_aggregated do
          fn ids ->
            ProfileQuery.query_lat_aggregated(ids,
              drrp_types: lat_drrp_types,
              governed_only: lat_governed_only,
              min_significance: lat_min_significance
            )
          end
        else
          fn ids ->
            ProfileQuery.query_lat(ids,
              section_types: lat_section_types,
              drrp_types: lat_drrp_types
            )
          end
        end

      with {:ok, lat_rows} <- lat_query_fn.(lrt_ids) do
        # Format LAT rows with link_row references to parent LRT
        formatted =
          Enum.map(lat_rows, fn lat ->
            # Legal_Register link: text value (law_name matches LRT primary field)
            provider.format_lat_row(lat, lat.law_name)
          end)

        # Collect all Postgres Names (section_ids) for delete reconciliation
        postgres_names =
          Enum.map(formatted, fn row -> row["Name"] end) |> Enum.reject(&is_nil/1)

        case sync_table(provider, provider_config, :lat, formatted, postgres_names, sync_config) do
          {:ok, _counts, _remote_map} ->
            {:ok, Map.update(job, :lat_count, length(lat_rows), fn _ -> length(lat_rows) end)}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  # ── Actor Tuples ──────────────────────────────────────────────────

  defp maybe_sync_actor_tuples(provider_config, sync_config, job) do
    actor_table_id = get_in(sync_config.target_config, ["actor_tuples_table_id"])

    if is_nil(actor_table_id) do
      # No actor tuples table configured — skip
      {:ok, job}
    else
      org_id = sync_config.organization_id
      provider = provider_module(sync_config.provider)
      governed_only = get_in(sync_config.target_config, ["governed_only"]) != false

      lat_table_id = get_in(sync_config.target_config, ["lat_table_id"])

      with {:ok, tuples} <- ActorTupleSync.extract_tuples(org_id, governed_only: governed_only) do
        formatted = ActorTupleSync.format_rows(tuples)

        # Collect all Postgres Names for delete reconciliation
        postgres_names =
          Enum.map(formatted, fn row -> row["Name"] end) |> Enum.reject(&is_nil/1)

        case sync_table(
               provider,
               provider_config,
               :actor_tuples,
               formatted,
               postgres_names,
               sync_config
             ) do
          {:ok, _counts, _remote_map} ->
            # Re-link LAT provisions to current tuple set (idempotent)
            if lat_table_id do
              link_lat_to_tuples(
                provider_config,
                provider,
                sync_config,
                postgres_names
              )
            end

            {:ok, job}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  # ── Controls sync ─────────────────────────────────────────────────

  defp maybe_sync_controls(provider_config, lrt_rows, sync_config, job) do
    controls_table_id = get_in(sync_config.target_config, ["controls_table_id"])

    if is_nil(controls_table_id) do
      {:ok, job}
    else
      provider = provider_module(sync_config.provider)

      # Get law_names from the org's LRT rows
      law_names = Enum.map(lrt_rows, & &1.name) |> Enum.reject(&is_nil/1)

      with {:ok, controls} <-
             SertantaiLegal.Legal.Control
             |> Ash.Query.for_read(:by_law_names, %{law_names: law_names})
             |> Ash.read() do
        formatted =
          Enum.map(controls, fn control ->
            # Legal_Register link: text value (law_name matches LRT primary field)
            provider.format_control_row(control, control.law_name)
          end)

        # Collect all Postgres Names for delete reconciliation
        postgres_names =
          Enum.map(formatted, fn row -> row["Name"] end) |> Enum.reject(&is_nil/1)

        case sync_table(
               provider,
               provider_config,
               :controls,
               formatted,
               postgres_names,
               sync_config
             ) do
          {:ok, _counts, _remote_map} ->
            {:ok, job}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp maybe_sync_control_mappings(provider_config, sync_config, job) do
    cm_table_id = get_in(sync_config.target_config, ["control_mappings_table_id"])

    if is_nil(cm_table_id) do
      {:ok, job}
    else
      provider = provider_module(sync_config.provider)
      lat_table_id = get_in(sync_config.target_config, ["lat_table_id"])

      # Get law_names from the org's synced controls (query directly from Postgres)
      # We need controls that are applicable to this org's law register
      with {:ok, sync_config} <- {:ok, sync_config},
           {:ok, profile} <- load_profile(sync_config.sync_profile_id),
           {:ok, entitlement} <- load_entitlement(sync_config.organization_id),
           {:ok, lrt_rows} <-
             ProfileQuery.query_lrt(profile, entitlement.field_tier,
               organization_id: sync_config.organization_id
             ) do
        law_names = Enum.map(lrt_rows, & &1.name) |> Enum.reject(&is_nil/1)

        with {:ok, mappings} <-
               SertantaiLegal.Legal.ControlMapping
               |> Ash.Query.for_read(:by_law_names, %{law_names: law_names})
               |> Ash.read() do
          # All links use text values — Baserow resolves by matching target table's primary field.

          # Build a set of LAT section_ids from Postgres
          # TODO: this matches raw section_ids, not aggregated Duties Names — see GH issue
          lat_postgres_names =
            if lat_table_id do
              lrt_ids = Enum.map(lrt_rows, & &1.id)

              case ProfileQuery.query_lat(lrt_ids) do
                {:ok, lat_rows} -> MapSet.new(lat_rows, fn lat -> lat.section_id end)
                _ -> MapSet.new()
              end
            else
              MapSet.new()
            end

          formatted =
            Enum.map(mappings, fn mapping ->
              # Controls link: Postgres PK (matches Controls primary field "Name")
              control_name = to_string(mapping.control_id)

              # Legal_Register link: law_name (matches LRT primary field)
              lrt_name = mapping.law_name

              # Duties link: section_id or nearest parent in LAT table
              duties_name = find_parent_in_set(mapping.section_id, lat_postgres_names)

              provider.format_control_mapping_row(mapping, control_name, duties_name, lrt_name)
            end)

          # Collect all Postgres Names for delete reconciliation
          postgres_names =
            Enum.map(formatted, fn row -> row["Name"] end) |> Enum.reject(&is_nil/1)

          case sync_table(
                 provider,
                 provider_config,
                 :control_mappings,
                 formatted,
                 postgres_names,
                 sync_config
               ) do
            {:ok, _counts, _remote_map} ->
              {:ok, job}

            {:error, reason} ->
              {:error, reason}
          end
        end
      end
    end
  end

  # Walk up the section_id hierarchy stripping trailing parentheticals
  # until we find a match in the given set.
  # e.g. UK_uksi_1999_3242:reg.3(1)(a) -> reg.3(1) -> reg.3
  defp find_parent_in_set(section_id, name_set) do
    if MapSet.member?(name_set, section_id) do
      section_id
    else
      parent = Regex.replace(~r/\([^()]*\)$/, section_id, "")

      cond do
        parent == section_id -> nil
        MapSet.member?(name_set, parent) -> parent
        true -> find_parent_in_set(parent, name_set)
      end
    end
  end

  # ── LAT ↔ Actor Tuple linking ────────────────────────────────────

  defp link_lat_to_tuples(
         provider_config,
         provider,
         sync_config,
         tuple_names
       ) do
    # Build set of known Actor Names for text-based linking
    tuple_name_set = MapSet.new(tuple_names)

    # Fetch LAT remote_map to look up row IDs by section_id (Name)
    case provider.list_all_rows(provider_config, :lat) do
      {:ok, lat_remote_map} ->
        lat_section_ids = Map.keys(lat_remote_map)

        if lat_section_ids == [] do
          Logger.debug("[Sync] No LAT rows in Baserow — skipping tuple linking")
        else
          # Query actors for each LAT provision
          {:ok, org_bin} = Ecto.UUID.dump(sync_config.organization_id)

          {:ok, %{rows: rows}} =
            SertantaiLegal.Repo.query(
              """
              SELECT la.section_id,
                (SELECT array_agg(
                  jsonb_build_object('label', a->>'label', 'position', a->>'position', 'label_source', a->>'label_source')
                ) FROM unnest(la.actors) a
                  WHERE a->>'position' IS NOT NULL AND a->>'label_source' = 'canonical'
                ) as actors_json,
                la.drrp_types
              FROM legal_articles la
              JOIN org_applicabilities oa ON oa.law_name = la.law_name
                AND oa.organization_id = $1 AND oa.status = 'yes'
              WHERE la.section_id = ANY($2)
              """,
              [org_bin, lat_section_ids]
            )

          # Build update rows: each LAT row gets its matching Actor Names (text-based linking)
          updates =
            rows
            |> Enum.map(fn [section_id, actors_json, drrp_types] ->
              # Look up Baserow row_id from the LAT remote_map
              lat_row_id = Map.get(lat_remote_map, section_id)
              actors = actors_json || []
              drrps = drrp_types || []

              actor_names =
                for a <- actors,
                    dt <- drrps,
                    label = a["label"],
                    position = a["position"],
                    label != nil and position != nil,
                    name = "#{label}|#{position}|#{dt}",
                    MapSet.member?(tuple_name_set, name),
                    do: name

              if lat_row_id && actor_names != [] do
                %{"id" => lat_row_id, "Actors" => Enum.uniq(actor_names)}
              end
            end)
            |> Enum.reject(&is_nil/1)

          if updates != [] do
            case provider.batch_update(provider_config, :lat, updates) do
              {:ok, count} ->
                Logger.info("[Sync] Linked #{count} LAT provisions to actor tuples")

              {:error, reason} ->
                Logger.warning("[Sync] Failed to link LAT to tuples: #{reason}")
            end
          end
        end

      {:error, reason} ->
        Logger.warning("[Sync] Failed to fetch LAT rows for tuple linking: #{inspect(reason)}")
    end
  end

  # ── Workspace Validation ──────────────────────────────────────────

  defp validate_workspace(provider_config, sync_config) do
    expected_workspace_id = sync_config.target_config["workspace_id"]
    base_url = provider_config["base_url"]
    jwt = provider_config["jwt"]

    table_ids =
      [
        provider_config["lrt_table_id"],
        provider_config["lat_table_id"],
        provider_config["actor_tuples_table_id"],
        provider_config["controls_table_id"],
        provider_config["control_mappings_table_id"]
      ]
      |> Enum.reject(&is_nil/1)

    if table_ids == [] do
      {:error, "No table IDs configured"}
    else
      workspace_ids =
        Enum.reduce_while(table_ids, {:ok, []}, fn table_id, {:ok, acc} ->
          case fetch_table_workspace(base_url, jwt, table_id) do
            {:ok, workspace_id} -> {:cont, {:ok, [workspace_id | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case workspace_ids do
        {:ok, ids} ->
          unique_ids = Enum.uniq(ids)

          cond do
            length(unique_ids) > 1 ->
              {:error,
               "Tables belong to different workspaces: #{inspect(unique_ids)}. All tables must be in the same workspace."}

            expected_workspace_id && hd(unique_ids) != expected_workspace_id ->
              {:error,
               "Tables belong to workspace #{hd(unique_ids)}, expected #{expected_workspace_id}"}

            true ->
              :ok
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_table_workspace(base_url, jwt, table_id) do
    headers = [
      {"Authorization", "JWT #{jwt}"},
      {"Content-Type", "application/json"}
    ]

    case Req.get("#{base_url}/api/database/tables/#{table_id}/",
           headers: headers,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: %{"database" => %{"group" => %{"id" => workspace_id}}}}} ->
        {:ok, workspace_id}

      {:ok, %{status: 200, body: %{"database" => %{"workspace" => %{"id" => workspace_id}}}}} ->
        # Newer Baserow versions use "workspace" instead of "group"
        {:ok, workspace_id}

      {:ok, %{status: 200, body: body}} ->
        # Extract workspace_id from nested structure — fallback
        db = body["database"] || %{}
        ws_id = get_in(db, ["group", "id"]) || get_in(db, ["workspace", "id"])

        if ws_id do
          {:ok, ws_id}
        else
          Logger.warning("[Sync] Could not extract workspace ID from table #{table_id} response")
          {:ok, :unknown}
        end

      {:ok, %{status: 404}} ->
        {:error, "Table #{table_id} not found in Baserow"}

      {:ok, %{status: status, body: body}} ->
        {:error, "Baserow table lookup returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to fetch table #{table_id}: #{inspect(reason)}"}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp load_sync_config(id) do
    case Ash.get(SertantaiLegal.Sync.SyncConfiguration, id) do
      {:ok, config} -> {:ok, config}
      {:error, _} -> {:error, "Sync configuration #{id} not found"}
    end
  end

  defp load_profile(id) do
    case Ash.get(SertantaiLegal.Sync.SyncProfile, id) do
      {:ok, profile} -> {:ok, profile}
      {:error, _} -> {:error, "Sync profile #{id} not found"}
    end
  end

  defp load_entitlement(organization_id) do
    case SertantaiLegal.Sync.OrgEntitlement
         |> Ash.Query.for_read(:by_organization, %{organization_id: organization_id})
         |> Ash.read() do
      {:ok, [entitlement | _]} -> {:ok, entitlement}
      {:ok, []} -> {:error, "No entitlement found for organization #{organization_id}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_profile_against_entitlement(profile, entitlement) do
    entitled_families = MapSet.new(entitlement.families)
    profile_families = MapSet.new(profile.families)

    if MapSet.subset?(profile_families, entitled_families) do
      :ok
    else
      unauthorized = MapSet.difference(profile_families, entitled_families) |> MapSet.to_list()
      {:error, "Profile includes families not in entitlement: #{inspect(unauthorized)}"}
    end
  end

  defp decrypt_credentials(sync_config) do
    Credentials.decrypt(sync_config.encrypted_credentials, sync_config.credentials_iv)
  end

  defp build_provider_config(sync_config, credentials) do
    tc = sync_config.target_config

    %{
      "target_config" => tc,
      "credentials" => credentials,
      "base_url" => tc["base_url"],
      "lrt_table_id" => tc["lrt_table_id"],
      "lat_table_id" => tc["lat_table_id"],
      "actor_tuples_table_id" => tc["actor_tuples_table_id"],
      "controls_table_id" => tc["controls_table_id"],
      "control_mappings_table_id" => tc["control_mappings_table_id"]
    }
  end

  defp provider_module(:baserow), do: SertantaiLegal.Sync.Providers.Baserow
  # Future: :airtable, :notion, :zapier

  defp authenticate_provider(:baserow, config), do: Baserow.authenticate(config)
  defp authenticate_provider(_, config), do: {:ok, config}

  defp prepare_tables(:baserow, config, sync_config) do
    lrt_name = sync_config.target_config["lrt_table_name"] || "Legal Register"
    Baserow.prepare_table(config, :lrt, lrt_name)
  end

  defp prepare_tables(_, _, _), do: :ok

  defp create_job(sync_config) do
    SertantaiLegal.Sync.SyncJob
    |> Ash.Changeset.for_create(:create, %{
      sync_configuration_id: sync_config.id,
      organization_id: sync_config.organization_id,
      status: :queued
    })
    |> Ash.create()
  end

  defp start_job(job) do
    job
    |> Ash.Changeset.for_update(:start, %{})
    |> Ash.update()
  end

  defp complete_job(job, attrs) do
    job
    |> Ash.Changeset.for_update(:complete, attrs)
    |> Ash.update()
  end

  defp fail_job(job, reason) do
    message = if is_binary(reason), do: reason, else: inspect(reason)

    job
    |> Ash.Changeset.for_update(:fail, %{error_message: message})
    |> Ash.update()
  end

  defp update_sync_config_status(sync_config, status, job) do
    summary =
      if job do
        %{
          rows_created: Map.get(job, :rows_created, 0),
          rows_updated: Map.get(job, :rows_updated, 0),
          rows_deleted: Map.get(job, :rows_deleted, 0),
          rows_failed: Map.get(job, :rows_failed, 0)
        }
      end

    sync_config
    |> Ash.Changeset.for_update(:update_sync_status, %{
      sync_status: status,
      last_synced_at: DateTime.utc_now(),
      last_sync_summary: summary
    })
    |> Ash.update()
  end

  # Update per-table last_synced_at in target_config
  defp update_table_synced_at(sync_config, table_key, timestamp) do
    tc = sync_config.target_config
    table_timestamps = Map.get(tc, "last_synced_at", %{})

    updated_timestamps =
      Map.put(table_timestamps, to_string(table_key), DateTime.to_iso8601(timestamp))

    updated_tc = Map.put(tc, "last_synced_at", updated_timestamps)
    update_target_config(sync_config, updated_tc)
  end

  defp update_target_config(sync_config, new_target_config) do
    sync_config
    |> Ash.Changeset.for_update(:update, %{target_config: new_target_config})
    |> Ash.update()
  end

  defp max_updated_at([]), do: nil

  defp max_updated_at(rows) do
    rows
    |> Enum.map(& &1.updated_at)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(NaiveDateTime, fn -> nil end)
    |> case do
      %NaiveDateTime{} = ndt -> DateTime.from_naive!(ndt, "Etc/UTC")
      other -> other
    end
  end
end

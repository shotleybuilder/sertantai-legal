defmodule SertantaiLegal.Sync.Engine do
  @moduledoc """
  Orchestrates a sync execution: loads config, queries data, pushes to provider,
  tracks row mappings, and records the job result.
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

  # ── Execution ─────────────────────────────────────────────────────

  defp execute_sync(sync_config, profile, entitlement, job) do
    credentials = decrypt_credentials(sync_config)
    provider_config = build_provider_config(sync_config, credentials)
    field_tier = entitlement.field_tier

    with {:ok, provider_config} <- authenticate_provider(sync_config.provider, provider_config),
         :ok <- prepare_tables(sync_config.provider, provider_config, sync_config),
         {:ok, lrt_rows} <-
           ProfileQuery.query_lrt(profile, field_tier,
             organization_id: sync_config.organization_id
           ),
         {:ok, job} <- sync_lrt(provider_config, lrt_rows, field_tier, sync_config, job),
         {:ok, job} <-
           maybe_sync_lat(provider_config, lrt_rows, profile, entitlement, sync_config, job),
         {:ok, job} <-
           maybe_sync_actor_tuples(provider_config, sync_config, job) do
      checkpoint = max_updated_at(lrt_rows)

      {:ok, job} =
        complete_job(job, %{
          law_count: length(lrt_rows),
          sync_checkpoint: checkpoint
        })

      update_sync_config_status(sync_config, :completed, job)

      {:ok, job}
    else
      {:error, reason} ->
        fail_job(job, reason)
        update_sync_config_status(sync_config, :failed, nil)
        {:error, reason}
    end
  end

  defp sync_lrt(provider_config, lrt_rows, field_tier, sync_config, job) do
    provider = provider_module(sync_config.provider)

    # Validate holder vocabulary — warn on drift but don't block sync.
    # Unknown labels are logged; they'll appear as plain text in Baserow
    # multi-selects until the actor dictionary is updated.
    case Baserow.validate_holder_vocabulary(lrt_rows) do
      :ok ->
        :ok

      {:error, unknown} ->
        Logger.warning(
          "[Sync] #{length(unknown)} actor labels not in dictionary (will sync as-is): #{inspect(unknown)}"
        )
    end

    field_specs = Baserow.lrt_field_specs(field_tier)

    with :ok <- provider.ensure_fields(provider_config, :lrt, field_specs) do
      # Format rows for the provider
      formatted =
        Enum.map(lrt_rows, fn row ->
          Baserow.format_lrt_row(row, field_tier)
        end)

      case provider.batch_create(provider_config, :lrt, formatted) do
        {:ok, mappings} ->
          save_row_mappings(sync_config.id, :lrt, mappings, lrt_rows)
          {:ok, %{job | rows_created: length(mappings)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp maybe_sync_lat(_config, _lrt_rows, %{include_lat: false}, _ent, _sc, job) do
    {:ok, job}
  end

  defp maybe_sync_lat(_config, _lrt_rows, _profile, %{data_tier: :lrt_only}, _sc, job) do
    {:ok, job}
  end

  defp maybe_sync_lat(provider_config, lrt_rows, _profile, _entitlement, sync_config, job) do
    # Check LAT table is configured
    lat_table_id = get_in(sync_config.target_config, ["lat_table_id"])

    if is_nil(lat_table_id) do
      Logger.warning("LAT sync requested but no lat_table_id configured")
      {:ok, job}
    else
      lrt_ids = Enum.map(lrt_rows, & &1.id)
      provider = provider_module(sync_config.provider)

      # Load LRT row mappings so we can set link_row values
      lrt_mappings = load_lrt_mappings(sync_config.id)
      lrt_table_id = get_in(sync_config.target_config, ["lrt_table_id"])

      lat_section_types = get_in(sync_config.target_config, ["lat_section_types"])
      lat_drrp_types = get_in(sync_config.target_config, ["lat_drrp_types"])
      lat_aggregated = get_in(sync_config.target_config, ["lat_aggregated"]) == true

      lat_query_fn =
        if lat_aggregated do
          fn ids -> ProfileQuery.query_lat_aggregated(ids, drrp_types: lat_drrp_types) end
        else
          fn ids ->
            ProfileQuery.query_lat(ids,
              section_types: lat_section_types,
              drrp_types: lat_drrp_types
            )
          end
        end

      with {:ok, lat_rows} <- lat_query_fn.(lrt_ids),
           field_specs = Baserow.lat_field_specs(lrt_table_id),
           :ok <- provider.ensure_fields(provider_config, :lat, field_specs) do
        # Format LAT rows with link_row references to parent LRT
        # Skip rows where the parent LRT mapping is missing (orphaned provisions)
        formatted =
          lat_rows
          |> Enum.map(fn lat ->
            law_id_str =
              case lat.law_id do
                <<_::128>> -> Ecto.UUID.load!(lat.law_id)
                id when is_binary(id) -> id
                _ -> to_string(lat.law_id)
              end

            lrt_external_id = Map.get(lrt_mappings, law_id_str)
            {lat, lrt_external_id}
          end)
          |> Enum.reject(fn {_lat, ext_id} -> is_nil(ext_id) end)
          |> Enum.map(fn {lat, ext_id} -> Baserow.format_lat_row(lat, ext_id) end)

        case provider.batch_create(provider_config, :lat, formatted) do
          {:ok, mappings} ->
            save_row_mappings(sync_config.id, :lat, mappings, lat_rows)

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

      lat_table_id = get_in(sync_config.target_config, ["lat_table_id"])

      with {:ok, tuples} <- ActorTupleSync.extract_tuples(org_id),
           field_specs = ActorTupleSync.field_specs(tuples),
           :ok <- provider.ensure_fields(provider_config, :actor_tuples, field_specs) do
        formatted = ActorTupleSync.format_rows(tuples)

        case provider.batch_create(provider_config, :actor_tuples, formatted) do
          {:ok, tuple_mappings} ->
            save_row_mappings(sync_config.id, :actor_tuples, tuple_mappings, tuples)
            Logger.info("[Sync] Created #{length(tuple_mappings)} actor tuples")

            # Link LAT provisions to their matching tuples
            link_lat_to_tuples(
              provider_config,
              provider,
              sync_config,
              lat_table_id,
              actor_table_id,
              tuple_mappings
            )

            {:ok, job}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end

  defp link_lat_to_tuples(
         provider_config,
         provider,
         sync_config,
         lat_table_id,
         actor_table_id,
         tuple_mappings
       ) do
    # Ensure the link_row field exists on LAT
    # Ensure link_row field exists on LAT → Actor Tuples
    case provider.list_fields(provider_config, :lat) do
      {:ok, fields} ->
        unless Enum.any?(fields, &(&1["name"] == "Actor Roles")) do
          body = %{
            "name" => "Actor Roles",
            "type" => "link_row",
            "link_row_table_id" => actor_table_id
          }

          h = [
            {"Authorization", "JWT #{provider_config["jwt"]}"},
            {"Content-Type", "application/json"}
          ]

          case Req.post(
                 "#{provider_config["base_url"]}/api/database/fields/table/#{lat_table_id}/",
                 headers: h,
                 json: body,
                 receive_timeout: 30_000
               ) do
            {:ok, %{status: 200}} ->
              Logger.info("[Sync] Created 'Actor Roles' link field on LAT")

            {:ok, %{status: s, body: b}} ->
              Logger.warning("[Sync] Failed to create link field: #{s} #{inspect(b)}")

            {:error, reason} ->
              Logger.warning("[Sync] Failed to create link field: #{inspect(reason)}")
          end
        end

      _ ->
        :ok
    end

    # Build tuple lookup from mappings
    tuple_lookup =
      Map.new(tuple_mappings, fn m ->
        source_id = m.source_id || m[:source_id]
        ext_id = m.external_row_id || m[:external_row_id]
        {source_id, ext_id}
      end)

    # Load LAT row mappings
    lat_mappings = load_lat_mappings(sync_config.id)

    # Load LAT provisions with their actors from the DB
    lat_section_ids = Map.keys(lat_mappings)

    if lat_section_ids == [] do
      Logger.debug("[Sync] No LAT mappings — skipping tuple linking")
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

      # Build update rows: each LAT row gets its matching tuple IDs
      updates =
        rows
        |> Enum.map(fn [section_id, actors_json, drrp_types] ->
          lat_ext_id = Map.get(lat_mappings, section_id)
          actors = actors_json || []
          drrps = drrp_types || []

          tuple_ids =
            for a <- actors,
                dt <- drrps,
                label = a["label"],
                position = a["position"],
                label != nil and position != nil,
                key = "#{label}|#{position}|#{dt}",
                ext_id = Map.get(tuple_lookup, key),
                ext_id != nil,
                do: ext_id

          if lat_ext_id && tuple_ids != [] do
            %{"id" => lat_ext_id, "Actor Roles" => Enum.uniq(tuple_ids)}
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
  end

  defp load_lat_mappings(sync_config_id) do
    case SertantaiLegal.Sync.SyncRowMapping
         |> Ash.Query.for_read(:by_configuration_and_type, %{
           sync_configuration_id: sync_config_id,
           source_type: :lat
         })
         |> Ash.read() do
      {:ok, mappings} ->
        Map.new(mappings, fn m -> {m.source_id, m.external_row_id} end)

      _ ->
        %{}
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
      "actor_tuples_table_id" => tc["actor_tuples_table_id"]
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

  defp save_row_mappings(sync_config_id, source_type, mappings, _source_rows) do
    now = DateTime.utc_now()

    # Build source_id lookup from _source_id in mappings
    Enum.each(mappings, fn mapping ->
      source_id = mapping.source_id || mapping[:source_id]
      external_row_id = mapping.external_row_id || mapping[:external_row_id]

      if source_id && external_row_id do
        Ash.create(
          SertantaiLegal.Sync.SyncRowMapping,
          %{
            sync_configuration_id: sync_config_id,
            source_type: source_type,
            source_id: to_string(source_id),
            external_row_id: external_row_id,
            last_synced_at: now
          },
          action: :upsert
        )
      end
    end)
  end

  defp load_lrt_mappings(sync_config_id) do
    case SertantaiLegal.Sync.SyncRowMapping
         |> Ash.Query.for_read(:by_configuration_and_type, %{
           sync_configuration_id: sync_config_id,
           source_type: :lrt
         })
         |> Ash.read() do
      {:ok, mappings} ->
        Map.new(mappings, fn m -> {m.source_id, m.external_row_id} end)

      _ ->
        %{}
    end
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

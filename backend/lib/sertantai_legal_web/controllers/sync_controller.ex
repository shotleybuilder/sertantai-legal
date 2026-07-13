defmodule SertantaiLegalWeb.SyncController do
  @moduledoc """
  API endpoints for managing sync profiles, configurations, and triggering syncs.
  All endpoints require JWT auth + admin role.
  """

  use SertantaiLegalWeb, :controller

  require Logger

  alias SertantaiLegal.Sync
  alias SertantaiLegal.Sync.{Credentials, ProfileQuery}
  alias SertantaiLegal.Sync.Workers.SyncWorker

  # ── Entitlements ──────────────────────────────────────────────────

  def entitlement(conn, _params) do
    org_id = conn.assigns.organization_id

    case Sync.OrgEntitlement
         |> Ash.Query.for_read(:by_organization, %{organization_id: org_id})
         |> Ash.read() do
      {:ok, [ent | _]} -> json(conn, format_entitlement(ent))
      {:ok, []} -> conn |> put_status(404) |> json(%{error: "No entitlement found"})
      {:error, _} -> conn |> put_status(404) |> json(%{error: "No entitlement found"})
    end
  end

  # ── Profiles ──────────────────────────────────────────────────────

  def list_profiles(conn, _params) do
    org_id = conn.assigns.organization_id

    {:ok, profiles} =
      Ash.read(Sync.SyncProfile,
        action: :by_organization,
        arguments: %{organization_id: org_id}
      )

    json(conn, %{profiles: Enum.map(profiles, &format_profile/1)})
  end

  def create_profile(conn, params) do
    org_id = conn.assigns.organization_id
    attrs = Map.put(params, "organization_id", org_id)

    case Ash.create(Sync.SyncProfile, atomize_keys(attrs)) do
      {:ok, profile} ->
        conn |> put_status(201) |> json(format_profile(profile))

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  def update_profile(conn, %{"id" => id} = params) do
    with {:ok, profile} <- Ash.get(Sync.SyncProfile, id),
         :ok <- verify_org(conn, profile.organization_id),
         {:ok, updated} <- Ash.update(profile, atomize_keys(params)) do
      json(conn, format_profile(updated))
    else
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  def preview_profile(conn, params) do
    org_id = conn.assigns.organization_id

    # Build a temporary profile struct for counting
    profile = %{
      organization_id: org_id,
      families: params["families"] || [],
      geo_regions: params["geo_regions"],
      function_filter: params["function_filter"],
      fitness_entities: params["fitness_entities"],
      live_filter: params["live_filter"]
    }

    law_count = ProfileQuery.count_lrt(profile)

    lat_count =
      if params["include_lat"] do
        # Quick estimate: query IDs and count LAT
        {:ok, lrt_rows} = ProfileQuery.query_lrt(profile, :essential)
        lrt_ids = Enum.map(lrt_rows, & &1.id)
        ProfileQuery.count_lat(lrt_ids)
      else
        0
      end

    json(conn, %{matched_law_count: law_count, matched_lat_count: lat_count})
  end

  def delete_profile(conn, %{"id" => id}) do
    with {:ok, profile} <- Ash.get(Sync.SyncProfile, id),
         :ok <- verify_org(conn, profile.organization_id),
         :ok <- Ash.destroy(profile) do
      conn |> put_status(204) |> send_resp(204, "")
    else
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  # ── Configurations ────────────────────────────────────────────────

  def list_configurations(conn, _params) do
    org_id = conn.assigns.organization_id

    {:ok, configs} =
      Ash.read(Sync.SyncConfiguration,
        action: :by_organization,
        arguments: %{organization_id: org_id}
      )

    json(conn, %{configurations: Enum.map(configs, &format_configuration/1)})
  end

  def create_configuration(conn, params) do
    org_id = conn.assigns.organization_id

    # Encrypt credentials
    {encrypted, iv} = Credentials.encrypt(params["credentials"] || %{})

    attrs =
      params
      |> Map.put("organization_id", org_id)
      |> Map.put("encrypted_credentials", encrypted)
      |> Map.put("credentials_iv", iv)
      |> Map.delete("credentials")

    case Ash.create(Sync.SyncConfiguration, atomize_keys(attrs)) do
      {:ok, config} ->
        conn |> put_status(201) |> json(format_configuration(config))

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  def update_configuration(conn, %{"id" => id} = params) do
    with {:ok, config} <- Ash.get(Sync.SyncConfiguration, id),
         :ok <- verify_org(conn, config.organization_id) do
      # Re-encrypt credentials if provided
      attrs =
        if params["credentials"] do
          {encrypted, iv} = Credentials.encrypt(params["credentials"])

          params
          |> Map.put("encrypted_credentials", encrypted)
          |> Map.put("credentials_iv", iv)
          |> Map.delete("credentials")
        else
          params
        end

      case Ash.update(config, atomize_keys(attrs)) do
        {:ok, updated} -> json(conn, format_configuration(updated))
        {:error, error} -> conn |> put_status(422) |> json(%{error: inspect(error)})
      end
    else
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  def test_connection(conn, %{"id" => id}) do
    with {:ok, config} <- Ash.get(Sync.SyncConfiguration, id),
         :ok <- verify_org(conn, config.organization_id) do
      credentials = Credentials.decrypt(config.encrypted_credentials, config.credentials_iv)

      provider_config = %{
        "base_url" => config.target_config["base_url"],
        "lrt_table_id" => config.target_config["lrt_table_id"],
        "lat_table_id" => config.target_config["lat_table_id"],
        "credentials" => credentials
      }

      case SertantaiLegal.Sync.Providers.Baserow.test_connection(provider_config) do
        {:ok, info} -> json(conn, %{ok: true, info: info})
        {:error, reason} -> conn |> put_status(422) |> json(%{ok: false, error: reason})
      end
    end
  end

  def delete_configuration(conn, %{"id" => id}) do
    with {:ok, config} <- Ash.get(Sync.SyncConfiguration, id),
         :ok <- verify_org(conn, config.organization_id),
         :ok <- Ash.destroy(config) do
      conn |> put_status(204) |> send_resp(204, "")
    else
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  # ── Sync Execution ────────────────────────────────────────────────

  def trigger_sync(conn, %{"id" => id}) do
    with {:ok, config} <- Ash.get(Sync.SyncConfiguration, id),
         :ok <- verify_org(conn, config.organization_id) do
      # Enqueue persistent Oban job (replaces fire-and-forget Task.start)
      {:ok, oban_job} =
        SyncWorker.new(%{"sync_config_id" => config.id, "operation" => "sync"})
        |> Oban.insert()

      # Update status to queued
      Ash.update(config, %{sync_status: :queued}, action: :update_sync_status)

      json(conn, %{ok: true, message: "Sync queued", oban_job_id: oban_job.id})
    else
      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Unauthorized"})

      {:error, error} ->
        conn |> put_status(422) |> json(%{error: inspect(error)})
    end
  end

  # ── Jobs ──────────────────────────────────────────────────────────

  def list_jobs(conn, _params) do
    org_id = conn.assigns.organization_id

    {:ok, jobs} =
      Ash.read(Sync.SyncJob,
        action: :recent_by_organization,
        arguments: %{organization_id: org_id}
      )

    json(conn, %{jobs: Enum.map(jobs, &format_job/1)})
  end

  # ── Helpers ───────────────────────────────────────────────────────

  defp verify_org(conn, org_id) do
    if conn.assigns.organization_id == org_id, do: :ok, else: {:error, :unauthorized}
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          ArgumentError -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end

  defp format_entitlement(ent) do
    %{
      id: ent.id,
      organization_id: ent.organization_id,
      families: ent.families,
      data_tier: ent.data_tier,
      field_tier: ent.field_tier,
      source: ent.source,
      granted_at: ent.granted_at,
      expires_at: ent.expires_at
    }
  end

  defp format_profile(p) do
    %{
      id: p.id,
      name: p.name,
      description: p.description,
      families: p.families,
      geo_regions: p.geo_regions,
      function_filter: p.function_filter,
      fitness_entities: p.fitness_entities,
      live_filter: p.live_filter,
      include_lat: p.include_lat,
      include_amendments: p.include_amendments,
      matched_law_count: p.matched_law_count,
      matched_lat_count: p.matched_lat_count,
      is_active: p.is_active,
      deactivation_reason: p.deactivation_reason,
      inserted_at: p.inserted_at,
      updated_at: p.updated_at
    }
  end

  defp format_configuration(c) do
    %{
      id: c.id,
      sync_profile_id: c.sync_profile_id,
      name: c.name,
      provider: c.provider,
      target_config: c.target_config,
      field_mapping: c.field_mapping,
      sync_frequency: c.sync_frequency,
      on_filter_change: c.on_filter_change,
      on_entitlement_change: c.on_entitlement_change,
      sync_status: c.sync_status,
      last_synced_at: c.last_synced_at,
      last_sync_summary: c.last_sync_summary,
      is_active: c.is_active,
      inserted_at: c.inserted_at,
      updated_at: c.updated_at
    }
  end

  defp format_job(j) do
    %{
      id: j.id,
      sync_configuration_id: j.sync_configuration_id,
      status: j.status,
      started_at: j.started_at,
      completed_at: j.completed_at,
      law_count: j.law_count,
      lat_count: j.lat_count,
      rows_created: j.rows_created,
      rows_updated: j.rows_updated,
      rows_deleted: j.rows_deleted,
      rows_failed: j.rows_failed,
      error_message: j.error_message,
      inserted_at: j.inserted_at
    }
  end
end

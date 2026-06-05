defmodule SertantaiLegalWeb.ScreeningController do
  @moduledoc """
  Customer-facing API for applicability screening.

  All endpoints are org-scoped via `organization_id` from JWT claims.
  """
  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.OrgApplicability

  require Logger

  @doc "GET /api/screening/applicabilities — list org's applicability decisions"
  def index(conn, _params) do
    org_id = conn.assigns.organization_id

    case OrgApplicability.by_organization(org_id) do
      {:ok, records} ->
        json(conn, %{
          applicabilities: Enum.map(records, &serialize/1),
          count: length(records)
        })

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  @doc "PUT /api/screening/applicabilities/:law_name — upsert applicability for a law"
  def upsert(conn, %{"law_name" => law_name} = params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns[:current_user_id]

    attrs = %{
      organization_id: org_id,
      law_name: law_name,
      status: params["status"] || "unreviewed",
      source: :manual,
      notes: params["notes"],
      reviewed_at: DateTime.utc_now(),
      reviewed_by: user_id
    }

    case OrgApplicability.upsert(attrs) do
      {:ok, record} ->
        json(conn, serialize(record))

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: inspect(changeset)})
    end
  end

  @doc "POST /api/screening/applicabilities/bulk — bulk set status for multiple laws"
  def bulk_upsert(conn, %{"law_names" => law_names, "status" => status})
      when is_list(law_names) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns[:current_user_id]
    now = DateTime.utc_now()

    results =
      Enum.map(law_names, fn law_name ->
        OrgApplicability.upsert(%{
          organization_id: org_id,
          law_name: law_name,
          status: status,
          source: :manual,
          reviewed_at: now,
          reviewed_by: user_id
        })
      end)

    succeeded = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    json(conn, %{updated: succeeded, failed: failed, total: length(law_names)})
  end

  def bulk_upsert(conn, _params) do
    conn |> put_status(400) |> json(%{error: "law_names (array) and status are required"})
  end

  @doc "GET /api/screening/stats — aggregate counts for the org's screening progress"
  def stats(conn, _params) do
    org_id = conn.assigns.organization_id

    {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

    {:ok, %{rows: [[total_making]]}} =
      Repo.query(
        "SELECT COUNT(*) FROM uk_lrt WHERE is_making = true AND live NOT LIKE '%Revoked%' AND live NOT LIKE '%Repealed%' AND live NOT LIKE '%Abolished%'",
        []
      )

    {:ok, %{rows: status_rows}} =
      Repo.query(
        """
        SELECT oa.status, COUNT(*)
        FROM org_applicabilities oa
        WHERE oa.organization_id = $1
        GROUP BY oa.status
        """,
        [org_id_binary]
      )

    status_counts = Map.new(status_rows, fn [status, count] -> {status, count} end)

    {:ok, %{rows: family_rows}} =
      Repo.query(
        """
        SELECT u.family, COUNT(*) as law_count,
               SUM(CASE WHEN u.duties IS NOT NULL THEN jsonb_array_length(u.duties->'entries') ELSE 0 END) as duty_count
        FROM org_applicabilities oa
        JOIN uk_lrt u ON u.name = oa.law_name
        WHERE oa.organization_id = $1 AND oa.status = 'yes'
          AND u.family IS NOT NULL
        GROUP BY u.family
        ORDER BY law_count DESC
        """,
        [org_id_binary]
      )

    families =
      Enum.map(family_rows, fn [family, law_count, duty_count] ->
        %{family: family, law_count: law_count, duty_count: duty_count}
      end)

    reviewed =
      Map.get(status_counts, "yes", 0) +
        Map.get(status_counts, "no", 0) +
        Map.get(status_counts, "excluded", 0)

    total_tracked =
      reviewed + Map.get(status_counts, "unreviewed", 0)

    json(conn, %{
      total_making: total_making,
      total_tracked: total_tracked,
      reviewed: reviewed,
      by_status: %{
        yes: Map.get(status_counts, "yes", 0),
        no: Map.get(status_counts, "no", 0),
        excluded: Map.get(status_counts, "excluded", 0),
        unreviewed: Map.get(status_counts, "unreviewed", 0)
      },
      families: families
    })
  end

  @doc "POST /api/screening/sync — trigger Baserow sync for this org"
  def trigger_sync(conn, _params) do
    org_id = conn.assigns.organization_id

    # Find sync configuration for this org
    case Repo.query(
           "SELECT id FROM sync_configurations WHERE organization_id = $1 LIMIT 1",
           [Ecto.UUID.dump!(org_id)]
         ) do
      {:ok, %{rows: [[config_id]]}} ->
        config_uuid = Ecto.UUID.load!(config_id)

        case SertantaiLegal.Sync.Engine.run(config_uuid) do
          {:ok, result} ->
            json(conn, %{status: "ok", result: inspect(result)})

          {:error, reason} ->
            conn |> put_status(500) |> json(%{error: inspect(reason)})
        end

      {:ok, %{rows: []}} ->
        conn
        |> put_status(404)
        |> json(%{error: "No sync configuration found for this organisation"})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  defp serialize(record) do
    %{
      id: record.id,
      organization_id: record.organization_id,
      law_name: record.law_name,
      status: record.status,
      source: record.source,
      notes: record.notes,
      reviewed_at: record.reviewed_at,
      reviewed_by: record.reviewed_by,
      inserted_at: record.inserted_at,
      updated_at: record.updated_at
    }
  end
end

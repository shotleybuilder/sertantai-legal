defmodule SertantaiLegalWeb.ScreeningController do
  @moduledoc """
  Customer-facing API for applicability screening.

  All endpoints are org-scoped via `organization_id` from JWT claims.
  """
  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.OrgApplicability
  alias SertantaiLegal.Sync.OrgScreeningProfile
  alias SertantaiLegal.Sync.ApplicabilityEvent

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
    new_status = params["status"] || "unreviewed"

    # Get previous status for audit trail
    previous = get_current_status(org_id, law_name)

    attrs = %{
      organization_id: org_id,
      law_name: law_name,
      status: new_status,
      source: :manual,
      notes: params["notes"],
      reviewed_at: DateTime.utc_now(),
      reviewed_by: user_id
    }

    case OrgApplicability.upsert(attrs) do
      {:ok, record} ->
        event_type = infer_event_type(previous, new_status)

        log_event(
          org_id,
          law_name,
          event_type,
          user_id || "unknown",
          previous,
          new_status,
          "manual",
          %{notes: params["notes"]}
        )

        json(conn, serialize(record))

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: inspect(changeset)})
    end
  end

  @doc "POST /api/screening/applicabilities/bulk — bulk set status for multiple laws"
  def bulk_upsert(conn, %{"law_names" => law_names, "status" => status} = params)
      when is_list(law_names) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns[:current_user_id]
    now = DateTime.utc_now()
    source = if params["source"] == "screener", do: :screener, else: :manual
    reviewed_by = if source == :screener, do: "sertantai", else: user_id

    source_str = to_string(source)
    actor = reviewed_by || "unknown"
    event_type = if source == :screener, do: "seeded", else: "added"

    results =
      Enum.map(law_names, fn law_name ->
        previous = get_current_status(org_id, law_name)

        result =
          OrgApplicability.upsert(%{
            organization_id: org_id,
            law_name: law_name,
            status: status,
            source: source,
            reviewed_at: now,
            reviewed_by: reviewed_by
          })

        case result do
          {:ok, _} ->
            log_event(
              org_id,
              law_name,
              event_type,
              actor,
              previous,
              status,
              source_str,
              params["metadata"]
            )

          _ ->
            nil
        end

        result
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

  # ── Event feed endpoints ────────────────────────────────────────

  @doc "GET /api/screening/events — activity feed for the org (paginated)"
  def events(conn, params) do
    org_id = conn.assigns.organization_id
    limit = min(String.to_integer(params["limit"] || "50"), 200)
    offset = String.to_integer(params["offset"] || "0")

    {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

    {:ok, %{rows: rows}} =
      Repo.query(
        """
        SELECT id, law_name, event, actor, status_before, status_after, source, metadata, inserted_at
        FROM applicability_events
        WHERE organization_id = $1
        ORDER BY inserted_at DESC
        LIMIT $2 OFFSET $3
        """,
        [org_id_binary, limit, offset]
      )

    {:ok, %{rows: [[total]]}} =
      Repo.query(
        "SELECT COUNT(*) FROM applicability_events WHERE organization_id = $1",
        [org_id_binary]
      )

    events =
      Enum.map(rows, fn [id, law_name, event, actor, before, after_, source, metadata, at] ->
        %{
          id: Ecto.UUID.load!(id),
          law_name: law_name,
          event: event,
          actor: actor,
          status_before: before,
          status_after: after_,
          source: source,
          metadata: metadata,
          inserted_at: at
        }
      end)

    json(conn, %{events: events, total: total, limit: limit, offset: offset})
  end

  @doc "GET /api/screening/events/:law_name — per-law history"
  def law_events(conn, %{"law_name" => law_name}) do
    org_id = conn.assigns.organization_id
    {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

    {:ok, %{rows: rows}} =
      Repo.query(
        """
        SELECT id, event, actor, status_before, status_after, source, metadata, inserted_at
        FROM applicability_events
        WHERE organization_id = $1 AND law_name = $2
        ORDER BY inserted_at DESC
        """,
        [org_id_binary, law_name]
      )

    events =
      Enum.map(rows, fn [id, event, actor, before, after_, source, metadata, at] ->
        %{
          id: Ecto.UUID.load!(id),
          event: event,
          actor: actor,
          status_before: before,
          status_after: after_,
          source: source,
          metadata: metadata,
          inserted_at: at
        }
      end)

    json(conn, %{law_name: law_name, events: events, count: length(events)})
  end

  @doc "POST /api/screening/undo — undo the most recent screening action"
  def undo(conn, _params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns[:current_user_id] || "unknown"
    {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

    # Find most recent event
    case Repo.query(
           "SELECT id, law_name, event, status_before, status_after, source FROM applicability_events WHERE organization_id = $1 ORDER BY inserted_at DESC LIMIT 1",
           [org_id_binary]
         ) do
      {:ok, %{rows: [[event_id, law_name, event, status_before, _status_after, _source]]}} ->
        if event == "restored" do
          conn |> put_status(400) |> json(%{error: "Cannot undo an undo"})
        else
          # Reverse: apply status_before
          if status_before do
            OrgApplicability.upsert(%{
              organization_id: org_id,
              law_name: law_name,
              status: status_before,
              source: :manual,
              reviewed_at: DateTime.utc_now(),
              reviewed_by: user_id
            })
          else
            # First event — delete the record entirely
            {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

            Repo.query(
              "DELETE FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
              [org_id_binary, law_name]
            )
          end

          # Log the undo as a 'restored' event
          log_event(
            org_id,
            law_name,
            "restored",
            user_id,
            nil,
            status_before || "unreviewed",
            "manual",
            %{undone_event_id: Ecto.UUID.load!(event_id)}
          )

          json(conn, %{
            undone: true,
            law_name: law_name,
            event: event,
            restored_to: status_before || "unreviewed"
          })
        end

      {:ok, %{rows: []}} ->
        conn |> put_status(404) |> json(%{error: "No events to undo"})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  # ── Profile endpoints ───────────────────────────────────────────

  @doc "GET /api/screening/profile — get org's screening profile"
  def get_profile(conn, _params) do
    org_id = conn.assigns.organization_id

    case OrgScreeningProfile.by_organization(org_id) do
      {:ok, profile} ->
        json(conn, serialize_profile(profile))

      {:error, _} ->
        # No profile yet — return empty defaults
        json(conn, %{
          regions: [],
          activities: [],
          locations: [],
          materials: [],
          processes: [],
          sector: []
        })
    end
  end

  @doc "PUT /api/screening/profile — create or update org's screening profile"
  def upsert_profile(conn, params) do
    org_id = conn.assigns.organization_id

    attrs = %{
      organization_id: org_id,
      regions: params["regions"] || [],
      governed_actors: params["governed_actors"] || [],
      government_actors: params["government_actors"] || [],
      activities: params["activities"] || [],
      locations: params["locations"] || [],
      materials: params["materials"] || [],
      processes: params["processes"] || [],
      sector: params["sector"] || []
    }

    case OrgScreeningProfile.upsert(attrs) do
      {:ok, profile} ->
        json(conn, serialize_profile(profile))

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: inspect(reason)})
    end
  end

  @doc "GET /api/screening/vocabulary — distinct fitness tag values from the law corpus"
  def vocabulary(conn, _params) do
    queries = [
      {"governed_actors",
       "SELECT DISTINCT val FROM (
          SELECT jsonb_array_elements_text(duty_holder->'values') as val
          FROM uk_lrt WHERE duty_holder IS NOT NULL AND duty_holder != 'null'
          UNION
          SELECT jsonb_array_elements_text(rights_holder->'values') as val
          FROM uk_lrt WHERE rights_holder IS NOT NULL AND rights_holder != 'null'
        ) sub WHERE val NOT LIKE 'Gvt:%' AND val NOT LIKE 'EU:%' AND val NOT LIKE 'HM %' AND val NOT LIKE 'Crown%' ORDER BY val"},
      {"government_actors",
       "SELECT DISTINCT val FROM (
          SELECT jsonb_array_elements_text(responsibility_holder->'values') as val
          FROM uk_lrt WHERE responsibility_holder IS NOT NULL AND responsibility_holder != 'null'
          UNION
          SELECT jsonb_array_elements_text(power_holder->'values') as val
          FROM uk_lrt WHERE power_holder IS NOT NULL AND power_holder != 'null'
        ) sub WHERE val LIKE 'Gvt:%' OR val LIKE 'EU:%' OR val LIKE 'HM %' OR val LIKE 'Crown%' ORDER BY val"},
      {"locations",
       "SELECT DISTINCT val FROM (SELECT unnest(fitness_place) as val FROM uk_lrt WHERE fitness_place IS NOT NULL) sub WHERE val NOT IN ('England', 'Scotland', 'Wales', 'Northern Ireland', 'Great Britain', 'United Kingdom') ORDER BY val"},
      {"materials",
       "SELECT DISTINCT val FROM (SELECT unnest(fitness_plant) as val FROM uk_lrt WHERE fitness_plant IS NOT NULL) sub ORDER BY val"},
      {"processes",
       "SELECT DISTINCT val FROM (SELECT unnest(fitness_process) as val FROM uk_lrt WHERE fitness_process IS NOT NULL) sub ORDER BY val"},
      {"sector",
       "SELECT DISTINCT val FROM (SELECT unnest(fitness_sector) as val FROM uk_lrt WHERE fitness_sector IS NOT NULL) sub ORDER BY val"},
      {"regions",
       "SELECT DISTINCT val FROM (SELECT unnest(geo_region) as val FROM uk_lrt WHERE geo_region IS NOT NULL) sub ORDER BY val"}
    ]

    vocab =
      Map.new(queries, fn {key, sql} ->
        case Repo.query(sql) do
          {:ok, %{rows: rows}} -> {key, Enum.map(rows, fn [val] -> val end)}
          _ -> {key, []}
        end
      end)

    json(conn, vocab)
  end

  @doc "POST /api/screening/debug-dump — dev-only: save seed preview JSON to data dir"
  def debug_dump(conn, params) do
    if Mix.env() == :prod do
      conn |> put_status(404) |> json(%{error: "Not available"})
    else
      path = Path.join(["data", "seed-preview-dump.json"])
      File.mkdir_p!("data")
      File.write!(path, Jason.encode!(params, pretty: true))
      Logger.info("[ScreeningController] Debug dump saved to #{path}")
      json(conn, %{saved: path})
    end
  end

  defp serialize_profile(profile) do
    %{
      id: profile.id,
      organization_id: profile.organization_id,
      regions: profile.regions || [],
      governed_actors: profile.governed_actors || [],
      government_actors: profile.government_actors || [],
      activities: profile.activities || [],
      locations: profile.locations || [],
      materials: profile.materials || [],
      processes: profile.processes || [],
      sector: profile.sector || [],
      inserted_at: profile.inserted_at,
      updated_at: profile.updated_at
    }
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

  # ── Audit trail helpers ────────────────────────────────────────

  defp log_event(
         org_id,
         law_name,
         event,
         actor,
         status_before,
         status_after,
         source,
         metadata \\ nil
       ) do
    ApplicabilityEvent.log(%{
      organization_id: org_id,
      law_name: law_name,
      event: event,
      actor: actor || "unknown",
      status_before: status_before,
      status_after: status_after,
      source: source,
      metadata: metadata
    })
  end

  defp get_current_status(org_id, law_name) do
    case Repo.query(
           "SELECT status FROM org_applicabilities WHERE organization_id = $1 AND law_name = $2",
           [Ecto.UUID.dump!(org_id), law_name]
         ) do
      {:ok, %{rows: [[status]]}} -> status
      _ -> nil
    end
  end

  defp infer_event_type(nil, "yes"), do: "added"
  defp infer_event_type(nil, "excluded"), do: "excluded"
  defp infer_event_type(nil, _), do: "added"
  defp infer_event_type("yes", "unreviewed"), do: "removed"
  defp infer_event_type("yes", "excluded"), do: "excluded"
  defp infer_event_type("excluded", "unreviewed"), do: "restored"
  defp infer_event_type("excluded", "yes"), do: "added"
  defp infer_event_type("unreviewed", "yes"), do: "added"
  defp infer_event_type(_, "yes"), do: "added"
  defp infer_event_type(_, "excluded"), do: "excluded"
  defp infer_event_type(_, "unreviewed"), do: "removed"
  defp infer_event_type(_, _), do: "changed"
end

defmodule SertantaiLegalWeb.Router do
  use SertantaiLegalWeb, :router

  # Note: AshAuthentication.Phoenix.Router removed — auth is handled by sertantai-auth

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Admin API pipeline — JWT auth + admin/owner role check
  pipeline :api_admin do
    plug(:accepts, ["json"])
    plug(SertantaiLegalWeb.LoadFromCookie)
    plug(SertantaiLegalWeb.AuthPlug)
    plug(SertantaiLegalWeb.RequireAdmin)
  end

  # Pipeline for Server-Sent Events - no content type restrictions
  # EventSource sends Accept: text/event-stream which Phoenix's :accepts plug doesn't handle
  pipeline :sse do
    # No accepts plug - we set content-type manually in the controller
  end

  # SSE with JWT auth (cookie or Bearer header)
  pipeline :sse_authenticated do
    plug(SertantaiLegalWeb.LoadFromCookie)
    plug(SertantaiLegalWeb.AuthPlug)
  end

  # AI service pipeline — API key auth for machine-to-machine LAN calls
  pipeline :api_ai do
    plug(:accepts, ["json"])
    plug(SertantaiLegalWeb.AiApiKeyPlug)
  end

  # Health check endpoints (no /api prefix, no authentication required)
  scope "/", SertantaiLegalWeb do
    pipe_through(:api)
    get("/health", HealthController, :index)
    get("/health/detailed", HealthController, :show)
  end

  # Public API endpoints — legal register reference data (read-only, no auth)
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api)
    get("/hello", HelloController, :index)

    # Legal register read endpoints (multi-jurisdiction, public reference data)
    get("/laws", UkLrtController, :index)
    get("/laws/filters", UkLrtController, :filters)
    get("/laws/search", UkLrtController, :search)
    get("/laws/exists/*name", UkLrtController, :exists)
    post("/laws/batch-exists", UkLrtController, :batch_exists)
    get("/laws/:id", UkLrtController, :show)

    # Legislative definitions (public reference data)
    get("/definitions", DefinitionController, :index)
    get("/definitions/search", DefinitionController, :search)

    # Zenoh query proxy (dev/internal — proxies GET to remote queryables)
    post("/zenoh/query", ZenohController, :proxy_query)
  end

  # AI service endpoints — machine-to-machine (API key auth)
  scope "/api/ai", SertantaiLegalWeb do
    pipe_through(:api_ai)
    get("/drrp/clause/queue", AiDrrpController, :queue)
    get("/sync/lat", AiSyncController, :lat)
    get("/sync/annotations", AiSyncController, :annotations)
  end

  # Authenticated SSE streaming (JWT auth)
  scope "/api", SertantaiLegalWeb do
    pipe_through([:sse, :sse_authenticated])
    get("/sessions/:id/parse-stream", ScrapeController, :parse_stream)
    get("/laws/:id/parse-stream", UkLrtController, :parse_stream)
    get("/lat/sessions/:id/parse-stream", LatAdminController, :lat_parse_stream)
  end

  # Legal register write endpoints (admin-only, moved from api_authenticated)
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api_admin)

    patch("/laws/:id", UkLrtController, :update)
    delete("/laws/:id", UkLrtController, :delete)
    post("/laws/:id/rescrape", UkLrtController, :rescrape)
  end

  # Admin API endpoints (JWT auth + admin role)
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api_admin)

    # Scraper endpoints (admin tools)
    post("/scrape", ScrapeController, :create)
    get("/sessions", ScrapeController, :index)
    get("/family-options", ScrapeController, :family_options)

    # Reparse session endpoints (must come before /sessions/:id to avoid capture)
    post("/sessions/reparse/preview", ScrapeController, :reparse_preview)
    post("/sessions/reparse/from-view", ScrapeController, :create_reparse_from_view)
    post("/sessions/reparse", ScrapeController, :create_reparse)

    get("/sessions/:id", ScrapeController, :show)
    get("/sessions/:id/db-status", ScrapeController, :db_status)
    get("/sessions/:id/group/:group", ScrapeController, :group)
    patch("/sessions/:id/group/:group/select", ScrapeController, :select)
    post("/sessions/:id/persist/:group", ScrapeController, :persist)
    post("/sessions/:id/parse/:group", ScrapeController, :parse)
    post("/sessions/:id/parse-one", ScrapeController, :parse_one)
    post("/sessions/:id/parse-metadata", ScrapeController, :parse_metadata)
    post("/sessions/:id/confirm", ScrapeController, :confirm)
    post("/sessions/:id/skip", ScrapeController, :skip)
    delete("/sessions/:id", ScrapeController, :delete)
    get("/sessions/:id/law-names", ScrapeController, :law_names)

    # Cascade update endpoints
    get("/sessions/:id/affected-laws", ScrapeController, :affected_laws)
    post("/sessions/:id/batch-reparse", ScrapeController, :batch_reparse)
    post("/sessions/:id/update-enacting-links", ScrapeController, :update_enacting_links)
    put("/sessions/:id/cascade-metadata", ScrapeController, :save_cascade_metadata)
    delete("/sessions/:id/affected-laws", ScrapeController, :clear_affected_laws)

    # Zenoh P2P mesh monitoring
    get("/zenoh/subscriptions", ZenohController, :subscriptions)
    get("/zenoh/queryables", ZenohController, :queryables)

    # LAT session endpoints (must come before /lat/:id routes)
    post("/lat/sessions/preview", LatAdminController, :lat_session_preview)
    post("/lat/sessions/from-view", LatAdminController, :create_lat_session_from_view)
    post("/lat/sessions", LatAdminController, :create_lat_session)
    get("/lat/sessions", LatAdminController, :lat_sessions)
    get("/lat/sessions/:id", LatAdminController, :lat_session_show)
    get("/lat/sessions/:id/records", LatAdminController, :lat_session_records)
    patch("/lat/sessions/:id/records/select", LatAdminController, :lat_select)
    post("/lat/sessions/:id/confirm", LatAdminController, :lat_confirm)
    delete("/lat/sessions/:id", LatAdminController, :lat_delete)

    # LAT admin endpoints
    get("/lat/audit", LatAdminController, :audit)
    get("/lat/audit/:law_name", LatAdminController, :audit_law)
    get("/lat/stats", LatAdminController, :stats)
    get("/lat/queue", LatAdminController, :queue)
    get("/lat/queue/org-applicabilities", LatAdminController, :org_applicabilities)
    get("/lat/queue/org-law-names/:org_id", LatAdminController, :org_law_names)
    get("/lat/laws", LatAdminController, :laws)
    get("/lat/laws/:law_name", LatAdminController, :show)
    get("/lat/laws/:law_name/annotations", LatAdminController, :annotations)
    post("/lat/laws/:law_name/reparse", LatAdminController, :reparse)
    delete("/lat/laws/:law_name/data", LatAdminController, :delete_lat)

    # Graph / family inference endpoints
    get("/graph/family-mismatches", GraphController, :family_mismatches)
    get("/graph/family-inference/:law_name", GraphController, :family_inference)
    post("/graph/rescrape-lrt/:law_name", GraphController, :rescrape_lrt)
    post("/graph/rebuild-edges", GraphController, :rebuild_edges)
    get("/graph/stats", GraphController, :stats)

    # Cascade management endpoints (standalone page)
    get("/cascade", CascadeController, :index)
    get("/cascade/sessions", CascadeController, :sessions)
    post("/cascade/reparse", CascadeController, :reparse)
    post("/cascade/update-enacting", CascadeController, :update_enacting)
    post("/cascade/add-laws", CascadeController, :add_laws)
    delete("/cascade/processed", CascadeController, :clear_processed)
    delete("/cascade/session/:session_id", CascadeController, :clear_session)
    delete("/cascade/:id", CascadeController, :delete)

    # Analytics endpoints
    get("/analytics/changes", AnalyticsController, :changes)
    get("/analytics/sessions", AnalyticsController, :sessions)
    get("/analytics/live-status", AnalyticsController, :live_status)
    get("/analytics/live-status/misclassified", AnalyticsController, :misclassified_names)

    # Definition resolution management
    get("/definitions/admin/stats", DefinitionsAdminController, :stats)
    get("/definitions/admin/diagnostic", DefinitionsAdminController, :diagnostic)
    post("/definitions/admin/parse", DefinitionsAdminController, :parse)
    post("/definitions/admin/resolve", DefinitionsAdminController, :resolve)

    # Data sync pipeline visibility + actions
    get("/sync/status", SyncAdminController, :status)
    post("/sync/snapshot-export", SyncAdminController, :snapshot_export)
    post("/sync/delta-export", SyncAdminController, :delta_export)
  end
end

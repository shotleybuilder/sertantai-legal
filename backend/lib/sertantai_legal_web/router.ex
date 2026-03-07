defmodule SertantaiLegalWeb.Router do
  use SertantaiLegalWeb, :router

  # Note: AshAuthentication.Phoenix.Router removed — auth is handled by sertantai-auth

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Authenticated API pipeline — validates JWT from sertantai-auth
  pipeline :api_authenticated do
    plug(:accepts, ["json"])
    plug(SertantaiLegalWeb.LoadFromCookie)
    plug(SertantaiLegalWeb.AuthPlug)
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

  # Public API endpoints — UK LRT reference data (read-only, no auth)
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api)
    get("/hello", HelloController, :index)

    # UK LRT read endpoints (public reference data)
    get("/uk-lrt", UkLrtController, :index)
    get("/uk-lrt/filters", UkLrtController, :filters)
    get("/uk-lrt/search", UkLrtController, :search)
    get("/uk-lrt/exists/*name", UkLrtController, :exists)
    post("/uk-lrt/batch-exists", UkLrtController, :batch_exists)
    get("/uk-lrt/:id", UkLrtController, :show)
  end

  # AI service endpoints — machine-to-machine (API key auth)
  scope "/api/ai", SertantaiLegalWeb do
    pipe_through(:api_ai)
    get("/drrp/clause/queue", AiDrrpController, :queue)
    get("/sync/lat", AiSyncController, :lat)
    get("/sync/annotations", AiSyncController, :annotations)
  end

  # Electric proxy — public shapes (UK LRT reference data)
  scope "/api/electric", SertantaiLegalWeb do
    pipe_through(:sse)
    get("/v1/shape", ElectricProxyController, :shape)
    delete("/v1/shape", ElectricProxyController, :delete_shape)
  end

  # Authenticated SSE streaming (JWT auth)
  scope "/api", SertantaiLegalWeb do
    pipe_through([:sse, :sse_authenticated])
    get("/sessions/:id/parse-stream", ScrapeController, :parse_stream)
    get("/uk-lrt/:id/parse-stream", UkLrtController, :parse_stream)
  end

  # Tenant-scoped API endpoints (JWT auth from sertantai-auth)
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api_authenticated)

    # UK LRT write endpoints (require org_id from JWT)
    patch("/uk-lrt/:id", UkLrtController, :update)
    delete("/uk-lrt/:id", UkLrtController, :delete)
    post("/uk-lrt/:id/rescrape", UkLrtController, :rescrape)
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
    delete("/sessions/:id", ScrapeController, :delete)

    # Cascade update endpoints
    get("/sessions/:id/affected-laws", ScrapeController, :affected_laws)
    post("/sessions/:id/batch-reparse", ScrapeController, :batch_reparse)
    post("/sessions/:id/update-enacting-links", ScrapeController, :update_enacting_links)
    put("/sessions/:id/cascade-metadata", ScrapeController, :save_cascade_metadata)
    delete("/sessions/:id/affected-laws", ScrapeController, :clear_affected_laws)

    # Zenoh P2P mesh monitoring
    get("/zenoh/subscriptions", ZenohController, :subscriptions)
    get("/zenoh/queryables", ZenohController, :queryables)

    # LAT admin endpoints
    get("/lat/stats", LatAdminController, :stats)
    get("/lat/queue", LatAdminController, :queue)
    get("/lat/laws", LatAdminController, :laws)
    get("/lat/laws/:law_name", LatAdminController, :show)
    get("/lat/laws/:law_name/annotations", LatAdminController, :annotations)
    post("/lat/laws/:law_name/reparse", LatAdminController, :reparse)

    # Cascade management endpoints (standalone page)
    get("/cascade", CascadeController, :index)
    get("/cascade/sessions", CascadeController, :sessions)
    post("/cascade/reparse", CascadeController, :reparse)
    post("/cascade/update-enacting", CascadeController, :update_enacting)
    post("/cascade/add-laws", CascadeController, :add_laws)
    delete("/cascade/processed", CascadeController, :clear_processed)
    delete("/cascade/session/:session_id", CascadeController, :clear_session)
    delete("/cascade/:id", CascadeController, :delete)
  end
end

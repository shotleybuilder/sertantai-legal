defmodule SertantaiLegalWeb.Router do
  use SertantaiLegalWeb, :router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Authenticated API pipeline — validates JWT from sertantai-auth
  pipeline :api_authenticated do
    plug(:accepts, ["json"])
    plug(SertantaiLegalWeb.AuthPlug)
  end

  # Pipeline for Server-Sent Events - no content type restrictions
  # EventSource sends Accept: text/event-stream which Phoenix's :accepts plug doesn't handle
  pipeline :sse do
    # No accepts plug - we set content-type manually in the controller
  end

  # SSE with authentication
  pipeline :sse_authenticated do
    plug(SertantaiLegalWeb.AuthPlug)
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

  # Authenticated SSE streaming endpoints
  scope "/api", SertantaiLegalWeb do
    pipe_through([:sse, :sse_authenticated])
    get("/sessions/:id/parse-stream", ScrapeController, :parse_stream)
  end

  # Authenticated API endpoints — admin/write operations
  scope "/api", SertantaiLegalWeb do
    pipe_through(:api_authenticated)

    # UK LRT write endpoints (require auth)
    patch("/uk-lrt/:id", UkLrtController, :update)
    delete("/uk-lrt/:id", UkLrtController, :delete)
    post("/uk-lrt/:id/rescrape", UkLrtController, :rescrape)
    post("/uk-lrt/:id/parse-preview", UkLrtController, :parse_preview)

    # Scraper endpoints (admin tools)
    post("/scrape", ScrapeController, :create)
    get("/sessions", ScrapeController, :index)
    get("/family-options", ScrapeController, :family_options)
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

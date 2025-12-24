defmodule SertantaiLegalWeb.Router do
  use SertantaiLegalWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoints (no /api prefix, no authentication required)
  scope "/", SertantaiLegalWeb do
    pipe_through :api
    get "/health", HealthController, :index
    get "/health/detailed", HealthController, :show
  end

  # API endpoints
  scope "/api", SertantaiLegalWeb do
    pipe_through :api
    get "/hello", HelloController, :index

    # Scraper endpoints
    post "/scrape", ScrapeController, :create
    get "/sessions", ScrapeController, :index
    get "/family-options", ScrapeController, :family_options
    get "/sessions/:id", ScrapeController, :show
    get "/sessions/:id/group/:group", ScrapeController, :group
    patch "/sessions/:id/group/:group/select", ScrapeController, :select
    post "/sessions/:id/persist/:group", ScrapeController, :persist
    post "/sessions/:id/parse/:group", ScrapeController, :parse
    post "/sessions/:id/parse-one", ScrapeController, :parse_one
    post "/sessions/:id/confirm", ScrapeController, :confirm
    delete "/sessions/:id", ScrapeController, :delete

    # Cascade update endpoints
    get "/sessions/:id/affected-laws", ScrapeController, :affected_laws
    post "/sessions/:id/batch-reparse", ScrapeController, :batch_reparse
    post "/sessions/:id/update-enacting-links", ScrapeController, :update_enacting_links
    delete "/sessions/:id/affected-laws", ScrapeController, :clear_affected_laws

    # UK LRT CRUD endpoints
    get "/uk-lrt", UkLrtController, :index
    get "/uk-lrt/filters", UkLrtController, :filters
    get "/uk-lrt/search", UkLrtController, :search
    get "/uk-lrt/exists/*name", UkLrtController, :exists
    post "/uk-lrt/batch-exists", UkLrtController, :batch_exists
    get "/uk-lrt/:id", UkLrtController, :show
    patch "/uk-lrt/:id", UkLrtController, :update
    delete "/uk-lrt/:id", UkLrtController, :delete
  end
end

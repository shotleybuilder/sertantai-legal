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
    get "/sessions/:id", ScrapeController, :show
    get "/sessions/:id/group/:group", ScrapeController, :group
    post "/sessions/:id/persist/:group", ScrapeController, :persist
    post "/sessions/:id/parse/:group", ScrapeController, :parse
    delete "/sessions/:id", ScrapeController, :delete

    # UK LRT CRUD endpoints
    get "/uk-lrt", UkLrtController, :index
    get "/uk-lrt/filters", UkLrtController, :filters
    get "/uk-lrt/search", UkLrtController, :search
    get "/uk-lrt/:id", UkLrtController, :show
    patch "/uk-lrt/:id", UkLrtController, :update
    delete "/uk-lrt/:id", UkLrtController, :delete
  end
end

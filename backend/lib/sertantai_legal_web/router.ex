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
  end
end

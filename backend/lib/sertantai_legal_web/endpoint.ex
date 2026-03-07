defmodule SertantaiLegalWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :sertantai_legal

  # No session needed — all auth is stateless JWT from sertantai-auth

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :sertantai_legal,
    gzip: false,
    only: SertantaiLegalWeb.static_paths()
  )

  # Tidewave MCP server for AI assistant integration
  # Available at http://localhost:4000/tidewave/mcp
  if Code.ensure_loaded?(Tidewave) do
    plug(Tidewave)
  end

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :sertantai_legal)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # CORS configuration
  plug(Corsica,
    origins: [
      # Vite dev server (port 5175 for sertantai-legal)
      "http://localhost:5175",
      "http://localhost:5173",
      "http://127.0.0.1:5175",
      "http://127.0.0.1:5173",
      System.get_env("FRONTEND_URL") || ""
    ],
    allow_credentials: true,
    allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers: ["content-type", "authorization"],
    # Expose Electric's custom headers so the browser allows JavaScript to read them
    expose_headers: [
      "electric-cursor",
      "electric-handle",
      "electric-offset",
      "electric-schema",
      "electric-up-to-date",
      "electric-internal-known-error"
    ],
    max_age: 600
  )

  plug(SertantaiLegalWeb.Router)
end

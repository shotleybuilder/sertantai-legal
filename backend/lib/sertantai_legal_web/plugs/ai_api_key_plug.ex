defmodule SertantaiLegalWeb.AiApiKeyPlug do
  @moduledoc """
  API key validation plug for AI service endpoints.

  Validates the `X-API-Key` header against an environment variable using
  timing-safe comparison. Designed for machine-to-machine LAN calls, not for
  user-facing endpoints.

  Options:
  - `:env` — the variable holding the expected key (default
    `AI_SERVICE_API_KEY`). The workflow API uses `WORKFLOW_API_KEY`, a separate
    write key, so the AI service's read-only sync key can't drive workflows.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: Keyword.put_new(opts, :env, "AI_SERVICE_API_KEY")

  @impl true
  def call(conn, opts) do
    expected = System.get_env(Keyword.get(opts, :env, "AI_SERVICE_API_KEY"))

    with [key] <- get_req_header(conn, "x-api-key"),
         true <- expected != nil and Plug.Crypto.secure_compare(key, expected) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{error: "Unauthorized", reason: "Invalid or missing API key"})
        )
        |> halt()
    end
  end
end

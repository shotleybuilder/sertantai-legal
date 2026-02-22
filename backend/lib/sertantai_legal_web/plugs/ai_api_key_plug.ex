defmodule SertantaiLegalWeb.AiApiKeyPlug do
  @moduledoc """
  API key validation plug for AI service endpoints.

  Validates the `X-API-Key` header against the `AI_SERVICE_API_KEY` environment
  variable using timing-safe comparison. Designed for machine-to-machine LAN
  calls from the AI service, not for user-facing endpoints.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected = System.get_env("AI_SERVICE_API_KEY")

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

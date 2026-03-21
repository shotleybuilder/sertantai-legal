defmodule SertantaiLegalWeb.WebhookApiKeyPlug do
  @moduledoc """
  API key validation plug for webhook endpoints from sertantai-hub.

  Validates the `X-API-Key` header against the `WEBHOOK_API_KEY` environment
  variable using timing-safe comparison.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    expected = System.get_env("WEBHOOK_API_KEY")

    with [key] <- get_req_header(conn, "x-api-key"),
         true <- expected != nil and Plug.Crypto.secure_compare(key, expected) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          401,
          Jason.encode!(%{error: "Unauthorized", reason: "Invalid or missing webhook API key"})
        )
        |> halt()
    end
  end
end

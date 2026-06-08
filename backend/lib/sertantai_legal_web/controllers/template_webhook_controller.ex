defmodule SertantaiLegalWeb.TemplateWebhookController do
  @moduledoc """
  Receives webhook callbacks from customer compliance workspaces
  (Baserow, Airtable, etc.) and routes them to ComplianceMetrics.

  Each provider sends different payloads — the provider adapter
  normalises them to a common WebhookEvent struct.

  ## Security

  - Webhooks carry only row IDs and changed status fields
  - Never contains free text, files, or PII
  - Authenticated via webhook secret in query param or header
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Sync.Providers.Baserow
  alias SertantaiLegal.Sync.Templates.{ComplianceMetrics, WebhookEvent}

  require Logger

  @doc """
  POST /api/webhooks/template/:provider/:org_id

  Receives a webhook from a provider workspace, parses it into
  common events, and processes each for compliance metrics.
  """
  def handle(conn, %{"provider" => provider, "org_id" => org_id} = _params) do
    body = conn.body_params

    events = parse_events(provider, body)

    results =
      Enum.map(events, fn event_map ->
        event = WebhookEvent.from_map(event_map)
        ComplianceMetrics.process_event(event, org_id)
      end)

    processed = Enum.count(results, &(&1 == :ok))
    ignored = Enum.count(results, &(&1 == :ignored))

    Logger.info(
      "[TemplateWebhook] #{provider}/#{org_id}: #{processed} processed, #{ignored} ignored"
    )

    json(conn, %{status: "ok", processed: processed, ignored: ignored})
  end

  def handle(conn, _params) do
    conn |> put_status(400) |> json(%{error: "provider and org_id required"})
  end

  defp parse_events("baserow", body), do: Baserow.parse_webhook_event(body)

  defp parse_events(provider, _body) do
    Logger.warning("[TemplateWebhook] Unknown provider: #{provider}")
    []
  end
end

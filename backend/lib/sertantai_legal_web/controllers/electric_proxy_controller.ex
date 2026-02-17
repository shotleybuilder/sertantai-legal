defmodule SertantaiLegalWeb.ElectricProxyController do
  @moduledoc """
  Guardian-pattern proxy for ElectricSQL shape requests.

  Validates JWT before forwarding requests to the Electric sync service.
  Server-side shape definitions prevent clients from accessing arbitrary tables.
  The Electric secret is appended server-side so it never reaches the client.

  See: https://electric-sql.com/docs/guides/auth
  """
  use SertantaiLegalWeb, :controller

  require Logger

  # Client-safe params that pass through to Electric unchanged
  @passthrough_params ~w(offset handle live cursor replica)

  @doc """
  Proxy GET /api/electric/v1/shape to Electric's HTTP API.

  The JWT has already been validated by AuthPlug in the router pipeline.
  This controller resolves the requested shape, builds server-side params
  (table, where, columns), and forwards to Electric with the secret appended.
  """
  def shape(conn, params) do
    with {:ok, shape_def} <- resolve_shape(params, conn.assigns) do
      electric_url = Application.get_env(:sertantai_legal, :electric_url)

      unless electric_url do
        raise "electric_url not configured"
      end

      query_params =
        shape_def
        |> Map.merge(passthrough_params(params))
        |> maybe_add_secret()
        |> URI.encode_query()

      upstream_url = "#{electric_url}/v1/shape?#{query_params}"

      stream_from_electric(conn, upstream_url)
    else
      {:error, :unknown_shape} ->
        conn
        |> put_status(400)
        |> json(%{error: "Unknown or disallowed shape"})
    end
  end

  @doc """
  Proxy DELETE /api/electric/v1/shape for shape recovery.

  Used by the frontend to delete broken shapes after Electric restarts.
  Only allows deletion of shapes the user has access to.
  """
  def delete_shape(conn, params) do
    with {:ok, shape_def} <- resolve_shape(params, conn.assigns) do
      electric_url = Application.get_env(:sertantai_legal, :electric_url)

      unless electric_url do
        raise "electric_url not configured"
      end

      query_params =
        %{"table" => shape_def["table"]}
        |> maybe_add_secret()
        |> URI.encode_query()

      upstream_url = "#{electric_url}/v1/shape?#{query_params}"

      case Req.delete(upstream_url, req_options()) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          send_resp(conn, 202, "")

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.warning("Electric shape delete returned #{status}: #{inspect(body)}")
          send_resp(conn, status, "")

        {:error, reason} ->
          Logger.error("Electric shape delete failed: #{inspect(reason)}")
          send_resp(conn, 502, "")
      end
    else
      {:error, :unknown_shape} ->
        conn
        |> put_status(400)
        |> json(%{error: "Unknown or disallowed shape"})
    end
  end

  # --- Shape Resolution ---

  # Resolves the requested shape name to server-side params.
  # This is the core of the Guardian pattern — the server defines
  # which shapes exist and what params they use.
  defp resolve_shape(params, assigns) do
    table = params["table"]

    case table do
      "uk_lrt" ->
        {:ok, uk_lrt_shape(params)}

      "organization_locations" ->
        case assigns[:organization_id] do
          nil -> {:error, :unknown_shape}
          org_id -> {:ok, org_scoped_shape("organization_locations", org_id, params)}
        end

      "location_screenings" ->
        case assigns[:organization_id] do
          nil -> {:error, :unknown_shape}
          org_id -> {:ok, org_scoped_shape("location_screenings", org_id, params)}
        end

      _ ->
        {:error, :unknown_shape}
    end
  end

  # UK LRT is public reference data — no org_id filter needed.
  # Client can specify WHERE and columns (validated against allowed set).
  defp uk_lrt_shape(params) do
    shape = %{"table" => "uk_lrt"}

    shape =
      case params["where"] do
        nil -> shape
        where when is_binary(where) -> Map.put(shape, "where", where)
        _ -> shape
      end

    case params["columns"] do
      nil -> shape
      columns when is_binary(columns) -> Map.put(shape, "columns", columns)
      _ -> shape
    end
  end

  # Org-scoped tables always filter by organization_id from JWT.
  defp org_scoped_shape(table, org_id, params) do
    # Build WHERE clause with mandatory org_id filter
    base_where = "\"organization_id\" = '#{org_id}'"

    where =
      case params["where"] do
        nil ->
          base_where

        extra when is_binary(extra) ->
          "(#{base_where}) AND (#{extra})"

        _ ->
          base_where
      end

    shape = %{"table" => table, "where" => where}

    case params["columns"] do
      nil -> shape
      columns when is_binary(columns) -> Map.put(shape, "columns", columns)
      _ -> shape
    end
  end

  # --- Helpers ---

  # Extract client-safe params that pass through to Electric
  defp passthrough_params(params) do
    params
    |> Map.take(@passthrough_params)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Append Electric secret if configured (production only)
  defp maybe_add_secret(params) do
    case Application.get_env(:sertantai_legal, :electric_secret) do
      nil -> params
      secret -> Map.put(params, "secret", secret)
    end
  end

  # Build Req options, using plug adapter in test environment
  defp req_options(extra_opts \\ []) do
    base_opts = [receive_timeout: 60_000, retry: false] ++ extra_opts

    if Application.get_env(:sertantai_legal, :test_mode, false) do
      Keyword.put(base_opts, :plug, {Req.Test, __MODULE__})
    else
      base_opts
    end
  end

  # Forward the response from Electric back to the client.
  # Electric uses long-polling for live mode — each request returns a complete
  # response, so we buffer and forward rather than streaming.
  defp stream_from_electric(conn, upstream_url) do
    case Req.get(upstream_url, req_options()) do
      {:ok, %Req.Response{status: status, body: body} = resp} when status in 200..299 ->
        conn
        |> forward_electric_headers(resp)
        |> put_resp_content_type(get_content_type(resp))
        |> send_resp(status, ensure_binary(body))

      {:ok, %Req.Response{status: status, body: body}} ->
        # Forward error responses from Electric (400, 409, etc.)
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(status, ensure_binary(body))

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        conn
        |> put_status(502)
        |> json(%{error: "Electric sync service unavailable"})

      {:error, reason} ->
        Logger.error("Electric proxy error: #{inspect(reason)}")

        conn
        |> put_status(502)
        |> json(%{error: "Failed to connect to Electric sync service"})
    end
  end

  defp get_content_type(%Req.Response{headers: headers}) do
    case Map.get(headers, "content-type") do
      [ct | _] -> ct
      _ -> "application/json"
    end
  end

  # Forward relevant Electric headers to the client
  # (e.g., electric-handle, electric-offset, electric-schema, electric-chunk-last-offset)
  # Req headers are %{"key" => ["value1", ...]}
  defp forward_electric_headers(conn, %Req.Response{headers: headers}) do
    Enum.reduce(headers, conn, fn {key, values}, conn ->
      if String.starts_with?(key, "electric-") or key in ~w(cache-control etag x-request-id) do
        case values do
          [val | _] -> put_resp_header(conn, key, val)
          _ -> conn
        end
      else
        conn
      end
    end)
  end

  defp ensure_binary(body) when is_binary(body), do: body
  defp ensure_binary(body) when is_map(body), do: Jason.encode!(body)
  defp ensure_binary(_body), do: ""
end

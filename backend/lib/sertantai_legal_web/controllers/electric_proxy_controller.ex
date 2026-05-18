defmodule SertantaiLegalWeb.ElectricProxyController do
  @moduledoc """
  Gatekeeper-pattern proxy for ElectricSQL shape requests.

  All shape requests are validated by sertantai-auth's Gatekeeper endpoint,
  which checks authentication, role-based access, and injects appropriate
  WHERE clauses (e.g. organization_id scoping for org-specific tables).

  The Electric secret is appended server-side so it never reaches the client.

  See: https://electric-sql.com/docs/guides/auth
  """
  use SertantaiLegalWeb, :controller

  require Logger

  # Client-safe params that pass through to Electric unchanged.
  # Includes subset__* params used by progressive/on-demand sync modes
  # for snapshot requests (fetchSnapshot/requestSnapshot in @electric-sql/client).
  @passthrough_params ~w(offset handle live cursor replica log
                         subset__where subset__params subset__limit subset__offset subset__order_by)

  # Tables allowed for shape recovery (DELETE). Kept as a simple static list
  # since DELETE doesn't need full Gatekeeper validation.
  @allowed_tables ~w(uk_lrt organization_locations location_screenings lat amendment_annotations)

  # Public reference tables — no auth required, bypass Gatekeeper.
  # These mirror the public REST API routes (e.g. GET /api/uk-lrt).
  @public_tables ~w(uk_lrt lat amendment_annotations)

  # Table name rewriting: views can't be synced by Electric (no WAL entries).
  # The frontend requests shape for "uk_lrt" (view), but Electric needs the
  # actual partition table "legal_register_uk" (which has REPLICA IDENTITY FULL).
  @table_rewrites %{
    "uk_lrt" => "legal_register_uk",
    "lat" => "legal_articles_uk"
  }

  @doc """
  Proxy GET /api/electric/v1/shape to Electric's HTTP API.

  All shapes are validated via sertantai-auth's Gatekeeper, which checks
  authentication, role access, and injects org-scoped WHERE clauses.
  """
  def shape(conn, params) do
    table = params["table"]
    handle = params["handle"]

    cond do
      # Follow-up requests (live polling) with an existing handle skip the
      # Gatekeeper — the initial shape request already validated access.
      # The handle is only valid for shapes Electric has already created,
      # and the ELECTRIC_SECRET is still appended server-side.
      is_binary(table) and table in @allowed_tables and is_binary(handle) and handle != "" ->
        forward_with_handle(conn, params)

      # Public reference tables (uk_lrt, lat, amendment_annotations) — no auth required.
      # These are read-only shared data, mirroring the public REST API routes.
      is_binary(table) and table in @public_tables ->
        forward_public_shape(conn, params)

      is_binary(table) ->
        forward_gatekeeper_shape(conn, params)

      true ->
        conn |> put_status(400) |> json(%{error: "Missing or invalid table parameter"})
    end
  end

  @doc """
  Proxy DELETE /api/electric/v1/shape for shape recovery.

  Used by the frontend to delete broken shapes after Electric restarts.
  Uses a simple static allowlist — no Gatekeeper needed for DELETE.
  """
  def delete_shape(conn, params) do
    table = params["table"]

    if table in @allowed_tables do
      electric_url = Application.get_env(:sertantai_legal, :electric_url)

      unless electric_url do
        raise "electric_url not configured"
      end

      shape_params = %{"table" => rewrite_table(table)}

      # Pass through columns param if provided — Electric validates columns
      # even on DELETE, and rejects shapes that include generated columns.
      shape_params =
        case params["columns"] do
          cols when is_binary(cols) and cols != "" ->
            Map.put(shape_params, "columns", inject_partition_pk(table, cols))

          _ ->
            shape_params
        end

      query_params =
        shape_params
        |> maybe_add_secret()
        |> encode_electric_query()

      upstream_url = "#{electric_url}/v1/shape?#{query_params}"

      case Req.delete(upstream_url, req_options()) do
        {:ok, %Req.Response{status: status}} when status in 200..299 ->
          send_resp(conn, 202, "")

        {:ok, %Req.Response{status: 400, body: body}} ->
          # Electric validates generated columns even on DELETE. Treat 400 as success
          # for shape recovery — the stale shape is already broken, and the next GET
          # with explicit columns will create a valid new shape.
          Logger.info(
            "Electric shape delete returned 400 (treating as success): #{inspect(body)}"
          )

          send_resp(conn, 202, "")

        {:ok, %Req.Response{status: status, body: body}} ->
          Logger.warning("Electric shape delete returned #{status}: #{inspect(body)}")
          send_resp(conn, status, "")

        {:error, reason} ->
          Logger.error("Electric shape delete failed: #{inspect(reason)}")
          send_resp(conn, 502, "")
      end
    else
      conn |> put_status(400) |> json(%{error: "Unknown or disallowed shape"})
    end
  end

  # --- Public table pass-through (no auth required) ---

  defp forward_public_shape(conn, params) do
    electric_url = Application.get_env(:sertantai_legal, :electric_url)

    unless electric_url do
      raise "electric_url not configured"
    end

    original_table = params["table"]

    query_params =
      params
      |> Map.take(["table", "where", "columns" | @passthrough_params])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
      |> Map.update("columns", nil, &inject_partition_pk(original_table, &1))
      |> Map.update("table", nil, &rewrite_table/1)
      |> maybe_add_secret()
      |> encode_electric_query()

    upstream_url = "#{electric_url}/v1/shape?#{query_params}"
    stream_from_electric(conn, upstream_url)
  end

  # --- Handle-based pass-through (live polling, already validated) ---

  defp forward_with_handle(conn, params) do
    electric_url = Application.get_env(:sertantai_legal, :electric_url)

    unless electric_url do
      raise "electric_url not configured"
    end

    original_table = params["table"]

    # Pass through all client params (table, where, columns, offset, handle, etc.)
    # and append the server-side secret.
    query_params =
      params
      |> Map.take(["table", "where", "columns" | @passthrough_params])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
      |> Map.update("columns", nil, &inject_partition_pk(original_table, &1))
      |> Map.update("table", nil, &rewrite_table/1)
      |> maybe_add_secret()
      |> encode_electric_query()

    upstream_url = "#{electric_url}/v1/shape?#{query_params}"
    stream_from_electric(conn, upstream_url)
  end

  # --- Gatekeeper-validated shapes (auth required) ---

  defp forward_gatekeeper_shape(conn, params) do
    auth_header = Plug.Conn.get_req_header(conn, "authorization")

    case auth_header do
      [bearer | _] when is_binary(bearer) ->
        case validate_with_gatekeeper(params, bearer) do
          {:ok, validated_shape} ->
            forward_validated_shape(conn, validated_shape, params)

          {:error, status, body} ->
            conn |> put_status(status) |> json(body)
        end

      _ ->
        conn |> put_status(401) |> json(%{error: "Authentication required"})
    end
  end

  defp validate_with_gatekeeper(params, auth_header) do
    auth_url = Application.get_env(:sertantai_legal, :auth_url)

    unless auth_url do
      raise "auth_url not configured"
    end

    shape_body = %{"table" => params["table"]}

    shape_body =
      case params["where"] do
        where when is_binary(where) and where != "" -> Map.put(shape_body, "where", where)
        _ -> shape_body
      end

    shape_body =
      case params["columns"] do
        cols when is_binary(cols) and cols != "" ->
          Map.put(shape_body, "columns", String.split(cols, ",", trim: true))

        _ ->
          shape_body
      end

    gatekeeper_url = "#{auth_url}/api/gatekeeper"

    case Req.post(gatekeeper_url,
           json: %{"shape" => shape_body},
           headers: [{"authorization", auth_header}],
           receive_timeout: 10_000,
           retry: false,
           plug: gatekeeper_plug()
         ) do
      {:ok, %Req.Response{status: 200, body: %{"status" => "success", "shape" => shape}}} ->
        {:ok, shape}

      {:ok, %Req.Response{status: status, body: %{"reason" => reason, "message" => message}}}
      when status in [400, 403, 422] ->
        {:error, status, %{error: message, reason: reason}}

      {:ok, %Req.Response{status: 401}} ->
        {:error, 401, %{error: "Authentication required"}}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Gatekeeper returned unexpected #{status}: #{inspect(body)}")
        {:error, 502, %{error: "Auth service error"}}

      {:error, %Req.TransportError{reason: :econnrefused}} ->
        Logger.error("Auth service unavailable (connection refused)")
        {:error, 502, %{error: "Auth service unavailable"}}

      {:error, reason} ->
        Logger.error("Gatekeeper request failed: #{inspect(reason)}")
        {:error, 502, %{error: "Auth service unavailable"}}
    end
  end

  defp forward_validated_shape(conn, validated_shape, params) do
    electric_url = Application.get_env(:sertantai_legal, :electric_url)

    unless electric_url do
      raise "electric_url not configured"
    end

    # Use table and where from Gatekeeper response (org-scoped WHERE injected by auth)
    # Rewrite view names to partition tables for Electric
    shape_params = %{"table" => rewrite_table(validated_shape["table"])}

    shape_params =
      case validated_shape["where"] do
        where when is_binary(where) and where != "" -> Map.put(shape_params, "where", where)
        _ -> shape_params
      end

    # Columns: prefer Gatekeeper response, fall back to original client request.
    # The Gatekeeper may not return columns (sertantai-auth currently doesn't),
    # so we pass through the client's columns to avoid syncing all columns
    # (which fails on tables with generated columns).
    shape_params =
      case validated_shape["columns"] do
        cols when is_binary(cols) and cols != "" ->
          Map.put(shape_params, "columns", cols)

        cols when is_list(cols) and cols != [] ->
          Map.put(shape_params, "columns", Enum.join(cols, ","))

        _ ->
          # Fall back to original client-requested columns
          case params["columns"] do
            cols when is_binary(cols) and cols != "" -> Map.put(shape_params, "columns", cols)
            _ -> shape_params
          end
      end

    query_params =
      shape_params
      |> Map.merge(passthrough_params(params))
      |> maybe_add_secret()
      |> encode_electric_query()

    upstream_url = "#{electric_url}/v1/shape?#{query_params}"
    stream_from_electric(conn, upstream_url)
  end

  # --- Helpers ---

  # Rewrite view names to partition table names for Electric sync.
  # Electric can't sync views (no WAL), so we translate to the actual partition.
  defp rewrite_table(table), do: Map.get(@table_rewrites, table, table)

  # Partitioned tables have composite PKs (id, country) / (section_id, country).
  # Electric requires all PK columns in the shape. The frontend doesn't know about
  # `country` yet, so inject it when the table is rewritten.
  @extra_pk_columns %{
    "uk_lrt" => "country",
    "lat" => "country"
  }

  defp inject_partition_pk(table, columns) when is_binary(columns) and columns != "" do
    case Map.get(@extra_pk_columns, table) do
      nil -> columns
      extra -> if String.contains?(columns, extra), do: columns, else: columns <> "," <> extra
    end
  end

  defp inject_partition_pk(_table, columns), do: columns

  # Extract client-safe params that pass through to Electric
  defp passthrough_params(params) do
    params
    |> Map.take(@passthrough_params)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Encode query params, preserving literal commas in the "columns" value.
  # URI.encode_query percent-encodes commas (a,b → a%2Cb%2Cc) but Electric
  # expects columns as a literal comma-separated list.
  defp encode_electric_query(params) do
    {columns, rest} = Map.pop(params, "columns")

    encoded = URI.encode_query(rest)

    case columns do
      cols when is_binary(cols) and cols != "" ->
        encoded <> "&columns=" <> URI.encode(cols)

      _ ->
        encoded
    end
  end

  # Append Electric secret if configured (production only)
  defp maybe_add_secret(params) do
    case Application.get_env(:sertantai_legal, :electric_secret) do
      nil -> params
      secret -> Map.put(params, "secret", secret)
    end
  end

  # Returns Req plug option for Gatekeeper calls (test mocking)
  defp gatekeeper_plug do
    if Application.get_env(:sertantai_legal, :test_mode, false) do
      {Req.Test, SertantaiLegalWeb.GatekeeperClient}
    else
      nil
    end
  end

  # Build Req options for Electric calls, using plug adapter in test environment.
  # Disables automatic JSON decoding so Electric's response body is passed through
  # as a raw binary — avoids a wasteful decode→encode round-trip.
  defp req_options(extra_opts \\ []) do
    base_opts = [receive_timeout: 60_000, retry: false, decode_body: false] ++ extra_opts

    if Application.get_env(:sertantai_legal, :test_mode, false) do
      Keyword.put(base_opts, :plug, {Req.Test, __MODULE__})
    else
      base_opts
    end
  end

  # Forward the response from Electric back to the client.
  defp stream_from_electric(conn, upstream_url) do
    case Req.get(upstream_url, req_options()) do
      {:ok, %Req.Response{status: status, body: body} = resp} when status in 200..299 ->
        conn
        |> forward_electric_headers(resp)
        |> put_resp_content_type(get_content_type(resp))
        |> send_resp(status, ensure_binary(body))

      {:ok, %Req.Response{status: status, body: body}} ->
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

  defp forward_electric_headers(conn, %Req.Response{headers: headers}) do
    # Follow the official Electric proxy pattern:
    # https://github.com/electric-sql/electric/blob/main/examples/proxy-auth/app/shape-proxy/route.ts
    #
    # 1. Forward all electric-* headers (required by the client protocol)
    # 2. Delete content-encoding and content-length (Req decompresses the body
    #    but doesn't remove these headers — stale values break browser decoding)
    # 3. Set cache-control: no-store (Electric sets "public, max-age=604800" which
    #    causes browsers to cache responses without CORS headers → MissingHeadersError)
    # 4. Set Vary: Authorization for per-user cache isolation
    # 5. Expose electric-* headers via CORS so the browser JS can read them

    # Headers to skip — either replaced or invalid after proxy decompression
    skip = MapSet.new(~w(cache-control content-encoding content-length transfer-encoding))

    conn =
      Enum.reduce(headers, conn, fn {key, values}, conn ->
        if key in skip do
          conn
        else
          if String.starts_with?(key, "electric-") or key in ~w(etag x-request-id) do
            case values do
              [val | _] -> put_resp_header(conn, key, val)
              _ -> conn
            end
          else
            conn
          end
        end
      end)

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("vary", "Authorization")
    |> put_resp_header(
      "access-control-expose-headers",
      "electric-cursor,electric-handle,electric-offset,electric-schema,electric-up-to-date,electric-internal-known-error"
    )
  end

  defp ensure_binary(body) when is_binary(body), do: body
  defp ensure_binary(body) when is_map(body), do: Jason.encode!(body)
  defp ensure_binary(body) when is_list(body), do: Jason.encode!(body)
  defp ensure_binary(_body), do: ""
end

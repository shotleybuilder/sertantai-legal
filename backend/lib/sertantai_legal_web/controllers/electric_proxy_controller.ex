defmodule SertantaiLegalWeb.ElectricProxyController do
  @moduledoc """
  Streaming reverse proxy for ElectricSQL shape API requests.

  Forwards /api/electric/* to the upstream Electric service using chunked
  transfer encoding (matching Electric's native response format).
  Injects ELECTRIC_SECRET when configured (production auth).
  """
  use SertantaiLegalWeb, :controller

  # Non-electric headers worth forwarding verbatim
  @extra_forward_headers ~w(content-type cache-control etag)

  @spec proxy(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def proxy(conn, %{"path" => path_parts}) do
    case Application.get_env(:sertantai_legal, :electric_url) do
      nil ->
        conn |> put_status(503) |> json(%{error: "Electric URL not configured"})

      electric_url ->
        do_proxy(conn, electric_url, path_parts)
    end
  end

  defp do_proxy(conn, electric_url, path_parts) do
    path = Enum.join(path_parts, "/")

    url =
      case conn.query_string do
        "" -> "#{electric_url}/#{path}"
        qs -> "#{electric_url}/#{path}?#{qs}"
      end

    headers =
      case Application.get_env(:sertantai_legal, :electric_secret) do
        nil -> []
        secret -> [{"authorization", "Bearer #{secret}"}]
      end

    # Stream the response using chunked transfer encoding to match Electric's
    # native format. Buffering large responses (e.g. 10MB definitions) before
    # forwarding causes PauseLock deadlocks in the Electric client library.
    conn_ref = make_ref()

    stream_fn = fn {:data, data}, {req, resp} ->
      chunked_conn = Process.get(conn_ref)

      chunked_conn =
        if chunked_conn do
          chunked_conn
        else
          # First data chunk — send status + headers, start chunked response
          resp.headers
          |> merge_headers(conn)
          |> send_chunked(resp.status)
        end

      case chunk(chunked_conn, data) do
        {:ok, updated} ->
          Process.put(conn_ref, updated)
          {:cont, {req, resp}}

        {:error, _reason} ->
          {:halt, {req, resp}}
      end
    end

    case Req.get(url,
           headers: headers,
           decode_body: false,
           redirect: false,
           receive_timeout: 60_000,
           into: stream_fn
         ) do
      {:ok, _resp} ->
        case Process.get(conn_ref) do
          nil ->
            # No data received — send empty response
            conn |> send_resp(204, "")

          chunked_conn ->
            chunked_conn
        end

      {:error, exception} ->
        # Only send error if we haven't started chunking yet
        if Process.get(conn_ref) do
          Process.get(conn_ref)
        else
          conn
          |> put_status(502)
          |> json(%{error: "Electric proxy error", detail: Exception.message(exception)})
        end
    end
  end

  defp merge_headers(resp_headers, conn) do
    Enum.reduce(resp_headers, conn, fn {name, values}, acc ->
      if forward_header?(name) do
        put_resp_header(acc, name, List.first(values))
      else
        acc
      end
    end)
  end

  # Forward all electric-* headers plus selected standard ones
  defp forward_header?("electric-" <> _), do: true
  defp forward_header?(name), do: name in @extra_forward_headers
end

defmodule SertantaiLegal.Scraper.LegislationGovUk.Client do
  @moduledoc """
  HTTP client for fetching data from legislation.gov.uk using Req.

  Ported from Legl.Services.LegislationGovUk.ClientAmdTbl

  ## Rate Limiting

  To avoid being blacklisted, requests are rate-limited with a configurable delay
  between calls (default: 2 seconds). The delay can be configured via:

      config :sertantai_legal, :scraper_request_delay_ms, 2000

  In test mode, the delay is disabled.

  ## Testing

  In test environment, the client uses Req.Test for mocking.
  Use `Req.Test.stub/2` to set up expected responses.
  """

  @endpoint "https://www.legislation.gov.uk"
  @default_delay_ms 2000

  @doc """
  Fetch HTML content from legislation.gov.uk.

  ## Parameters
  - path: URL path (e.g., "/new/all/2024-01-15")

  ## Returns
  - `{:ok, body}` - HTML content as string
  - `{:error, code, message}` - Error with HTTP status code and message
  """
  @spec fetch_html(String.t()) :: {:ok, String.t()} | {:error, integer(), String.t()}
  def fetch_html(path) do
    rate_limit_delay()
    url = @endpoint <> path

    case Req.get(url, req_options()) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: 301, headers: headers}} ->
        handle_redirect(headers)

      {:ok, %Req.Response{status: 307, headers: headers}} ->
        handle_redirect(headers)

      {:ok, %Req.Response{status: 404}} ->
        {:error, 404, "Not found: #{path}"}

      {:ok, %Req.Response{status: status}} ->
        {:error, status, "Unexpected status #{status} for #{path}"}

      {:error, exception} ->
        {:error, 0, "Request failed: #{inspect(exception)}"}
    end
  end

  @doc """
  Fetch XML content from legislation.gov.uk (for metadata).

  ## Parameters
  - path: URL path (e.g., "/uksi/2024/123/data.xml")

  ## Returns
  - `{:ok, body}` - XML content as string
  - `{:ok, :html, body}` - HTML content when XML expected
  - `{:error, code, message}` - Error with HTTP status code and message
  """
  @spec fetch_xml(String.t()) ::
          {:ok, String.t()} | {:ok, :html, String.t()} | {:error, integer(), String.t()}
  def fetch_xml(path) do
    rate_limit_delay()
    url = @endpoint <> path

    case Req.get(url, req_options()) do
      {:ok, %Req.Response{status: 200, body: body, headers: headers}} ->
        case get_content_type(headers) do
          :xml -> {:ok, body}
          :html -> {:ok, :html, body}
          _ -> {:ok, body}
        end

      {:ok, %Req.Response{status: 307}} ->
        # Try with /made/ path for older legislation
        if not String.contains?(path, "made") do
          fetch_xml(String.replace(path, "data.xml", "made/data.xml"))
        else
          {:error, 307, "Temporary redirect for #{path}"}
        end

      {:ok, %Req.Response{status: 404}} ->
        # Try without /made/ if present
        if String.contains?(path, "/made/") do
          fetch_xml(String.replace(path, "/made", ""))
        else
          {:error, 404, "Not found: #{path}"}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, status, "Unexpected status #{status} for #{path}"}

      {:error, exception} ->
        {:error, 0, "Request failed: #{inspect(exception)}"}
    end
  end

  defp handle_redirect(headers) do
    location =
      headers
      |> Enum.find(fn {k, _v} -> String.downcase(k) == "location" end)
      |> case do
        {_, location} -> location
        nil -> nil
      end

    case location do
      nil -> {:error, 301, "Redirect without location"}
      url -> {:redirect, url}
    end
  end

  defp get_content_type(headers) do
    ct =
      headers
      |> find_header("content-type")
      |> normalize_header_value()

    cond do
      String.contains?(ct, "application/xml") -> :xml
      String.contains?(ct, "text/xml") -> :xml
      String.contains?(ct, "text/html") -> :html
      String.contains?(ct, "application/xhtml+xml") -> :xhtml
      String.contains?(ct, "application/atom+xml") -> :atom
      true -> :unknown
    end
  end

  # Find header value from Req response headers (always a map)
  defp find_header(headers, name) when is_map(headers) do
    Map.get(headers, name) || Map.get(headers, String.capitalize(name))
  end

  # Normalize header value (could be string or list)
  defp normalize_header_value(nil), do: ""
  defp normalize_header_value([value | _]) when is_binary(value), do: value
  defp normalize_header_value(value) when is_binary(value), do: value
  defp normalize_header_value(_), do: ""

  @doc """
  Get the base endpoint URL.
  """
  @spec endpoint() :: String.t()
  def endpoint, do: @endpoint

  # Get Req options, using plug adapter in test environment
  defp req_options do
    base_opts = [receive_timeout: 20_000]

    if Application.get_env(:sertantai_legal, :test_mode, false) do
      Keyword.put(base_opts, :plug, {Req.Test, __MODULE__})
    else
      base_opts
    end
  end

  # Rate limit delay to avoid being blacklisted by legislation.gov.uk
  # Disabled in test mode for fast test execution
  defp rate_limit_delay do
    unless Application.get_env(:sertantai_legal, :test_mode, false) do
      delay_ms =
        Application.get_env(:sertantai_legal, :scraper_request_delay_ms, @default_delay_ms)

      Process.sleep(delay_ms)
    end
  end
end

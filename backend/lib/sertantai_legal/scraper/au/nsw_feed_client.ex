defmodule SertantaiLegal.Scraper.Au.NswFeedClient do
  @moduledoc """
  Client for NSW legislation search feed (Atom XML).

  NSW legislation.nsw.gov.au blocks normal HTTP access (403) but exposes
  an Atom feed endpoint for search results that bypasses the block.

  Feed URL pattern:
    https://legislation.nsw.gov.au/feed?id=search&query=...&db=NSW_PCO-FragTocRelationIdxDatasource

  The query uses a custom query language with PrintType, Repealed, Title filters.
  """

  require Logger

  @base_url "https://legislation.nsw.gov.au"
  @db "NSW_PCO-FragTocRelationIdxDatasource"

  @doc """
  Search NSW legislation by exact title phrase.

  Returns list of matches with title, source_url, number, status, type.
  """
  @spec search_by_title(String.t()) :: {:ok, [map()]} | {:error, any()}
  def search_by_title(title) do
    # Escape quotes in title (replace " with ')
    escaped = String.replace(title, "\"", "'")
    pit = pit_date()

    # Build query: search across in-force and repealed Acts, SLs, EPIs
    query = build_nsw_query(escaped, pit)

    url =
      "#{@base_url}/feed?" <>
        URI.encode_query(%{
          "id" => "search",
          "desc" => "Search",
          "db" => @db,
          "query" => query
        })

    fetch_with_retry(url, 3)
  end

  # ── Feed Parsing ────────────────────────────────────────────────────

  defp parse_feed(xml) do
    # Simple regex-based parsing — Atom feeds have a predictable structure
    ~r{<entry>.*?<title[^>]*>(.+?)</title>.*?<link[^>]*href="([^"]+)"[^/]*/?>.*?</entry>}s
    |> Regex.scan(xml)
    |> Enum.map(fn [_, title, link] ->
      title = String.trim(__MODULE__.HtmlEntities.decode(title))
      clean_url = extract_clean_url(link)
      {type_prefix, year, number} = parse_nsw_id(clean_url)
      status = if String.contains?(clean_url, "/inforce/"), do: "✔ In force", else: "✗ Repealed"

      %{
        title: title,
        source_url: clean_url,
        number: number,
        year: year,
        type_prefix: type_prefix,
        status: status
      }
    end)
  end

  # Extract clean URL: strip query params, fix http→https
  defp extract_clean_url(raw_url) do
    raw_url
    |> String.replace("http://legislation.nsw.gov.au:80", "https://legislation.nsw.gov.au")
    |> String.replace(~r/\?.*$/, "")
    |> __MODULE__.HtmlEntities.decode()
  end

  # Parse NSW legislation ID from URL path
  # e.g., /view/html/inforce/current/act-2021-006 → {"act", 2021, "006"}
  defp parse_nsw_id(url) do
    case Regex.run(~r/\/(act|sl|epi)-(\d\d\d\d)-(\d+)/, url) do
      [_, type, year, number] -> {type, String.to_integer(year), number}
      _ -> {nil, nil, nil}
    end
  end

  defp fetch_with_retry(_url, 0), do: {:error, :rate_limited}

  defp fetch_with_retry(url, retries) do
    case Req.get(url, req_options(receive_timeout: 15_000, retry: false)) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, parse_feed(body)}

      {:ok, %Req.Response{status: 429}} ->
        Logger.info("[NSW Feed] Rate limited, waiting 30s (#{retries - 1} retries left)")
        Process.sleep(30_000)
        fetch_with_retry(url, retries - 1)

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("[NSW Feed] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Get Req options, using plug adapter in test environment
  defp req_options(base_opts) do
    if Application.get_env(:sertantai_legal, :test_mode, false) do
      Keyword.put(base_opts, :plug, {Req.Test, __MODULE__})
    else
      base_opts
    end
  end

  defp build_nsw_query(escaped_title, pit) do
    dq = "\""

    "((Repealed=N AND PrintType=#{dq}act.reprint#{dq} AND PitValid=@pointInTime(#{pit}))" <>
      " OR (Repealed=Y AND PrintType=#{dq}act.reprint#{dq})" <>
      " OR (Repealed=N AND PrintType=#{dq}reprint#{dq} AND PitValid=@pointInTime(#{pit}))" <>
      " OR (Repealed=Y AND PrintType=#{dq}reprint#{dq})" <>
      " OR (Repealed=N AND (PrintType=#{dq}epi.reprint#{dq} OR PrintType=#{dq}epi.electronic#{dq}) AND PitValid=@pointInTime(#{pit}))" <>
      " OR Repealed=Y AND (PrintType=#{dq}epi.reprint#{dq} OR PrintType=#{dq}epi.electronic#{dq}))" <>
      " AND Title=(#{dq}#{escaped_title}#{dq})"
  end

  defp pit_date do
    Date.utc_today()
    |> Date.to_iso8601(:basic)
    |> String.replace("-", "")
    |> Kernel.<>("000000")
  end

  # Minimal HTML entity decoder for feed titles
  defmodule HtmlEntities do
    def decode(str) do
      str
      |> String.replace("&amp;", "&")
      |> String.replace("&lt;", "<")
      |> String.replace("&gt;", ">")
      |> String.replace("&quot;", "\"")
      |> String.replace("&#38;", "&")
      |> String.replace("&#39;", "'")
    end
  end
end

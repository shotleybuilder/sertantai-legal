defmodule SertantaiLegal.Scraper.Au.FederalClient do
  @moduledoc """
  Client for the Australian Federal Register of Legislation OData API.

  Endpoint: `https://api.prod.legislation.gov.au/v1/`

  This is an undocumented OData v4 API backing legislation.gov.au.
  Discovered from the site's Content-Security-Policy header.

  ## Available Entity Sets
  - Titles — legislation metadata (name, ID, year, number, status, history)
  - Versions — specific versions of legislation
  - Affects — amendment/repeal relationships
  - Content — legislation text
  - Documents — downloadable documents

  ## Usage

      {:ok, results} = FederalClient.search_titles("Work Health and Safety Act 2011")
      {:ok, title} = FederalClient.get_title("C2011A00137")
  """

  require Logger

  @base_url "https://api.prod.legislation.gov.au/v1"

  @doc """
  Search Titles by name substring match.

  Returns a list of matching titles with metadata.
  Uses OData `contains()` filter for case-insensitive substring matching.
  """
  @spec search_titles(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def search_titles(query, opts \\ []) do
    top = Keyword.get(opts, :top, 10)

    params = %{
      "$filter" => "contains(Name,'#{escape_odata(query)}')",
      "$top" => to_string(top),
      "$orderby" => "Name"
    }

    case get("Titles", params) do
      {:ok, %{"value" => titles}} -> {:ok, Enum.map(titles, &normalize_title/1)}
      error -> error
    end
  end

  @doc """
  Search for an exact title match (title + year).

  Returns `{:ok, title_map}` if found, `{:ok, nil}` if not.
  """
  @spec find_title(String.t()) :: {:ok, map() | nil} | {:error, any()}
  def find_title(name) do
    params = %{
      "$filter" => "Name eq '#{escape_odata(name)}'",
      "$top" => "1"
    }

    case get("Titles", params) do
      {:ok, %{"value" => [title | _]}} -> {:ok, normalize_title(title)}
      {:ok, %{"value" => []}} -> {:ok, nil}
      error -> error
    end
  end

  @doc """
  Get a single Title by its legislation ID (e.g. "C2011A00137").
  """
  @spec get_title(String.t()) :: {:ok, map()} | {:error, any()}
  def get_title(id) do
    case get("Titles('#{id}')") do
      {:ok, data} when is_map(data) -> {:ok, normalize_title(data)}
      error -> error
    end
  end

  @doc """
  Get amendments/affects for a title by ID.
  """
  @spec get_affects(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def get_affects(title_id, opts \\ []) do
    top = Keyword.get(opts, :top, 50)

    params = %{
      "$filter" => "TitleId eq '#{escape_odata(title_id)}'",
      "$top" => to_string(top)
    }

    case get("Affect", params) do
      {:ok, %{"value" => affects}} -> {:ok, affects}
      error -> error
    end
  end

  # ── HTTP ────────────────────────────────────────────────────────────

  defp get(path, params \\ %{}) do
    query = URI.encode_query(params)
    url = if query == "", do: "#{@base_url}/#{path}", else: "#{@base_url}/#{path}?#{query}"

    case Req.get(url, receive_timeout: 15_000, retry: :transient, max_retries: 2) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:error, :invalid_json}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("[AU Federal API] #{status}: #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("[AU Federal API] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ── Normalization ───────────────────────────────────────────────────

  defp normalize_title(raw) do
    %{
      id: raw["id"],
      name: raw["name"],
      year: raw["year"],
      number: raw["number"],
      collection: raw["collection"],
      is_in_force: raw["isInForce"],
      status: raw["status"],
      is_principal: raw["isPrincipal"],
      making_date: raw["makingDate"],
      registered_at: raw["asMadeRegisteredAt"],
      series_type: raw["seriesType"],
      source_url: "https://www.legislation.gov.au/#{raw["id"]}/latest/text",
      details_url: "https://www.legislation.gov.au/#{raw["id"]}/latest/details",
      status_history: raw["statusHistory"] || [],
      status_possible_future: raw["statusPossibleFuture"] || [],
      name_history: raw["nameHistory"] || []
    }
  end

  defp escape_odata(str) do
    String.replace(str, "'", "''")
  end

  @doc """
  Normalize a title for fuzzy matching.
  Strips dashes, em-dashes, en-dashes and normalizes whitespace.
  The federal register often uses em-dashes (—) where seed data has hyphens (-).
  """
  def normalize_for_search(str) do
    str
    |> String.replace(~r/[—–\-]/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end

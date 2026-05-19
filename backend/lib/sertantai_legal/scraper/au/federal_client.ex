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
  Get all versions for a title, ordered newest first.

  Each version includes `reasons` listing which laws caused that compilation
  (amendments, repeals). This is the primary source for relationship data.
  """
  @spec get_versions(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def get_versions(title_id, opts \\ []) do
    top = Keyword.get(opts, :top, 50)

    params = %{
      "$filter" => "TitleId eq '#{escape_odata(title_id)}'",
      "$orderby" => "start desc",
      "$top" => to_string(top)
    }

    case get("Versions", params) do
      {:ok, %{"value" => versions}} -> {:ok, versions}
      error -> error
    end
  end

  @doc """
  Get recently registered versions across all titles.

  Used for cascade detection: when a new amending law is published,
  affected laws get new compilations that reference the amending law.
  """
  @spec get_recent_versions(String.t(), keyword()) :: {:ok, [map()]} | {:error, any()}
  def get_recent_versions(since_date, opts \\ []) do
    top = Keyword.get(opts, :top, 100)

    params = %{
      "$filter" => "registeredAt gt #{since_date}",
      "$orderby" => "registeredAt desc",
      "$top" => to_string(top)
    }

    case get("Versions", params) do
      {:ok, %{"value" => versions}} -> {:ok, versions}
      error -> error
    end
  end

  @doc """
  Extract all relationships from a title's versions and status history.

  Returns a map with:
  - `amended_by`: list of `%{title_id, name, provisions}` — laws that amended this one
  - `rescinded_by`: list of `%{title_id, name, provisions}` — laws that repealed this one
  - `latest_amend_date`: date of most recent amendment compilation
  - `latest_rescind_date`: date of repeal (if repealed)
  """
  @spec extract_relationships(String.t()) :: {:ok, map()} | {:error, any()}
  def extract_relationships(title_id) do
    with {:ok, title} <- get_title(title_id),
         {:ok, versions} <- get_versions(title_id, top: 100) do
      # Extract amended_by from Versions reasons
      amended_by =
        versions
        |> Enum.flat_map(fn v -> v["reasons"] || [] end)
        |> Enum.filter(&(&1["affect"] == "Amend"))
        |> Enum.map(fn r ->
          t = r["affectedByTitle"] || %{}

          %{
            title_id: t["titleId"],
            name: t["name"],
            provisions: t["provisions"]
          }
        end)
        |> Enum.uniq_by(& &1.title_id)

      # Extract rescinded_by from Titles statusHistory
      rescinded_by =
        (title.status_history || [])
        |> Enum.flat_map(fn sh -> sh["reasons"] || [] end)
        |> Enum.filter(&(&1["affect"] == "Repeal"))
        |> Enum.map(fn r ->
          t = r["affectedByTitle"] || %{}

          %{
            title_id: t["titleId"],
            name: t["name"],
            provisions: t["provisions"]
          }
        end)
        |> Enum.uniq_by(& &1.title_id)

      # Latest amendment date = start date of most recent version with reasons
      latest_amend_date =
        versions
        |> Enum.filter(fn v -> (v["reasons"] || []) != [] end)
        |> Enum.map(fn v -> v["start"] end)
        |> List.first()

      # Repeal date
      latest_rescind_date =
        (title.status_history || [])
        |> Enum.filter(&(&1["status"] == "Repealed"))
        |> Enum.map(& &1["start"])
        |> List.first()

      {:ok,
       %{
         amended_by: amended_by,
         rescinded_by: rescinded_by,
         latest_amend_date: latest_amend_date,
         latest_rescind_date: latest_rescind_date
       }}
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

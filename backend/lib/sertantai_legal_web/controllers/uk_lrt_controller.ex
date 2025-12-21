defmodule SertantaiLegalWeb.UkLrtController do
  @moduledoc """
  API controller for UK Legal Register Table (LRT) CRUD operations.

  Provides endpoints to:
  - List and search UK legislation records
  - Get individual record details
  - Update record metadata
  - Delete records
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query

  @doc """
  GET /api/uk-lrt

  List UK LRT records with optional filtering and pagination.

  ## Query Parameters
  - family: Filter by family classification
  - year: Filter by year
  - type_code: Filter by type code (uksi, ukpga, etc.)
  - status: Filter by live status
  - search: Search in title, name, number
  - limit: Number of records (default: 50, max: 100)
  - offset: Pagination offset
  """
  def index(conn, params) do
    limit = min(parse_integer(params["limit"], 50), 100)
    offset = parse_integer(params["offset"], 0)

    query_args = %{
      family: params["family"],
      year: parse_integer_or_nil(params["year"]),
      type_code: params["type_code"],
      status: params["status"],
      search: params["search"]
    }

    case UkLrt.paginated(
           query_args.family,
           query_args.year,
           query_args.type_code,
           query_args.status,
           query_args.search,
           page: [limit: limit, offset: offset]
         ) do
      {:ok, page} ->
        json(conn, %{
          records: Enum.map(page.results, &record_to_json/1),
          count: length(page.results),
          limit: limit,
          offset: offset,
          has_more: page.more?
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: format_error(reason)})
    end
  end

  @doc """
  GET /api/uk-lrt/:id

  Get a single UK LRT record by ID.
  """
  def show(conn, %{"id" => id}) do
    case UkLrt.by_id(id) do
      {:ok, record} ->
        json(conn, record_to_json(record))

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Record not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  PATCH /api/uk-lrt/:id

  Update a UK LRT record.

  ## Body Parameters
  Any valid UK LRT attributes (title_en, family, tags, etc.)
  """
  def update(conn, %{"id" => id} = params) do
    attrs = Map.drop(params, ["id"])

    case UkLrt.by_id(id) do
      {:ok, record} ->
        case record
             |> Ash.Changeset.for_update(:update, attrs)
             |> Ash.update() do
          {:ok, updated} ->
            json(conn, record_to_json(updated))

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: format_error(reason)})
        end

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Record not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  DELETE /api/uk-lrt/:id

  Delete a UK LRT record.
  """
  def delete(conn, %{"id" => id}) do
    case UkLrt.by_id(id) do
      {:ok, record} ->
        case Ash.destroy(record) do
          :ok ->
            json(conn, %{message: "Record deleted", id: id})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: format_error(reason)})
        end

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Record not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  GET /api/uk-lrt/search

  Search UK LRT records with full-text search.
  Alias for index with search parameter.
  """
  def search(conn, params) do
    index(conn, params)
  end

  @doc """
  GET /api/uk-lrt/filters

  Get available filter values (families, years, type_codes, statuses).
  """
  def filters(conn, _params) do
    with {:ok, families} <- UkLrt.distinct_families(),
         {:ok, years} <- UkLrt.distinct_years() do
      json(conn, %{
        families: families |> Enum.map(& &1.family) |> Enum.reject(&is_nil/1) |> Enum.sort(),
        years: years |> Enum.map(& &1.year) |> Enum.reject(&is_nil/1) |> Enum.sort(:desc)
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: format_error(reason)})
    end
  end

  # Private helpers

  defp record_to_json(record) do
    %{
      id: record.id,
      name: record.name,
      title_en: record.title_en,
      year: record.year,
      number: record.number,
      type_code: record.type_code,
      type_class: record.type_class,
      family: record.family,
      family_ii: record.family_ii,
      live: record.live,
      live_description: record.live_description,
      geo_extent: record.geo_extent,
      geo_region: record.geo_region,
      acronym: record.acronym,
      leg_gov_uk_url: record.leg_gov_uk_url,
      md_description: record.md_description,
      md_subjects: record.md_subjects,
      si_code: record.si_code,
      tags: record.tags,
      function: record.function,
      duty_holder: record.duty_holder,
      power_holder: record.power_holder,
      rights_holder: record.rights_holder,
      is_making: record.is_making,
      enacted_by: record.enacted_by,
      amending: record.amending,
      amended_by: record.amended_by,
      md_made_date: record.md_made_date,
      md_enactment_date: record.md_enactment_date,
      md_coming_into_force_date: record.md_coming_into_force_date,
      latest_amend_date: record.latest_amend_date
    }
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end
  defp parse_integer(value, _default) when is_integer(value), do: value
  defp parse_integer(_, default), do: default

  defp parse_integer_or_nil(nil), do: nil
  defp parse_integer_or_nil(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end
  defp parse_integer_or_nil(value) when is_integer(value), do: value
  defp parse_integer_or_nil(_), do: nil

  defp format_error(%{errors: errors}) when is_list(errors) do
    Enum.map_join(errors, ", ", &inspect/1)
  end
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp not_found_error?(%Ash.Error.Query.NotFound{}), do: true
  defp not_found_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, &not_found_error?/1)
  end
  defp not_found_error?(_), do: false
end

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

  @doc """
  GET /api/uk-lrt/exists/:name

  Check if a UK LRT record exists by name (e.g., "uksi/2025/1227").
  Uses wildcard path to capture the full name with slashes.
  """
  def exists(conn, %{"name" => name_parts}) do
    # Handle wildcard path (comes as list) or single segment
    decoded_name =
      case name_parts do
        parts when is_list(parts) -> Enum.join(parts, "/")
        name when is_binary(name) -> URI.decode(name)
      end

    case UkLrt
         |> Ash.Query.filter(name == ^decoded_name)
         |> Ash.read() do
      {:ok, [existing | _]} ->
        json(conn, %{
          exists: true,
          id: existing.id,
          name: existing.name,
          title_en: existing.title_en,
          family: existing.family,
          updated_at: existing.updated_at
        })

      {:ok, []} ->
        json(conn, %{exists: false})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: format_error(reason)})
    end
  end

  @doc """
  POST /api/uk-lrt/batch-exists

  Check existence of multiple laws in a single request.

  ## Parameters
  - names: List of law names to check (e.g., ["uksi/2024/123", "ukpga/2020/1"])

  ## Returns
  - existing: List of laws that exist (with id, name, title_en)
  - missing: List of names that don't exist
  """
  def batch_exists(conn, %{"names" => names}) when is_list(names) do
    existing =
      UkLrt
      |> Ash.Query.filter(name in ^names)
      |> Ash.Query.select([:id, :name, :title_en, :year, :type_code])
      |> Ash.read!()
      |> Enum.map(fn r ->
        %{
          id: r.id,
          name: r.name,
          title_en: r.title_en,
          year: r.year,
          type_code: r.type_code
        }
      end)

    existing_names = MapSet.new(existing, & &1.name)
    missing = Enum.reject(names, &MapSet.member?(existing_names, &1))

    json(conn, %{
      existing: existing,
      existing_count: length(existing),
      missing: missing,
      missing_count: length(missing)
    })
  end

  def batch_exists(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: names (array of law names)"})
  end

@doc """
  POST /api/uk-lrt/:id/rescrape

  Re-scrape and re-parse a single UK LRT record from legislation.gov.uk.
  Updates the record with fresh data from all parsing stages.
  """
  def rescrape(conn, %{"id" => id}) do
    alias SertantaiLegal.Scraper.StagedParser

    case UkLrt.by_id(id) do
      {:ok, record} ->
        # Build the input record for StagedParser
        input = %{
          type_code: record.type_code,
          Year: record.year,
          Number: record.number,
          Title_EN: record.title_en,
          name: record.name
        }

# StagedParser.parse always returns {:ok, result}
        {:ok, result} = StagedParser.parse(input)

        # Extract parsed data from stages
        parsed_data = build_update_attrs(result)

        # Update the record
        case record
             |> Ash.Changeset.for_update(:update, parsed_data)
             |> Ash.update() do
          {:ok, updated} ->
            json(conn, %{
              message: "Rescrape completed successfully",
              record: record_to_json(updated),
              stages: format_stages(result.stages),
              errors: result.errors,
              has_errors: result.has_errors
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Update failed: #{format_error(reason)}"})
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

  # Build update attributes from parsed result
  defp build_update_attrs(result) do
    stages = result.stages

    base_attrs = %{}

    # Extent stage
    base_attrs =
      if stages[:extent][:status] == :ok and stages[:extent][:data] do
        Map.merge(base_attrs, %{
          geo_extent: stages[:extent][:data][:geo_extent],
          geo_region: stages[:extent][:data][:geo_region],
          geo_detail: stages[:extent][:data][:geo_detail]
        })
      else
        base_attrs
      end

    # Enacted_by stage
    base_attrs =
      if stages[:enacted_by][:status] == :ok and stages[:enacted_by][:data] do
        Map.merge(base_attrs, %{
          enacted_by: stages[:enacted_by][:data][:enacted_by]
        })
      else
        base_attrs
      end

    # Amendments stage
    base_attrs =
      if stages[:amendments][:status] == :ok and stages[:amendments][:data] do
        Map.merge(base_attrs, %{
          amending: stages[:amendments][:data][:amending],
          amended_by: stages[:amendments][:data][:amended_by]
        })
      else
        base_attrs
      end

    # Repeal/revoke stage
    base_attrs =
      if stages[:repeal_revoke][:status] == :ok and stages[:repeal_revoke][:data] do
        Map.merge(base_attrs, %{
          live: stages[:repeal_revoke][:data][:live],
          live_description: stages[:repeal_revoke][:data][:live_description],
          rescinding: stages[:repeal_revoke][:data][:rescinding],
          rescinded_by: stages[:repeal_revoke][:data][:rescinded_by]
        })
      else
        base_attrs
      end

    # Taxa stage
    base_attrs =
      if stages[:taxa][:status] == :ok and stages[:taxa][:data] do
        Map.merge(base_attrs, %{
          role: stages[:taxa][:data][:role],
          role_gvt: stages[:taxa][:data][:role_gvt],
          duty_type: stages[:taxa][:data][:duty_type],
          duty_holder: stages[:taxa][:data][:duty_holder],
          duty_holder_article_clause: stages[:taxa][:data][:duty_holder_article_clause],
          rights_holder: stages[:taxa][:data][:rights_holder],
          rights_holder_article_clause: stages[:taxa][:data][:rights_holder_article_clause],
          responsibility_holder: stages[:taxa][:data][:responsibility_holder],
          responsibility_holder_article_clause: stages[:taxa][:data][:responsibility_holder_article_clause],
          power_holder: stages[:taxa][:data][:power_holder],
          power_holder_article_clause: stages[:taxa][:data][:power_holder_article_clause],
          popimar: stages[:taxa][:data][:popimar],
          popimar_article_clause: stages[:taxa][:data][:popimar_article_clause]
        })
      else
        base_attrs
      end

    # Filter out nil values
    base_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Format stages for JSON response
  defp format_stages(stages) do
    stages
    |> Enum.map(fn {stage, result} ->
      {stage, %{
        status: result.status,
        error: result[:error]
      }}
    end)
    |> Map.new()
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
      geo_detail: record.geo_detail,
      md_restrict_extent: record.md_restrict_extent,
      acronym: record.acronym,
      leg_gov_uk_url: record.leg_gov_uk_url,
      md_description: record.md_description,
      md_subjects: record.md_subjects,
      si_code: record.si_code,
      tags: record.tags,
      function: record.function,
      # Role/Actor
      role: record.role,
      role_gvt: record.role_gvt,
      article_role: record.article_role,
      role_article: record.role_article,
      # Duty Type
      duty_type: record.duty_type,
      duty_type_article: record.duty_type_article,
      article_duty_type: record.article_duty_type,
      # Duty Holder
      duty_holder: record.duty_holder,
      duty_holder_article: record.duty_holder_article,
      duty_holder_article_clause: record.duty_holder_article_clause,
      article_duty_holder: record.article_duty_holder,
      article_duty_holder_clause: record.article_duty_holder_clause,
      # Power Holder
      power_holder: record.power_holder,
      power_holder_article: record.power_holder_article,
      power_holder_article_clause: record.power_holder_article_clause,
      article_power_holder: record.article_power_holder,
      article_power_holder_clause: record.article_power_holder_clause,
      # Rights Holder
      rights_holder: record.rights_holder,
      rights_holder_article: record.rights_holder_article,
      rights_holder_article_clause: record.rights_holder_article_clause,
      article_rights_holder: record.article_rights_holder,
      article_rights_holder_clause: record.article_rights_holder_clause,
      # Responsibility Holder
      responsibility_holder: record.responsibility_holder,
      responsibility_holder_article: record.responsibility_holder_article,
      responsibility_holder_article_clause: record.responsibility_holder_article_clause,
      article_responsibility_holder: record.article_responsibility_holder,
      article_responsibility_holder_clause: record.article_responsibility_holder_clause,
      # POPIMAR
      popimar: record.popimar,
      popimar_article: record.popimar_article,
      popimar_article_clause: record.popimar_article_clause,
      article_popimar: record.article_popimar,
      article_popimar_clause: record.article_popimar_clause,
      # Purpose
      purpose: record.purpose,
      is_making: record.is_making,
      enacted_by: record.enacted_by,
      amending: record.amending,
      amended_by: record.amended_by,
      md_date: record.md_date,
      md_made_date: record.md_made_date,
      md_enactment_date: record.md_enactment_date,
      md_coming_into_force_date: record.md_coming_into_force_date,
      md_dct_valid_date: record.md_dct_valid_date,
      md_restrict_start_date: record.md_restrict_start_date,
      md_total_paras: record.md_total_paras,
      md_body_paras: record.md_body_paras,
      md_schedule_paras: record.md_schedule_paras,
      md_attachment_paras: record.md_attachment_paras,
      md_images: record.md_images,
      latest_amend_date: record.latest_amend_date,
      # Timestamps
      created_at: record.created_at,
      updated_at: record.updated_at
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

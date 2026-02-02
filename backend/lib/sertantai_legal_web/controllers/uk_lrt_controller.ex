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

  DEPRECATED: This endpoint has been replaced by the parse-preview workflow.
  Use POST /api/uk-lrt/:id/parse-preview to get parsed data for review,
  then PATCH /api/uk-lrt/:id to save approved changes.

  This ensures all changes are reviewed before being saved to the database.
  """
  def rescrape(conn, _params) do
    conn
    |> put_status(:gone)
    |> json(%{
      error: "This endpoint is deprecated",
      message:
        "Use POST /api/uk-lrt/:id/parse-preview to get parsed data, " <>
          "then PATCH /api/uk-lrt/:id to save changes after review.",
      migration: %{
        old: "POST /api/uk-lrt/:id/rescrape",
        new: [
          "POST /api/uk-lrt/:id/parse-preview (get parsed data + diff)",
          "PATCH /api/uk-lrt/:id (save approved changes)"
        ]
      }
    })
  end

  @doc """
  POST /api/uk-lrt/:id/parse-preview

  Parse a UK LRT record without saving to database.
  Returns parsed data, current DB record, and diff for review.

  ## Query Parameters
  - stages: Comma-separated list of stages to run (optional, defaults to all)
            Valid stages: metadata, extent, enacted_by, amending, amended_by, repeal_revoke, taxa

  ## Response
  - parsed: The newly parsed data
  - current: The current DB record
  - diff: Fields that differ between parsed and current
  - stages: Status of each parse stage
  - errors: Any parse errors
  - has_errors: Boolean indicating if any stage failed
  """
  def parse_preview(conn, %{"id" => id} = params) do
    alias SertantaiLegal.Scraper.StagedParser

    # Parse stages parameter if provided
    stages_to_run = parse_stages_param(params["stages"])

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

        # Parse with optional stage filtering
        parse_opts = if stages_to_run, do: [stages: stages_to_run], else: []
        {:ok, result} = StagedParser.parse(input, parse_opts)

        # Extract parsed data from stages
        parsed_data = build_update_attrs(result)

        # Get current record as map for comparison
        current_data = record_to_json(record)

        # Compute diff - fields where parsed differs from current
        diff = compute_diff(current_data, parsed_data)

        json(conn, %{
          parsed: parsed_data,
          current: current_data,
          diff: diff,
          stages: format_stages(result.stages),
          errors: result.errors,
          has_errors: result.has_errors
        })

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

  # Parse comma-separated stages parameter into list of atoms
  defp parse_stages_param(nil), do: nil
  defp parse_stages_param(""), do: nil

  defp parse_stages_param(stages_str) when is_binary(stages_str) do
    valid_stages = ~w(metadata extent enacted_by amending amended_by repeal_revoke taxa)a

    stages_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.filter(&(&1 in valid_stages))
    |> case do
      [] -> nil
      stages -> stages
    end
  rescue
    ArgumentError -> nil
  end

  # Compute diff between current and parsed data
  defp compute_diff(current, parsed) do
    parsed
    |> Enum.filter(fn {key, parsed_value} ->
      current_value = Map.get(current, key)
      # Consider it changed if values differ (handling nil vs missing)
      normalize_value(parsed_value) != normalize_value(current_value)
    end)
    |> Enum.map(fn {key, parsed_value} ->
      {key, %{current: Map.get(current, key), parsed: parsed_value}}
    end)
    |> Map.new()
  end

  # Normalize values for comparison (treat empty lists/maps as nil-equivalent)
  defp normalize_value(nil), do: nil
  defp normalize_value([]), do: nil
  defp normalize_value(%{} = map) when map_size(map) == 0, do: nil
  defp normalize_value(value), do: value

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
          duty_type: list_to_jsonb_map(stages[:taxa][:data][:duty_type]),
          duty_holder: stages[:taxa][:data][:duty_holder],
          duty_holder_article_clause: stages[:taxa][:data][:duty_holder_article_clause],
          rights_holder: stages[:taxa][:data][:rights_holder],
          rights_holder_article_clause: stages[:taxa][:data][:rights_holder_article_clause],
          responsibility_holder: stages[:taxa][:data][:responsibility_holder],
          responsibility_holder_article_clause:
            stages[:taxa][:data][:responsibility_holder_article_clause],
          power_holder: stages[:taxa][:data][:power_holder],
          power_holder_article_clause: stages[:taxa][:data][:power_holder_article_clause],
          popimar: stages[:taxa][:data][:popimar],
          # Phase 4 Issue #15: popimar_details replaces deprecated text columns
          popimar_details: stages[:taxa][:data][:popimar_details]
        })
      else
        base_attrs
      end

    # Filter out nil values - empty lists/maps should still update to clear stale data
    base_attrs
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Format stages for JSON response
  defp format_stages(stages) do
    stages
    |> Enum.map(fn {stage, result} ->
      {stage,
       %{
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
      # Phase 4 Issue #16: Removed deprecated text columns - article_role, role_article
      role_details: record.role_details,
      role_gvt_details: record.role_gvt_details,
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
      # Phase 4 Issue #15: Consolidated JSONB field replaces deprecated text columns
      popimar_details: record.popimar_details,
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

  # Convert list to JSONB map format for DB storage
  defp list_to_jsonb_map(nil), do: nil
  defp list_to_jsonb_map([]), do: nil
  defp list_to_jsonb_map(list) when is_list(list), do: %{"values" => list}
  defp list_to_jsonb_map(%{"values" => _} = map), do: map
  defp list_to_jsonb_map(_), do: nil
end

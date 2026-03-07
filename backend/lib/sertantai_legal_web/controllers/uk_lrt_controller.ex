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

  DEPRECATED: This endpoint has been replaced by the streaming parse workflow.
  Use GET /api/uk-lrt/:id/parse-stream for real-time SSE parse progress,
  then PATCH /api/uk-lrt/:id to save approved changes.
  """
  def rescrape(conn, _params) do
    conn
    |> put_status(:gone)
    |> json(%{
      error: "This endpoint is deprecated",
      message:
        "Use GET /api/uk-lrt/:id/parse-stream for real-time SSE parse progress, " <>
          "then PATCH /api/uk-lrt/:id to save changes after review.",
      migration: %{
        old: "POST /api/uk-lrt/:id/rescrape",
        new: [
          "GET /api/uk-lrt/:id/parse-stream (SSE streaming parse with progress)",
          "PATCH /api/uk-lrt/:id (save approved changes)"
        ]
      }
    })
  end

  # SSE heartbeat interval in milliseconds (keeps connection alive during long parses)
  @sse_heartbeat_interval 5_000

  @doc """
  GET /api/uk-lrt/:id/parse-stream

  Stream parse progress for an existing UK LRT record via Server-Sent Events.
  Mirrors the scrape session parse-stream endpoint but works without a session.

  ## Query Parameters
  - stages: Comma-separated list of stages to run (optional, defaults to all)
            Valid stages: metadata, extent, enacted_by, amending, amended_by, repeal_revoke
  """
  def parse_stream(conn, %{"id" => id} = params) do
    alias SertantaiLegal.Scraper.StagedParser
    alias SertantaiLegal.Scraper.ParsedLaw

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

        # Set up SSE connection
        conn =
          conn
          |> put_resp_content_type("text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("connection", "keep-alive")
          |> send_chunked(200)

        # Send initial event to confirm connection is established
        {:ok, conn} =
          chunk(conn, "data: #{Jason.encode!(%{event: "connected", name: record.name})}\n\n")

        caller = self()

        # Progress callback sends messages to the controller process
        send_progress = fn event ->
          send(caller, {:sse_event, event})
          :ok
        end

        # Parse stages parameter if provided (for retry functionality)
        valid_stages_map = %{
          "metadata" => :metadata,
          "extent" => :extent,
          "enacted_by" => :enacted_by,
          "amending" => :amending,
          "amended_by" => :amended_by,
          "repeal_revoke" => :repeal_revoke
        }

        parse_opts =
          case params["stages"] do
            nil ->
              [on_progress: send_progress]

            stages_str when is_binary(stages_str) ->
              stages =
                stages_str
                |> String.split(",")
                |> Enum.map(&String.trim/1)
                |> Enum.map(&Map.get(valid_stages_map, &1))
                |> Enum.reject(&is_nil/1)

              [on_progress: send_progress, stages: stages]
          end

        # Start the parser in a separate task
        task = Task.async(fn -> StagedParser.parse(input, parse_opts) end)

        # Event loop: receive parser events or send heartbeats on timeout
        conn = sse_event_loop(conn, task, record.name)

        conn

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

  # SSE event loop - receives parser events or sends heartbeats on timeout
  defp sse_event_loop(conn, task, name) do
    receive do
      {:sse_event, event} ->
        # Forward parser event to client
        data = encode_progress_event(event)

        case chunk(conn, "data: #{data}\n\n") do
          {:ok, conn} ->
            sse_event_loop(conn, task, name)

          {:error, _reason} ->
            # Client disconnected, but let task finish
            Task.await(task, :infinity)
            conn
        end

      {ref, {:ok, result}} when is_reference(ref) ->
        # Task completed successfully
        Process.demonitor(ref, [:flush])
        send_sse_parse_complete(conn, result, name)

      {ref, {:error, reason}} when is_reference(ref) ->
        # Task failed
        Process.demonitor(ref, [:flush])

        require Logger
        Logger.error("[SSE] Parse task failed: #{inspect(reason)}")

        conn

      {:DOWN, _ref, :process, _pid, reason} ->
        # Task crashed
        require Logger
        Logger.error("[SSE] Parse task crashed: #{inspect(reason)}")

        conn
    after
      @sse_heartbeat_interval ->
        # Send SSE comment as heartbeat (keeps connection alive)
        case chunk(conn, ": heartbeat\n\n") do
          {:ok, conn} ->
            sse_event_loop(conn, task, name)

          {:error, _reason} ->
            require Logger
            Logger.info("[SSE] Client disconnected during heartbeat")

            Task.await(task, :infinity)
            conn
        end
    end
  end

  # Send the final parse_complete event with duplicate check for diff display
  defp send_sse_parse_complete(conn, result, name) do
    alias SertantaiLegal.Scraper.ParsedLaw
    alias SertantaiLegal.Scraper.IdField

    unless result.cancelled do
      comparison_map = ParsedLaw.to_comparison_map(result.law)
      scraped_keys = Map.keys(comparison_map)

      # Check for existing record to enable diff display
      duplicate = check_duplicate_for_stream(name, scraped_keys)

      final_event =
        Jason.encode!(%{
          event: "parse_complete",
          has_errors: result.has_errors,
          result: %{
            name: name,
            record: comparison_map,
            stages: format_stages_for_stream(result.stages),
            errors: result.errors,
            has_errors: result.has_errors,
            duplicate: duplicate
          }
        })

      chunk(conn, "data: #{final_event}\n\n")
    end

    conn
  end

  # Encode progress events to JSON for SSE
  defp encode_progress_event({:stage_start, stage, stage_num, total}) do
    Jason.encode!(%{
      event: "stage_start",
      stage: stage,
      stage_num: stage_num,
      total: total
    })
  end

  defp encode_progress_event({:stage_complete, stage, status, summary}) do
    Jason.encode!(%{
      event: "stage_complete",
      stage: stage,
      status: status,
      summary: summary
    })
  end

  defp encode_progress_event({:parse_complete, has_errors}) do
    Jason.encode!(%{
      event: "parse_done",
      has_errors: has_errors
    })
  end

  # Check for existing record in DB (for diff display in parse_stream)
  defp check_duplicate_for_stream(name, _scraped_keys) do
    alias SertantaiLegal.Scraper.IdField
    alias SertantaiLegal.Scraper.ParsedLaw
    require Ash.Query

    db_name = IdField.normalize_to_db_name(name)

    case UkLrt
         |> Ash.Query.filter(name == ^db_name)
         |> Ash.read() do
      {:ok, [existing | _]} ->
        %{
          exists: true,
          id: existing.id,
          updated_at: existing.updated_at,
          family: existing.family,
          record:
            existing
            |> ParsedLaw.from_db_record()
            |> ParsedLaw.to_comparison_map()
        }

      _ ->
        %{exists: false}
    end
  end

  # Format stages for SSE stream response (includes data field)
  defp format_stages_for_stream(stages) do
    stages
    |> Enum.map(fn {stage, result} ->
      {stage,
       %{
         status: result.status,
         error: result.error,
         data: result.data
       }}
    end)
    |> Enum.into(%{})
  end
end

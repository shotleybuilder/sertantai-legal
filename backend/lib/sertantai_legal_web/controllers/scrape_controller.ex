defmodule SertantaiLegalWeb.ScrapeController do
  @moduledoc """
  API controller for scraping legislation.gov.uk.

  Provides endpoints to:
  - Create and run scrape sessions
  - List and view sessions
  - Access group records
  - Persist and parse groups
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Scraper.SessionManager
  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.LawParser
  alias SertantaiLegal.Scraper.ScrapeSession
  alias SertantaiLegal.Scraper.Models
  alias SertantaiLegal.Scraper.TypeClass

  @doc """
  POST /api/scrape

  Create and run a new scrape session.

  ## Parameters
  - year: integer (required)
  - month: integer 1-12 (required)
  - day_from: integer 1-31 (required)
  - day_to: integer 1-31 (required)
  - type_code: string (optional) - e.g., "uksi", "ukpga"
  """
  def create(conn, params) do
    with {:ok, year} <- get_integer_param(params, "year"),
         {:ok, month} <- get_integer_param(params, "month"),
         {:ok, day_from} <- get_integer_param(params, "day_from"),
         {:ok, day_to} <- get_integer_param(params, "day_to") do
      type_code = params["type_code"]

      case SessionManager.run(year, month, day_from, day_to, type_code) do
        {:ok, session} ->
          conn
          |> put_status(:created)
          |> json(session_to_json(session))

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: format_error(reason)})
      end
    else
      {:error, field, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid #{field}: #{message}"})
    end
  end

  @doc """
  GET /api/sessions

  List recent scrape sessions.
  """
  def index(conn, _params) do
    case SessionManager.list_recent() do
      {:ok, sessions} ->
        json(conn, %{sessions: Enum.map(sessions, &session_to_json/1)})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: format_error(reason)})
    end
  end

  @doc """
  GET /api/sessions/:id

  Get session detail by session_id.
  """
  def show(conn, %{"id" => session_id}) do
    case SessionManager.get(session_id) do
      {:ok, session} ->
        json(conn, session_to_json(session))

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  GET /api/sessions/:id/group/:group

  Get records for a specific group.

  ## Parameters
  - group: "1", "2", or "3"
  """
  def group(conn, %{"id" => session_id, "group" => group_str}) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, _session} <- SessionManager.get(session_id) do
      case Storage.read_json(session_id, group) do
        {:ok, records} ->
          json(conn, %{
            session_id: session_id,
            group: group_str,
            count: count_records(records),
            records: normalize_records(records)
          })

        {:error, reason} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Group file not found: #{reason}"})
      end
    else
      {:error, :invalid_group} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid group. Use 1, 2, or 3"})

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  POST /api/sessions/:id/persist/:group

  Persist a group to the uk_lrt table.

  ## Parameters
  - group: "1", "2", or "3"
  """
  def persist(conn, %{"id" => session_id, "group" => group_str}) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, session} <- SessionManager.get(session_id),
         {:ok, updated_session} <- SessionManager.persist_group(session, group) do
      json(conn, %{
        message: "Group #{group_str} persisted successfully",
        session: session_to_json(updated_session)
      })
    else
      {:error, :invalid_group} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid group. Use 1, 2, or 3"})

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  POST /api/sessions/:id/parse/:group

  Parse a group to fetch metadata from legislation.gov.uk XML API.

  ## Parameters
  - group: "1", "2", or "3"
  - selected_only: boolean (optional) - if true, only parse selected records
  """
  def parse(conn, %{"id" => session_id, "group" => group_str} = params) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, _session} <- SessionManager.get(session_id) do
      # Parse with auto_confirm since this is API-driven
      # Optionally filter by selection
      selected_only = params["selected_only"] == true || params["selected_only"] == "true"
      opts = [auto_confirm: true, selected_only: selected_only]

      case LawParser.parse_group(session_id, group, opts) do
        {:ok, results} ->
          json(conn, %{
            message: "Group #{group_str} parsed",
            session_id: session_id,
            results: results
          })

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: format_error(reason)})
      end
    else
      {:error, :invalid_group} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid group. Use 1, 2, or 3"})

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  PATCH /api/sessions/:id/group/:group/select

  Update selection state for records in a group.

  ## Parameters
  - group: "1", "2", or "3"
  - names: list of record names to update
  - selected: boolean
  """
  def select(conn, %{"id" => session_id, "group" => group_str} = params) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, _session} <- SessionManager.get(session_id),
         {:ok, names} <- get_list_param(params, "names"),
         {:ok, selected} <- get_boolean_param(params, "selected") do
      case Storage.update_selection(session_id, group, names, selected) do
        {:ok, count} ->
          json(conn, %{
            message: "Selection updated",
            session_id: session_id,
            group: group_str,
            updated: count,
            selected: selected
          })

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: format_error(reason)})
      end
    else
      {:error, :invalid_group} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid group. Use 1, 2, or 3"})

      {:error, field, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid #{field}: #{message}"})

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  @doc """
  POST /api/sessions/:id/parse-one

  Parse a single record with staged parsing for interactive review.
  Does NOT persist - returns data for user review.

  ## Parameters
  - name: record name (e.g., "uksi/2025/1227")
  """
  def parse_one(conn, %{"id" => session_id, "name" => name}) do
    alias SertantaiLegal.Scraper.StagedParser
    alias SertantaiLegal.Scraper.Storage

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Find the record in any group
      record = find_record_in_session(session_id, name)

      case record do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Record not found in session: #{name}"})

        record ->
          # Run staged parse
          case StagedParser.parse(record) do
            {:ok, result} ->
              # Check for duplicate in database
              duplicate = check_duplicate(name)

              # Enrich record with type fields and normalize keys
              enriched_record = enrich_type_fields(result.record)

              json(conn, %{
                session_id: session_id,
                name: name,
                record: enriched_record,
                stages: format_stages(result.stages),
                errors: result.errors,
                has_errors: result.has_errors,
                duplicate: duplicate
              })
          end
      end
    else
      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  def parse_one(conn, %{"id" => _session_id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: name"})
  end

  @doc """
  POST /api/sessions/:id/confirm

  Confirm and persist a reviewed record to uk_lrt.

  ## Parameters
  - name: record name (e.g., "uksi/2025/1227")
  - family: Family classification (e.g., "E", "H", "S")
  - overrides: Optional map of field overrides
  """
  def confirm(conn, %{"id" => session_id, "name" => name} = params) do
    alias SertantaiLegal.Scraper.StagedParser
    alias SertantaiLegal.Scraper.LawParser

    family = params["family"]
    overrides = params["overrides"] || %{}

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Find the record in any group
      record = find_record_in_session(session_id, name)

      case record do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Record not found in session: #{name}"})

        record ->
          # Run staged parse to get full metadata
          case StagedParser.parse(record) do
            {:ok, result} ->
              # Merge family and overrides
              record_to_persist =
                result.record
                |> Map.put(:Family, family)
                |> Map.merge(atomize_keys(overrides))

              # Persist using LawParser (handles create/update)
              case LawParser.parse_record(record_to_persist, persist: true) do
                {:ok, persisted} ->
                  # Mark record as reviewed in session
                  mark_record_reviewed(session_id, name)

                  json(conn, %{
                    message: "Record persisted successfully",
                    name: name,
                    id: persisted.id,
                    action: if(check_duplicate(name), do: "updated", else: "created")
                  })

                {:error, reason} ->
                  conn
                  |> put_status(:unprocessable_entity)
                  |> json(%{error: "Failed to persist: #{reason}"})
              end
          end
      end
    else
      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  def confirm(conn, %{"id" => _session_id}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: name"})
  end

  @doc """
  GET /api/family-options

  Get the list of all available family options for UI dropdowns.
  Returns families grouped by category (health_safety, environment, hr).
  """
  def family_options(conn, _params) do
    json(conn, %{
      families: Models.ehs_family() ++ Models.hr_family(),
      grouped: Models.family_options_grouped()
    })
  end

  @doc """
  DELETE /api/sessions/:id

  Delete a session and its files.
  """
  def delete(conn, %{"id" => session_id}) do
    case SessionManager.get(session_id) do
      {:ok, _session} ->
        case SessionManager.delete(session_id) do
          :ok ->
            json(conn, %{message: "Session deleted"})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: format_error(reason)})
        end

      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_status(:not_found)
          |> json(%{error: "Session not found"})
        else
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: format_error(reason)})
        end
    end
  end

  # Private helpers

  defp get_integer_param(params, field) do
    case params[field] do
      nil ->
        {:error, field, "is required"}

      value when is_integer(value) ->
        {:ok, value}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {int, ""} -> {:ok, int}
          _ -> {:error, field, "must be an integer"}
        end

      _ ->
        {:error, field, "must be an integer"}
    end
  end

  defp get_list_param(params, field) do
    case params[field] do
      nil ->
        {:error, field, "is required"}

      value when is_list(value) ->
        {:ok, value}

      _ ->
        {:error, field, "must be a list"}
    end
  end

  defp get_boolean_param(params, field) do
    case params[field] do
      nil ->
        {:error, field, "is required"}

      value when is_boolean(value) ->
        {:ok, value}

      "true" ->
        {:ok, true}

      "false" ->
        {:ok, false}

      _ ->
        {:error, field, "must be a boolean"}
    end
  end

  defp parse_group("1"), do: {:ok, :group1}
  defp parse_group("2"), do: {:ok, :group2}
  defp parse_group("3"), do: {:ok, :group3}
  defp parse_group(_), do: {:error, :invalid_group}

  defp session_to_json(%ScrapeSession{} = session) do
    %{
      id: session.id,
      session_id: session.session_id,
      year: session.year,
      month: session.month,
      day_from: session.day_from,
      day_to: session.day_to,
      type_code: session.type_code,
      status: session.status,
      error_message: session.error_message,
      total_fetched: session.total_fetched,
      title_excluded_count: session.title_excluded_count,
      group1_count: session.group1_count,
      group2_count: session.group2_count,
      group3_count: session.group3_count,
      persisted_count: session.persisted_count,
      inserted_at: session.inserted_at,
      updated_at: session.updated_at
    }
  end

  defp count_records(records) when is_list(records), do: length(records)
  defp count_records(records) when is_map(records), do: map_size(records)
  defp count_records(_), do: 0

  # Normalize records to list format for JSON response and enrich with type fields
  defp normalize_records(records) when is_list(records) do
    Enum.map(records, &enrich_type_fields/1)
  end

  defp normalize_records(records) when is_map(records) do
    # Group 3 is indexed map, convert to list with index
    records
    |> Enum.sort_by(fn {k, _v} -> String.to_integer(to_string(k)) end)
    |> Enum.map(fn {id, record} ->
      record
      |> Map.put(:_index, id)
      |> enrich_type_fields()
    end)
  end

  defp normalize_records(_), do: []

  # Enrich record with type_desc and type_class if missing, normalize keys
  defp enrich_type_fields(record) do
    record
    |> maybe_enrich_type_desc()
    |> maybe_enrich_type_class()
    |> normalize_family_key()
    |> normalize_tags_key()
  end

  # Note: geo_detail is populated from Airtable CSV export, not derived from geo_region.
  # geo_detail contains section-by-section extent breakdown with emoji flags.

  # Normalize Family key to lowercase for consistency
  defp normalize_family_key(record) do
    family = record[:Family] || record["Family"]
    if family do
      record
      |> Map.put(:family, family)
      |> Map.delete(:Family)
      |> Map.delete("Family")
    else
      record
    end
  end

  # Normalize Tags key to lowercase for consistency
  defp normalize_tags_key(record) do
    tags = record[:Tags] || record["Tags"]
    if tags do
      record
      |> Map.put(:tags, tags)
      |> Map.delete(:Tags)
      |> Map.delete("Tags")
    else
      record
    end
  end

  defp maybe_enrich_type_desc(record) do
    # Skip if already has type_desc
    case record[:type_desc] || record["type_desc"] do
      nil ->
        type_code = record[:type_code] || record["type_code"]
        if type_code do
          enriched = TypeClass.set_type(%{type_code: type_code})
          type_desc = enriched[:Type]
          if type_desc, do: Map.put(record, :type_desc, type_desc), else: record
        else
          record
        end
      _ ->
        record
    end
  end

  defp maybe_enrich_type_class(record) do
    # Skip if already has type_class
    case record[:type_class] || record["type_class"] do
      nil ->
        title = record[:Title_EN] || record["Title_EN"]
        if title do
          enriched = TypeClass.set_type_class(%{Title_EN: title})
          type_class = enriched[:type_class]
          if type_class, do: Map.put(record, :type_class, type_class), else: record
        else
          record
        end
      _ ->
        record
    end
  end

  defp format_error(%{errors: errors}) when is_list(errors) do
    Enum.map_join(errors, ", ", &inspect/1)
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  # Check if an error is a "not found" error (handles wrapped Ash errors)
  defp not_found_error?(%Ash.Error.Query.NotFound{}), do: true

  defp not_found_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, &not_found_error?/1)
  end

  defp not_found_error?(_), do: false

  # Find a record by name across all groups in a session
  defp find_record_in_session(session_id, name) do
    groups = [:group1, :group2, :group3]

    Enum.find_value(groups, fn group ->
      case Storage.read_json(session_id, group) do
        {:ok, records} when is_list(records) ->
          Enum.find(records, fn r ->
            (r[:name] || r["name"]) == name
          end)

        {:ok, records} when is_map(records) ->
          records
          |> Map.values()
          |> Enum.find(fn r ->
            (r[:name] || r["name"]) == name
          end)

        _ ->
          nil
      end
    end)
  end

  # Check if a record with this name already exists in uk_lrt
  defp check_duplicate(name) do
    alias SertantaiLegal.Legal.UkLrt
    require Ash.Query

    case UkLrt
         |> Ash.Query.filter(name == ^name)
         |> Ash.read() do
      {:ok, [existing | _]} ->
        %{
          exists: true,
          id: existing.id,
          updated_at: existing.updated_at
        }

      _ ->
        %{exists: false}
    end
  end

  # Format stages for JSON response
  defp format_stages(stages) do
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

  # Mark a record as reviewed in the session JSON
  defp mark_record_reviewed(session_id, name) do
    # Update the record in all groups to mark as reviewed
    groups = [:group1, :group2, :group3]

    Enum.each(groups, fn group ->
      case Storage.read_json(session_id, group) do
        {:ok, records} when is_list(records) ->
          updated =
            Enum.map(records, fn r ->
              if (r[:name] || r["name"]) == name do
                Map.put(r, :reviewed, true)
              else
                r
              end
            end)

          Storage.save_json(session_id, group, updated)

        {:ok, records} when is_map(records) ->
          updated =
            Enum.map(records, fn {k, r} ->
              if (r[:name] || r["name"]) == name do
                {k, Map.put(r, :reviewed, true)}
              else
                {k, r}
              end
            end)
            |> Enum.into(%{})

          Storage.save_json(session_id, group, updated)

        _ ->
          :ok
      end
    end)
  end

  # Convert string keys to atoms for overrides
  defp atomize_keys(map) when is_map(map) do
    map
    |> Enum.map(fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
    |> Enum.into(%{})
  end

  defp atomize_keys(other), do: other
end

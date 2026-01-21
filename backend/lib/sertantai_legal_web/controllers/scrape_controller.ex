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
  alias SertantaiLegal.Scraper.ParsedLaw

  require Ash.Query

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
  GET /api/sessions/:id/db-status

  Get the count of session records that already exist in uk_lrt.
  Returns counts for each group and total.
  """
  def db_status(conn, %{"id" => session_id}) do
    alias SertantaiLegal.Legal.UkLrt

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Collect all record names from groups 1 and 2 (group 3 is excluded)
      names =
        [:group1, :group2]
        |> Enum.flat_map(fn group ->
          case Storage.read_session_records(session_id, group) do
            {:ok, records} ->
              Enum.map(records, fn r -> r[:name] || r["name"] end)

            {:error, _} ->
              []
          end
        end)
        |> Enum.reject(&is_nil/1)

      # Query DB for existing records with updated_at
      existing_records =
        if length(names) > 0 do
          UkLrt
          |> Ash.Query.filter(name in ^names)
          |> Ash.Query.select([:name, :updated_at])
          |> Ash.read!()
        else
          []
        end

      existing_names = existing_records |> Enum.map(& &1.name) |> MapSet.new()

      # Build map of name -> updated_at for frontend
      updated_at_map =
        existing_records
        |> Enum.map(fn r -> {r.name, r.updated_at} end)
        |> Enum.into(%{})

      json(conn, %{
        session_id: session_id,
        total_records: length(names),
        existing_in_db: MapSet.size(existing_names),
        new_records: length(names) - MapSet.size(existing_names),
        existing_names: MapSet.to_list(existing_names),
        updated_at_map: updated_at_map
      })
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

  @doc """
  GET /api/sessions/:id/group/:group

  Get records for a specific group.

  ## Parameters
  - group: "1", "2", or "3"
  """
  def group(conn, %{"id" => session_id, "group" => group_str}) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, _session} <- SessionManager.get(session_id) do
      # Use read_session_records_with_source which tries DB first, falls back to JSON
      case Storage.read_session_records_with_source(session_id, group) do
        {:ok, records, data_source} ->
          json(conn, %{
            session_id: session_id,
            group: group_str,
            count: count_records(records),
            records: normalize_records(records),
            data_source: data_source
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
      # Update both JSON and DB for backwards compatibility
      json_result = Storage.update_selection(session_id, group, names, selected)
      db_result = Storage.update_selection_db(session_id, group, names, selected)

      # Use whichever succeeded (prefer DB count if both succeeded)
      case {json_result, db_result} do
        {{:ok, _json_count}, {:ok, db_count}} ->
          json(conn, %{
            message: "Selection updated",
            session_id: session_id,
            group: group_str,
            updated: db_count,
            selected: selected
          })

        {{:ok, json_count}, {:error, _}} ->
          # DB failed but JSON succeeded - still report success
          json(conn, %{
            message: "Selection updated",
            session_id: session_id,
            group: group_str,
            updated: json_count,
            selected: selected
          })

        {{:error, _}, {:ok, db_count}} ->
          # JSON failed but DB succeeded
          json(conn, %{
            message: "Selection updated",
            session_id: session_id,
            group: group_str,
            updated: db_count,
            selected: selected
          })

        {{:error, reason}, {:error, _}} ->
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
      # Find the record in any group, or build from name for cascade updates
      record = find_record_in_session(session_id, name) || build_record_from_name(name)

      case record do
        nil ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Invalid record name format: #{name}"})

        record ->
          # Run staged parse
          case StagedParser.parse(record) do
            {:ok, result} ->
              # Use ParsedLaw.to_comparison_map for normalized diff comparison
              # This handles all key normalization and excludes empty/nil fields
              comparison_map = ParsedLaw.to_comparison_map(result.law)

              # Check for duplicate in database, filtering to only keys the scraper produces
              scraped_keys = Map.keys(comparison_map)
              duplicate = check_duplicate(name, scraped_keys)

              json(conn, %{
                session_id: session_id,
                name: name,
                record: comparison_map,
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
  - record: Optional pre-parsed record data (avoids redundant re-parse)
  """
  def confirm(conn, %{"id" => session_id, "name" => name} = params) do
    alias SertantaiLegal.Scraper.LawParser
    alias SertantaiLegal.Scraper.Storage

    family = params["family"]
    overrides = params["overrides"] || %{}
    pre_parsed_record = params["record"]

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Use pre-parsed record if provided, otherwise this is an error
      # (the frontend should always send the record to avoid redundant parsing)
      case pre_parsed_record do
        nil ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Missing required parameter: record (pre-parsed data from parse_one)"})

        record_data when is_map(record_data) ->
          # Atomize keys and merge family/overrides
          record_to_persist =
            record_data
            |> atomize_keys()
            |> Map.put(:Family, family)
            |> Map.merge(atomize_keys(overrides))

          # Persist directly - record already has full metadata from parse_one
          case LawParser.persist_direct(record_to_persist) do
            {:ok, persisted} ->
              # Mark record as reviewed in session
              mark_record_reviewed(session_id, name)

              # Collect affected laws for cascade update
              amending = record_to_persist[:amending] || []
              rescinding = record_to_persist[:rescinding] || []
              # enacted_by can be list of maps or strings - extract names
              enacted_by_names = extract_enacted_by_names(record_to_persist[:enacted_by])

              Storage.add_affected_laws(
                session_id,
                name,
                amending,
                rescinding,
                enacted_by_names
              )

              # Check if there are affected laws
              has_affected = length(amending) + length(rescinding) > 0
              has_enacting_parents = length(enacted_by_names) > 0

              json(conn, %{
                message: "Record persisted successfully",
                name: name,
                id: persisted.id,
                action: if(check_duplicate(name), do: "updated", else: "created"),
                has_affected_laws: has_affected,
                affected_count: length(amending) + length(rescinding),
                has_enacting_parents: has_enacting_parents,
                enacting_parents_count: length(enacted_by_names)
              })

            {:error, reason} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Failed to persist: #{reason}"})
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

  # Enrich record with type_desc and type_class if missing (for session list display)
  # Does NOT normalize credential keys - UI expects Year, Number, Title_EN
  defp enrich_type_fields(record) do
    record
    |> maybe_enrich_type_desc()
    |> maybe_enrich_type_class()
    |> normalize_family_key()
    |> normalize_tags_key()
    |> maybe_calculate_md_date()
  end

  # Extract name strings from enacted_by which can be list of maps or strings
  defp extract_enacted_by_names(nil), do: []
  defp extract_enacted_by_names([]), do: []

  defp extract_enacted_by_names(enacted_by) when is_list(enacted_by) do
    Enum.map(enacted_by, fn
      %{name: name} -> name
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Parse a law name into components (type_code, year, number)
  # Handles both formats: UK_uksi_2020_847 or uksi/2020/847
  defp parse_law_name(name) when is_binary(name) do
    cond do
      # UK_ format: UK_uksi_2020_847
      String.starts_with?(name, "UK_") ->
        case String.split(name, "_") do
          ["UK", type_code, year, number] ->
            case Integer.parse(year) do
              {year_int, ""} -> {:ok, type_code, year_int, number}
              _ -> :error
            end

          _ ->
            :error
        end

      # Slash format: uksi/2020/847
      String.contains?(name, "/") ->
        case String.split(name, "/") do
          [type_code, year, number] ->
            case Integer.parse(year) do
              {year_int, ""} -> {:ok, type_code, year_int, number}
              _ -> :error
            end

          _ ->
            :error
        end

      true ->
        :error
    end
  end

  defp parse_law_name(_), do: :error

  # Calculate md_date if missing (for backwards compatibility with old session data)
  # Priority: enactment_date > coming_into_force_date > made_date > dct_valid_date
  defp maybe_calculate_md_date(record) do
    md_date = record[:md_date] || record["md_date"]

    if present?(md_date) do
      record
    else
      calculated_date =
        cond do
          present?(record[:md_enactment_date] || record["md_enactment_date"]) ->
            record[:md_enactment_date] || record["md_enactment_date"]

          present?(record[:md_coming_into_force_date] || record["md_coming_into_force_date"]) ->
            record[:md_coming_into_force_date] || record["md_coming_into_force_date"]

          present?(record[:md_made_date] || record["md_made_date"]) ->
            record[:md_made_date] || record["md_made_date"]

          present?(record[:md_dct_valid_date] || record["md_dct_valid_date"]) ->
            record[:md_dct_valid_date] || record["md_dct_valid_date"]

          true ->
            nil
        end

      if calculated_date do
        Map.put(record, :md_date, calculated_date)
      else
        record
      end
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

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

  # Build a minimal record from a name string (e.g., "uksi/2025/622" or "UK_uksi_2025_622")
  # Used for cascade updates where records exist in uk_lrt but not in session
  defp build_record_from_name(name) do
    # Handle both formats: "uksi/2025/622" and "UK_uksi_2025_622"
    normalized =
      name
      |> String.replace("UK_", "")
      |> String.replace("_", "/")

    case String.split(normalized, "/") do
      [type_code, year_str, number] ->
        case Integer.parse(year_str) do
          {year, ""} ->
            %{
              type_code: type_code,
              Year: year,
              Number: number,
              name: "#{type_code}/#{year}/#{number}"
            }

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Find a record by name across all groups in a session
  defp find_record_in_session(session_id, name) do
    groups = [:group1, :group2, :group3]

    Enum.find_value(groups, fn group ->
      case Storage.read_session_records(session_id, group) do
        {:ok, records} ->
          Enum.find(records, fn r ->
            (r[:name] || r["name"]) == name
          end)

        {:error, _} ->
          nil
      end
    end)
  end

  # Check if a record with this name already exists in uk_lrt
  # Returns the full existing record for diff comparison
  # Optional scraped_keys filters the existing record to only include keys the scraper produces
  defp check_duplicate(name, scraped_keys \\ nil) do
    alias SertantaiLegal.Legal.UkLrt
    alias SertantaiLegal.Scraper.IdField
    require Ash.Query

    # Normalize name to database format (uksi/2025/622 -> UK_uksi_2025_622)
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
          record: existing_record_to_map(existing, scraped_keys)
        }

      _ ->
        %{exists: false}
    end
  end

  # Convert an existing UkLrt struct to a map for JSON serialization and diff comparison
  # Uses ParsedLaw.from_db_record/1 to unwrap JSONB fields to list format
  # If scraped_keys is provided, only include keys that the scraper produces
  defp existing_record_to_map(existing, scraped_keys) do
    # Use ParsedLaw to handle JSONB unwrapping consistently
    result =
      existing
      |> ParsedLaw.from_db_record()
      |> ParsedLaw.to_comparison_map()

    # Filter to only keys the scraper produces (avoids showing "deleted" for unscraped fields)
    if scraped_keys do
      Map.take(result, scraped_keys)
    else
      result
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

  # Mark a record as reviewed/confirmed in session storage
  defp mark_record_reviewed(session_id, name) do
    # Update DB record status to confirmed
    Storage.confirm_session_record(session_id, name)

    # Also update JSON files for backwards compatibility
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

  # ============================================================================
  # Cascade Update Actions
  # ============================================================================

  @doc """
  GET /api/sessions/:id/affected-laws

  Get affected laws for a session, partitioned by DB existence.

  Returns:
  - in_db: Laws that exist in uk_lrt (can be re-parsed)
  - not_in_db: Laws that don't exist (can be scraped)
  """
  def affected_laws(conn, %{"id" => session_id}) do
    alias SertantaiLegal.Legal.UkLrt

    with {:ok, _session} <- SessionManager.get(session_id) do
      summary = Storage.get_affected_laws_summary(session_id)

      # Check which laws exist in DB (for amending/rescinding - need re-parse)
      all_affected = summary.all_affected

      {in_db, not_in_db} =
        if all_affected == [] do
          {[], []}
        else
          # Query DB for existing laws
          existing =
            UkLrt
            |> Ash.Query.filter(name in ^all_affected)
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

          not_existing =
            all_affected
            |> Enum.reject(&MapSet.member?(existing_names, &1))
            |> Enum.map(fn name -> %{name: name} end)

          {existing, not_existing}
        end

      # Check which enacting parents exist in DB (for direct array update)
      enacting_parents = summary.enacting_parents

      {enacting_parents_in_db, enacting_parents_not_in_db} =
        if enacting_parents == [] do
          {[], []}
        else
          existing =
            UkLrt
            |> Ash.Query.filter(name in ^enacting_parents)
            |> Ash.Query.select([
              :id,
              :name,
              :title_en,
              :year,
              :type_code,
              :enacting,
              :is_enacting
            ])
            |> Ash.read!()
            |> Enum.map(fn r ->
              %{
                id: r.id,
                name: r.name,
                title_en: r.title_en,
                year: r.year,
                type_code: r.type_code,
                current_enacting_count: length(r.enacting || []),
                is_enacting: r.is_enacting
              }
            end)

          existing_names = MapSet.new(existing, & &1.name)

          not_existing =
            enacting_parents
            |> Enum.reject(&MapSet.member?(existing_names, &1))
            |> Enum.map(fn name -> %{name: name} end)

          {existing, not_existing}
        end

      json(conn, %{
        session_id: session_id,
        source_laws: summary.source_laws,
        source_count: summary.source_count,
        # Laws needing re-parse (amending/rescinding relationships)
        in_db: in_db,
        in_db_count: length(in_db),
        not_in_db: not_in_db,
        not_in_db_count: length(not_in_db),
        total_affected: summary.all_affected_count,
        # Parent laws needing direct enacting array update
        enacting_parents_in_db: enacting_parents_in_db,
        enacting_parents_in_db_count: length(enacting_parents_in_db),
        enacting_parents_not_in_db: enacting_parents_not_in_db,
        enacting_parents_not_in_db_count: length(enacting_parents_not_in_db),
        total_enacting_parents: summary.enacting_parents_count
      })
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

  @doc """
  POST /api/sessions/:id/batch-reparse

  Trigger batch re-parse for laws in the DB.

  ## Parameters
  - names: List of law names to re-parse (optional, defaults to all in_db)

  Returns progress and results for each law.
  """
  def batch_reparse(conn, %{"id" => session_id} = params) do
    alias SertantaiLegal.Scraper.StagedParser
    alias SertantaiLegal.Scraper.LawParser
    alias SertantaiLegal.Legal.UkLrt

    names = params["names"]

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Get names to re-parse
      target_names =
        if names && is_list(names) && length(names) > 0 do
          names
        else
          # Default to all affected laws in DB
          summary = Storage.get_affected_laws_summary(session_id)

          UkLrt
          |> Ash.Query.filter(name in ^summary.all_affected)
          |> Ash.Query.select([:name])
          |> Ash.read!()
          |> Enum.map(& &1.name)
        end

      # Re-parse each law
      results =
        Enum.map(target_names, fn name ->
          # Build minimal record for StagedParser
          # Handle both formats: UK_uksi_2020_847 or uksi/2020/847
          case parse_law_name(name) do
            {:ok, type_code, year, number} ->
              record = %{
                type_code: type_code,
                Year: year,
                Number: number,
                name: name
              }

              # StagedParser.parse always returns {:ok, result}
              {:ok, result} = StagedParser.parse(record)

              # Persist the updated record
              case LawParser.parse_record(result.record, persist: true) do
                {:ok, _persisted} ->
                  # Mark cascade entry as processed
                  Storage.mark_cascade_processed(session_id, name)
                  %{name: name, status: "success", message: "Re-parsed and updated"}

                {:error, reason} ->
                  %{name: name, status: "error", message: "Persist failed: #{inspect(reason)}"}
              end

            :error ->
              %{name: name, status: "error", message: "Invalid name format"}
          end
        end)

      success_count = Enum.count(results, &(&1.status == "success"))
      error_count = Enum.count(results, &(&1.status == "error"))

      json(conn, %{
        session_id: session_id,
        total: length(results),
        success: success_count,
        errors: error_count,
        results: results
      })
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

  @doc """
  POST /api/sessions/:id/update-enacting-links

  Update enacting arrays on parent laws directly.

  Unlike amending/rescinding (which requires re-parsing from legislation.gov.uk),
  enacting relationships are derived from enacted_by. This endpoint directly
  appends source laws to parent laws' enacting arrays.

  ## Parameters
  - names: List of parent law names to update (optional, defaults to all enacting_parents)

  ## Returns
  Progress and results for each parent law updated.
  """
  def update_enacting_links(conn, %{"id" => session_id} = params) do
    alias SertantaiLegal.Legal.UkLrt
    alias SertantaiLegal.Scraper.CascadeAffectedLaw

    names = params["names"]

    with {:ok, _session} <- SessionManager.get(session_id) do
      # Get enacting_link entries from DB
      enacting_entries =
        case CascadeAffectedLaw.by_session_and_type(session_id, :enacting_link) do
          {:ok, entries} -> entries
          _ -> []
        end

      # Fall back to JSON if no DB entries
      {target_parents, parent_to_sources} =
        if enacting_entries == [] do
          # Use JSON format (backwards compatibility)
          affected_data = Storage.read_affected_laws(session_id)
          entries = affected_data[:entries] || []

          all_parents =
            if names && is_list(names) && length(names) > 0 do
              names
            else
              affected_data[:all_enacting_parents] || []
            end

          # Build map from old JSON format (entry has :enacted_by list)
          sources_map =
            Enum.reduce(entries, %{}, fn entry, acc ->
              source_law = entry[:source_law] || entry["source_law"]
              enacted_by_list = entry[:enacted_by] || entry["enacted_by"] || []

              Enum.reduce(enacted_by_list, acc, fn parent, inner_acc ->
                if parent in all_parents do
                  Map.update(inner_acc, parent, [source_law], &[source_law | &1])
                else
                  inner_acc
                end
              end)
            end)

          {all_parents, sources_map}
        else
          # Use DB format
          all_parents =
            if names && is_list(names) && length(names) > 0 do
              Enum.filter(enacting_entries, &(&1.affected_law in names))
            else
              enacting_entries
            end
            |> Enum.map(& &1.affected_law)

          # Build map from DB entries (each entry is a parent with source_laws)
          sources_map =
            enacting_entries
            |> Enum.filter(&(&1.affected_law in all_parents))
            |> Enum.map(fn entry -> {entry.affected_law, entry.source_laws} end)
            |> Map.new()

          {all_parents, sources_map}
        end

      if target_parents == [] do
        json(conn, %{
          session_id: session_id,
          total: 0,
          success: 0,
          errors: 0,
          results: [],
          message: "No enacting parents to update"
        })
      else
        # Update each parent law
        results =
          Enum.map(target_parents, fn parent_name ->
            sources_to_add = Map.get(parent_to_sources, parent_name, []) |> Enum.uniq()

            if sources_to_add == [] do
              %{name: parent_name, status: "skipped", message: "No source laws to add"}
            else
              # Find the parent law in DB
              case UkLrt
                   |> Ash.Query.filter(name == ^parent_name)
                   |> Ash.read_one() do
                {:ok, nil} ->
                  %{
                    name: parent_name,
                    status: "error",
                    message: "Parent law not found in database"
                  }

                {:ok, parent_law} ->
                  # Merge existing enacting with new sources
                  existing_enacting = parent_law.enacting || []
                  new_enacting = Enum.uniq(existing_enacting ++ sources_to_add)

                  # Only update if there's something new to add
                  added = Enum.reject(sources_to_add, &(&1 in existing_enacting))

                  if added == [] do
                    # Mark as processed even if unchanged
                    Storage.mark_cascade_processed(session_id, parent_name)

                    %{
                      name: parent_name,
                      status: "unchanged",
                      message: "All source laws already in enacting array",
                      current_count: length(existing_enacting)
                    }
                  else
                    # Update using Ash - use specific update_enacting action
                    case Ash.Changeset.for_update(parent_law, :update_enacting, %{
                           enacting: new_enacting,
                           is_enacting: true
                         })
                         |> Ash.update() do
                      {:ok, updated} ->
                        # Mark cascade entry as processed
                        Storage.mark_cascade_processed(session_id, parent_name)

                        %{
                          name: parent_name,
                          status: "success",
                          message: "Updated enacting array",
                          added: added,
                          added_count: length(added),
                          new_total: length(updated.enacting || [])
                        }

                      {:error, reason} ->
                        %{
                          name: parent_name,
                          status: "error",
                          message: "Update failed: #{inspect(reason)}"
                        }
                    end
                  end

                {:error, reason} ->
                  %{
                    name: parent_name,
                    status: "error",
                    message: "Query failed: #{inspect(reason)}"
                  }
              end
            end
          end)

        success_count = Enum.count(results, &(&1.status == "success"))
        error_count = Enum.count(results, &(&1.status == "error"))
        unchanged_count = Enum.count(results, &(&1.status == "unchanged"))

        json(conn, %{
          session_id: session_id,
          total: length(results),
          success: success_count,
          unchanged: unchanged_count,
          errors: error_count,
          results: results
        })
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

  @doc """
  DELETE /api/sessions/:id/affected-laws

  Clear affected laws for a session after cascade update is complete.
  """
  def clear_affected_laws(conn, %{"id" => session_id}) do
    with {:ok, _session} <- SessionManager.get(session_id),
         :ok <- Storage.clear_affected_laws(session_id) do
      json(conn, %{
        message: "Affected laws cleared",
        session_id: session_id
      })
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
end

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
  """
  def parse(conn, %{"id" => session_id, "group" => group_str}) do
    with {:ok, group} <- parse_group(group_str),
         {:ok, _session} <- SessionManager.get(session_id) do
      # Parse with auto_confirm since this is API-driven
      case LawParser.parse_group(session_id, group, auto_confirm: true) do
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

  # Normalize records to list format for JSON response
  defp normalize_records(records) when is_list(records), do: records

  defp normalize_records(records) when is_map(records) do
    # Group 3 is indexed map, convert to list with index
    records
    |> Enum.sort_by(fn {k, _v} -> String.to_integer(to_string(k)) end)
    |> Enum.map(fn {id, record} -> Map.put(record, :_index, id) end)
  end

  defp normalize_records(_), do: []

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
end

defmodule SertantaiLegalWeb.CascadeController do
  @moduledoc """
  Controller for standalone cascade update management.

  Provides endpoints for viewing and processing cascade updates across sessions,
  separate from the synchronous modal workflow.
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Scraper.CascadeAffectedLaw
  alias SertantaiLegal.Scraper.SessionManager
  alias SertantaiLegal.Scraper.StagedParser
  alias SertantaiLegal.Scraper.LawParser
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query

  @doc """
  GET /api/cascade

  Get all pending cascade entries, optionally filtered by session_id.

  Query params:
  - session_id: Filter to specific session (optional)

  Returns grouped data:
  - sessions: List of sessions with pending cascade
  - reparse: Laws needing re-parse (in DB)
  - reparse_missing: Laws needing re-parse (NOT in DB - need adding)
  - enacting: Parent laws needing enacting update
  - summary: Count totals
  """
  def index(conn, params) do
    session_id = params["session_id"]

    # Get pending entries
    entries =
      case session_id do
        nil -> CascadeAffectedLaw.all_pending!()
        id -> CascadeAffectedLaw.pending_for_session!(id)
      end

    # Get unique session IDs with pending work
    session_ids = entries |> Enum.map(& &1.session_id) |> Enum.uniq()

    # Fetch session details for context
    sessions =
      session_ids
      |> Enum.map(fn sid ->
        case SessionManager.get(sid) do
          {:ok, session} ->
            %{
              session_id: session.session_id,
              year: session.year,
              month: session.month,
              day_from: session.day_from,
              day_to: session.day_to,
              status: session.status,
              persisted_count: session.persisted_count
            }

          _ ->
            %{
              session_id: sid,
              year: nil,
              month: nil,
              day_from: nil,
              day_to: nil,
              status: nil,
              persisted_count: 0
            }
        end
      end)

    # Split by update type
    reparse_entries = Enum.filter(entries, &(&1.update_type == :reparse))
    enacting_entries = Enum.filter(entries, &(&1.update_type == :enacting_link))

    # Get all affected law names
    reparse_names = Enum.map(reparse_entries, & &1.affected_law)
    enacting_names = Enum.map(enacting_entries, & &1.affected_law)

    # Check which laws exist in DB
    all_names = Enum.uniq(reparse_names ++ enacting_names)
    existing_laws = lookup_existing_laws(all_names)
    existing_names = MapSet.new(Map.keys(existing_laws))

    # Also look up source law titles (source laws are in DB - they triggered the cascade)
    all_source_names =
      entries
      |> Enum.flat_map(& &1.source_laws)
      |> Enum.uniq()

    source_laws_map = lookup_existing_laws(all_source_names)

    # Build reparse lists (in DB vs missing)
    reparse_in_db =
      reparse_entries
      |> Enum.filter(&MapSet.member?(existing_names, &1.affected_law))
      |> Enum.map(fn entry ->
        law = existing_laws[entry.affected_law]

        %{
          id: entry.id,
          affected_law: entry.affected_law,
          session_id: entry.session_id,
          source_laws: entry.source_laws,
          title_en: law[:title_en],
          year: law[:year],
          type_code: law[:type_code],
          family: law[:family]
        }
      end)

    reparse_missing =
      reparse_entries
      |> Enum.reject(&MapSet.member?(existing_names, &1.affected_law))
      |> Enum.map(fn entry ->
        %{
          id: entry.id,
          affected_law: entry.affected_law,
          session_id: entry.session_id,
          source_laws: entry.source_laws,
          source_laws_details: build_source_details(entry.source_laws, source_laws_map)
        }
      end)

    # Build enacting list (only in DB makes sense)
    enacting_in_db =
      enacting_entries
      |> Enum.filter(&MapSet.member?(existing_names, &1.affected_law))
      |> Enum.map(fn entry ->
        law = existing_laws[entry.affected_law]

        %{
          id: entry.id,
          affected_law: entry.affected_law,
          session_id: entry.session_id,
          source_laws: entry.source_laws,
          title_en: law[:title_en],
          year: law[:year],
          type_code: law[:type_code],
          current_enacting: law[:enacting] || [],
          current_enacting_count: length(law[:enacting] || []),
          is_enacting: law[:is_enacting] || false
        }
      end)

    enacting_missing =
      enacting_entries
      |> Enum.reject(&MapSet.member?(existing_names, &1.affected_law))
      |> Enum.map(fn entry ->
        %{
          id: entry.id,
          affected_law: entry.affected_law,
          session_id: entry.session_id,
          source_laws: entry.source_laws
        }
      end)

    json(conn, %{
      sessions: sessions,
      reparse_in_db: reparse_in_db,
      reparse_missing: reparse_missing,
      enacting_in_db: enacting_in_db,
      enacting_missing: enacting_missing,
      summary: %{
        total_pending: length(entries),
        reparse_in_db_count: length(reparse_in_db),
        reparse_missing_count: length(reparse_missing),
        enacting_in_db_count: length(enacting_in_db),
        enacting_missing_count: length(enacting_missing),
        session_count: length(session_ids)
      },
      filter: %{
        session_id: session_id
      }
    })
  end

  @doc """
  GET /api/cascade/sessions

  List sessions that have pending cascade entries.
  """
  def sessions(conn, _params) do
    entries = CascadeAffectedLaw.all_pending!()

    # Group by session and count
    session_stats =
      entries
      |> Enum.group_by(& &1.session_id)
      |> Enum.map(fn {session_id, entries} ->
        reparse_count = Enum.count(entries, &(&1.update_type == :reparse))
        enacting_count = Enum.count(entries, &(&1.update_type == :enacting_link))

        session_info =
          case SessionManager.get(session_id) do
            {:ok, session} ->
              %{
                year: session.year,
                month: session.month,
                day_from: session.day_from,
                day_to: session.day_to,
                status: session.status,
                persisted_count: session.persisted_count
              }

            _ ->
              %{
                year: nil,
                month: nil,
                day_from: nil,
                day_to: nil,
                status: nil,
                persisted_count: 0
              }
          end

        Map.merge(session_info, %{
          session_id: session_id,
          pending_count: length(entries),
          reparse_count: reparse_count,
          enacting_count: enacting_count
        })
      end)
      |> Enum.sort_by(& &1.session_id, :desc)

    json(conn, %{sessions: session_stats})
  end

  @doc """
  POST /api/cascade/reparse

  Batch re-parse selected laws.

  Body:
  - ids: List of cascade entry IDs to process (required)
  """
  def reparse(conn, %{"ids" => ids}) when is_list(ids) do
    # Get the entries
    entries =
      ids
      |> Enum.map(fn id ->
        case Ash.get(CascadeAffectedLaw, id) do
          {:ok, entry} -> entry
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Process each entry
    results =
      Enum.map(entries, fn entry ->
        case reparse_law(entry) do
          {:ok, _} ->
            # Mark as processed
            CascadeAffectedLaw.mark_processed!(entry)

            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "success",
              message: "Re-parsed successfully"
            }

          {:error, reason} ->
            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "error",
              message: format_error(reason)
            }
        end
      end)

    success_count = Enum.count(results, &(&1.status == "success"))
    error_count = Enum.count(results, &(&1.status == "error"))

    json(conn, %{
      total: length(results),
      success: success_count,
      errors: error_count,
      results: results
    })
  end

  def reparse(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: ids (array of cascade entry IDs)"})
  end

  @doc """
  POST /api/cascade/update-enacting

  Batch update enacting links for parent laws.

  Body:
  - ids: List of cascade entry IDs to process (required)
  """
  def update_enacting(conn, %{"ids" => ids}) when is_list(ids) do
    # Get the entries
    entries =
      ids
      |> Enum.map(fn id ->
        case Ash.get(CascadeAffectedLaw, id) do
          {:ok, entry} -> entry
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Process each entry
    results =
      Enum.map(entries, fn entry ->
        case update_enacting_for_entry(entry) do
          {:ok, :updated, count} ->
            CascadeAffectedLaw.mark_processed!(entry)

            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "success",
              message: "Added #{count} enacting link(s)"
            }

          {:ok, :unchanged} ->
            CascadeAffectedLaw.mark_processed!(entry)

            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "unchanged",
              message: "Already up to date"
            }

          {:ok, :not_found} ->
            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "skipped",
              message: "Parent law not found in database"
            }

          {:error, reason} ->
            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "error",
              message: format_error(reason)
            }
        end
      end)

    success_count = Enum.count(results, &(&1.status == "success"))
    unchanged_count = Enum.count(results, &(&1.status == "unchanged"))
    error_count = Enum.count(results, &(&1.status == "error"))

    json(conn, %{
      total: length(results),
      success: success_count,
      unchanged: unchanged_count,
      errors: error_count,
      results: results
    })
  end

  def update_enacting(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: ids (array of cascade entry IDs)"})
  end

  @doc """
  POST /api/cascade/add-laws

  Add missing laws to the database by parsing them.

  Body:
  - ids: List of cascade entry IDs for missing laws (required)
  """
  def add_laws(conn, %{"ids" => ids}) when is_list(ids) do
    # Get the entries
    entries =
      ids
      |> Enum.map(fn id ->
        case Ash.get(CascadeAffectedLaw, id) do
          {:ok, entry} -> entry
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Process each entry - parse and add to DB
    results =
      Enum.map(entries, fn entry ->
        case add_law_to_db(entry) do
          {:ok, :created} ->
            CascadeAffectedLaw.mark_processed!(entry)

            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "success",
              message: "Added to database"
            }

          {:ok, :exists} ->
            CascadeAffectedLaw.mark_processed!(entry)

            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "exists",
              message: "Already exists in database"
            }

          {:error, reason} ->
            %{
              id: entry.id,
              affected_law: entry.affected_law,
              status: "error",
              message: format_error(reason)
            }
        end
      end)

    success_count = Enum.count(results, &(&1.status == "success"))
    exists_count = Enum.count(results, &(&1.status == "exists"))
    error_count = Enum.count(results, &(&1.status == "error"))

    json(conn, %{
      total: length(results),
      success: success_count,
      exists: exists_count,
      errors: error_count,
      results: results
    })
  end

  def add_laws(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: ids (array of cascade entry IDs)"})
  end

  @doc """
  DELETE /api/cascade/:id

  Remove a specific cascade entry.
  """
  def delete(conn, %{"id" => id}) do
    case Ash.get(CascadeAffectedLaw, id) do
      {:ok, entry} ->
        case CascadeAffectedLaw.destroy(entry) do
          :ok ->
            json(conn, %{message: "Cascade entry deleted", id: id})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: format_error(reason)})
        end

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Cascade entry not found"})
    end
  end

  @doc """
  DELETE /api/cascade/processed

  Clear all processed cascade entries.

  Query params:
  - session_id: Filter to specific session (optional)
  """
  def clear_processed(conn, params) do
    session_id = params["session_id"]

    # Get processed entries
    entries =
      case session_id do
        nil ->
          CascadeAffectedLaw
          |> Ash.Query.filter(status == :processed)
          |> Ash.read!()

        id ->
          CascadeAffectedLaw.by_session_and_status!(id, :processed)
      end

    # Delete all
    deleted_count =
      Enum.reduce(entries, 0, fn entry, acc ->
        case CascadeAffectedLaw.destroy(entry) do
          :ok -> acc + 1
          _ -> acc
        end
      end)

    json(conn, %{
      message: "Cleared processed entries",
      deleted_count: deleted_count,
      filter: %{session_id: session_id}
    })
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp lookup_existing_laws(names) when is_list(names) do
    if Enum.empty?(names) do
      %{}
    else
      UkLrt
      |> Ash.Query.filter(name in ^names)
      |> Ash.Query.select([:name, :title_en, :year, :type_code, :family, :enacting, :is_enacting])
      |> Ash.read!()
      |> Enum.map(fn law ->
        {law.name,
         %{
           title_en: law.title_en,
           year: law.year,
           type_code: law.type_code,
           family: law.family,
           enacting: law.enacting,
           is_enacting: law.is_enacting
         }}
      end)
      |> Enum.into(%{})
    end
  end

  defp reparse_law(entry) do
    # Build minimal record from law name
    record = build_record_from_name(entry.affected_law)

    case record do
      nil ->
        {:error, "Invalid law name format"}

      record ->
        # Parse using StagedParser (always returns {:ok, result})
        {:ok, result} = StagedParser.parse(record)
        # Persist the result
        LawParser.parse_record(result.record, persist: true)
    end
  end

  defp update_enacting_for_entry(entry) do
    parent_name = entry.affected_law
    source_laws = entry.source_laws || []

    # Look up parent law
    case UkLrt
         |> Ash.Query.filter(name == ^parent_name)
         |> Ash.Query.select([:id, :name, :enacting, :is_enacting])
         |> Ash.read_one() do
      {:ok, nil} ->
        {:ok, :not_found}

      {:ok, parent} ->
        current_enacting = parent.enacting || []
        new_laws = source_laws -- current_enacting

        if Enum.empty?(new_laws) do
          {:ok, :unchanged}
        else
          updated_enacting = current_enacting ++ new_laws

          case Ash.update(parent, %{enacting: updated_enacting, is_enacting: true},
                 action: :update_enacting
               ) do
            {:ok, _} -> {:ok, :updated, length(new_laws)}
            error -> error
          end
        end

      error ->
        error
    end
  end

  defp add_law_to_db(entry) do
    law_name = entry.affected_law

    # Check if already exists (Ash.read_one always returns {:ok, result | nil})
    {:ok, existing} =
      UkLrt
      |> Ash.Query.filter(name == ^law_name)
      |> Ash.read_one()

    if existing do
      {:ok, :exists}
    else
      # Parse and add
      record = build_record_from_name(law_name)

      case record do
        nil ->
          {:error, "Invalid law name format"}

        record ->
          # StagedParser.parse always returns {:ok, result}
          {:ok, result} = StagedParser.parse(record)

          case LawParser.parse_record(result.record, persist: true) do
            {:ok, _} -> {:ok, :created}
            error -> error
          end
      end
    end
  end

  defp build_record_from_name(name) do
    # Parse name like "UK_uksi_2025_622" into record
    case String.split(name, "_") do
      ["UK", type_code, year, number] ->
        %{
          type_code: type_code,
          Year: String.to_integer(year),
          Number: number,
          name: name
        }

      _ ->
        nil
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(%{message: msg}), do: msg
  defp format_error(error), do: inspect(error)

  defp build_source_details(source_laws, source_laws_map) do
    Enum.map(source_laws, fn name ->
      case Map.get(source_laws_map, name) do
        nil -> %{name: name, title_en: nil}
        details -> %{name: name, title_en: details[:title_en]}
      end
    end)
  end
end

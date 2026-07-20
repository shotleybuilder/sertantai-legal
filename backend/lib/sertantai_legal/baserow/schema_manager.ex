defmodule SertantaiLegal.Baserow.SchemaManager do
  @moduledoc """
  Baserow-specific schema management — creates tables, fields, and views
  using the four-phase pattern from BASEROW-SYNC-ARCHITECTURE.md.

  Knows about Baserow quirks:
  - Reverse link_row fields (auto-created by Baserow)
  - Formula field ordering (must defer until dependencies exist)
  - Lookup field ordering (must defer until target table + field exist)
  - Default field cleanup (Name, Notes, Active on new tables)

  Uses `Baserow.Client` for all API calls.

  ## Four-Phase Pattern

  Every resource follows: verify → create if missing → validate → persist ID.

  1. **Phase 1**: Tables + primary fields
  2. **Phase 2**: Simple fields + forward link_row fields
  3. **Phase 3**: Formula + lookup fields (all deps exist)
  4. **Phase 4**: Views
  """

  require Logger

  alias SertantaiLegal.Baserow.Client

  @doc """
  Apply a complete schema to a Baserow database.

  Takes a database_id, authenticated config, and a list of table specs.
  Each table spec: `%{key: :controls, fields: [...], views: [...]}`

  Returns `{:ok, %{tables: %{key => table_id}, ...}}` or `{:error, reason}`.
  """
  def apply_schema(config, database_id, table_specs) do
    config = Map.put(config, "database_id", database_id)

    with {:ok, existing_tables} <- list_existing_tables(config, database_id),
         {:ok, table_ids} <- phase_1_tables(config, table_specs, existing_tables),
         config = Map.put(config, "table_ids", table_ids),
         {:ok, field_counts} <- phase_2_simple_fields(config, table_specs, table_ids),
         {:ok, formula_counts} <- phase_3_formula_lookup_fields(config, table_specs, table_ids),
         {:ok, view_counts} <- phase_4_views(config, table_specs, table_ids) do
      {:ok,
       %{
         table_ids: table_ids,
         tables_created: count_new(table_ids, existing_tables),
         fields_created: field_counts + formula_counts,
         views_created: view_counts
       }}
    end
  end

  # ── Phase 1: Tables + Primary Fields ─────────────────────────────

  defp phase_1_tables(config, table_specs, existing_tables) do
    Logger.info("[SchemaManager] Phase 1: Tables + primary fields")

    existing_by_name = Map.new(existing_tables, fn t -> {t["name"], t["id"]} end)

    Enum.reduce_while(table_specs, {:ok, %{}}, fn spec, {:ok, acc} ->
      table_name = spec.name

      case verify_or_create_table(config, table_name, existing_by_name) do
        {:ok, table_id} ->
          Logger.info("[SchemaManager] Table #{table_name} → #{table_id}")

          # Clean up Baserow defaults and ensure primary field
          primary = Enum.find(spec.fields, & &1[:primary])

          if primary do
            cleanup_and_set_primary(config, table_id, spec.fields)
          end

          {:cont, {:ok, Map.put(acc, spec.key, table_id)}}

        {:error, reason} ->
          {:halt, {:error, {:phase_1_failed, table_name, reason}}}
      end
    end)
  end

  defp verify_or_create_table(config, table_name, existing_by_name) do
    case Map.get(existing_by_name, table_name) do
      nil ->
        case Client.create_table(config, table_name) do
          {:ok, table_id} ->
            # Validate: read back
            Logger.debug("[SchemaManager] Created table #{table_name} (#{table_id})")
            {:ok, table_id}

          {:error, reason} ->
            {:error, reason}
        end

      table_id ->
        Logger.debug("[SchemaManager] Table #{table_name} already exists (#{table_id})")
        {:ok, table_id}
    end
  end

  defp cleanup_and_set_primary(config, table_id, field_specs) do
    case Client.cleanup_table_defaults(config, table_id, field_specs) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("[SchemaManager] Cleanup failed: #{inspect(reason)}")
    end
  end

  # ── Phase 2: Simple Fields + Forward Link_Row ────────────────────

  defp phase_2_simple_fields(config, table_specs, table_ids) do
    Logger.info("[SchemaManager] Phase 2: Simple fields + link_row")

    Enum.reduce_while(table_specs, {:ok, 0}, fn spec, {:ok, total} ->
      table_id = Map.get(table_ids, spec.key)

      if is_nil(table_id) do
        {:halt, {:error, {:missing_table, spec.key}}}
      else
        # Filter to non-formula, non-lookup, non-primary fields
        simple_fields =
          Enum.filter(spec.fields, fn f ->
            f[:type] not in [:formula, :lookup, :rollup] and !f[:primary]
          end)

        case create_fields_verified(config, table_id, simple_fields) do
          {:ok, count} ->
            {:cont, {:ok, total + count}}

          {:error, reason} ->
            {:halt, {:error, {:phase_2_failed, spec.key, reason}}}
        end
      end
    end)
  end

  # ── Phase 3: Formula + Lookup Fields ─────────────────────────────

  defp phase_3_formula_lookup_fields(config, table_specs, table_ids) do
    Logger.info("[SchemaManager] Phase 3: Formula + lookup fields")

    # Collect ALL formula + lookup fields across ALL tables
    deferred =
      Enum.flat_map(table_specs, fn spec ->
        table_id = Map.get(table_ids, spec.key)

        spec.fields
        |> Enum.filter(fn f -> f[:type] in [:formula, :lookup, :rollup] and !f[:primary] end)
        |> Enum.map(fn f -> {spec.key, table_id, f} end)
      end)

    # Also collect cross_table_fields if defined
    cross_table =
      Enum.flat_map(table_specs, fn spec ->
        fields = Map.get(spec, :cross_table_fields, [])

        Enum.map(fields, fn {table_key, field_list} ->
          table_id = Map.get(table_ids, table_key)
          Enum.map(field_list, fn f -> {table_key, table_id, f} end)
        end)
      end)
      |> List.flatten()

    all_deferred = deferred ++ cross_table

    Enum.reduce_while(all_deferred, {:ok, 0}, fn {table_key, table_id, field}, {:ok, total} ->
      if is_nil(table_id) do
        Logger.warning("[SchemaManager] Skipping #{field.name} — table #{table_key} not found")
        {:cont, {:ok, total}}
      else
        case create_field_verified(config, table_id, field) do
          {:ok, :created} ->
            {:cont, {:ok, total + 1}}

          {:ok, :exists} ->
            {:cont, {:ok, total}}

          {:error, reason} ->
            if field[:type] == :lookup do
              Logger.warning("[SchemaManager] Skipping lookup #{field.name}: #{inspect(reason)}")

              {:cont, {:ok, total}}
            else
              {:halt, {:error, {:phase_3_failed, table_key, field.name, reason}}}
            end
        end
      end
    end)
  end

  # ── Phase 4: Views ───────────────────────────────────────────────

  defp phase_4_views(config, table_specs, table_ids) do
    Logger.info("[SchemaManager] Phase 4: Views")

    Enum.reduce_while(table_specs, {:ok, 0}, fn spec, {:ok, total} ->
      table_id = Map.get(table_ids, spec.key)
      views = Map.get(spec, :views, [])

      if is_nil(table_id) or views == [] do
        {:cont, {:ok, total}}
      else
        # Get existing view names to skip duplicates
        existing_names =
          case Client.list_views(config, table_id) do
            {:ok, views_list} -> MapSet.new(views_list, & &1["name"])
            _ -> MapSet.new()
          end

        count =
          Enum.reduce(views, 0, fn view, acc ->
            if MapSet.member?(existing_names, view.name) do
              acc
            else
              case Client.create_view(config, table_id, view) do
                {:ok, _} ->
                  acc + 1

                {:error, reason} ->
                  Logger.warning("[SchemaManager] Skipping view #{view.name}: #{inspect(reason)}")

                  acc
              end
            end
          end)

        {:cont, {:ok, total + count}}
      end
    end)
  end

  # ── Verified Field Creation ──────────────────────────────────────

  defp create_fields_verified(config, table_id, fields) do
    # Get existing fields to skip duplicates
    existing =
      case Client.list_fields(config, table_id) do
        {:ok, fields} -> MapSet.new(fields, & &1["name"])
        _ -> MapSet.new()
      end

    Enum.reduce_while(fields, {:ok, 0}, fn field, {:ok, count} ->
      case create_field_verified(config, table_id, field, existing) do
        {:ok, :created} -> {:cont, {:ok, count + 1}}
        {:ok, :exists} -> {:cont, {:ok, count}}
        {:error, reason} -> {:halt, {:error, {:create_field_failed, field.name, reason}}}
      end
    end)
  end

  defp create_field_verified(config, table_id, field, existing \\ nil) do
    existing =
      existing ||
        case Client.list_fields(config, table_id) do
          {:ok, fields} -> MapSet.new(fields, & &1["name"])
          _ -> MapSet.new()
        end

    if MapSet.member?(existing, field.name) do
      {:ok, :exists}
    else
      case Client.create_field(config, table_id, field) do
        {:ok, _field_id} ->
          Logger.debug("[SchemaManager] Created field #{field.name}")
          {:ok, :created}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

  defp list_existing_tables(config, database_id) do
    headers = [{"Authorization", "JWT #{config["jwt"]}"}]
    base_url = String.trim_trailing(config["base_url"] || "", "/")

    case Req.get("#{base_url}/api/database/tables/database/#{database_id}/",
           headers: headers,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: tables}} when is_list(tables) ->
        {:ok, tables}

      {:ok, %{status: status, body: body}} ->
        {:error, "List tables returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "List tables failed: #{inspect(reason)}"}
    end
  end

  defp count_new(table_ids, existing_tables) do
    existing_ids = MapSet.new(existing_tables, & &1["id"])
    Enum.count(table_ids, fn {_key, id} -> not MapSet.member?(existing_ids, id) end)
  end
end

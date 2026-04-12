#!/usr/bin/env elixir

# Export delta SQL for dev→prod promotion
#
# Usage:
#   cd backend && mix run ../scripts/sync/export_delta.exs [options]
#
# Options:
#   --since TIMESTAMP    Export rows changed after this timestamp (ISO 8601)
#   --tables t1,t2       Only export specific tables (comma-separated)
#   --limit N            Limit rows per table (for testing)
#   --dry-run            Show counts only, don't write files
#   --output-dir DIR     Output directory (default: ../scripts/sync/)
#
# Examples:
#   mix run ../scripts/sync/export_delta.exs --since "2026-04-01T00:00:00Z"
#   mix run ../scripts/sync/export_delta.exs --dry-run --limit 10
#   mix run ../scripts/sync/export_delta.exs --tables uk_lrt,lat --since "2026-03-01"

defmodule DeltaSync.Config do
  @moduledoc "Table configuration for delta sync."

  # Columns that exist only in dev (not in prod) — exclude from delta export.
  # Update this list as prod catches up with migrations.
  @dev_only_columns %{
    "uk_lrt" => [],
    "lat" => [],
    "amendment_annotations" => [],
    "scrape_sessions" => [],
    "scrape_session_records" => [],
    "cascade_affected_laws" => []
  }

  # Columns auto-populated by triggers or GENERATED ALWAYS — never write
  @generated_columns %{
    "uk_lrt" => [
      "number_int",
      "leg_gov_uk_url",
      "has_fitness",
      "md_date_year",
      "md_date_month",
      "lat_count",
      "latest_lat_updated_at"
    ],
    "lat" => [],
    "amendment_annotations" => [],
    "scrape_sessions" => [],
    "scrape_session_records" => [],
    "cascade_affected_laws" => []
  }

  @tables [
    %{
      name: "uk_lrt",
      resource: SertantaiLegal.Legal.UkLrt,
      pk: "id",
      timestamp_col: "updated_at",
      order: 1
    },
    %{
      name: "lat",
      resource: SertantaiLegal.Legal.Lat,
      pk: "section_id",
      timestamp_col: "updated_at",
      order: 2
    },
    %{
      name: "amendment_annotations",
      resource: SertantaiLegal.Legal.AmendmentAnnotation,
      pk: "id",
      timestamp_col: "updated_at",
      order: 3
    },
    %{
      name: "scrape_sessions",
      resource: SertantaiLegal.Scraper.ScrapeSession,
      pk: "id",
      timestamp_col: "updated_at",
      order: 4
    },
    %{
      name: "scrape_session_records",
      resource: SertantaiLegal.Scraper.ScrapeSessionRecord,
      pk: "id",
      timestamp_col: "updated_at",
      order: 5
    },
    %{
      name: "cascade_affected_laws",
      resource: SertantaiLegal.Scraper.CascadeAffectedLaw,
      pk: "id",
      timestamp_col: "updated_at",
      order: 6
    }
  ]

  def tables, do: @tables |> Enum.sort_by(& &1.order)

  def excluded_columns(table_name) do
    dev_only = Map.get(@dev_only_columns, table_name, [])
    generated = Map.get(@generated_columns, table_name, [])
    dev_only ++ generated
  end
end

defmodule DeltaSync.ColumnMapper do
  @moduledoc "Discovers Elixir attribute → Postgres column mappings from Ash resources."

  def writable_columns(resource, excluded) do
    pk_names =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(& &1.primary_key?)
      |> Enum.map(& &1.name)
      |> MapSet.new()

    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reject(fn attr ->
      pg_name = postgres_column_name(resource, attr)
      # Always include PK columns (even if writable? is false)
      # Skip non-writable (generated/trigger-maintained) or explicitly excluded columns
      !MapSet.member?(pk_names, attr.name) && (!attr.writable? || pg_name in excluded)
    end)
    |> Enum.map(fn attr ->
      %{
        elixir_name: attr.name,
        pg_name: postgres_column_name(resource, attr),
        type: attr.type
      }
    end)
  end

  def postgres_column_name(_resource, attr) do
    # The source: option on the attribute holds the actual Postgres column name
    # (e.g., emoji-prefixed stats columns). Falls back to the Elixir attribute name.
    to_string(attr.source || attr.name)
  end
end

defmodule DeltaSync.SqlGenerator do
  @moduledoc "Generates INSERT ... ON CONFLICT DO UPDATE SQL statements."

  def generate_upsert(table_name, pk_col, columns, row) do
    col_names = Enum.map(columns, fn c -> quote_ident(c.pg_name) end)
    values = Enum.map(columns, fn c -> escape_value(Map.get(row, c.pg_name), c.type) end)

    update_cols =
      columns
      |> Enum.reject(fn c -> c.pg_name == pk_col end)
      |> Enum.map(fn c -> "#{quote_ident(c.pg_name)} = EXCLUDED.#{quote_ident(c.pg_name)}" end)

    """
    INSERT INTO #{quote_ident(table_name)} (#{Enum.join(col_names, ", ")})
    VALUES (#{Enum.join(values, ", ")})
    ON CONFLICT (#{quote_ident(pk_col)}) DO UPDATE SET
      #{Enum.join(update_cols, ",\n      ")};
    """
  end

  def quote_ident(name), do: ~s("#{name}")

  def escape_value(nil, _type), do: "NULL"

  # Maps and JSONB — handle Ash.Type.Map and plain :map
  def escape_value(value, _type) when is_map(value) and not is_struct(value) do
    json = Jason.encode!(value)
    "'#{escape_string(json)}'::jsonb"
  end

  # Arrays of maps/JSONB — build ARRAY[elem::jsonb, ...] literal
  def escape_value(value, {:array, inner})
      when is_list(value) and inner in [:map, Ash.Type.Map] do
    if value == [] do
      "'{}'"
    else
      elements =
        Enum.map(value, fn elem ->
          json = Jason.encode!(elem)
          "'#{escape_string(json)}'::jsonb"
        end)

      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # Arrays of strings
  def escape_value(value, {:array, inner})
      when is_list(value) and inner in [:string, Ash.Type.String] do
    if value == [] do
      "'{}'"
    else
      elements = Enum.map(value, fn v -> "'#{escape_string(to_string(v))}'" end)
      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # Arrays of other types
  def escape_value(value, {:array, _inner}) when is_list(value) do
    if value == [] do
      "'{}'"
    else
      elements =
        Enum.map(value, fn
          v when is_binary(v) -> "'#{escape_string(v)}'"
          v when is_integer(v) -> to_string(v)
          v when is_map(v) -> "'#{escape_string(Jason.encode!(v))}'"
          v -> to_string(v)
        end)

      "ARRAY[#{Enum.join(elements, ", ")}]"
    end
  end

  # UUID binary (16 bytes from Postgrex) — only when type is :uuid or Ash.Type.UUID
  def escape_value(<<_::128>> = value, type) when type in [:uuid, Ash.Type.UUID] do
    "'#{format_uuid(value)}'"
  end

  # Scalars — booleans before atoms (false/true are atoms)
  def escape_value(value, _type) when is_boolean(value), do: to_string(value)

  # Atoms (Ash enums stored as strings in Postgres)
  def escape_value(value, _type) when is_atom(value) and not is_nil(value) do
    "'#{escape_string(to_string(value))}'"
  end

  def escape_value(value, _type) when is_binary(value), do: "'#{escape_string(value)}'"
  def escape_value(value, _type) when is_integer(value), do: to_string(value)
  def escape_value(value, _type) when is_float(value), do: to_string(value)

  # Dates/times
  def escape_value(%DateTime{} = dt, _type), do: "'#{DateTime.to_iso8601(dt)}'::timestamptz"

  def escape_value(%NaiveDateTime{} = dt, _type),
    do: "'#{NaiveDateTime.to_iso8601(dt)}'::timestamp"

  def escape_value(%Date{} = d, _type), do: "'#{Date.to_iso8601(d)}'::date"

  # Decimal
  def escape_value(%Decimal{} = d, _type), do: Decimal.to_string(d)

  # Catch-all for unexpected types — JSON encode
  def escape_value(value, _type) do
    json = Jason.encode!(value)
    "'#{escape_string(json)}'::jsonb"
  end

  defp escape_string(str), do: String.replace(str, "'", "''")

  defp format_uuid(<<a::32, b::16, c::16, d::16, e::48>>) do
    # Fixed widths per UUID spec: 8-4-4-4-12
    [{a, 8}, {b, 4}, {c, 4}, {d, 4}, {e, 12}]
    |> Enum.map_join("-", fn {part, width} ->
      Integer.to_string(part, 16) |> String.pad_leading(width, "0") |> String.downcase()
    end)
  end
end

defmodule DeltaSync.Export do
  @moduledoc "Main export logic."

  alias DeltaSync.{Config, ColumnMapper, SqlGenerator}

  @script_dir Path.dirname(__ENV__.file)
  @watermark_file Path.join(@script_dir, "last_sync.json")

  def run(opts) do
    since = Keyword.get(opts, :since)
    tables_filter = Keyword.get(opts, :tables)
    limit = Keyword.get(opts, :limit)
    dry_run = Keyword.get(opts, :dry_run, false)
    output_dir = Keyword.get(opts, :output_dir, @script_dir)

    watermarks = load_watermarks()

    tables =
      Config.tables()
      |> maybe_filter_tables(tables_filter)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Delta Export — dev → prod")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Tables: #{Enum.map(tables, & &1.name) |> Enum.join(", ")}")
    IO.puts("  Limit: #{if limit, do: limit, else: "none"}")
    IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")

    if since do
      IO.puts("  Since: #{since} (from --since flag)")
    else
      IO.puts("  Since: per-table watermarks from last_sync.json")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    # Process each table
    results =
      Enum.map(tables, fn table ->
        table_since = since || Map.get(watermarks, table.name)
        process_table(table, table_since, limit)
      end)

    total_rows = Enum.sum(Enum.map(results, fn {_, count, _, _} -> count end))

    if total_rows == 0 do
      IO.puts("  No changes found. Nothing to export.\n")
      :ok
    else
      IO.puts("\n  ── Summary ──────────────────────────────────")

      Enum.each(results, fn {table_name, count, _sql, _max_ts} ->
        IO.puts("  #{String.pad_trailing(table_name, 30)} #{count} rows")
      end)

      IO.puts("  #{String.pad_trailing("TOTAL", 30)} #{total_rows} rows")

      if dry_run do
        IO.puts("\n  DRY RUN — no files written.\n")
      else
        write_delta(results, output_dir, watermarks, since)
      end
    end
  end

  defp process_table(table, since, limit) do
    excluded = Config.excluded_columns(table.name)
    columns = ColumnMapper.writable_columns(table.resource, excluded)

    col_names = Enum.map(columns, fn c -> ~s("#{c.pg_name}") end) |> Enum.join(", ")

    {where_clause, params} =
      if since do
        {"WHERE \"#{table.timestamp_col}\" > $1", [parse_timestamp(since)]}
      else
        {"", []}
      end

    limit_clause = if limit, do: "LIMIT #{limit}", else: ""

    query = """
    SELECT #{col_names}
    FROM "#{table.name}"
    #{where_clause}
    ORDER BY "#{table.timestamp_col}" ASC
    #{limit_clause}
    """

    %{rows: rows, columns: result_columns} =
      Ecto.Adapters.SQL.query!(SertantaiLegal.Repo, query, params)

    # Build row maps keyed by postgres column name
    row_maps =
      Enum.map(rows, fn row ->
        Enum.zip(result_columns, row) |> Map.new()
      end)

    # Generate SQL
    sql =
      if Enum.empty?(row_maps) do
        ""
      else
        statements =
          Enum.map(row_maps, fn row ->
            SqlGenerator.generate_upsert(table.name, table.pk, columns, row)
          end)

        Enum.join(statements, "\n")
      end

    # Track max timestamp for watermark update
    max_ts =
      if Enum.empty?(row_maps) do
        nil
      else
        row_maps
        |> Enum.map(fn row -> Map.get(row, table.timestamp_col) end)
        |> Enum.reject(&is_nil/1)
        |> Enum.max(DateTime, fn -> nil end)
      end

    count = length(row_maps)

    if count > 0 do
      IO.puts(
        "  [#{table.name}] #{count} rows changed#{if since, do: " since #{since}", else: ""}"
      )
    else
      IO.puts("  [#{table.name}] no changes")
    end

    {table.name, count, sql, max_ts}
  end

  defp write_delta(results, output_dir, old_watermarks, explicit_since) do
    now = DateTime.utc_now()
    timestamp = now |> DateTime.to_iso8601() |> String.replace(":", "-") |> String.slice(0, 19)
    sql_filename = "delta_#{timestamp}.sql"
    manifest_filename = "delta_#{timestamp}_manifest.json"
    sql_path = Path.join(output_dir, sql_filename)
    manifest_path = Path.join(output_dir, manifest_filename)

    # Build SQL file
    header = """
    -- Delta Export: dev → prod
    -- Generated: #{DateTime.to_iso8601(now)}
    -- Source: sertantai_legal_dev
    --
    -- This file is idempotent (INSERT ... ON CONFLICT DO UPDATE).
    -- Apply with: TARGET_DATABASE_URL=... mix run ../scripts/sync/apply_delta.exs #{sql_filename}

    BEGIN;

    """

    table_sections =
      results
      |> Enum.filter(fn {_, count, _, _} -> count > 0 end)
      |> Enum.map(fn {table_name, count, sql, _max_ts} ->
        """
        -- ══════════════════════════════════════════════════
        -- #{table_name} (#{count} rows)
        -- ══════════════════════════════════════════════════

        #{sql}
        """
      end)

    footer = "\nCOMMIT;\n"

    full_sql = header <> Enum.join(table_sections, "\n") <> footer
    File.write!(sql_path, full_sql)

    # SHA256 checksum
    sha256 = :crypto.hash(:sha256, full_sql) |> Base.encode16(case: :lower)

    # Build manifest
    new_watermarks =
      Enum.reduce(results, old_watermarks || %{}, fn {table_name, _count, _sql, max_ts}, acc ->
        if max_ts do
          ts_str =
            case max_ts do
              %DateTime{} -> DateTime.to_iso8601(max_ts)
              other -> to_string(other)
            end

          Map.put(acc, table_name, ts_str)
        else
          acc
        end
      end)

    manifest = %{
      exported_at: DateTime.to_iso8601(now),
      source_db: "sertantai_legal_dev",
      watermark_used:
        Enum.into(results, %{}, fn {table_name, _, _, _} ->
          used = explicit_since || Map.get(old_watermarks || %{}, table_name, "epoch")
          {table_name, used}
        end),
      tables:
        Enum.into(results, %{}, fn {table_name, count, _sql, max_ts} ->
          {table_name,
           %{
             rows: count,
             max_updated_at:
               if(max_ts,
                 do:
                   case max_ts do
                     %DateTime{} -> DateTime.to_iso8601(max_ts)
                     other -> to_string(other)
                   end,
                 else: nil
               )
           }}
        end),
      total_rows: Enum.sum(Enum.map(results, fn {_, count, _, _} -> count end)),
      sql_file: sql_filename,
      sha256: sha256
    }

    File.write!(manifest_path, Jason.encode!(manifest, pretty: true))

    # Update watermark file
    watermark_data = %{
      last_export_at: DateTime.to_iso8601(now),
      watermarks: new_watermarks,
      last_delta_file: sql_filename
    }

    File.write!(@watermark_file, Jason.encode!(watermark_data, pretty: true))

    IO.puts("\n  ── Files Written ────────────────────────────")
    IO.puts("  SQL:      #{sql_path}")
    IO.puts("  Manifest: #{manifest_path}")
    IO.puts("  SHA256:   #{sha256}")
    IO.puts("  Watermarks updated in last_sync.json\n")
  end

  defp load_watermarks do
    if File.exists?(@watermark_file) do
      @watermark_file
      |> File.read!()
      |> Jason.decode!()
      |> Map.get("watermarks", %{})
    else
      %{}
    end
  end

  defp maybe_filter_tables(tables, nil), do: tables

  defp maybe_filter_tables(tables, filter) do
    names = String.split(filter, ",") |> Enum.map(&String.trim/1)
    Enum.filter(tables, fn t -> t.name in names end)
  end

  defp parse_timestamp(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _offset} ->
        dt

      {:error, _} ->
        # Try NaiveDateTime and assume UTC
        case NaiveDateTime.from_iso8601(ts) do
          {:ok, ndt} ->
            DateTime.from_naive!(ndt, "Etc/UTC")

          {:error, _} ->
            IO.puts("  ERROR: Cannot parse timestamp: #{ts}")
            System.halt(1)
        end
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
end

# ── CLI Entry Point ──────────────────────────────────────────────────

args = System.argv()

{opts, _rest} =
  OptionParser.parse!(args,
    strict: [
      since: :string,
      tables: :string,
      limit: :integer,
      dry_run: :boolean,
      output_dir: :string
    ],
    aliases: [s: :since, t: :tables, n: :limit, d: :dry_run]
  )

DeltaSync.Export.run(opts)

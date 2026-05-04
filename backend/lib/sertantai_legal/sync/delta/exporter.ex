defmodule SertantaiLegal.Sync.Delta.Exporter do
  @moduledoc """
  Exports differential SQL from dev DB for promotion to prod.

  Core logic extracted from scripts/sync/export_delta.exs.
  Called by Mix.Tasks.Data.ExportDelta.
  """

  alias SertantaiLegal.Sync.Delta.{Config, ColumnMapper, SqlGenerator}

  defp default_output_dir do
    # Mix tasks run from backend/ — scripts/sync/ is one level up
    Path.expand("../scripts/sync")
  end

  defp watermark_file, do: Path.join(default_output_dir(), "last_sync.json")

  @doc """
  Run the delta export with IO output (for Mix task / CLI use).
  """
  def run(opts) do
    since = Keyword.get(opts, :since)
    tables_filter = Keyword.get(opts, :tables)
    limit = Keyword.get(opts, :limit)
    dry_run = Keyword.get(opts, :dry_run, false)
    output_dir = Keyword.get(opts, :output_dir, default_output_dir())

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

  @doc """
  Export delta and return structured results (for API / controller use).

  Returns `{:ok, result_map}` on success or `{:ok, :no_changes}` if nothing to export.
  """
  def export(opts \\ []) do
    output_dir = Keyword.get(opts, :output_dir, default_output_dir())
    watermarks = load_watermarks()
    tables = Config.tables()

    results =
      Enum.map(tables, fn table ->
        table_since = Map.get(watermarks, table.name)
        process_table(table, table_since, nil)
      end)

    total_rows = Enum.sum(Enum.map(results, fn {_, count, _, _} -> count end))

    if total_rows == 0 do
      {:ok, :no_changes}
    else
      write_delta(results, output_dir, watermarks, nil)

      watermark_data = read_watermark_file()

      table_summary =
        Enum.map(results, fn {table_name, count, _sql, max_ts} ->
          %{
            name: table_name,
            rows: count,
            max_updated_at: format_ts(max_ts)
          }
        end)

      {:ok,
       %{
         tables: table_summary,
         total_rows: total_rows,
         delta_file: Map.get(watermark_data, "last_delta_file"),
         exported_at: Map.get(watermark_data, "last_export_at")
       }}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp read_watermark_file do
    wf = watermark_file()

    case File.read(wf) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  defp format_ts(nil), do: nil
  defp format_ts(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_ts(other), do: to_string(other)

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

    row_maps =
      Enum.map(rows, fn row ->
        Enum.zip(result_columns, row) |> Map.new()
      end)

    sql =
      if Enum.empty?(row_maps) do
        ""
      else
        row_maps
        |> Enum.map(fn row ->
          SqlGenerator.generate_upsert(table.name, table.pk, columns, row)
        end)
        |> Enum.join("\n")
      end

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

    header = """
    -- Delta Export: dev → prod
    -- Generated: #{DateTime.to_iso8601(now)}
    -- Source: sertantai_legal_dev
    --
    -- This file is idempotent (INSERT ... ON CONFLICT DO UPDATE).
    -- Apply with: TARGET_DATABASE_URL=... mix data.apply_delta #{sql_filename}

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

    sha256 = :crypto.hash(:sha256, full_sql) |> Base.encode16(case: :lower)

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

    watermark_data = %{
      last_export_at: DateTime.to_iso8601(now),
      watermarks: new_watermarks,
      last_delta_file: sql_filename
    }

    File.write!(watermark_file(), Jason.encode!(watermark_data, pretty: true))

    IO.puts("\n  ── Files Written ────────────────────────────")
    IO.puts("  SQL:      #{sql_path}")
    IO.puts("  Manifest: #{manifest_path}")
    IO.puts("  SHA256:   #{sha256}")
    IO.puts("  Watermarks updated in last_sync.json\n")
  end

  defp load_watermarks do
    wf = watermark_file()

    if File.exists?(wf) do
      wf
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
        case NaiveDateTime.from_iso8601(ts) do
          {:ok, ndt} ->
            DateTime.from_naive!(ndt, "Etc/UTC")

          {:error, _} ->
            Mix.raise("Cannot parse timestamp: #{ts}")
        end
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
end

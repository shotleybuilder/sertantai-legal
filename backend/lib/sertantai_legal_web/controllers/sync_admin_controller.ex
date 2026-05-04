defmodule SertantaiLegalWeb.SyncAdminController do
  @moduledoc """
  Admin endpoint for data sync pipeline visibility.

  Returns dev DB stats, NAS snapshot info, watermarks, and pending delta
  counts so the admin can assess staleness before promoting data.
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.Delta.Config

  @nas_manifest_path "/mnt/nas/sertantai-data/data/snapshots/latest/manifest.json"

  defp watermark_path, do: Path.expand("../scripts/sync/last_sync.json")

  def status(conn, _params) do
    tables = Config.tables()

    # Gather data in parallel
    dev_task = Task.async(fn -> fetch_dev_stats(tables) end)
    nas_task = Task.async(fn -> read_nas_manifest() end)
    watermark_task = Task.async(fn -> read_watermarks() end)

    dev_stats = Task.await(dev_task)
    nas_manifest = Task.await(nas_task)
    watermark_data = Task.await(watermark_task)

    watermarks = Map.get(watermark_data, "watermarks", %{})

    # Pending row counts (rows changed since last watermark)
    pending_counts = fetch_pending_counts(tables, watermarks)

    nas_tables = get_in(nas_manifest, ["tables"]) || %{}
    nas_date = get_in(nas_manifest, ["date"])

    table_rows =
      Enum.map(tables, fn table ->
        dev = Map.get(dev_stats, table.name, %{count: 0, max_updated_at: nil})
        nas_entry = Map.get(nas_tables, table.name, %{})
        pending = Map.get(pending_counts, table.name, 0)

        %{
          name: table.name,
          dev: %{
            count: dev.count,
            max_updated_at: format_timestamp(dev.max_updated_at)
          },
          nas: %{
            count: nas_entry["rows"],
            snapshot_date: nas_date
          },
          watermark: Map.get(watermarks, table.name),
          pending_rows: pending
        }
      end)

    json(conn, %{
      tables: table_rows,
      nas_snapshot: %{
        date: nas_date,
        available: nas_manifest != nil
      },
      last_export: %{
        at: Map.get(watermark_data, "last_export_at"),
        delta_file: Map.get(watermark_data, "last_delta_file")
      }
    })
  end

  defp fetch_dev_stats(tables) do
    tables
    |> Enum.map(fn table ->
      sql = """
      SELECT COUNT(*)::bigint, MAX("#{table.timestamp_col}")
      FROM "#{table.name}"
      """

      {table.name, Task.async(fn -> Repo.query!(sql) end)}
    end)
    |> Enum.into(%{}, fn {name, task} ->
      %{rows: [[count, max_ts]]} = Task.await(task)
      {name, %{count: count, max_updated_at: max_ts}}
    end)
  end

  defp fetch_pending_counts(tables, watermarks) do
    tables
    |> Enum.map(fn table ->
      watermark = Map.get(watermarks, table.name)

      {sql, params} =
        if watermark do
          ts =
            case DateTime.from_iso8601(watermark) do
              {:ok, dt, _} -> dt
              _ -> ~U[1970-01-01 00:00:00Z]
            end

          {"SELECT COUNT(*)::bigint FROM \"#{table.name}\" WHERE \"#{table.timestamp_col}\" > $1",
           [ts]}
        else
          {"SELECT COUNT(*)::bigint FROM \"#{table.name}\"", []}
        end

      {table.name, Task.async(fn -> Repo.query!(sql, params) end)}
    end)
    |> Enum.into(%{}, fn {name, task} ->
      %{rows: [[count]]} = Task.await(task)
      {name, count}
    end)
  end

  defp read_nas_manifest do
    case File.read(@nas_manifest_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp read_watermarks do
    path = watermark_path()

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          _ -> %{}
        end

      _ ->
        %{}
    end
  end

  @doc """
  POST /api/sync/snapshot-export

  Runs scripts/nas/export-snapshot.sh --archive and returns the output.
  """
  def snapshot_export(conn, _params) do
    script = Path.expand("../scripts/nas/export-snapshot.sh")

    unless File.exists?(script) do
      conn |> put_status(500) |> json(%{error: "Script not found: #{script}"})
    else
      case System.cmd("bash", [script, "--archive"],
             stderr_to_stdout: true,
             env: [{"PGPASSWORD", "postgres"}]
           ) do
        {output, 0} ->
          json(conn, %{ok: true, output: output})

        {output, code} ->
          conn |> put_status(500) |> json(%{error: "Exit code #{code}", output: output})
      end
    end
  end

  @doc """
  POST /api/sync/delta-export

  Runs the delta export and returns a structured summary.
  """
  def delta_export(conn, _params) do
    case SertantaiLegal.Sync.Delta.Exporter.export() do
      {:ok, :no_changes} ->
        json(conn, %{ok: true, no_changes: true, message: "No pending changes to export."})

      {:ok, result} ->
        json(conn, %{ok: true, no_changes: false} |> Map.merge(result))

      {:error, message} ->
        conn |> put_status(500) |> json(%{error: message})
    end
  end

  defp format_timestamp(nil), do: nil
  defp format_timestamp(%NaiveDateTime{} = ts), do: NaiveDateTime.to_iso8601(ts)
  defp format_timestamp(%DateTime{} = ts), do: DateTime.to_iso8601(ts)
  defp format_timestamp(other), do: to_string(other)
end

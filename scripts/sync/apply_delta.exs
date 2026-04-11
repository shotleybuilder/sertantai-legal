#!/usr/bin/env elixir

# Apply a delta SQL file to a target database.
#
# Usage:
#   cd backend
#   TARGET_DATABASE_URL=postgresql://... mix run ../scripts/sync/apply_delta.exs <sql_file> [options]
#
# Options:
#   --confirm       Skip interactive confirmation prompt
#   --dry-run       Validate file and manifest only, don't execute SQL
#
# Examples:
#   # Test against local throwaway DB
#   TARGET_DATABASE_URL=postgresql://postgres:postgres@localhost:5436/sertantai_legal_sync_test \
#     mix run ../scripts/sync/apply_delta.exs delta_2026-04-11.sql
#
#   # Prod via SSH tunnel (user sets up tunnel first)
#   TARGET_DATABASE_URL=postgresql://postgres:PWD@localhost:5437/sertantai_legal_prod \
#     mix run ../scripts/sync/apply_delta.exs delta_2026-04-11.sql --confirm
#
# Safety:
#   - Refuses to run against dev DB (checks for _dev suffix or port 5436)
#   - SHA256 checksum verification against manifest
#   - Interactive confirmation with summary (unless --confirm)
#   - SQL is already transaction-wrapped (BEGIN/COMMIT)

defmodule DeltaSync.Apply do
  @script_dir Path.dirname(__ENV__.file)

  def run(sql_file, opts) do
    confirm = Keyword.get(opts, :confirm, false)
    dry_run = Keyword.get(opts, :dry_run, false)

    # Resolve SQL file path
    sql_path = resolve_path(sql_file)

    unless File.exists?(sql_path) do
      IO.puts("ERROR: SQL file not found: #{sql_path}")
      System.halt(1)
    end

    # Read and validate SQL
    sql = File.read!(sql_path)
    manifest = load_manifest(sql_path)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Delta Apply — SQL → target DB")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  File: #{Path.basename(sql_path)}")
    IO.puts("  Size: #{byte_size(sql)} bytes")
    IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")

    # Verify checksum
    if manifest do
      verify_checksum!(sql, manifest)
      IO.puts("  Checksum: verified")
      print_manifest_summary(manifest)
    else
      IO.puts("  Checksum: no manifest found (skipping)")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if dry_run do
      IO.puts("\n  DRY RUN — file validated, no SQL executed.\n")
      :ok
    else
      # Get and validate target DB
      target_url = get_target_url!()
      validate_target!(target_url)

      IO.puts("  Target: #{redact_url(target_url)}")

      # Confirm unless --confirm flag
      unless confirm do
        IO.write("\n  Apply this delta? [y/N] ")
        response = IO.read(:stdio, :line) |> String.trim() |> String.downcase()

        unless response in ["y", "yes"] do
          IO.puts("  Aborted.\n")
          System.halt(0)
        end
      end

      # Connect and execute
      IO.puts("\n  Connecting to target database...")
      apply_sql!(target_url, sql)
    end
  end

  defp resolve_path(file) do
    cond do
      Path.type(file) == :absolute -> file
      File.exists?(file) -> Path.expand(file)
      File.exists?(Path.join(@script_dir, file)) -> Path.join(@script_dir, file)
      true -> Path.expand(file)
    end
  end

  defp load_manifest(sql_path) do
    manifest_path = String.replace(sql_path, ~r/\.sql$/, "_manifest.json")

    if File.exists?(manifest_path) do
      manifest_path |> File.read!() |> Jason.decode!()
    else
      nil
    end
  end

  defp verify_checksum!(sql, manifest) do
    expected = manifest["sha256"]

    if expected do
      actual = :crypto.hash(:sha256, sql) |> Base.encode16(case: :lower)

      unless actual == expected do
        IO.puts("  ERROR: SHA256 mismatch!")
        IO.puts("    Expected: #{expected}")
        IO.puts("    Actual:   #{actual}")
        IO.puts("  File may have been modified. Aborting.")
        System.halt(1)
      end
    end
  end

  defp print_manifest_summary(manifest) do
    tables = manifest["tables"] || %{}
    total = manifest["total_rows"] || 0
    exported_at = manifest["exported_at"] || "unknown"

    IO.puts("  Exported: #{exported_at}")
    IO.puts("  Total rows: #{total}")
    IO.puts("")

    for {table, info} <- Enum.sort(tables) do
      rows = info["rows"] || 0
      IO.puts("    #{String.pad_trailing(table, 28)} #{rows} rows")
    end

    IO.puts("")
  end

  defp get_target_url! do
    case System.get_env("TARGET_DATABASE_URL") do
      nil ->
        IO.puts("  ERROR: TARGET_DATABASE_URL environment variable not set.")
        IO.puts("  Set it to the target database connection string.")
        IO.puts("  Example: TARGET_DATABASE_URL=postgresql://user:pass@host:port/dbname")
        System.halt(1)

      url ->
        url
    end
  end

  defp validate_target!(url) do
    uri = URI.parse(url)
    db_name = uri.path && String.trim_leading(uri.path, "/")
    port = uri.port

    cond do
      db_name && String.ends_with?(db_name, "_dev") ->
        IO.puts("  ERROR: Refusing to apply to dev database (#{db_name}).")
        IO.puts("  This script is for applying deltas to non-dev targets.")
        System.halt(1)

      port == 5436 && db_name != "sertantai_legal_sync_test" ->
        IO.puts("  ERROR: Port 5436 is the dev database port.")
        IO.puts("  Use a different port for the target database.")
        System.halt(1)

      true ->
        :ok
    end
  end

  defp redact_url(url) do
    uri = URI.parse(url)
    userinfo = if uri.userinfo, do: String.replace(uri.userinfo, ~r/:.*/, ":***"), else: nil
    %{uri | userinfo: userinfo} |> URI.to_string()
  end

  defp apply_sql!(url, sql) do
    uri = URI.parse(url)
    db_name = uri.path && String.trim_leading(uri.path, "/")
    [user | pass_parts] = if uri.userinfo, do: String.split(uri.userinfo, ":"), else: ["postgres"]
    password = Enum.join(pass_parts, ":")

    conn_opts = [
      hostname: uri.host || "localhost",
      port: uri.port || 5432,
      username: user,
      password: password,
      database: db_name,
      timeout: 60_000
    ]

    {:ok, pid} = Postgrex.start_link(conn_opts)

    IO.puts("  Connected. Executing delta SQL...")

    # Split SQL into individual statements (Postgrex can't execute multiple in one query)
    statements = split_statements(sql)
    IO.puts("  Statements: #{length(statements)}")

    start = System.monotonic_time(:millisecond)

    # Execute all statements in a single transaction
    result =
      Postgrex.transaction(
        pid,
        fn conn ->
          Enum.reduce(statements, 0, fn stmt, acc ->
            case Postgrex.query(conn, stmt, [], timeout: 30_000) do
              {:ok, %{num_rows: n}} -> acc + n
              {:error, error} -> Postgrex.rollback(conn, error)
            end
          end)
        end,
        timeout: 120_000
      )

    case result do
      {:ok, total_rows} ->
        elapsed = System.monotonic_time(:millisecond) - start
        IO.puts("  Success! #{total_rows} rows affected in #{elapsed}ms.")
        IO.puts("")

      {:error, %Postgrex.Error{postgres: %{message: msg} = pg}} ->
        detail = Map.get(pg, :detail)
        IO.puts("  ERROR: #{msg}")
        if detail, do: IO.puts("  Detail: #{detail}")
        IO.puts("  Transaction rolled back — no changes applied.")
        GenServer.stop(pid)
        System.halt(1)

      {:error, error} ->
        IO.puts("  ERROR: #{inspect(error)}")
        IO.puts("  Transaction rolled back — no changes applied.")
        GenServer.stop(pid)
        System.halt(1)
    end

    GenServer.stop(pid)
  end

  defp split_statements(sql) do
    sql
    |> String.split(~r/;\s*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn stmt ->
      # Remove empty, comment-only, BEGIN, and COMMIT lines
      clean = String.replace(stmt, ~r/--[^\n]*\n?/, "") |> String.trim()
      clean == "" || clean =~ ~r/^(BEGIN|COMMIT)$/i
    end)
  end
end

# ── CLI Entry Point ──────────────────────────────────────────────────

args = System.argv()

{opts, rest} =
  OptionParser.parse!(args,
    strict: [
      confirm: :boolean,
      dry_run: :boolean
    ],
    aliases: [y: :confirm, d: :dry_run]
  )

case rest do
  [sql_file | _] ->
    DeltaSync.Apply.run(sql_file, opts)

  [] ->
    IO.puts("Usage: mix run ../scripts/sync/apply_delta.exs <sql_file> [--confirm] [--dry-run]")
    System.halt(1)
end

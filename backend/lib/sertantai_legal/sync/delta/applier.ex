defmodule SertantaiLegal.Sync.Delta.Applier do
  @moduledoc """
  Applies a delta SQL file to a target database.

  Core logic extracted from scripts/sync/apply_delta.exs.
  Called by Mix.Tasks.Data.ApplyDelta.
  """

  defp default_search_dir do
    # Mix tasks run from backend/ — scripts/sync/ is one level up
    Path.expand("../scripts/sync")
  end

  def run(sql_file, opts) do
    confirm = Keyword.get(opts, :confirm, false)
    dry_run = Keyword.get(opts, :dry_run, false)

    sql_path = resolve_path(sql_file)

    unless File.exists?(sql_path) do
      Mix.raise("SQL file not found: #{sql_path}")
    end

    sql = File.read!(sql_path)
    manifest = load_manifest(sql_path)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Delta Apply — SQL → target DB")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  File: #{Path.basename(sql_path)}")
    IO.puts("  Size: #{byte_size(sql)} bytes")
    IO.puts("  Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")

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
      target_url = get_target_url!()
      validate_target!(target_url)

      IO.puts("  Target: #{redact_url(target_url)}")

      unless confirm do
        response =
          Mix.shell().prompt("  Apply this delta? [y/N]") |> String.trim() |> String.downcase()

        unless response in ["y", "yes"] do
          IO.puts("  Aborted.\n")
          :aborted
        else
          connect_and_apply!(target_url, sql)
        end
      else
        connect_and_apply!(target_url, sql)
      end
    end
  end

  defp connect_and_apply!(target_url, sql) do
    IO.puts("\n  Connecting to target database...")
    apply_sql!(target_url, sql)
  end

  defp resolve_path(file) do
    cond do
      Path.type(file) == :absolute -> file
      File.exists?(file) -> Path.expand(file)
      File.exists?(Path.join(default_search_dir(), file)) -> Path.join(default_search_dir(), file)
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
        Mix.raise("""
        SHA256 mismatch!
          Expected: #{expected}
          Actual:   #{actual}
        File may have been modified.
        """)
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
        Mix.raise("""
        TARGET_DATABASE_URL environment variable not set.
        Set it to the target database connection string.
        Example: TARGET_DATABASE_URL=postgresql://user:pass@host:port/dbname
        """)

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
        Mix.raise(
          "Refusing to apply to dev database (#{db_name}). This task is for non-dev targets."
        )

      port == 5436 && db_name != "sertantai_legal_sync_test" ->
        Mix.raise("Port 5436 is the dev database port. Use a different port for the target.")

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

    statements = split_statements(sql)
    IO.puts("  Statements: #{length(statements)}")

    start = System.monotonic_time(:millisecond)

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
        IO.puts("  Success! #{total_rows} rows affected in #{elapsed}ms.\n")
        GenServer.stop(pid)
        :ok

      {:error, %Postgrex.Error{postgres: %{message: msg} = pg}} ->
        detail = Map.get(pg, :detail)
        GenServer.stop(pid)

        Mix.raise(
          "#{msg}#{if detail, do: "\n  Detail: #{detail}", else: ""}\nTransaction rolled back — no changes applied."
        )

      {:error, error} ->
        GenServer.stop(pid)
        Mix.raise("#{inspect(error)}\nTransaction rolled back — no changes applied.")
    end
  end

  defp split_statements(sql) do
    sql
    |> String.split(~r/;\s*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn stmt ->
      clean = String.replace(stmt, ~r/--[^\n]*\n?/, "") |> String.trim()
      clean == "" || clean =~ ~r/^(BEGIN|COMMIT)$/i
    end)
  end
end

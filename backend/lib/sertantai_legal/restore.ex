defmodule SertantaiLegal.Restore do
  @moduledoc """
  In-database restore copies: the rows an apply is about to change, copied
  into the `restore` schema as `restore.<tag>__<table>` (never `public`) and
  recorded in `restore.points` (DATA-ARCHITECTURE (f), policy points 1 and 2).
  The NAS restore point (`nas-backup.sh --tables … --tag`) stays the durable
  copy; these are for a quick rollback within the session.
  """

  alias SertantaiLegal.Repo

  @schema "restore"
  # Postgres truncates identifiers past 63 bytes; two copies would collide
  @max_identifier 63

  @doc "The qualified name of `table`'s copy under `tag`."
  @spec name(String.t(), String.t()) :: String.t()
  def name(tag, table) do
    copy = "#{identifier(tag)}__#{identifier(table)}"

    if byte_size(copy) > @max_identifier,
      do: raise(ArgumentError, "restore copy name over #{@max_identifier} bytes: #{copy}")

    "#{@schema}.#{copy}"
  end

  @doc """
  Copy the rows `select` returns into `name(tag, table)` and record the
  copy. Runs in the caller's transaction, if any. Returns the copy's name.
  """
  @spec copy!(String.t(), String.t(), String.t(), list()) :: String.t()
  def copy!(tag, table, select, params \\ []) do
    copy = name(tag, table)

    %{num_rows: rows} =
      Repo.query!("CREATE TABLE #{copy} AS #{select}", params, timeout: :infinity)

    Repo.query!(
      "INSERT INTO restore.points (tag, copy, source, rows) VALUES ($1, $2, $3, $4)",
      [tag, copy, table, rows]
    )

    copy
  end

  defp identifier(s), do: s |> String.downcase() |> String.replace(~r/[^a-z0-9_]+/, "_")
end

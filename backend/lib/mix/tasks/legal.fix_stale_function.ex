defmodule Mix.Tasks.Legal.FixStaleFunction do
  @shortdoc "Strip non-structural tags from function JSONB (Making, Empowering, Housekeeping, Maker composites)"

  @moduledoc """
  One-off cleanup: the function column now stores structural role only
  (Amending, Revoking, Commencing, Enacting). This task strips any
  obligation-content or composite tags that were written by older code.

  Tags removed: Making, Empowering, Housekeeping, Amending Maker,
  Revoking Maker, Enacting Maker.

  ## Usage

      mix legal.fix_stale_function            # Dry run — report only
      mix legal.fix_stale_function --apply     # Apply fixes
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  @removed_tags [
    "Making",
    "Empowering",
    "Housekeeping",
    "Amending Maker",
    "Revoking Maker",
    "Enacting Maker"
  ]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    apply? = "--apply" in args

    # Find all laws with any of the removed tags in function
    conditions =
      @removed_tags
      |> Enum.map(fn tag -> "function ? '#{tag}'" end)
      |> Enum.join(" OR ")

    query_sql = "SELECT id, name, function FROM legal_register WHERE #{conditions} ORDER BY name"

    case Repo.query(query_sql) do
      {:ok, %{rows: []}} ->
        IO.puts("No records with removed function tags. All clean.")

      {:ok, %{rows: rows}} ->
        IO.puts("Found #{length(rows)} laws with non-structural function tags:\n")

        Enum.each(rows, fn [_id, name, function] ->
          stale = Map.keys(function) |> Enum.filter(&(&1 in @removed_tags))
          IO.puts("  #{name}  remove: #{inspect(stale)}  current: #{inspect(function)}")
        end)

        if apply? do
          IO.puts("\nApplying fixes...")

          fixed =
            Enum.count(rows, fn [id, name, function] ->
              new_function = Map.drop(function, @removed_tags)
              new_function = if map_size(new_function) == 0, do: nil, else: new_function

              case Repo.query(
                     "UPDATE legal_register SET function = $1, updated_at = now() WHERE id = $2",
                     [new_function, id]
                   ) do
                {:ok, _} ->
                  IO.puts("  ✓ #{name}")
                  true

                {:error, reason} ->
                  IO.puts("  ✗ #{name}: #{inspect(reason)}")
                  false
              end
            end)

          IO.puts("\nFixed #{fixed}/#{length(rows)} records.")
        else
          IO.puts("\nDry run. Use --apply to fix these records.")
        end

      {:error, reason} ->
        IO.puts("Query failed: #{inspect(reason)}")
    end
  end
end

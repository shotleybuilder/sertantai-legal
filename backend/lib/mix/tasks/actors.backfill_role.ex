defmodule Mix.Tasks.Actors.BackfillRole do
  @moduledoc """
  Backfill the `role` field on existing actors JSONB entries in legal_articles.

  Stamps each actor entry with `"role": "governed"` or `"role": "government"`
  using `ActorDefinitions.actor_role/1` — the single canonical classifier.

  ## Usage

      mix actors.backfill_role           # backfill all provisions with actors
      mix actors.backfill_role --dry-run # show counts without modifying data
  """

  use Mix.Task

  @shortdoc "Backfill role field on actors JSONB in legal_articles"

  @impl Mix.Task
  def run(args) do
    dry_run = "--dry-run" in args

    Mix.Task.run("app.start")

    alias SertantaiLegal.Legal.Taxa.ActorDefinitions

    # Direct SQL for performance — updating ~71K rows through Ash would be slow.
    # The query finds all provisions where actors array has at least one entry
    # missing the "role" key, then stamps each entry using the label prefix rules.

    if dry_run do
      run_dry(ActorDefinitions)
    else
      run_backfill(ActorDefinitions)
    end
  end

  defp run_dry(_actor_defs) do
    count_sql = """
    SELECT
      COUNT(*) FILTER (WHERE needs_role) AS needs_backfill,
      COUNT(*) AS total_with_actors,
      COUNT(DISTINCT law_name) FILTER (WHERE needs_role) AS laws_needing_backfill
    FROM (
      SELECT law_name,
        EXISTS (
          SELECT 1 FROM unnest(actors) AS a
          WHERE a->>'role' IS NULL
        ) AS needs_role
      FROM legal_articles
      WHERE actors IS NOT NULL AND array_length(actors, 1) > 0
    ) sub
    """

    case SertantaiLegal.Repo.query(count_sql) do
      {:ok, %{rows: [[needs, total, laws]]}} ->
        IO.puts("Dry run:")
        IO.puts("  Total provisions with actors: #{total}")
        IO.puts("  Provisions needing backfill:  #{needs}")
        IO.puts("  Laws needing backfill:        #{laws}")

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp run_backfill(actor_defs) do
    # Use a SQL function to stamp role based on label prefix.
    # This mirrors ActorDefinitions.actor_role/1 in SQL for bulk performance.
    backfill_sql = """
    UPDATE legal_articles
    SET actors = (
      SELECT array_agg(
        CASE
          WHEN elem->>'role' IS NOT NULL THEN elem
          ELSE elem || jsonb_build_object('role',
            CASE
              WHEN elem->>'label' LIKE 'Gvt:%' THEN 'government'
              WHEN elem->>'label' LIKE 'EU:%' THEN 'government'
              WHEN elem->>'label' LIKE 'HM Forces%' THEN 'government'
              WHEN elem->>'label' = 'Crown' THEN 'government'
              ELSE 'governed'
            END
          )
        END
      )
      FROM unnest(actors) AS elem
    ),
    updated_at = now()
    WHERE actors IS NOT NULL
      AND array_length(actors, 1) > 0
      AND EXISTS (
        SELECT 1 FROM unnest(actors) AS a
        WHERE a->>'role' IS NULL
      )
    """

    IO.puts("Backfilling actor roles...")

    case SertantaiLegal.Repo.query(backfill_sql, [], timeout: 120_000) do
      {:ok, %{num_rows: n}} ->
        IO.puts("Done. Updated #{n} provisions.")
        verify_backfill(actor_defs)

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp verify_backfill(_actor_defs) do
    verify_sql = """
    SELECT
      COUNT(*) FILTER (WHERE has_null_role) AS still_missing,
      COUNT(*) AS total
    FROM (
      SELECT EXISTS (
        SELECT 1 FROM unnest(actors) AS a
        WHERE a->>'role' IS NULL
      ) AS has_null_role
      FROM legal_articles
      WHERE actors IS NOT NULL AND array_length(actors, 1) > 0
    ) sub
    """

    case SertantaiLegal.Repo.query(verify_sql) do
      {:ok, %{rows: [[0, total]]}} ->
        IO.puts("Verified: all #{total} provisions have role on every actor entry.")

      {:ok, %{rows: [[missing, _total]]}} ->
        IO.puts("Warning: #{missing} provisions still have actors without role.")

      _ ->
        :ok
    end
  end
end

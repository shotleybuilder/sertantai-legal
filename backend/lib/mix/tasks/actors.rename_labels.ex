defmodule Mix.Tasks.Actors.RenameLabels do
  @moduledoc """
  Apply fractalaw's actor-dictionary rename map to stored labels
  (actor reconciliation, Jason 2026-10-05; fractalaw 050e829).

  fractalaw's `actor-dictionary.yaml` is canonical. Its single-run publish
  rebuilds the laws in its run with the new labels; this task renames the
  labels in place everywhere else, so no old label is left.

  Steps, in order:
  1. Delete the entries fractalaw's retired correlative rule inferred
     (`Ind: Public`, reason `inferred`, position `beneficiary`, drrp `none`)
     from `legal_articles.actors` — first, so they don't merge into real
     `Public` entries (Jason 2026-10-05; fractalaw 12ce423)
  2. Rename labels per the map (including `Public` → `Ind: Public`) in:
     - `legal_register` holder fields (`{"values": [...]}`): labels renamed,
    de-duplicated and sorted
     - `legal_register` DRRP entries (`{"entries": [{"holder": ...}]}`):
    holder renamed, identical entries merged, order kept
     - `legal_register.role`, `legal_articles.governed_actors` /
    `government_actors` (`text[]`): renamed, de-duplicated, order kept
     - `legal_articles.actors` (`jsonb[]` of `{label, role, ...}`): label
    renamed, identical entries merged, and `Spc: Authorised Person` entries
    flipped from role `government` to `governed` (class change, Jason
    2026-10-05)

  Every updated row gets `updated_at = now()` so the delta sync carries
  the change to compliance.

  ## Usage

      mix actors.rename_labels --dry-run  # apply in a transaction, report, roll back
      mix actors.rename_labels            # apply and commit
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  @shortdoc "Rename stored actor labels to fractalaw's canonical labels"

  @renames %{
    "SC: Applicant" => "Ind: Applicant",
    "Spc: Licence Holder" => "Ind: Licensee",
    "Spc: Appellant" => "Ind: Appellant",
    "Public: Provider" => "Svc: Provider",
    "Public: Dealer" => "SC: Dealer",
    "Public: Keeper" => "SC: Keeper",
    "Public" => "Ind: Public"
  }

  @flip_to_governed "Spc: Authorised Person"

  @values_columns ~w(duty_holder rights_holder responsibility_holder power_holder
                     current_duty_holder current_rights_holder
                     current_responsibility_holder current_power_holder
                     claim_holder liability_holder protected_holder)

  @entries_columns ~w(duties rights responsibilities powers)

  @text_array_columns [
    {"legal_register", "role"},
    {"legal_articles", "governed_actors"},
    {"legal_articles", "government_actors"}
  ]

  @impl Mix.Task
  def run(args) do
    dry_run = "--dry-run" in args

    Mix.Task.run("app.start")

    map = @renames

    IO.puts("Before:")
    before = report_residuals(map)

    result =
      Repo.transaction(
        fn ->
          delete_retired_inferred()
          apply_renames(map)
          IO.puts("\nAfter (inside transaction):")
          after_counts = report_residuals(map)

          if dry_run, do: Repo.rollback({:dry_run, after_counts}), else: after_counts
        end,
        timeout: :infinity
      )

    case result do
      {:error, {:dry_run, _}} ->
        IO.puts("\nDry run — rolled back. Before: #{inspect(before)}")

      {:ok, after_counts} ->
        IO.puts("\nCommitted. Residual old labels: #{inspect(after_counts)}")

      {:error, reason} ->
        Mix.raise("Rename failed, rolled back: #{inspect(reason)}")
    end
  end

  @retired_inferred """
  x ->> 'label' = 'Ind: Public' AND x ->> 'reason' = 'inferred'
    AND x ->> 'position' = 'beneficiary' AND x ->> 'drrp' = 'none'
  """

  defp delete_retired_inferred do
    run_update(
      "legal_articles.actors (retired Ind: Public beneficiaries deleted)",
      """
      UPDATE legal_articles
      SET actors = ARRAY(
            SELECT x FROM unnest(actors) WITH ORDINALITY t(x, o)
            WHERE NOT (#{@retired_inferred})
            ORDER BY o),
          updated_at = now()
      WHERE EXISTS (SELECT 1 FROM unnest(actors) x WHERE #{@retired_inferred})
      """,
      []
    )
  end

  # Columns are matched structurally (label membership in the map): their
  # text forms escape quotes differently per type, so a text regex misses.
  defp apply_renames(map) do
    for col <- @values_columns do
      run_update(
        "legal_register.#{col}",
        """
        UPDATE legal_register
        SET #{col} = jsonb_set(#{col}, '{values}', (
              SELECT coalesce(jsonb_agg(DISTINCT coalesce($1::jsonb ->> v, v) ORDER BY coalesce($1::jsonb ->> v, v)), '[]'::jsonb)
              FROM jsonb_array_elements_text(#{col} -> 'values') v)),
            updated_at = now()
        WHERE jsonb_typeof(#{col} -> 'values') = 'array'
          AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(#{col} -> 'values') v
                      WHERE $1::jsonb ? v)
        """,
        [map]
      )
    end

    for col <- @entries_columns do
      run_update(
        "legal_register.#{col}",
        """
        UPDATE legal_register
        SET #{col} = jsonb_set(#{col}, '{entries}', (
              SELECT coalesce(jsonb_agg(e ORDER BY o), '[]'::jsonb)
              FROM (
                SELECT DISTINCT ON (e) e, o
                FROM (
                  SELECT CASE WHEN $1::jsonb ? (x ->> 'holder')
                              THEN jsonb_set(x, '{holder}', to_jsonb($1::jsonb ->> (x ->> 'holder')))
                              ELSE x END AS e,
                         o
                  FROM jsonb_array_elements(#{col} -> 'entries') WITH ORDINALITY t(x, o)
                ) renamed
                ORDER BY e, o
              ) deduped)),
            updated_at = now()
        WHERE jsonb_typeof(#{col} -> 'entries') = 'array'
          AND EXISTS (SELECT 1 FROM jsonb_array_elements(#{col} -> 'entries') x
                      WHERE $1::jsonb ? (x ->> 'holder'))
        """,
        [map]
      )
    end

    for {table, col} <- @text_array_columns do
      run_update(
        "#{table}.#{col}",
        """
        UPDATE #{table}
        SET #{col} = ARRAY(
              SELECT v FROM (
                SELECT DISTINCT ON (v) v, o
                FROM (
                  SELECT coalesce($1::jsonb ->> x, x) AS v, o
                  FROM unnest(#{col}) WITH ORDINALITY t(x, o)
                ) renamed
                ORDER BY v, o
              ) deduped
              ORDER BY o),
            updated_at = now()
        WHERE EXISTS (SELECT 1 FROM unnest(#{col}) x WHERE $1::jsonb ? x)
        """,
        [map]
      )
    end

    run_update(
      "legal_articles.actors",
      """
      UPDATE legal_articles
      SET actors = ARRAY(
            SELECT e FROM (
              SELECT DISTINCT ON (e) e, o
              FROM (
                SELECT CASE
                         WHEN x ->> 'label' = $2 AND x ->> 'role' = 'government'
                           THEN jsonb_set(x, '{role}', '"governed"')
                         WHEN $1::jsonb ? (x ->> 'label')
                           THEN jsonb_set(x, '{label}', to_jsonb($1::jsonb ->> (x ->> 'label')))
                         ELSE x
                       END AS e,
                       o
                FROM unnest(actors) WITH ORDINALITY t(x, o)
              ) renamed
              ORDER BY e, o
            ) deduped
            ORDER BY o),
          updated_at = now()
      WHERE EXISTS (SELECT 1 FROM unnest(actors) x
                    WHERE $1::jsonb ? (x ->> 'label')
                       OR (x ->> 'label' = $2 AND x ->> 'role' = 'government'))
      """,
      [map, @flip_to_governed]
    )
  end

  defp run_update(name, sql, params) do
    %{num_rows: n} = Repo.query!(sql, params, timeout: :infinity)
    IO.puts("  #{name}: #{n} rows updated")
  end

  # Rows still carrying an old label in any handled column (matched
  # structurally, like the updates), Spc: Authorised Person actors still
  # marked government, and retired inferred beneficiaries left.
  defp report_residuals(map) do
    register_preds =
      Enum.map(@values_columns, fn col ->
        "EXISTS (SELECT 1 FROM jsonb_array_elements_text(CASE WHEN jsonb_typeof(#{col} -> 'values') = 'array' THEN #{col} -> 'values' END) v WHERE $1::jsonb ? v)"
      end) ++
        Enum.map(@entries_columns, fn col ->
          "EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(#{col} -> 'entries') = 'array' THEN #{col} -> 'entries' END) x WHERE $1::jsonb ? (x ->> 'holder'))"
        end) ++
        ["EXISTS (SELECT 1 FROM unnest(role) x WHERE $1::jsonb ? x)"]

    articles_preds = [
      "EXISTS (SELECT 1 FROM unnest(actors) x WHERE $1::jsonb ? (x ->> 'label'))",
      "EXISTS (SELECT 1 FROM unnest(governed_actors) x WHERE $1::jsonb ? x)",
      "EXISTS (SELECT 1 FROM unnest(government_actors) x WHERE $1::jsonb ? x)"
    ]

    %{rows: [[register, articles, gvt_ap, retired]]} =
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM legal_register WHERE #{Enum.join(register_preds, " OR ")}),
          (SELECT count(*) FROM legal_articles WHERE #{Enum.join(articles_preds, " OR ")}),
          (SELECT count(*) FROM legal_articles, unnest(actors) x
            WHERE x ->> 'label' = $2 AND x ->> 'role' = 'government'),
          (SELECT count(*) FROM legal_articles, unnest(actors) x WHERE #{@retired_inferred})
        """,
        [map, @flip_to_governed],
        timeout: :infinity
      )

    counts = %{
      legal_register_rows: register,
      legal_articles_rows: articles,
      authorised_person_government_actors: gvt_ap,
      retired_inferred_actors: retired
    }

    IO.puts("  #{inspect(counts)}")
    counts
  end
end

defmodule Mix.Tasks.Actors.FixHolders do
  @moduledoc """
  Fix DRRP holder assignment on legal_register (#138).

  Filters government actors out of duty_holder/rights_holder and
  governed actors out of responsibility_holder/power_holder.

  ## Usage

      mix actors.fix_holders           # fix all laws
      mix actors.fix_holders --dry-run # show counts without modifying data
  """

  use Mix.Task

  @shortdoc "Fix government/governed actor cross-assignment in holder fields"

  @impl Mix.Task
  def run(args) do
    dry_run = "--dry-run" in args

    Mix.Task.run("app.start")

    if dry_run do
      run_dry()
    else
      run_fix()
    end
  end

  # Government actor SQL filter — mirrors ActorDefinitions.government_label?/1
  @government_filter """
  v LIKE 'Gvt:%' OR v LIKE 'EU:%' OR v LIKE 'HM Forces%' OR v = 'Crown'
  """

  defp run_dry do
    sql = """
    SELECT
      COUNT(*) FILTER (WHERE has_gvt_in_duty) AS gvt_in_duty_holder,
      COUNT(*) FILTER (WHERE has_gvt_in_rights) AS gvt_in_rights_holder,
      COUNT(*) FILTER (WHERE has_governed_in_resp) AS governed_in_responsibility,
      COUNT(*) FILTER (WHERE has_governed_in_power) AS governed_in_power
    FROM (
      SELECT name,
        EXISTS (SELECT 1 FROM jsonb_array_elements_text(duty_holder->'values') v
          WHERE #{@government_filter}) AS has_gvt_in_duty,
        EXISTS (SELECT 1 FROM jsonb_array_elements_text(rights_holder->'values') v
          WHERE #{@government_filter}) AS has_gvt_in_rights,
        EXISTS (SELECT 1 FROM jsonb_array_elements_text(responsibility_holder->'values') v
          WHERE NOT (#{@government_filter})) AS has_governed_in_resp,
        EXISTS (SELECT 1 FROM jsonb_array_elements_text(power_holder->'values') v
          WHERE NOT (#{@government_filter})) AS has_governed_in_power
      FROM legal_register
      WHERE duty_holder IS NOT NULL OR rights_holder IS NOT NULL
        OR responsibility_holder IS NOT NULL OR power_holder IS NOT NULL
    ) sub
    """

    case SertantaiLegal.Repo.query(sql) do
      {:ok, %{rows: [[d, r, resp, p]]}} ->
        IO.puts("Dry run — laws with cross-assigned actors:")
        IO.puts("  Government actors in duty_holder:         #{d}")
        IO.puts("  Government actors in rights_holder:       #{r}")
        IO.puts("  Governed actors in responsibility_holder:  #{resp}")
        IO.puts("  Governed actors in power_holder:           #{p}")

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp run_fix do
    # Filter each holder field in a single UPDATE per field.
    # Each removes actors that violate the DRRP constraint.

    fixes = [
      {"duty_holder", "NOT (#{@government_filter})", "governed only"},
      {"rights_holder", "NOT (#{@government_filter})", "governed only"},
      {"responsibility_holder", @government_filter, "government only"},
      {"power_holder", @government_filter, "government only"}
    ]

    for {field, keep_filter, label} <- fixes do
      sql = """
      UPDATE legal_register
      SET #{field} = (
        SELECT CASE
          WHEN count(*) = 0 THEN NULL
          ELSE jsonb_build_object('values', jsonb_agg(v ORDER BY v))
        END
        FROM jsonb_array_elements_text(#{field}->'values') v
        WHERE #{keep_filter}
      ),
      updated_at = now()
      WHERE #{field} IS NOT NULL
        AND #{field}->'values' IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM jsonb_array_elements_text(#{field}->'values') v
          WHERE NOT (#{keep_filter})
        )
      """

      IO.write("Fixing #{field} (#{label})... ")

      case SertantaiLegal.Repo.query(sql, [], timeout: 60_000) do
        {:ok, %{num_rows: n}} -> IO.puts("#{n} laws updated")
        {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
      end
    end

    IO.puts("\nDone. Run --dry-run to verify zero cross-assignments remain.")
  end
end

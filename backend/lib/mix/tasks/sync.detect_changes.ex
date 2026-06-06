defmodule Mix.Tasks.Sync.DetectChanges do
  @moduledoc """
  Run change detection for all orgs (or a specific org).

  Detects law status changes, new law matches, and enrichment score
  changes, logging events to applicability_events.

  ## Usage

      mix sync.detect_changes                    # All orgs
      mix sync.detect_changes --org ORG_UUID     # Specific org
      mix sync.detect_changes --dry-run          # Show what would be detected
  """

  use Mix.Task

  @shortdoc "Detect legal register changes for customer orgs"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [org: :string, dry_run: :boolean],
        aliases: [o: :org, n: :dry_run]
      )

    alias SertantaiLegal.Sync.ChangeDetector

    if opts[:org] do
      org_id = opts[:org]
      Mix.shell().info("Running change detection for org #{org_id}...")

      case ChangeDetector.detect_for_org(org_id) do
        {:ok, counts} ->
          Mix.shell().info("""
          Done:
            Status changes: #{counts.status_changes}
            New laws:       #{counts.new_laws}
            Score changes:  #{counts.score_changes}
          """)

        {:error, reason} ->
          Mix.shell().error("Failed: #{inspect(reason)}")
      end
    else
      Mix.shell().info("Running change detection for all orgs...")

      case ChangeDetector.detect_all() do
        {:ok, results} ->
          Enum.each(results, fn {org_id, counts} ->
            total = counts.status_changes + counts.new_laws + counts.score_changes

            if total > 0 do
              Mix.shell().info(
                "  #{org_id}: #{counts.status_changes} status, #{counts.new_laws} new, #{counts.score_changes} score"
              )
            end
          end)

          total_orgs = map_size(results)

          total_events =
            Enum.reduce(results, 0, fn {_, c}, acc ->
              acc + c.status_changes + c.new_laws + c.score_changes
            end)

          Mix.shell().info("\n#{total_orgs} orgs checked, #{total_events} events logged.")

        {:error, reason} ->
          Mix.shell().error("Failed: #{inspect(reason)}")
      end
    end
  end
end

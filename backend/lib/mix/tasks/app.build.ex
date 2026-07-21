defmodule Mix.Tasks.App.Build do
  @shortdoc "Build the Compliance Workbench app from YAML recipes"

  @moduledoc """
  Build the Compliance Workbench Baserow app from YAML recipes.

  Reads recipe files from `priv/baserow/app/recipes/`,
  resolves field names to IDs, creates pages/elements/workflows,
  and publishes.

  ## Usage

      mix app.build                           # Build ALL recipes
      mix app.build --only controls_list      # Build single recipe
      mix app.build --only controls_list,evidence_detail  # Build specific recipes
      mix app.build --config UUID             # Specific sync config

  ## What it does

  1. Authenticates with Baserow
  2. Creates or finds the Compliance Workbench app
  3. Loads YAML recipes (all or --only subset)
  4. Resolves field names → IDs for each table
  5. Creates pages, data sources, elements, workflow actions
  6. Publishes to baserow.site
  7. Prints manual steps for API-unsupported features
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, positional, _} =
      OptionParser.parse(args,
        strict: [config: :string, only: :string],
        aliases: [c: :config, o: :only]
      )

    config_id =
      opts[:config] || List.first(positional) || find_default_config()

    unless config_id do
      Mix.shell().error("No sync configuration found. Provide a config UUID.")
      System.halt(1)
    end

    only_recipes =
      case opts[:only] do
        nil -> nil
        str -> str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.map(&String.to_atom/1)
      end

    if only_recipes do
      Mix.shell().info("Building recipes: #{Enum.join(only_recipes, ", ")}")
    else
      Mix.shell().info("Building ALL recipes")
    end

    Mix.shell().info("Config: #{config_id}\n")

    case SertantaiLegal.Baserow.App.Builder.build(config_id, only: only_recipes) do
      {:ok, result} ->
        Mix.shell().info("\n=== Build Complete ===")
        Mix.shell().info("Pages: #{map_size(result.pages)}")

        Enum.each(result.pages, fn {key, id} ->
          Mix.shell().info("  #{key}: #{id}")
        end)

        if result.manual_steps != [] do
          Mix.shell().info("\n=== Manual Steps Required ===")

          Enum.each(result.manual_steps, fn {page_key, steps} ->
            Mix.shell().info("\n#{page_key}:")

            Enum.with_index(steps, 1)
            |> Enum.each(fn {step, i} ->
              Mix.shell().info("  #{i}. #{step}")
            end)
          end)
        end

      {:error, reason} ->
        Mix.shell().error("Build failed: #{inspect(reason, limit: 300)}")
        System.halt(1)
    end
  end

  defp find_default_config do
    case SertantaiLegal.Repo.query("SELECT id FROM sync_configurations LIMIT 1") do
      {:ok, %{rows: [[id]]}} -> Ecto.UUID.load!(id)
      _ -> nil
    end
  end
end

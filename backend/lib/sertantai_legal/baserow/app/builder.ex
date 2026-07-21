defmodule SertantaiLegal.Baserow.App.Builder do
  @moduledoc """
  Orchestrates building the Compliance Workbench app from YAML recipes.

  Reads all recipe files, resolves field IDs, creates pages in dependency order,
  and generates a MANUAL_STEPS.md for anything the API can't do.

  ## Usage

      SertantaiLegal.Baserow.App.Builder.build(sync_config_id)

  Or via mix task:

      mix app.build [--config UUID]
  """

  require Logger

  alias SertantaiLegal.Baserow.App.{RecipeParser, FieldResolver, PageBuilder}
  alias SertantaiLegal.Sync.{Credentials, SyncConfiguration}
  alias SertantaiLegal.Sync.Providers.Baserow, as: BaserowProvider

  @app_name "Compliance Workbench"
  @domain_prefix "sertantai-compliance"

  @doc """
  Build the complete Compliance Workbench app from recipes.
  """
  def build(sync_config_id, opts \\ []) do
    only = Keyword.get(opts, :only)
    Logger.info("[AppBuilder] Starting build#{if only, do: " (only: #{inspect(only)})", else: ""}")

    with {:ok, config, sc} <- authenticate(sync_config_id),
         {:ok, builder_id, integration_id} <- ensure_app_and_integration(config),
         {:ok, all_recipes} <- load_recipes(),
         recipes <- filter_recipes(all_recipes, only),
         {:ok, table_ids} <- resolve_table_ids(sc),
         {:ok, resolver} <- build_resolver(config, table_ids),
         {:ok, page_registry} <- build_pages(all_recipes, recipes, config, builder_id, integration_id, table_ids, resolver),
         {:ok, manual_steps} <- generate_manual_steps(recipes),
         {:ok, _} <- publish(config, builder_id) do
      Logger.info("[AppBuilder] Build complete — #{map_size(page_registry)} pages")

      {:ok,
       %{
         pages: page_registry,
         manual_steps: manual_steps,
         builder_id: builder_id
       }}
    end
  end

  # ── Authentication ──────────────────────────────────────

  defp authenticate(config_id) do
    {:ok, sc} = Ash.get(SyncConfiguration, config_id)
    creds = Credentials.decrypt(sc.encrypted_credentials, sc.credentials_iv)
    config = %{"base_url" => sc.target_config["base_url"], "credentials" => creds}
    {:ok, config} = BaserowProvider.authenticate(config)
    {:ok, config, sc}
  end

  # ── App & Integration ───────────────────────────────────

  defp ensure_app_and_integration(config) do
    headers = auth_headers(config)
    base = config["base_url"]

    {:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
    workspace_id = hd(apps)["workspace"]["id"]

    # Find or create builder app
    builder =
      case Enum.find(apps, fn a -> a["type"] == "builder" end) do
        nil ->
          {:ok, %{body: app}} =
            Req.post("#{base}/api/applications/workspace/#{workspace_id}/",
              headers: headers,
              json: %{"name" => @app_name, "type" => "builder"},
              receive_timeout: 15_000)

          Logger.info("[AppBuilder] Created app: #{app["id"]}")
          app

        existing ->
          Logger.info("[AppBuilder] Found app: #{existing["id"]}")
          existing
      end

    # Find or create integration
    {:ok, %{body: integrations}} =
      Req.get("#{base}/api/application/#{builder["id"]}/integrations/",
        headers: headers, receive_timeout: 15_000)

    integration =
      case Enum.find(integrations, fn i -> i["type"] == "local_baserow" end) do
        nil ->
          {:ok, %{body: intg}} =
            Req.post("#{base}/api/application/#{builder["id"]}/integrations/",
              headers: headers,
              json: %{"type" => "local_baserow", "name" => "Local Database"},
              receive_timeout: 15_000)

          Logger.info("[AppBuilder] Created integration: #{intg["id"]}")
          intg

        existing ->
          existing
      end

    {:ok, builder["id"], integration["id"]}
  end

  # ── Recipe Filtering ─────────────────────────────────────

  defp filter_recipes(all_recipes, nil), do: all_recipes

  defp filter_recipes(all_recipes, only) when is_list(only) do
    Map.take(all_recipes, only)
  end

  # ── Recipes ─────────────────────────────────────────────

  defp load_recipes do
    recipes = RecipeParser.load_all()
    Logger.info("[AppBuilder] Loaded #{map_size(recipes)} recipes")
    {:ok, recipes}
  end

  # ── Table IDs ───────────────────────────────────────────

  defp resolve_table_ids(sc) do
    tc = sc.target_config

    table_ids =
      %{
        lrt: tc["lrt_table_id"],
        lat: tc["lat_table_id"],
        assessments: tc["assessments_table_id"],
        actions: tc["actions_table_id"],
        controls: tc["controls_table_id"],
        control_mappings: tc["control_mappings_table_id"],
        hierarchy: tc["hierarchy_table_id"],
        personnel: tc["personnel_table_id"],
        evidence_patterns: tc["evidence_patterns_table_id"],
        artefact_templates: tc["artefact_templates_table_id"]
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    {:ok, table_ids}
  end

  # ── Field Resolution ────────────────────────────────────

  defp build_resolver(config, table_ids) do
    resolver = FieldResolver.build(config, table_ids)
    {:ok, resolver}
  end

  # ── Page Building ───────────────────────────────────────

  # Build order matters — pages that are linked TO must be created before
  # pages that link FROM. We do two passes: first create all pages (to get IDs),
  # then populate elements.

  defp build_pages(all_recipes, recipes_to_build, config, builder_id, integration_id, table_ids, resolver) do
    # Pass 1: create/find pages for ALL recipes (need full registry for cross-page links)
    page_registry =
      Enum.reduce(all_recipes, %{}, fn {key, recipe}, registry ->
        page_spec = recipe["page"]
        headers = auth_headers(config)
        base = config["base_url"]

        {:ok, %{body: apps}} = Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)
        builder = Enum.find(apps, fn a -> a["id"] == builder_id end)
        pages = (builder["pages"] || []) |> Enum.reject(fn p -> p["shared"] end)

        page =
          case Enum.find(pages, fn p -> p["path"] == page_spec["path"] end) do
            nil ->
              page_body = %{"name" => page_spec["name"], "path" => page_spec["path"]}

              page_body =
                if page_spec["path_params"],
                  do: Map.put(page_body, "path_params", page_spec["path_params"]),
                  else: page_body

              {:ok, %{body: p}} =
                Req.post("#{base}/api/builder/#{builder_id}/pages/",
                  headers: headers, json: page_body, receive_timeout: 15_000)

              p

            existing ->
              existing
          end

        # Set query params
        if page_spec["query_params"] do
          Req.patch("#{base}/api/builder/pages/#{page["id"]}/",
            headers: headers,
            json: %{"query_params" => page_spec["query_params"]},
            receive_timeout: 15_000)
        end

        Map.put(registry, key, page["id"])
      end)

    Logger.info("[AppBuilder] Page registry: #{inspect(Map.keys(page_registry))}")

    # Pass 2: build page content ONLY for requested recipes
    Enum.each(recipes_to_build, fn {key, recipe} ->
      Logger.info("[AppBuilder] Building: #{key}")

      PageBuilder.build(recipe,
        config: config,
        builder_id: builder_id,
        integration_id: integration_id,
        table_ids: table_ids,
        resolver: resolver,
        page_registry: page_registry
      )
    end)

    {:ok, page_registry}
  end

  # ── Manual Steps ────────────────────────────────────────

  defp generate_manual_steps(recipes) do
    steps =
      Enum.flat_map(recipes, fn {key, recipe} ->
        page_steps = RecipeParser.manual_steps(recipe)

        if page_steps != [] do
          [{key, page_steps}]
        else
          []
        end
      end)

    # Log manual steps
    if steps != [] do
      Logger.info("[AppBuilder] Manual steps required:")

      Enum.each(steps, fn {key, page_steps} ->
        Logger.info("[AppBuilder]   #{key}:")
        Enum.each(page_steps, fn step -> Logger.info("[AppBuilder]     - #{step}") end)
      end)
    end

    {:ok, steps}
  end

  # ── Publish ─────────────────────────────────────────────

  defp publish(config, builder_id) do
    headers = auth_headers(config)
    base = config["base_url"]

    {:ok, %{body: domains}} =
      Req.get("#{base}/api/builder/#{builder_id}/domains/",
        headers: headers, receive_timeout: 15_000)

    domain =
      case domains do
        [] ->
          {:ok, %{body: d}} =
            Req.post("#{base}/api/builder/#{builder_id}/domains/",
              headers: headers,
              json: %{
                "domain_name" => "#{@domain_prefix}.baserow.site",
                "type" => "sub_domain"
              },
              receive_timeout: 15_000)

          d

        [d | _] ->
          d
      end

    {:ok, %{status: s}} =
      Req.post("#{base}/api/builder/domains/#{domain["id"]}/publish/async/",
        headers: headers, json: %{}, receive_timeout: 15_000)

    Logger.info("[AppBuilder] Published to #{domain["domain_name"]}: #{s}")
    {:ok, domain}
  end

  defp auth_headers(config) do
    [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
  end
end

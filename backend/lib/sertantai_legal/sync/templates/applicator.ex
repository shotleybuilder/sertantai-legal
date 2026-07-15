defmodule SertantaiLegal.Sync.Templates.Applicator do
  @moduledoc """
  Orchestrates template application across any provider.

  Takes a list of template IDs + sub-pattern config, resolves dependencies,
  and creates tables → fields → views → rollups → webhooks → seed data
  in the correct order.

  All operations are idempotent — checks for existing elements before
  creating, safe to re-run on failure.
  """

  alias SertantaiLegal.Sync.Templates.{Registry, SubPatterns}

  require Logger

  @type apply_result :: %{
          templates_applied: [atom()],
          tables_created: non_neg_integer(),
          fields_created: non_neg_integer(),
          views_created: non_neg_integer(),
          webhooks_created: non_neg_integer(),
          rows_seeded: non_neg_integer()
        }

  @doc """
  Apply templates to a provider workspace.

  ## Parameters
  - `config` — authenticated provider config (from SyncConfiguration)
  - `provider` — provider adapter module (e.g., `Providers.Baserow`)
  - `template_ids` — list of template IDs to apply (e.g., `[:foundation, :personnel, :compliance_assessment]`)
  - `sub_patterns` — sub-pattern config struct or keyword list
  - `opts` — options:
    - `:table_ids` — map of `%{table_key => provider_table_id}` for existing tables
    - `:row_mappings` — map of `%{table_key => [%{source_id, external_row_id}]}` from previous syncs

  ## Returns
  `{:ok, result}` or `{:error, reason}`
  """
  def apply(config, provider, template_ids, sub_patterns \\ [], opts \\ []) do
    sp =
      if is_struct(sub_patterns, SubPatterns),
        do: sub_patterns,
        else: SubPatterns.new(sub_patterns)

    with :ok <- SubPatterns.validate(sp),
         {:ok, modules} <- Registry.resolve(template_ids),
         :ok <- check_capabilities(provider, modules, sp) do
      context = %{
        config: config,
        provider: provider,
        sub_patterns: sp,
        table_ids: Keyword.get(opts, :table_ids, %{}),
        row_mappings: Keyword.get(opts, :row_mappings, %{}),
        results: %{
          templates_applied: [],
          tables_created: 0,
          fields_created: 0,
          views_created: 0,
          webhooks_created: 0,
          rows_seeded: 0
        }
      }

      apply_templates(modules, context)
    end
  end

  # ── Internal ──────────────────────────────────────────────────

  defp apply_templates([], context) do
    {:ok, Map.put(context.results, :table_ids, context.table_ids)}
  end

  defp apply_templates([mod | rest], context) do
    template_id = mod.id()
    Logger.info("[TemplateApplicator] Applying template: #{template_id}")

    with {:ok, context} <- create_tables(mod, context),
         {:ok, context} <- create_fields(mod, context),
         :ok <- finalize_primary_formulas(mod, context),
         {:ok, context} <- create_cross_table_fields(mod, context),
         {:ok, context} <- create_views(mod, context),
         {:ok, context} <- create_webhooks(mod, context),
         {:ok, context} <- seed_data(mod, context) do
      results = %{
        context.results
        | templates_applied: context.results.templates_applied ++ [template_id]
      }

      apply_templates(rest, %{context | results: results})
    else
      {:error, reason} ->
        Logger.error("[TemplateApplicator] Failed on #{template_id}: #{inspect(reason)}")
        {:error, {:template_failed, template_id, reason}}
    end
  end

  defp create_tables(mod, context) do
    tables = mod.tables()
    field_map = mod.field_specs(context.sub_patterns)

    Enum.reduce_while(tables, {:ok, context}, fn table_key, {:ok, ctx} ->
      table_name = humanize_table_name(table_key)

      if Map.has_key?(ctx.table_ids, table_key) do
        Logger.debug("[TemplateApplicator] Table #{table_name} already exists, skipping")
        {:cont, {:ok, ctx}}
      else
        case ctx.provider.create_table(ctx.config, table_name) do
          {:ok, table_id} ->
            Logger.info("[TemplateApplicator] Created table #{table_name} (#{table_id})")

            # Clean up provider defaults (Baserow: delete Notes, handle Name/Active)
            field_specs = Map.get(field_map, table_key, [])

            if function_exported?(ctx.provider, :cleanup_table_defaults, 3) do
              ctx.provider.cleanup_table_defaults(ctx.config, table_id, field_specs)
            end

            ctx = %{
              ctx
              | table_ids: Map.put(ctx.table_ids, table_key, table_id),
                results: %{ctx.results | tables_created: ctx.results.tables_created + 1}
            }

            {:cont, {:ok, ctx}}

          {:error, reason} ->
            {:halt, {:error, {:create_table_failed, table_name, reason}}}
        end
      end
    end)
  end

  defp create_fields(mod, context) do
    field_map = mod.field_specs(context.sub_patterns)
    do_create_fields(field_map, context)
  end

  defp finalize_primary_formulas(mod, context) do
    if function_exported?(context.provider, :finalize_primary_formula, 3) do
      field_map = mod.field_specs(context.sub_patterns)

      Enum.each(field_map, fn {table_key, fields} ->
        table_id = Map.get(context.table_ids, table_key)

        if table_id,
          do: context.provider.finalize_primary_formula(context.config, table_id, fields)
      end)
    end

    :ok
  end

  defp create_cross_table_fields(mod, context) do
    if function_exported?(mod, :cross_table_fields, 1) do
      field_map = mod.cross_table_fields(context.sub_patterns)
      do_create_fields(field_map, context)
    else
      {:ok, context}
    end
  end

  defp do_create_fields(field_map, context) do
    Enum.reduce_while(field_map, {:ok, context}, fn {table_key, fields}, {:ok, ctx} ->
      table_id = Map.get(ctx.table_ids, table_key)

      if is_nil(table_id) do
        {:halt, {:error, {:missing_table, table_key}}}
      else
        case create_fields_for_table(ctx, table_id, fields) do
          {:ok, count} ->
            ctx = %{
              ctx
              | results: %{ctx.results | fields_created: ctx.results.fields_created + count}
            }

            {:cont, {:ok, ctx}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end
    end)
  end

  defp create_fields_for_table(ctx, table_id, fields) do
    # Inject table_ids into config so the adapter can resolve link_row targets
    config_with_tables = Map.put(ctx.config, "table_ids", ctx.table_ids)

    # Get existing fields to skip duplicates (idempotent)
    existing =
      case ctx.provider.list_fields(config_with_tables, table_id) do
        {:ok, fields} -> MapSet.new(fields, & &1["name"])
        _ -> MapSet.new()
      end

    # Create non-formula/lookup fields first, then formulas, then lookups
    # (lookups depend on link_row + target fields existing)
    {lookup_fields, rest} = Enum.split_with(fields, fn f -> f[:type] == :lookup end)
    {formula_fields, regular_fields} = Enum.split_with(rest, fn f -> f[:type] == :formula end)

    ordered_fields = regular_fields ++ formula_fields ++ lookup_fields

    results =
      Enum.reduce_while(ordered_fields, {:ok, 0}, fn field, {:ok, count} ->
        cond do
          # Skip primary fields — handled by cleanup_table_defaults + finalize
          field[:primary] ->
            {:cont, {:ok, count}}

          MapSet.member?(existing, field.name) ->
            {:cont, {:ok, count}}

          true ->
            case ctx.provider.create_field(config_with_tables, table_id, field) do
              {:ok, _field_id} ->
                {:cont, {:ok, count + 1}}

              {:error, reason} ->
                if field[:type] == :lookup do
                  # Lookup fields may fail if target field doesn't exist yet
                  # (created by sync, not by template). Skip gracefully.
                  Logger.warning("[TemplateApplicator] Skipping lookup #{field.name}: #{reason}")

                  {:cont, {:ok, count}}
                else
                  {:halt, {:error, {:create_field_failed, field.name, reason}}}
                end
            end
        end
      end)

    results
  end

  defp create_views(mod, context) do
    view_map = mod.view_specs(context.sub_patterns)
    capabilities = get_capabilities(context.provider)

    Enum.reduce_while(view_map, {:ok, context}, fn {table_key, views}, {:ok, ctx} ->
      table_id = Map.get(ctx.table_ids, table_key)

      if is_nil(table_id) do
        {:halt, {:error, {:missing_table, table_key}}}
      else
        {created, ctx} =
          Enum.reduce(views, {0, ctx}, fn view, {count, ctx} ->
            if view.type in capabilities.view_types do
              case ctx.provider.create_view(ctx.config, table_id, view) do
                {:ok, _} ->
                  {count + 1, ctx}

                {:error, reason} ->
                  Logger.warning("[TemplateApplicator] Skipping view #{view.name}: #{reason}")
                  {count, ctx}
              end
            else
              Logger.warning(
                "[TemplateApplicator] Provider doesn't support #{view.type} views, skipping #{view.name}"
              )

              {count, ctx}
            end
          end)

        ctx = %{
          ctx
          | results: %{ctx.results | views_created: ctx.results.views_created + created}
        }

        {:cont, {:ok, ctx}}
      end
    end)
  end

  defp create_webhooks(mod, context) do
    if function_exported?(mod, :webhook_specs, 0) do
      capabilities = get_capabilities(context.provider)

      if capabilities.webhooks do
        specs = mod.webhook_specs()

        count =
          Enum.count(specs, fn spec ->
            table_id = Map.get(context.table_ids, spec.table)

            if table_id do
              case context.provider.create_webhook(context.config, table_id, spec) do
                {:ok, _} ->
                  true

                {:error, reason} ->
                  Logger.warning(
                    "[TemplateApplicator] Webhook failed for #{spec.table}: #{reason}"
                  )

                  false
              end
            else
              false
            end
          end)

        {:ok,
         %{
           context
           | results: %{
               context.results
               | webhooks_created: context.results.webhooks_created + count
             }
         }}
      else
        Logger.warning("[TemplateApplicator] Provider doesn't support webhooks, skipping")
        {:ok, context}
      end
    else
      {:ok, context}
    end
  end

  defp seed_data(mod, context) do
    if function_exported?(mod, :seed, 1) do
      case mod.seed(context) do
        {:ok, count} ->
          {:ok,
           %{
             context
             | results: %{context.results | rows_seeded: context.results.rows_seeded + count}
           }}

        {:error, reason} ->
          {:error, {:seed_failed, mod.id(), reason}}
      end
    else
      {:ok, context}
    end
  end

  # ── Capability checking ───────────────────────────────────────

  defp check_capabilities(provider, _modules, _sp) do
    # For now, just verify the provider has capabilities defined
    # Future: check specific sub-pattern requirements against capabilities
    _caps = get_capabilities(provider)
    :ok
  end

  defp get_capabilities(provider) do
    if function_exported?(provider, :capabilities, 0) do
      provider.capabilities()
    else
      # Default capabilities for providers that haven't implemented the callback
      %{
        view_types: [:grid],
        field_level_permissions: false,
        webhooks: false,
        webhook_includes_old_values: false,
        webhook_includes_user_id: false,
        batch_size: 100
      }
    end
  end

  # Human-friendly Baserow table names.
  # Internal keys use snake_case atoms; Baserow tables use readable names.
  @table_names %{
    lrt: "Legal Register",
    lat: "Duties",
    actor_tuples: "Actors",
    controls: "Controls",
    control_mappings: "Control Mappings",
    assessments: "Assessments",
    actions: "Actions",
    personnel: "Personnel",
    hierarchy: "Hierarchy",
    incidents: "Incidents",
    improvements: "Improvements",
    artefacts: "Artefacts",
    judgements: "Judgements",
    gaps: "Gaps",
    raci: "RACI",
    compliance_events: "Compliance Events"
  }

  defp humanize_table_name(table_key) do
    Map.get(
      @table_names,
      table_key,
      table_key |> to_string() |> String.replace("_", " ") |> String.capitalize()
    )
  end

  @doc """
  Build table specs from resolved template modules for SchemaManager.

  Converts template definitions into the flat list format SchemaManager expects:
  `[%{key: :controls, name: "Controls", fields: [...], views: [...], cross_table_fields: %{}}]`
  """
  def build_table_specs(template_ids, sub_patterns \\ []) do
    sp =
      if is_struct(sub_patterns, SubPatterns),
        do: sub_patterns,
        else: SubPatterns.new(sub_patterns)

    with {:ok, modules} <- Registry.resolve(template_ids) do
      specs =
        Enum.flat_map(modules, fn mod ->
          tables = mod.tables()
          field_map = mod.field_specs(sp)
          view_map = if function_exported?(mod, :view_specs, 1), do: mod.view_specs(sp), else: %{}

          cross_table =
            if function_exported?(mod, :cross_table_fields, 1),
              do: mod.cross_table_fields(sp),
              else: %{}

          Enum.map(tables, fn table_key ->
            %{
              key: table_key,
              name: humanize_table_name(table_key),
              fields: Map.get(field_map, table_key, []),
              views: Map.get(view_map, table_key, []),
              cross_table_fields: cross_table
            }
          end)
        end)
        # Deduplicate — dependency resolution may include the same table twice
        |> Enum.uniq_by(& &1.key)

      {:ok, specs}
    end
  end
end

defmodule SertantaiLegal.Baserow.App.PageBuilder do
  @moduledoc """
  Builds a Baserow App Builder page from a recipe.

  Creates pages, data sources, elements, and workflow actions via the Baserow API.
  Resolves field names to IDs using the FieldResolver.
  """

  require Logger

  alias SertantaiLegal.Baserow.App.FieldResolver

  @doc """
  Build a page from a recipe. Returns `{:ok, page_id}` or `{:error, reason}`.

  Options:
  - `config` — authenticated Baserow config (with JWT)
  - `builder_id` — the App Builder application ID
  - `integration_id` — the local_baserow integration ID
  - `table_ids` — map of table_key → table_id (from sync config)
  - `resolver` — FieldResolver map
  - `page_registry` — map of recipe_key → page_id (for cross-page links)
  """
  def build(recipe, opts) do
    config = opts[:config]
    headers = [{"Authorization", "JWT #{config["jwt"]}"}, {"Content-Type", "application/json"}]
    base = config["base_url"]
    builder_id = opts[:builder_id]
    integration_id = opts[:integration_id]
    table_ids = opts[:table_ids]
    resolver = opts[:resolver]
    page_registry = opts[:page_registry]

    page_spec = recipe["page"]

    # Find or create page
    {:ok, %{body: apps}} =
      Req.get("#{base}/api/applications/", headers: headers, receive_timeout: 15_000)

    builder = Enum.find(apps, fn a -> a["id"] == builder_id end)
    pages = (builder["pages"] || []) |> Enum.reject(fn p -> p["shared"] end)

    page =
      case Enum.find(pages, fn p -> p["path"] == page_spec["path"] end) do
        nil ->
          page_body = %{"name" => page_spec["name"], "path" => page_spec["path"]}

          page_body =
            if page_spec["path_params"] do
              Map.put(page_body, "path_params", page_spec["path_params"])
            else
              page_body
            end

          case Req.post("#{base}/api/builder/#{builder_id}/pages/",
                 headers: headers,
                 json: page_body,
                 receive_timeout: 15_000
               ) do
            {:ok, %{status: 200, body: p}} ->
              Logger.info("[AppBuilder] Created page #{p["name"]} (#{p["id"]})")
              p

            {:ok, %{status: status, body: err}} ->
              Logger.error(
                "[AppBuilder] Failed to create page #{page_spec["name"]}: #{status} #{inspect(err, limit: 5)}"
              )

              raise "Page creation failed: #{status}"
          end

        existing ->
          Logger.info("[AppBuilder] Found page #{existing["name"]} (#{existing["id"]})")
          existing
      end

    page_id = page["id"]

    # Set query params if specified
    if page_spec["query_params"] do
      Req.patch("#{base}/api/builder/pages/#{page_id}/",
        headers: headers,
        json: %{"query_params" => page_spec["query_params"]},
        receive_timeout: 15_000
      )
    end

    # Check if page already has elements
    {:ok, %{body: existing_els}} =
      Req.get("#{base}/api/builder/page/#{page_id}/elements/",
        headers: headers,
        receive_timeout: 15_000
      )

    if length(existing_els) > 0 do
      Logger.info(
        "[AppBuilder] Page #{page_spec["name"]} already has #{length(existing_els)} elements — skipping"
      )

      {:ok, page_id}
    else
      # Create data sources
      ds_registry =
        create_data_sources(recipe, page_id, integration_id, table_ids, resolver, headers, base)

      # Determine which table this page primarily uses
      primary_table =
        case recipe["data_sources"] do
          [first | _] -> String.to_atom(first["table"])
          _ -> nil
        end

      # Create elements
      create_elements(
        recipe["elements"] || [],
        page_id,
        ds_registry,
        resolver,
        primary_table,
        table_ids,
        page_registry,
        integration_id,
        headers,
        base
      )

      # Create workflow actions
      create_workflow(
        recipe["workflow"],
        page_id,
        ds_registry,
        table_ids,
        integration_id,
        page_registry,
        headers,
        base
      )

      Logger.info("[AppBuilder] Built page #{page_spec["name"]}")
      {:ok, page_id}
    end
  end

  # ── Data Sources ────────────────────────────────────────

  defp create_data_sources(recipe, page_id, integration_id, table_ids, resolver, headers, base) do
    (recipe["data_sources"] || [])
    |> Enum.reduce(%{}, fn ds_spec, registry ->
      table_key = String.to_atom(ds_spec["table"])
      table_id = Map.get(table_ids, table_key)

      type =
        case ds_spec["type"] do
          "list_rows" -> "local_baserow_list_rows"
          "get_row" -> "local_baserow_get_row"
          "summarize" -> "local_baserow_aggregate_rows"
          other -> other
        end

      {:ok, %{body: ds}} =
        Req.post("#{base}/api/builder/page/#{page_id}/data-sources/",
          headers: headers,
          json: %{
            "name" => ds_spec["name"],
            "type" => type,
            "integration_id" => integration_id,
            "table_id" => table_id
          },
          receive_timeout: 15_000
        )

      Logger.info("[AppBuilder]   DS: #{ds_spec["name"]} (#{ds["id"]})")

      # Set row_id if specified and not manual
      if ds_spec["row_id"] && !ds_spec["manual_config"] do
        set_data_source_row_id(base, headers, ds["id"], ds_spec["row_id"])
      end

      # Set filters if specified
      if ds_spec["filters"] do
        table_key_atom = String.to_atom(ds_spec["table"])

        filters =
          Enum.map(ds_spec["filters"], fn filter_spec ->
            field_id = FieldResolver.resolve(resolver, table_key_atom, filter_spec["field"])

            filter = %{
              "field" => field_id,
              "type" => filter_spec["type"]
            }

            filter =
              if filter_spec["value_is_formula"] do
                filter
                |> Map.put("value", %{
                  "formula" => filter_spec["value"],
                  "mode" => "simple",
                  "version" => "0.1"
                })
                |> Map.put("value_is_formula", true)
              else
                Map.put(filter, "value", filter_spec["value"] || "")
              end

            filter
          end)

        Req.patch("#{base}/api/builder/data-source/#{ds["id"]}/",
          headers: headers,
          json: %{"filters" => filters},
          receive_timeout: 15_000
        )

        Logger.info("[AppBuilder]   Filters: #{length(filters)} applied")
      end

      Map.put(registry, ds_spec["name"], ds["id"])
    end)
  end

  # ── Elements ────────────────────────────────────────────

  defp create_elements(
         elements,
         page_id,
         ds_registry,
         resolver,
         table_key,
         table_ids,
         page_registry,
         integration_id,
         headers,
         base
       ) do
    formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

    Enum.each(elements, fn el ->
      case el["type"] do
        "heading" ->
          value = resolve_value(el["value"], resolver, table_key, ds_registry)

          Req.post!("#{base}/api/builder/page/#{page_id}/elements/",
            headers: headers,
            json: %{
              "type" => "heading",
              "page_id" => page_id,
              "value" => formula.(value),
              "level" => el["level"] || 1
            }
          )

        "text" ->
          value = resolve_value(el["value"], resolver, table_key, ds_registry)

          Req.post!("#{base}/api/builder/page/#{page_id}/elements/",
            headers: headers,
            json: %{
              "type" => "text",
              "page_id" => page_id,
              "value" => formula.(value)
            }
          )

        "link" ->
          target_page_id = resolve_page_target(el["navigate_to"], page_id, page_registry)
          value = resolve_value(el["value"], resolver, table_key, ds_registry)

          link_json = %{
            "type" => "link",
            "page_id" => page_id,
            "value" => formula.(value),
            "navigate_to_page_id" => target_page_id,
            "navigation_type" => "page"
          }

          link_json =
            if el["params"] do
              params =
                Enum.map(el["params"], fn {k, v} ->
                  resolved = resolve_value(v, resolver, table_key, ds_registry)
                  %{"name" => k, "value" => resolved}
                end)

              Map.put(link_json, "page_parameters", params)
            else
              link_json
            end

          link_json =
            if el["query"] do
              query =
                Enum.map(el["query"], fn {k, v} ->
                  resolved = resolve_value(v, resolver, table_key, ds_registry)
                  %{"name" => k, "value" => resolved}
                end)

              Map.put(link_json, "query_parameters", query)
            else
              link_json
            end

          Req.post!("#{base}/api/builder/page/#{page_id}/elements/",
            headers: headers,
            json: link_json
          )

        "button" ->
          value = resolve_value(el["value"], resolver, table_key, ds_registry)

          {:ok, %{body: btn}} =
            Req.post("#{base}/api/builder/page/#{page_id}/elements/",
              headers: headers,
              json: %{
                "type" => "button",
                "page_id" => page_id,
                "value" => formula.(value)
              }
            )

          # Create button events
          create_button_events(
            el["events"],
            btn["id"],
            page_id,
            table_ids,
            integration_id,
            page_registry,
            headers,
            base
          )

        "table" ->
          ds_id = Map.get(ds_registry, el["data_source"])

          {:ok, %{body: table_el}} =
            Req.post("#{base}/api/builder/page/#{page_id}/elements/",
              headers: headers,
              json: %{
                "type" => "table",
                "page_id" => page_id,
                "data_source_id" => ds_id,
                "items_per_page" => el["items_per_page"] || 25,
                "is_publicly_filterable" => el["filterable"] || false,
                "is_publicly_sortable" => el["sortable"] || false,
                "is_publicly_searchable" => el["searchable"] || false
              }
            )

          # Configure columns
          columns =
            build_table_columns(
              el["columns"] || [],
              resolver,
              table_key,
              page_id,
              page_registry,
              ds_registry
            )

          patch_body = %{"fields" => columns}

          # Configure CSS class
          patch_body =
            if el["css_class"],
              do: Map.put(patch_body, "css_classes", el["css_class"]),
              else: patch_body

          Req.patch!("#{base}/api/builder/element/#{table_el["id"]}/",
            headers: headers,
            json: patch_body
          )

          # Configure user_actions (filter/sort/search per field)
          if el["user_actions"] do
            property_options = build_property_options(el["user_actions"], resolver, table_key)

            Req.patch!("#{base}/api/builder/element/#{table_el["id"]}/",
              headers: headers,
              json: %{"property_options" => property_options}
            )

            Logger.info(
              "[AppBuilder]   User actions: #{length(property_options)} fields configured"
            )
          end

          Logger.info("[AppBuilder]   Table: #{table_el["id"]} (#{length(columns)} columns)")

        "form_container" ->
          {:ok, %{body: form}} =
            Req.post("#{base}/api/builder/page/#{page_id}/elements/",
              headers: headers,
              json: %{
                "type" => "form_container",
                "page_id" => page_id,
                "submit_button_label" => formula.("\"#{el["submit_label"] || "Submit"}\"")
              }
            )

          Logger.info("[AppBuilder]   Form: #{form["id"]}")

          # Create children (as siblings — manual nesting required)
          Enum.each(el["children"] || [], fn child ->
            create_form_child(child, page_id, ds_registry, resolver, table_key, headers, base)
          end)

        _ ->
          Logger.warning("[AppBuilder] Unknown element type: #{el["type"]}")
      end
    end)
  end

  defp create_form_child(child, page_id, ds_registry, resolver, table_key, headers, base) do
    formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

    json =
      %{"type" => child["type"], "page_id" => page_id}
      |> maybe_put("label", child["label"], formula)
      |> maybe_put("placeholder", child["placeholder"], formula)
      |> maybe_put_bool("is_multiline", child["multiline"])
      |> maybe_put_bool("required", child["required"])

    # Default value from data source
    json =
      if child["default_from"] do
        expr = resolve_default_from(child["default_from"], resolver, table_key, ds_registry)
        Map.put(json, "default_value", formula.(expr))
      else
        json
      end

    # Choice options
    json =
      if child["options"] do
        options =
          Enum.map(child["options"], fn
            opt when is_binary(opt) -> %{"name" => opt, "value" => opt}
            %{"name" => n, "value" => v} -> %{"name" => n, "value" => v}
            opt when is_map(opt) -> opt
          end)

        Map.merge(json, %{"option_type" => "manual", "options" => options})
      else
        json
      end

    # Record selector
    json =
      if child["data_source"] do
        ds_id = Map.get(ds_registry, child["data_source"])
        Map.put(json, "data_source_id", ds_id)
      else
        json
      end

    {:ok, %{body: el}} =
      Req.post("#{base}/api/builder/page/#{page_id}/elements/",
        headers: headers,
        json: json,
        receive_timeout: 15_000
      )

    Logger.info("[AppBuilder]     #{child["type"]}: #{el["id"]} (#{child["label"]})")
  end

  # ── Table Columns ───────────────────────────────────────

  defp build_table_columns(columns, resolver, table_key, page_id, page_registry, ds_registry) do
    formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

    Enum.map(columns, fn col ->
      case col["type"] do
        "text" ->
          expr = FieldResolver.column_formula(col, resolver, table_key)
          %{"name" => col["name"], "type" => "text", "value" => formula.(expr)}

        "tags" ->
          field_id = FieldResolver.resolve(resolver, table_key, col["field"])

          %{
            "name" => col["name"],
            "type" => "tags",
            "values" => formula.("get('current_record.field_#{field_id}.*.value')"),
            "colors" => formula.("get('current_record.field_#{field_id}.*.color')")
          }

        "link" ->
          target_page_id = resolve_page_target(col["navigate_to"], page_id, page_registry)

          link = %{
            "name" => col["name"],
            "type" => "link",
            "navigate_to_page_id" => target_page_id,
            "navigation_type" => "page"
          }

          link =
            if col["params"] do
              params =
                Enum.map(col["params"], fn {k, v} ->
                  resolved = FieldResolver.interpolate_formula(v, resolver, table_key)
                  %{"name" => k, "value" => resolved}
                end)

              Map.put(link, "page_parameters", params)
            else
              link
            end

          link =
            if col["query"] do
              query =
                Enum.map(col["query"], fn {k, v} ->
                  resolved = FieldResolver.interpolate_formula(v, resolver, table_key)
                  %{"name" => k, "value" => resolved}
                end)

              Map.put(link, "query_parameters", query)
            else
              link
            end

          link =
            if col["link_name"] do
              Map.put(link, "link_name", formula.("\"#{col["link_name"]}\""))
            else
              link
            end

          link

        _ ->
          %{"name" => col["name"], "type" => "text", "value" => formula.("''")}
      end
    end)
  end

  # ── Property Options (user filter/sort/search) ───────────

  defp build_property_options(user_actions, resolver, table_key) do
    Enum.map(user_actions, fn action ->
      field_id = FieldResolver.resolve(resolver, table_key, action["field"])

      %{
        "schema_property" => "field_#{field_id}",
        "filterable" => action["filterable"] || false,
        "sortable" => action["sortable"] || false,
        "searchable" => action["searchable"] || false
      }
    end)
  end

  # ── Workflow Actions ────────────────────────────────────

  defp create_workflow(
         nil,
         _page_id,
         _ds_registry,
         _table_ids,
         _integration_id,
         _page_registry,
         _headers,
         _base
       ),
       do: :ok

  defp create_workflow(
         workflow,
         page_id,
         ds_registry,
         table_ids,
         integration_id,
         page_registry,
         headers,
         base
       ) do
    formula = fn expr -> %{"formula" => expr, "mode" => "simple", "version" => "0.1"} end

    # Find the form container on this page
    {:ok, %{body: elements}} =
      Req.get("#{base}/api/builder/page/#{page_id}/elements/",
        headers: headers,
        receive_timeout: 15_000
      )

    form = Enum.find(elements, fn e -> e["type"] == "form_container" end)
    form_id = if form, do: form["id"], else: nil

    Enum.each(workflow["on_submit"] || [], fn action ->
      element_id = form_id

      case action["type"] do
        "update_row" ->
          table_key = String.to_atom(action["table"])
          table_id = Map.get(table_ids, table_key)

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "update_row",
              "element_id" => element_id,
              "event" => "submit",
              "service" => %{
                "type" => "local_baserow_upsert_row",
                "integration_id" => integration_id,
                "table_id" => table_id
              }
            }
          )

        "create_row" ->
          table_key = String.to_atom(action["table"])
          table_id = Map.get(table_ids, table_key)

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "create_row",
              "element_id" => element_id,
              "event" => "submit",
              "service" => %{
                "type" => "local_baserow_upsert_row",
                "integration_id" => integration_id,
                "table_id" => table_id
              }
            }
          )

        "notification" ->
          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "notification",
              "element_id" => element_id,
              "event" => "submit",
              "title" => formula.("\"#{action["title"]}\""),
              "description" => formula.("\"#{action["description"]}\"")
            }
          )

        "open_page" ->
          target_page_id = resolve_page_target(action["target"], page_id, page_registry)

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "open_page",
              "element_id" => element_id,
              "event" => "submit",
              "navigate_to_page_id" => target_page_id
            }
          )

        "refresh_data_source" ->
          ds_id = Map.get(ds_registry, action["target"])

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "refresh_data_source",
              "element_id" => element_id,
              "event" => "submit",
              "data_source_id" => ds_id
            }
          )

        _ ->
          Logger.warning("[AppBuilder] Unknown workflow action: #{action["type"]}")
      end
    end)
  end

  # ── Button Events ───────────────────────────────────────

  defp create_button_events(
         nil,
         _btn_id,
         _page_id,
         _table_ids,
         _integration_id,
         _page_registry,
         _headers,
         _base
       ),
       do: :ok

  defp create_button_events(
         events,
         btn_id,
         page_id,
         table_ids,
         integration_id,
         page_registry,
         headers,
         base
       ) do
    Enum.each(events["on_click"] || [], fn action ->
      case action["type"] do
        "create_row" ->
          table_key = String.to_atom(action["table"])
          table_id = Map.get(table_ids, table_key)

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "create_row",
              "element_id" => btn_id,
              "event" => "click",
              "service" => %{
                "type" => "local_baserow_upsert_row",
                "integration_id" => integration_id,
                "table_id" => table_id
              }
            }
          )

        "open_page" ->
          target_page_id = resolve_page_target(action["target"], page_id, page_registry)

          Req.post!("#{base}/api/builder/page/#{page_id}/workflow_actions/",
            headers: headers,
            json: %{
              "type" => "open_page",
              "element_id" => btn_id,
              "event" => "click",
              "navigate_to_page_id" => target_page_id
            }
          )

        _ ->
          Logger.warning("[AppBuilder] Unknown button action: #{action["type"]}")
      end
    end)
  end

  # ── Helpers ─────────────────────────────────────────────

  defp resolve_value(value, resolver, table_key, ds_registry) when is_binary(value) do
    # If it starts with get( it's a formula — interpolate field names
    if String.starts_with?(value, "get(") or String.starts_with?(value, "concat(") do
      value
      |> FieldResolver.interpolate_formula(resolver, table_key)
      |> interpolate_ds_refs(ds_registry)
    else
      # Static string — wrap in quotes
      "\"#{value}\""
    end
  end

  defp resolve_value(nil, _, _, _), do: "''"

  defp resolve_default_from(expr, resolver, table_key, ds_registry) do
    # Format: "{DS Name}.Field_Name.accessor"
    expr
    |> FieldResolver.interpolate_formula(resolver, table_key)
    |> interpolate_ds_refs(ds_registry)
  end

  defp interpolate_ds_refs(formula, ds_registry) do
    Regex.replace(~r/\{([^}]+)\}/, formula, fn _, ds_name ->
      case Map.get(ds_registry, ds_name) do
        nil -> "{#{ds_name}}"
        id -> to_string(id)
      end
    end)
  end

  defp resolve_page_target("_self", page_id, _registry), do: page_id

  defp resolve_page_target(key, _page_id, registry) when is_binary(key) do
    Map.get(registry, String.to_atom(key))
  end

  defp resolve_page_target(nil, _page_id, _registry), do: nil

  defp maybe_put(json, _key, nil, _formula_fn), do: json

  defp maybe_put(json, key, value, formula_fn),
    do: Map.put(json, key, formula_fn.("\"#{value}\""))

  defp maybe_put_bool(json, _key, nil), do: json
  defp maybe_put_bool(json, key, value), do: Map.put(json, key, value)

  # Self-hosted Baserow expects row_id as plain string; SaaS uses a formula object.
  # Try plain string first, fall back to formula object on validation error.
  defp set_data_source_row_id(base, headers, ds_id, formula_str) do
    case Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
           headers: headers,
           json: %{"row_id" => formula_str},
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200}} ->
        Logger.info("[AppBuilder]   row_id set: #{formula_str}")

      {:ok, %{status: 400}} ->
        # Retry with formula object (SaaS format)
        formula_obj = %{"formula" => formula_str, "mode" => "simple", "version" => "0.1"}

        case Req.patch("#{base}/api/builder/data-source/#{ds_id}/",
               headers: headers,
               json: %{"row_id" => formula_obj},
               receive_timeout: 15_000
             ) do
          {:ok, %{status: 200}} ->
            Logger.info("[AppBuilder]   row_id set (SaaS format): #{formula_str}")

          {:ok, %{status: s, body: b}} ->
            Logger.warning(
              "[AppBuilder]   row_id PATCH failed both formats (#{s}): #{inspect(b)}"
            )

          {:error, reason} ->
            Logger.warning("[AppBuilder]   row_id PATCH error: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.warning("[AppBuilder]   row_id PATCH error: #{inspect(reason)}")
    end
  end
end

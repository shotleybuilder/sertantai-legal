defmodule SertantaiLegal.Zenoh.DataServer do
  @moduledoc """
  Declares Zenoh queryables for legislation and secondary source data.

  Fractalaw queries these key expressions to pull data on demand.
  Default response format is Arrow IPC streaming. Append `?format=json` to the
  query parameters for JSON.

  Key expressions:
    fractalaw/@{tenant}/data/legislation/lrt              -- all LRT records
    fractalaw/@{tenant}/data/legislation/lrt/{name}       -- single LRT by name
    fractalaw/@{tenant}/data/legislation/lat/{name}       -- LAT sections for a law
    fractalaw/@{tenant}/data/legislation/amendments/{name} -- annotations for a law
    fractalaw/@{tenant}/data/legislation/definitions/{name} -- definitions for a law
    fractalaw/@{tenant}/data/secondary/sources            -- all secondary sources
    fractalaw/@{tenant}/data/secondary/sources/{source_id} -- single source metadata
    fractalaw/@{tenant}/data/secondary/provisions/{source_id} -- provisions for a source
    fractalaw/@{tenant}/sertantai/customers/{id}/laws     -- law names for a customer
  """

  use GenServer
  require Logger

  import Ecto.Query

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Legal.{
    LegalRegister,
    Lat,
    AmendmentAnnotation,
    LegislativeDefinition,
    SecondarySource,
    SecondarySourceProvision
  }

  alias SertantaiLegal.Zenoh.ActivityLog

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns current status for the admin dashboard."
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  catch
    :exit, _ -> %{state: :stopped, queryable_count: 0, key_expressions: []}
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    ActivityLog.set_status(:data_server, :connecting)
    send(self(), :setup)
    {:ok, %{queryable_ids: [], poll_count: 0, key_expressions: []}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        {queryable_ids, key_expressions} = declare_queryables(session_id)
        Logger.info("[Zenoh.DataServer] Declared #{length(queryable_ids)} queryables")
        ActivityLog.set_status(:data_server, :ready)
        ActivityLog.record(:data_server, :connected, %{queryables: length(queryable_ids)})
        {:noreply, %{state | queryable_ids: queryable_ids, key_expressions: key_expressions}}

      {:error, :not_ready} ->
        if state.poll_count < @max_poll_attempts do
          Process.send_after(self(), :setup, @poll_interval)
          {:noreply, %{state | poll_count: state.poll_count + 1}}
        else
          Logger.error(
            "[Zenoh.DataServer] Session not ready after #{@max_poll_attempts} attempts"
          )

          {:stop, :session_not_ready, state}
        end
    end
  end

  # Handle incoming Zenoh queries
  def handle_info(%Zenohex.Query{} = query, state) do
    Task.start(fn -> handle_query(query) end)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      state: if(state.queryable_ids != [], do: :ready, else: :connecting),
      queryable_count: length(state.queryable_ids),
      key_expressions: state.key_expressions
    }

    {:reply, status, state}
  end

  # --- Query Handling ---

  defp handle_query(%Zenohex.Query{key_expr: key_expr, parameters: params, zenoh_query: zq}) do
    tenant = tenant_id()
    prefix = "fractalaw/@#{tenant}/data/legislation"
    secondary_prefix = "fractalaw/@#{tenant}/data/secondary"
    customers_prefix = "fractalaw/@#{tenant}/sertantai/customers"
    format = parse_format(params)

    {duration_us, result} =
      :timer.tc(fn ->
        case key_expr do
          ^prefix <> "/lrt" ->
            fetch_all_lrt(format)

          ^prefix <> "/lrt/" <> law_name ->
            fetch_lrt_by_name(law_name, format)

          ^prefix <> "/lat/" <> law_name ->
            fetch_lat_by_law(law_name, format)

          ^prefix <> "/amendments/" <> law_name ->
            fetch_amendments_by_law(law_name, format)

          ^prefix <> "/definitions/" <> law_name ->
            fetch_definitions_by_law(law_name, format)

          ^secondary_prefix <> "/sources" ->
            fetch_all_secondary_sources()

          ^secondary_prefix <> "/sources/" <> source_id ->
            fetch_secondary_source(source_id)

          ^secondary_prefix <> "/provisions/" <> source_id ->
            fetch_secondary_provisions(source_id, format)

          ^customers_prefix ->
            fetch_customer_list()

          ^customers_prefix <> "/" <> rest ->
            case String.split(rest, "/") do
              [customer_id, "laws"] -> fetch_customer_laws(customer_id)
              _ -> {:error, :unknown_key}
            end

          _ ->
            {:error, :unknown_key}
        end
      end)

    duration_ms = div(duration_us, 1000)

    case result do
      {:ok, payload} ->
        ActivityLog.increment(:data_server, :queries)

        ActivityLog.record(:data_server, :query, %{
          key_expr: key_expr,
          format: format,
          duration_ms: duration_ms
        })

        Zenohex.Query.reply(zq, key_expr, payload, final?: true)

      {:error, reason} ->
        ActivityLog.increment(:data_server, :errors)
        ActivityLog.record(:data_server, :error, %{key_expr: key_expr, reason: inspect(reason)})
        Logger.warning("[Zenoh.DataServer] Query failed for #{key_expr}: #{inspect(reason)}")
        error_payload = Jason.encode!(%{error: to_string(reason)})
        Zenohex.Query.reply(zq, key_expr, error_payload, final?: true)
    end
  rescue
    e ->
      ActivityLog.increment(:data_server, :errors)

      ActivityLog.record(:data_server, :error, %{key_expr: key_expr, reason: Exception.message(e)})

      Logger.error("[Zenoh.DataServer] Query error: #{Exception.message(e)}")
  end

  defp parse_format(params) when is_binary(params) do
    if String.contains?(params, "format=json"), do: :json, else: :arrow
  end

  defp parse_format(_), do: :arrow

  # --- Data Fetching ---

  defp fetch_all_lrt(:json) do
    records =
      from(u in LegalRegister, order_by: [asc: u.name])
      |> Repo.all()
      |> Enum.map(&serialize_lrt/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_all_lrt(:arrow) do
    records = from(u in LegalRegister, order_by: [asc: u.name]) |> Repo.all()
    lrt_to_arrow(records)
  end

  defp fetch_lrt_by_name(law_name, :json) do
    case Repo.one(from(u in LegalRegister, where: u.name == ^law_name)) do
      nil -> {:error, :not_found}
      record -> {:ok, Jason.encode!(serialize_lrt(record))}
    end
  end

  defp fetch_lrt_by_name(law_name, :arrow) do
    case Repo.one(from(u in LegalRegister, where: u.name == ^law_name)) do
      nil -> {:error, :not_found}
      record -> lrt_to_arrow([record])
    end
  end

  defp fetch_lat_by_law(law_name, :json) do
    records =
      from(l in Lat,
        where: l.law_name == ^law_name,
        order_by: [asc: l.sort_key]
      )
      |> Repo.all()
      |> Enum.map(&serialize_lat/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_lat_by_law(law_name, :arrow) do
    records =
      from(l in Lat,
        where: l.law_name == ^law_name,
        order_by: [asc: l.sort_key]
      )
      |> Repo.all()

    lat_to_arrow(records)
  end

  defp fetch_amendments_by_law(law_name, :json) do
    records =
      from(a in AmendmentAnnotation,
        where: a.law_name == ^law_name,
        order_by: [asc: a.id]
      )
      |> Repo.all()
      |> Enum.map(&serialize_amendment/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_amendments_by_law(law_name, :arrow) do
    records =
      from(a in AmendmentAnnotation,
        where: a.law_name == ^law_name,
        order_by: [asc: a.id]
      )
      |> Repo.all()

    amendments_to_arrow(records)
  end

  defp fetch_definitions_by_law(law_name, :json) do
    records =
      from(d in LegislativeDefinition,
        where: d.law_name == ^law_name,
        order_by: [asc: d.term]
      )
      |> Repo.all()
      |> Enum.map(&serialize_definition/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_definitions_by_law(law_name, :arrow) do
    records =
      from(d in LegislativeDefinition,
        where: d.law_name == ^law_name,
        order_by: [asc: d.term]
      )
      |> Repo.all()

    definitions_to_arrow(records)
  end

  # --- Serialization ---

  defp serialize_lrt(r) do
    %{
      id: r.id,
      family: r.family,
      family_ii: r.family_ii,
      name: r.name,
      title_en: r.title_en,
      year: r.year,
      number: r.number,
      type_desc: r.type_desc,
      type_code: r.type_code,
      type_class: r.type_class,
      domain: r.domain,
      geo_extent: r.geo_extent,
      geo_region: r.geo_region,
      live: r.live,
      function: r.function,
      is_making: r.is_making,
      is_amending: r.is_amending,
      is_rescinding: r.is_rescinding,
      is_enacting: r.is_enacting,
      is_commencing: r.is_commencing,
      duty_holder: r.duty_holder,
      power_holder: r.power_holder,
      rights_holder: r.rights_holder,
      responsibility_holder: r.responsibility_holder,
      purpose: r.purpose,
      duty_type: r.duty_type,
      role: r.role,
      popimar: r.popimar,
      amending: r.amending,
      amended_by: r.amended_by,
      rescinding: r.rescinding,
      rescinded_by: r.rescinded_by,
      enacting: r.enacting,
      enacted_by: r.enacted_by,
      leg_gov_uk_url: r.leg_gov_uk_url,
      explanatory_note: r.explanatory_note,
      updated_at: r.updated_at
    }
  end

  defp serialize_lat(r) do
    %{
      section_id: r.section_id,
      law_id: r.law_id,
      law_name: r.law_name,
      section_type: r.section_type,
      text: r.text,
      hierarchy_path: r.hierarchy_path,
      depth: r.depth,
      sort_key: r.sort_key,
      position: r.position,
      extent_code: r.extent_code,
      amendment_count: r.amendment_count,
      modification_count: r.modification_count,
      commencement_count: r.commencement_count,
      updated_at: r.updated_at
    }
  end

  defp serialize_amendment(r) do
    %{
      id: r.id,
      law_id: r.law_id,
      law_name: r.law_name,
      code: r.code,
      code_type: r.code_type,
      text: r.text,
      source: r.source,
      affected_sections: r.affected_sections,
      updated_at: r.updated_at
    }
  end

  defp serialize_definition(d) do
    %{
      id: d.id,
      law_name: d.law_name,
      term: d.term,
      term_welsh: d.term_welsh,
      definition: d.definition,
      section_id: d.section_id,
      scope: d.scope,
      references_other_law: d.references_other_law,
      updated_at: d.updated_at
    }
  end

  defp fetch_customer_list do
    query =
      from(oa in "org_applicabilities",
        join: o in "organizations",
        on: o.id == oa.organization_id,
        where: oa.status == "yes",
        group_by: [oa.organization_id, o.name, oa.source],
        select: %{
          id: type(oa.organization_id, Ecto.UUID),
          name: o.name,
          source: oa.source,
          law_count: count(oa.id)
        },
        order_by: [asc: o.name]
      )

    case Repo.all(query) do
      [] -> {:error, :not_found}
      customers -> {:ok, Jason.encode!(customers)}
    end
  end

  defp fetch_customer_laws(customer_id) do
    query =
      from(oa in "org_applicabilities",
        join: lr in "legal_register",
        on: lr.name == oa.law_name,
        where: oa.organization_id == type(^customer_id, :binary_id),
        where: oa.status == "yes",
        select: %{
          law_name: oa.law_name,
          live: lr.live
        },
        order_by: [asc: oa.law_name]
      )

    case Repo.all(query) do
      [] -> {:error, :not_found}
      laws -> {:ok, Jason.encode!(laws)}
    end
  end

  # --- Arrow IPC Serialization ---

  defp lat_to_arrow([]), do: {:ok, <<>>}

  defp lat_to_arrow(records) do
    df =
      Explorer.DataFrame.new(%{
        section_id: Enum.map(records, & &1.section_id),
        law_name: Enum.map(records, & &1.law_name),
        section_type: Enum.map(records, &to_string(&1.section_type)),
        text: Enum.map(records, & &1.text),
        sort_key: Enum.map(records, & &1.sort_key),
        position: Enum.map(records, & &1.position),
        depth: Enum.map(records, & &1.depth),
        hierarchy_path: Enum.map(records, & &1.hierarchy_path),
        extent_code: Enum.map(records, & &1.extent_code),
        language: Enum.map(records, & &1.language),
        part: Enum.map(records, & &1.part),
        chapter: Enum.map(records, & &1.chapter),
        heading_group: Enum.map(records, & &1.heading_group),
        provision: Enum.map(records, & &1.provision),
        paragraph: Enum.map(records, & &1.paragraph),
        sub_paragraph: Enum.map(records, & &1.sub_paragraph),
        schedule: Enum.map(records, & &1.schedule),
        amendment_count: Enum.map(records, & &1.amendment_count),
        modification_count: Enum.map(records, & &1.modification_count),
        commencement_count: Enum.map(records, & &1.commencement_count),
        extent_count: Enum.map(records, & &1.extent_count),
        editorial_count: Enum.map(records, & &1.editorial_count),
        updated_at: Enum.map(records, & &1.updated_at)
      })

    df =
      cast_columns(
        df,
        ~w(position depth amendment_count modification_count commencement_count extent_count editorial_count),
        {:s, 32}
      )

    Explorer.DataFrame.dump_ipc_stream(df)
  end

  defp lrt_to_arrow([]), do: {:ok, <<>>}

  defp lrt_to_arrow(records) do
    df =
      Explorer.DataFrame.new(%{
        id: Enum.map(records, & &1.id),
        family: Enum.map(records, & &1.family),
        family_ii: Enum.map(records, & &1.family_ii),
        name: Enum.map(records, & &1.name),
        title_en: Enum.map(records, & &1.title_en),
        year: Enum.map(records, & &1.year),
        number: Enum.map(records, & &1.number),
        type_desc: Enum.map(records, & &1.type_desc),
        type_code: Enum.map(records, & &1.type_code),
        type_class: Enum.map(records, & &1.type_class),
        domain: Enum.map(records, & &1.domain),
        geo_extent: Enum.map(records, & &1.geo_extent),
        geo_region: Enum.map(records, & &1.geo_region),
        live: Enum.map(records, & &1.live),
        is_making: Enum.map(records, & &1.is_making),
        is_amending: Enum.map(records, & &1.is_amending),
        is_rescinding: Enum.map(records, & &1.is_rescinding),
        is_enacting: Enum.map(records, & &1.is_enacting),
        is_commencing: Enum.map(records, & &1.is_commencing),
        source_url: Enum.map(records, & &1.source_url),
        explanatory_note: Enum.map(records, & &1.explanatory_note),
        updated_at: Enum.map(records, & &1.updated_at)
      })

    df = cast_columns(df, ~w(year), {:s, 32})

    Explorer.DataFrame.dump_ipc_stream(df)
  end

  defp amendments_to_arrow([]), do: {:ok, <<>>}

  defp amendments_to_arrow(records) do
    df =
      Explorer.DataFrame.new(%{
        id: Enum.map(records, & &1.id),
        law_id: Enum.map(records, & &1.law_id),
        law_name: Enum.map(records, & &1.law_name),
        code: Enum.map(records, & &1.code),
        code_type: Enum.map(records, & &1.code_type),
        text: Enum.map(records, & &1.text),
        source: Enum.map(records, & &1.source),
        updated_at: Enum.map(records, & &1.updated_at)
      })

    Explorer.DataFrame.dump_ipc_stream(df)
  end

  defp definitions_to_arrow([]), do: {:ok, <<>>}

  defp definitions_to_arrow(records) do
    df =
      Explorer.DataFrame.new(%{
        id: Enum.map(records, & &1.id),
        law_name: Enum.map(records, & &1.law_name),
        term: Enum.map(records, & &1.term),
        term_welsh: Enum.map(records, & &1.term_welsh),
        definition: Enum.map(records, & &1.definition),
        section_id: Enum.map(records, & &1.section_id),
        scope: Enum.map(records, &to_string(&1.scope || "")),
        references_other_law: Enum.map(records, & &1.references_other_law),
        updated_at: Enum.map(records, & &1.updated_at)
      })

    Explorer.DataFrame.dump_ipc_stream(df)
  end

  # --- Secondary Source Fetching ---

  defp fetch_all_secondary_sources do
    records =
      from(s in SecondarySource, order_by: [asc: s.source_id])
      |> Repo.all()
      |> Enum.map(&serialize_secondary_source/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_secondary_source(source_id) do
    case Repo.all(from(s in SecondarySource, where: s.source_id == ^source_id)) do
      [source] -> {:ok, Jason.encode!(serialize_secondary_source(source))}
      [] -> {:error, :not_found}
    end
  end

  defp fetch_secondary_provisions(source_id, :json) do
    records =
      from(p in SecondarySourceProvision,
        where: p.source_id == ^source_id,
        order_by: [asc: p.position]
      )
      |> Repo.all()
      |> Enum.map(&serialize_secondary_provision/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_secondary_provisions(source_id, :arrow) do
    records =
      from(p in SecondarySourceProvision,
        where: p.source_id == ^source_id,
        order_by: [asc: p.position]
      )
      |> Repo.all()

    secondary_provisions_to_arrow(records)
  end

  defp serialize_secondary_source(s) do
    %{
      id: s.id,
      source_id: s.source_id,
      source_type: to_string(s.source_type),
      title: s.title,
      issuer: s.issuer,
      legal_weight: to_string(s.legal_weight),
      status: to_string(s.status),
      edition: s.edition,
      parent_source_id: s.parent_source_id,
      updated_at: s.updated_at
    }
  end

  defp serialize_secondary_provision(p) do
    %{
      id: p.id,
      section_id: p.section_id,
      source_id: p.source_id,
      sort_key: p.sort_key,
      position: p.position,
      section_type: to_string(p.section_type),
      depth: p.depth,
      hierarchy_path: p.hierarchy_path,
      heading: p.heading,
      text: p.text,
      text_source: to_string(p.text_source),
      drrp_types: p.drrp_types,
      actors: p.actors,
      governed_actors: p.governed_actors,
      popimar: p.popimar,
      significance_overall: p.significance_overall,
      taxa_enriched_at: p.taxa_enriched_at,
      updated_at: p.updated_at
    }
  end

  defp secondary_provisions_to_arrow([]), do: {:ok, <<>>}

  defp secondary_provisions_to_arrow(records) do
    df =
      Explorer.DataFrame.new(%{
        id: Enum.map(records, & &1.id),
        section_id: Enum.map(records, & &1.section_id),
        source_id: Enum.map(records, & &1.source_id),
        position: Enum.map(records, & &1.position),
        section_type: Enum.map(records, &to_string(&1.section_type)),
        depth: Enum.map(records, & &1.depth),
        heading: Enum.map(records, & &1.heading),
        text: Enum.map(records, & &1.text),
        text_source: Enum.map(records, &to_string(&1.text_source)),
        updated_at: Enum.map(records, & &1.updated_at)
      })

    Explorer.DataFrame.dump_ipc_stream(df)
  end

  defp cast_columns(df, col_names, dtype) do
    Enum.reduce(col_names, df, fn col, acc ->
      series = Explorer.DataFrame.pull(acc, col)
      casted = Explorer.Series.cast(series, dtype)
      Explorer.DataFrame.put(acc, col, casted)
    end)
  end

  # --- Queryable Declaration ---

  defp declare_queryables(session_id) do
    tenant = tenant_id()
    prefix = "fractalaw/@#{tenant}/data/legislation"
    secondary_prefix = "fractalaw/@#{tenant}/data/secondary"
    customers_prefix = "fractalaw/@#{tenant}/sertantai/customers"

    keys = [
      "#{prefix}/lrt",
      "#{prefix}/lrt/*",
      "#{prefix}/lat/*",
      "#{prefix}/amendments/*",
      "#{prefix}/definitions/*",
      "#{secondary_prefix}/sources",
      "#{secondary_prefix}/sources/*",
      "#{secondary_prefix}/provisions/*",
      "#{customers_prefix}",
      "#{customers_prefix}/*/laws"
    ]

    queryable_ids =
      Enum.map(keys, fn key ->
        {:ok, qid} = Zenohex.Session.declare_queryable(session_id, key, self())
        Logger.info("[Zenoh.DataServer] Queryable declared: #{key}")
        qid
      end)

    {queryable_ids, keys}
  end

  defp tenant_id do
    Application.get_env(:sertantai_legal, :zenoh, [])
    |> Keyword.get(:tenant, "dev")
  end
end

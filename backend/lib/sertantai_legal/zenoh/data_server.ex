defmodule SertantaiLegal.Zenoh.DataServer do
  @moduledoc """
  Declares Zenoh queryables for LRT, LAT, and AmendmentAnnotation tables.

  Fractalaw queries these key expressions to pull legislation data on demand.
  Responds with JSON-encoded records.

  Key expressions:
    fractalaw/@{tenant}/data/legislation/lrt           -- all LRT records
    fractalaw/@{tenant}/data/legislation/lrt/{name}    -- single LRT by name
    fractalaw/@{tenant}/data/legislation/lat/{name}    -- LAT sections for a law
    fractalaw/@{tenant}/data/legislation/amendments/{name} -- annotations for a law
  """

  use GenServer
  require Logger

  import Ecto.Query

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Legal.{UkLrt, Lat, AmendmentAnnotation}

  @poll_interval :timer.seconds(2)
  @max_poll_attempts 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    send(self(), :setup)
    {:ok, %{queryable_ids: [], poll_count: 0}}
  end

  @impl true
  def handle_info(:setup, state) do
    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        queryable_ids = declare_queryables(session_id)
        Logger.info("[Zenoh.DataServer] Declared #{length(queryable_ids)} queryables")
        {:noreply, %{state | queryable_ids: queryable_ids}}

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

  # --- Query Handling ---

  defp handle_query(%Zenohex.Query{key_expr: key_expr, zenoh_query: zq} = _query) do
    tenant = tenant_id()
    prefix = "fractalaw/@#{tenant}/data/legislation"

    result =
      case key_expr do
        ^prefix <> "/lrt" ->
          fetch_all_lrt()

        ^prefix <> "/lrt/" <> law_name ->
          fetch_lrt_by_name(law_name)

        ^prefix <> "/lat/" <> law_name ->
          fetch_lat_by_law(law_name)

        ^prefix <> "/amendments/" <> law_name ->
          fetch_amendments_by_law(law_name)

        _ ->
          {:error, :unknown_key}
      end

    case result do
      {:ok, payload} ->
        Zenohex.Query.reply(zq, key_expr, payload, final?: true)

      {:error, reason} ->
        Logger.warning("[Zenoh.DataServer] Query failed for #{key_expr}: #{inspect(reason)}")
        error_payload = Jason.encode!(%{error: to_string(reason)})
        Zenohex.Query.reply(zq, key_expr, error_payload, final?: true)
    end
  rescue
    e ->
      Logger.error("[Zenoh.DataServer] Query error: #{Exception.message(e)}")
  end

  # --- Data Fetching ---

  defp fetch_all_lrt do
    records =
      from(u in UkLrt, order_by: [asc: u.name])
      |> Repo.all()
      |> Enum.map(&serialize_lrt/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_lrt_by_name(law_name) do
    case Repo.one(from(u in UkLrt, where: u.name == ^law_name)) do
      nil -> {:error, :not_found}
      record -> {:ok, Jason.encode!(serialize_lrt(record))}
    end
  end

  defp fetch_lat_by_law(law_name) do
    records =
      from(l in Lat,
        where: l.law_name == ^law_name,
        order_by: [asc: l.sort_key]
      )
      |> Repo.all()
      |> Enum.map(&serialize_lat/1)

    {:ok, Jason.encode!(records)}
  end

  defp fetch_amendments_by_law(law_name) do
    records =
      from(a in AmendmentAnnotation,
        where: a.law_name == ^law_name,
        order_by: [asc: a.id]
      )
      |> Repo.all()
      |> Enum.map(&serialize_amendment/1)

    {:ok, Jason.encode!(records)}
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

  # --- Queryable Declaration ---

  defp declare_queryables(session_id) do
    tenant = tenant_id()
    prefix = "fractalaw/@#{tenant}/data/legislation"

    keys = [
      "#{prefix}/lrt",
      "#{prefix}/lrt/*",
      "#{prefix}/lat/*",
      "#{prefix}/amendments/*"
    ]

    Enum.map(keys, fn key ->
      {:ok, qid} = Zenohex.Session.declare_queryable(session_id, key, self())
      Logger.info("[Zenoh.DataServer] Queryable declared: #{key}")
      qid
    end)
  end

  defp tenant_id do
    Application.get_env(:sertantai_legal, :zenoh, [])
    |> Keyword.get(:tenant, "dev")
  end
end

defmodule SertantaiLegal.Scraper.LatSessionManager do
  @moduledoc """
  Creates LAT parse sessions from existing uk_lrt records.

  LAT parse sessions allow batch LAT re-parsing of making laws, filtered by
  family, type_code, function, and queue_reason. Once created, they use the
  LAT session detail page with streaming progress.

  Distinguished from other session types by `session_type: "lat_parse"` and
  the `lat-parse-` prefix in session_id.

  Format: `lat-parse-{family}[-{type_code}][-{function}]-{YYYY-MM-DD}[-{seq}]`
  """

  alias SertantaiLegal.Scraper.{ScrapeSession, Storage}
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query
  require Logger

  @doc """
  Preview: return count of records matching filters without creating a session.

  ## Filters
  - `family` (required) — e.g. "💙 FIRE", "💚 WASTE"
  - `type_code` (optional) — e.g. "uksi", "ukpga"
  - `function` (optional) — e.g. "Making", "Amending" (key in function JSONB map)
  - `queue_reason` (optional) — "missing" (lat_count=0), "stale" (lat older than 6 months)
  """
  @spec preview(map()) :: {:ok, %{count: integer()}} | {:error, any()}
  def preview(%{"family" => family} = filters) do
    query = build_query(family, filters)

    case Ash.count(query) do
      {:ok, count} -> {:ok, %{count: count}}
      {:error, reason} -> {:error, reason}
    end
  end

  def preview(_), do: {:error, "family is required"}

  @doc """
  Create a LAT parse session from filtered uk_lrt records.

  Returns the created ScrapeSession with session records populated in
  `scrape_session_records` as group1, status pending.
  """
  @spec create(map()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def create(%{"family" => family} = filters) do
    query = build_query(family, filters)

    case Ash.read(query) do
      {:ok, records} when records != [] ->
        session_id = generate_session_id(filters)
        today = Date.utc_today()

        session_attrs = %{
          session_id: session_id,
          session_type: "lat_parse",
          year: today.year,
          month: today.month,
          day_from: today.day,
          day_to: today.day,
          type_code: filters["type_code"],
          status: :reviewing,
          group1_count: length(records)
        }

        with {:ok, session} <- ScrapeSession.create(session_attrs),
             {:ok, session} <- ScrapeSession.mark_reviewing(session) do
          # Bulk-insert session records
          # Keys must match scrape record format: Title_EN, Year, Number (capitalized)
          session_records =
            Enum.map(records, fn record ->
              %{
                name: record.name,
                Title_EN: record.title_en,
                type_code: record.type_code,
                Year: record.year,
                Number: record.number,
                si_code: record.si_code
              }
            end)

          case Storage.save_session_records(session_id, session_records, :group1) do
            {:ok, count} ->
              Logger.info(
                "[LatSessionManager] Created session #{session_id} with #{count} records"
              )

              {:ok, session}

            {:error, reason} ->
              ScrapeSession.destroy(session)
              {:error, "Failed to create session records: #{inspect(reason)}"}
          end
        end

      {:ok, []} ->
        {:error, "No records match the given filters"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create(_), do: {:error, "family is required"}

  @doc """
  Create a LAT parse session from an explicit list of law names.

  Used by the "Reparse View" button which sends the names of all records
  currently displayed in the queue table.
  """
  @spec create_from_names(map()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def create_from_names(%{"names" => names, "label" => label})
      when is_list(names) and names != [] do
    query =
      UkLrt
      |> Ash.Query.filter(name in ^names)
      |> Ash.Query.sort(name: :asc)

    case Ash.read(query) do
      {:ok, records} when records != [] ->
        today = Date.utc_today()

        session_id =
          find_unique_session_id("lat-parse-#{slugify(label)}-#{Date.to_iso8601(today)}")

        session_attrs = %{
          session_id: session_id,
          session_type: "lat_parse",
          year: today.year,
          month: today.month,
          day_from: today.day,
          day_to: today.day,
          status: :reviewing,
          group1_count: length(records)
        }

        with {:ok, session} <- ScrapeSession.create(session_attrs),
             {:ok, session} <- ScrapeSession.mark_reviewing(session) do
          session_records =
            Enum.map(records, fn record ->
              %{
                name: record.name,
                Title_EN: record.title_en,
                type_code: record.type_code,
                Year: record.year,
                Number: record.number,
                si_code: record.si_code
              }
            end)

          case Storage.save_session_records(session_id, session_records, :group1) do
            {:ok, count} ->
              Logger.info(
                "[LatSessionManager] Created from-view session #{session_id} with #{count} records"
              )

              {:ok, session}

            {:error, reason} ->
              ScrapeSession.destroy(session)
              {:error, "Failed to create session records: #{inspect(reason)}"}
          end
        end

      {:ok, []} ->
        {:error, "No records found for the given names"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def create_from_names(_), do: {:error, "names (list) and label are required"}

  @doc """
  Generate a session_id from filters.

  Format: `lat-parse-{family}[-{type_code}][-{function}]-{YYYY-MM-DD}[-{seq}]`
  If a session with the same ID already exists, appends a sequence number.
  """
  @spec generate_session_id(map()) :: String.t()
  def generate_session_id(filters) do
    family = filters["family"]
    type_code = filters["type_code"]
    function = filters["function"]
    today = Date.utc_today() |> Date.to_iso8601()

    base =
      ["lat-parse", slugify(family)]
      |> maybe_append(type_code)
      |> maybe_append(function && String.downcase(function))
      |> Kernel.++([today])
      |> Enum.join("-")

    find_unique_session_id(base)
  end

  # Build an Ash query from filters.
  # Base filters match the LAT queue page's QUEUE_BASE_WHERE + QUEUE_LAT_WHERE:
  #   is_making=true, not classified as not_making, not fully revoked, has title
  # Then applies user-selected optional filters on top.
  defp build_query(family, filters) do
    UkLrt
    |> Ash.Query.filter(family == ^family)
    |> Ash.Query.filter(is_making == true)
    |> Ash.Query.filter(is_nil(making_classification) or making_classification != "not_making")
    |> Ash.Query.filter(not is_nil(title_en))
    |> maybe_filter_type_code(filters["type_code"])
    |> maybe_filter_function(filters["function"])
    |> maybe_filter_queue_reason(filters["queue_reason"])
    |> maybe_filter_live(filters["live"])
    |> Ash.Query.sort(name: :asc)
  end

  defp maybe_filter_type_code(query, nil), do: query
  defp maybe_filter_type_code(query, ""), do: query

  defp maybe_filter_type_code(query, type_code) do
    Ash.Query.filter(query, type_code == ^type_code)
  end

  defp maybe_filter_function(query, nil), do: query
  defp maybe_filter_function(query, ""), do: query

  defp maybe_filter_function(query, function_key) do
    # function is a JSONB map like {"Making": true, "Amending": true}
    Ash.Query.filter(query, fragment("?->>? = 'true'", function, ^function_key))
  end

  # "All (Missing + Stale)" — default: records that need LAT parsing
  defp maybe_filter_queue_reason(query, nil), do: filter_missing_or_stale(query)
  defp maybe_filter_queue_reason(query, ""), do: filter_missing_or_stale(query)

  defp maybe_filter_queue_reason(query, "missing") do
    Ash.Query.filter(query, fragment("COALESCE(?, 0) = 0", lat_count))
  end

  defp maybe_filter_queue_reason(query, "stale") do
    Ash.Query.filter(
      query,
      fragment(
        "? > 0 AND ? > ? + INTERVAL '6 months'",
        lat_count,
        updated_at,
        latest_lat_updated_at
      )
    )
  end

  defp maybe_filter_queue_reason(query, _), do: filter_missing_or_stale(query)

  defp filter_missing_or_stale(query) do
    Ash.Query.filter(
      query,
      fragment(
        "COALESCE(?, 0) = 0 OR (? > 0 AND ? IS NOT NULL AND ? IS NOT NULL AND ? > ? + INTERVAL '6 months')",
        lat_count,
        lat_count,
        updated_at,
        latest_lat_updated_at,
        updated_at,
        latest_lat_updated_at
      )
    )
  end

  defp maybe_filter_live(query, nil), do: query
  defp maybe_filter_live(query, []), do: query

  defp maybe_filter_live(query, live_values) when is_list(live_values) do
    Ash.Query.filter(query, live in ^live_values)
  end

  defp maybe_filter_live(query, _), do: query

  # Slugify a family name for use in session_id
  # "💙 OH&S: Occupational / Personal Safety" -> "ohs-occupational-personal-safety"
  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[&:]/, "")
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp maybe_append(parts, nil), do: parts
  defp maybe_append(parts, ""), do: parts
  defp maybe_append(parts, value), do: parts ++ [value]

  # Find a unique session_id by appending a sequence number if needed
  defp find_unique_session_id(base, seq \\ nil) do
    candidate = if seq, do: "#{base}-#{seq}", else: base

    case ScrapeSession.by_session_id(candidate) do
      {:ok, _existing} ->
        find_unique_session_id(base, (seq || 1) + 1)

      {:error, _} ->
        candidate
    end
  end
end

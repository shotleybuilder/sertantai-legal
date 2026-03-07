defmodule SertantaiLegal.Scraper.ReparseManager do
  @moduledoc """
  Creates reparse sessions from existing uk_lrt records.

  Reparse sessions allow batch re-processing of laws already in the database,
  filtered by family, type_code, and function tags. Once created, they use the
  same session detail page and ParseReviewModal as scrape sessions.

  Distinguished from scrape sessions by the `reparse-` prefix in session_id.
  Format: `reparse-{family}[-{type_code}][-{function}]-{YYYY-MM-DD}[-{seq}]`
  """

  alias SertantaiLegal.Scraper.{ScrapeSession, Storage}
  alias SertantaiLegal.Legal.UkLrt

  require Ash.Query
  require Logger

  @doc """
  Preview: return count of records matching filters without creating a session.

  ## Filters
  - `family` (required) — e.g. "FIRE", "OH&S: Occupational Safety"
  - `family_ii` (optional) — sub-family refinement
  - `type_code` (optional) — e.g. "uksi", "ukpga"
  - `function` (optional) — e.g. "Making", "Amending" (key in function JSONB map)
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
  Create a reparse session from filtered uk_lrt records.

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

        # Create the session using existing :create action with current date
        session_attrs = %{
          session_id: session_id,
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
          session_records =
            Enum.map(records, fn record ->
              %{name: record.name, Title_EN: record.title_en, type_code: record.type_code}
            end)

          case Storage.save_session_records(session_id, session_records, :group1) do
            {:ok, count} ->
              Logger.info("[ReparseManager] Created session #{session_id} with #{count} records")

              {:ok, session}

            {:error, reason} ->
              # Clean up the session if record insertion failed
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
  Generate a session_id from filters.

  Format: `reparse-{family}[-{type_code}][-{function}]-{YYYY-MM-DD}[-{seq}]`
  If a session with the same ID already exists, appends a sequence number.
  """
  @spec generate_session_id(map()) :: String.t()
  def generate_session_id(filters) do
    family = filters["family"]
    type_code = filters["type_code"]
    function = filters["function"]
    today = Date.utc_today() |> Date.to_iso8601()

    base =
      ["reparse", slugify(family)]
      |> maybe_append(type_code)
      |> maybe_append(function && String.downcase(function))
      |> Kernel.++([today])
      |> Enum.join("-")

    find_unique_session_id(base)
  end

  # Build an Ash query from filters
  defp build_query(family, filters) do
    UkLrt
    |> Ash.Query.filter(family == ^family)
    |> maybe_filter_family_ii(filters["family_ii"])
    |> maybe_filter_type_code(filters["type_code"])
    |> maybe_filter_function(filters["function"])
    |> Ash.Query.sort(name: :asc)
  end

  defp maybe_filter_family_ii(query, nil), do: query
  defp maybe_filter_family_ii(query, ""), do: query

  defp maybe_filter_family_ii(query, family_ii) do
    Ash.Query.filter(query, family_ii == ^family_ii)
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
    # Filter where function->>key = 'true'
    Ash.Query.filter(query, fragment("?->>? = 'true'", function, ^function_key))
  end

  # Slugify a family name for use in session_id
  # "OH&S: Occupational Safety" -> "ohs-occupational-safety"
  defp slugify(name) do
    name
    |> String.downcase()
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

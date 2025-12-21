defmodule SertantaiLegal.Scraper.SessionManager do
  @moduledoc """
  Manages scraping sessions for legislation.gov.uk new laws.

  This is the main entry point for the scraping workflow:

  1. create_and_scrape/4 - Create session, scrape, save raw.json
  2. categorize/1 - Read raw.json, categorize into 3 groups
  3. (User reviews JSON files in IDE)
  4. persist_group/2 or persist_all/1 - Save to uk_lrt table

  ## Usage in IEx

      alias SertantaiLegal.Scraper.SessionManager

      # Create and scrape
      {:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)

      # Categorize
      {:ok, session} = SessionManager.categorize(session.session_id)

      # After review, persist
      {:ok, session} = SessionManager.persist_group(session.session_id, :group1)
  """

  alias SertantaiLegal.Scraper.ScrapeSession
  alias SertantaiLegal.Scraper.NewLaws
  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.Categorizer
  alias SertantaiLegal.Scraper.Persister

  @doc """
  Generate a session ID from date parameters.
  """
  @spec generate_session_id(integer(), integer(), integer(), integer()) :: String.t()
  def generate_session_id(year, month, day_from, day_to) do
    month_str = String.pad_leading(Integer.to_string(month), 2, "0")
    from_str = String.pad_leading(Integer.to_string(day_from), 2, "0")
    to_str = String.pad_leading(Integer.to_string(day_to), 2, "0")
    "#{year}-#{month_str}-#{from_str}-to-#{to_str}"
  end

  @doc """
  Create a new scraping session.
  """
  @spec create(integer(), integer(), integer(), integer(), String.t() | nil) ::
          {:ok, ScrapeSession.t()} | {:error, any()}
  def create(year, month, day_from, day_to, type_code \\ nil) do
    session_id = generate_session_id(year, month, day_from, day_to)

    # Check if session already exists
    case ScrapeSession.by_session_id(session_id) do
      {:ok, existing} ->
        IO.puts("Session #{session_id} already exists with status: #{existing.status}")
        {:ok, existing}

      {:error, _} ->
        # Create new session
        ScrapeSession.create(%{
          session_id: session_id,
          year: year,
          month: month,
          day_from: day_from,
          day_to: day_to,
          type_code: type_code
        })
    end
  end

  @doc """
  Create a session and immediately scrape.

  This is the main entry point for starting a new scraping session.
  """
  @spec create_and_scrape(integer(), integer(), integer(), integer(), String.t() | nil) ::
          {:ok, ScrapeSession.t()} | {:error, any()}
  def create_and_scrape(year, month, day_from, day_to, type_code \\ nil) do
    with {:ok, session} <- create(year, month, day_from, day_to, type_code),
         {:ok, session} <- scrape(session) do
      {:ok, session}
    end
  end

  @doc """
  Scrape legislation.gov.uk for the session's date range.

  Saves results to raw.json in the session directory.
  """
  @spec scrape(ScrapeSession.t() | String.t()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def scrape(%ScrapeSession{} = session) do
    IO.puts("\n=== SCRAPING SESSION: #{session.session_id} ===")

    # Mark as scraping
    {:ok, session} = ScrapeSession.mark_scraping(session)

    # fetch_range always returns {:ok, records} (errors on individual days are logged but not propagated)
    {:ok, records} = NewLaws.fetch_range(session.year, session.month, session.day_from, session.day_to, session.type_code)

    # Save to raw.json
    case Storage.save_json(session.session_id, :raw, records) do
      :ok ->
        ScrapeSession.mark_scraped(session, %{
          total_fetched: Enum.count(records),
          raw_file: Storage.relative_path(session.session_id, :raw)
        })

      {:error, reason} ->
        ScrapeSession.mark_failed(session, %{error_message: "Failed to save: #{reason}"})
    end
  end

  def scrape(session_id) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> scrape(session)
      error -> error
    end
  end

  @doc """
  Categorize a scraped session into three groups.

  Reads raw.json and saves:
  - inc_w_si.json (Group 1)
  - inc_wo_si.json (Group 2)
  - exc.json (Group 3)
  """
  @spec categorize(ScrapeSession.t() | String.t()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def categorize(%ScrapeSession{} = session) do
    case Categorizer.categorize(session.session_id) do
      {:ok, counts} ->
        ScrapeSession.mark_categorized(session, %{
          title_excluded_count: counts.title_excluded_count,
          group1_count: counts.group1_count,
          group2_count: counts.group2_count,
          group3_count: counts.group3_count,
          group1_file: Storage.relative_path(session.session_id, :group1),
          group2_file: Storage.relative_path(session.session_id, :group2),
          group3_file: Storage.relative_path(session.session_id, :group3)
        })

      {:error, reason} ->
        ScrapeSession.mark_failed(session, %{error_message: "Categorization failed: #{reason}"})
    end
  end

  def categorize(session_id) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> categorize(session)
      error -> error
    end
  end

  @doc """
  Full workflow: create, scrape, and categorize.
  """
  @spec run(integer(), integer(), integer(), integer(), String.t() | nil) ::
          {:ok, ScrapeSession.t()} | {:error, any()}
  def run(year, month, day_from, day_to, type_code \\ nil) do
    with {:ok, session} <- create_and_scrape(year, month, day_from, day_to, type_code),
         {:ok, session} <- categorize(session) do
      print_session_summary(session)
      {:ok, session}
    end
  end

  @doc """
  Mark session as under review.
  """
  @spec mark_reviewing(ScrapeSession.t() | String.t()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def mark_reviewing(%ScrapeSession{} = session) do
    ScrapeSession.mark_reviewing(session)
  end

  def mark_reviewing(session_id) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> mark_reviewing(session)
      error -> error
    end
  end

  @doc """
  Persist a specific group to the uk_lrt table.

  Groups: :group1, :group2, :group3
  """
  @spec persist_group(ScrapeSession.t() | String.t(), atom()) ::
          {:ok, ScrapeSession.t()} | {:error, any()}
  def persist_group(%ScrapeSession{} = session, group) when group in [:group1, :group2, :group3] do
    case Persister.persist_group(session.session_id, group) do
      {:ok, count} ->
        new_count = (session.persisted_count || 0) + count
        ScrapeSession.update(session, %{persisted_count: new_count})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def persist_group(session_id, group) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> persist_group(session, group)
      error -> error
    end
  end

  @doc """
  Persist all groups (1 and 2) to the uk_lrt table.

  Group 3 is excluded by default - use persist_group/2 to persist specific records.
  """
  @spec persist_all(ScrapeSession.t() | String.t()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def persist_all(%ScrapeSession{} = session) do
    with {:ok, session} <- persist_group(session, :group1),
         {:ok, session} <- persist_group(session, :group2) do
      ScrapeSession.mark_completed(session, %{persisted_count: session.persisted_count})
    end
  end

  def persist_all(session_id) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> persist_all(session)
      error -> error
    end
  end

  @doc """
  Get a session by session_id.
  """
  @spec get(String.t()) :: {:ok, ScrapeSession.t()} | {:error, any()}
  def get(session_id) do
    ScrapeSession.by_session_id(session_id)
  end

  @doc """
  List recent sessions.
  """
  @spec list_recent() :: {:ok, list(ScrapeSession.t())} | {:error, any()}
  def list_recent do
    ScrapeSession.recent()
  end

  @doc """
  List active (non-completed) sessions.
  """
  @spec list_active() :: {:ok, list(ScrapeSession.t())} | {:error, any()}
  def list_active do
    ScrapeSession.active()
  end

  @doc """
  Delete a session and its files.
  """
  @spec delete(ScrapeSession.t() | String.t()) :: :ok | {:error, any()}
  def delete(%ScrapeSession{} = session) do
    with :ok <- Storage.delete_session(session.session_id),
         {:ok, _} <- ScrapeSession.destroy(session) do
      :ok
    end
  end

  def delete(session_id) when is_binary(session_id) do
    case get(session_id) do
      {:ok, session} -> delete(session)
      error -> error
    end
  end

  @doc """
  Print session summary.
  """
  @spec print_session_summary(ScrapeSession.t()) :: :ok
  def print_session_summary(%ScrapeSession{} = session) do
    IO.puts("\n=== SESSION SUMMARY ===")
    IO.puts("Session ID:      #{session.session_id}")
    IO.puts("Status:          #{session.status}")
    IO.puts("Date range:      #{session.year}-#{session.month}-#{session.day_from} to #{session.day_to}")
    IO.puts("Total fetched:   #{session.total_fetched}")
    IO.puts("Group 1 (SI):    #{session.group1_count}")
    IO.puts("Group 2 (Term):  #{session.group2_count}")
    IO.puts("Group 3 (Exc):   #{session.group3_count}")
    IO.puts("Persisted:       #{session.persisted_count}")
    IO.puts("")
    IO.puts("Files location:  #{Storage.session_path(session.session_id)}")
    IO.puts("=======================")
    :ok
  end

  @doc """
  Open session directory in file manager (for review).
  """
  @spec open_session_dir(String.t()) :: :ok | {:error, any()}
  def open_session_dir(session_id) do
    path = Storage.session_path(session_id)

    case System.cmd("xdg-open", [path], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> {:error, error}
    end
  end
end

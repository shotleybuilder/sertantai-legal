defmodule SertantaiLegal.Scraper.SessionManagerTest do
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.SessionManager
  alias SertantaiLegal.Scraper.ScrapeSession
  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @test_session_id "2024-12-02-to-05"

  setup do
    # Stub HTTP responses for both HTML (new laws) and XML (metadata)
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/introduction/data.xml") ->
          xml = fixture("introduction_sample.xml")
          Req.Test.text(conn, xml)

        true ->
          html = fixture("new_laws_sample.html")
          Req.Test.html(conn, html)
      end
    end)

    # Clean up any existing test session
    Storage.delete_session(@test_session_id)

    case ScrapeSession.by_session_id(@test_session_id) do
      {:ok, existing} -> ScrapeSession.destroy(existing)
      _ -> :ok
    end

    on_exit(fn ->
      Storage.delete_session(@test_session_id)

      case ScrapeSession.by_session_id(@test_session_id) do
        {:ok, existing} -> ScrapeSession.destroy(existing)
        _ -> :ok
      end
    end)

    :ok
  end

  describe "generate_session_id/4" do
    test "generates correct format" do
      id = SessionManager.generate_session_id(2024, 12, 2, 5)
      assert id == "2024-12-02-to-05"
    end

    test "pads single digit month and days" do
      id = SessionManager.generate_session_id(2024, 1, 1, 9)
      assert id == "2024-01-01-to-09"
    end
  end

  describe "create/4" do
    test "creates a new session record" do
      {:ok, session} = SessionManager.create(2024, 12, 2, 5)

      assert session.session_id == "2024-12-02-to-05"
      assert session.year == 2024
      assert session.month == 12
      assert session.day_from == 2
      assert session.day_to == 5
      assert session.status == :pending
    end

    test "returns existing session if already exists" do
      {:ok, first} = SessionManager.create(2024, 12, 2, 5)
      {:ok, second} = SessionManager.create(2024, 12, 2, 5)

      assert first.id == second.id
    end

    test "accepts optional type_code" do
      {:ok, session} = SessionManager.create(2024, 12, 2, 5, "uksi")

      assert session.type_code == "uksi"
    end
  end

  describe "create_and_scrape/4" do
    test "creates session and scrapes data" do
      {:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)

      assert session.session_id == @test_session_id
      assert session.status == :scraping
      assert session.total_fetched > 0
      assert session.raw_file != nil
    end

    test "saves raw.json file" do
      {:ok, _session} = SessionManager.create_and_scrape(2024, 12, 2, 5)

      assert Storage.file_exists?(@test_session_id, :raw)
    end
  end

  describe "categorize/1" do
    test "categorizes a scraped session" do
      {:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)
      {:ok, session} = SessionManager.categorize(session)

      assert session.status == :categorized
      assert session.group1_count >= 0
      assert session.group2_count >= 0
      assert session.group3_count >= 0
    end

    test "saves group files" do
      {:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)
      {:ok, _session} = SessionManager.categorize(session)

      assert Storage.file_exists?(@test_session_id, :group1)
      assert Storage.file_exists?(@test_session_id, :group2)
      assert Storage.file_exists?(@test_session_id, :group3)
    end

    test "accepts session_id string" do
      {:ok, _} = SessionManager.create_and_scrape(2024, 12, 2, 5)
      {:ok, session} = SessionManager.categorize(@test_session_id)

      assert session.status == :categorized
    end
  end

  describe "run/4" do
    test "runs full workflow: create, scrape, categorize" do
      {:ok, session} = SessionManager.run(2024, 12, 2, 5)

      assert session.status == :categorized
      assert session.total_fetched > 0
      assert Storage.file_exists?(@test_session_id, :raw)
      assert Storage.file_exists?(@test_session_id, :group1)
    end
  end

  describe "get/1" do
    test "retrieves session by session_id" do
      {:ok, created} = SessionManager.create(2024, 12, 2, 5)
      {:ok, retrieved} = SessionManager.get(@test_session_id)

      assert retrieved.id == created.id
    end

    test "returns error for non-existent session" do
      {:error, _} = SessionManager.get("nonexistent-session")
    end
  end

  describe "delete/1" do
    test "deletes session and files" do
      {:ok, session} = SessionManager.create_and_scrape(2024, 12, 2, 5)

      assert Storage.file_exists?(@test_session_id, :raw)

      :ok = SessionManager.delete(session)

      refute Storage.session_exists?(@test_session_id)
      {:error, _} = SessionManager.get(@test_session_id)
    end

    test "accepts session_id string" do
      {:ok, _} = SessionManager.create_and_scrape(2024, 12, 2, 5)

      :ok = SessionManager.delete(@test_session_id)

      {:error, _} = SessionManager.get(@test_session_id)
    end
  end

  describe "list_recent/0" do
    test "returns recent sessions" do
      {:ok, _} = SessionManager.create(2024, 12, 2, 5)

      {:ok, sessions} = SessionManager.list_recent()

      assert length(sessions) >= 1
    end
  end

  describe "list_active/0" do
    test "returns active sessions" do
      {:ok, _} = SessionManager.create(2024, 12, 2, 5)

      {:ok, sessions} = SessionManager.list_active()

      # Our test session should be in active list (status: pending)
      session_ids = Enum.map(sessions, & &1.session_id)
      assert @test_session_id in session_ids
    end
  end

  defp fixture(name) do
    Path.join([
      File.cwd!(),
      "test/fixtures/legislation_gov_uk",
      name
    ])
    |> File.read!()
  end
end

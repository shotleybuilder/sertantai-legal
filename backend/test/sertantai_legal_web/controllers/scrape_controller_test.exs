defmodule SertantaiLegalWeb.ScrapeControllerTest do
  use SertantaiLegalWeb.ConnCase

  alias SertantaiLegal.Scraper.ScrapeSession
  alias SertantaiLegal.Scraper.Storage

  @test_session_id "test-2024-12-01-to-05"

  setup do
    # Clean up any test session files
    Storage.delete_session(@test_session_id)
    on_exit(fn -> Storage.delete_session(@test_session_id) end)
    :ok
  end

  describe "POST /api/scrape" do
    test "returns 400 when year is missing", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{month: 12, day_from: 1, day_to: 5})

      assert json_response(conn, 400)["error"] =~ "Invalid year"
    end

    test "returns 400 when month is missing", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{year: 2024, day_from: 1, day_to: 5})

      assert json_response(conn, 400)["error"] =~ "Invalid month"
    end

    test "returns 400 when day_from is missing", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{year: 2024, month: 12, day_to: 5})

      assert json_response(conn, 400)["error"] =~ "Invalid day_from"
    end

    test "returns 400 when day_to is missing", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{year: 2024, month: 12, day_from: 1})

      assert json_response(conn, 400)["error"] =~ "Invalid day_to"
    end

    test "returns 400 when year is not an integer", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{year: "abc", month: 12, day_from: 1, day_to: 5})

      assert json_response(conn, 400)["error"] =~ "Invalid year"
    end

    # Note: We don't test the full create flow here because it makes HTTP calls
    # to legislation.gov.uk. Integration tests would be in a separate file.
  end

  describe "GET /api/sessions" do
    test "returns empty list when no sessions exist", %{conn: conn} do
      conn = get(conn, "/api/sessions")

      response = json_response(conn, 200)
      assert is_list(response["sessions"])
    end

    test "returns sessions when they exist", %{conn: conn} do
      # Create a session directly
      {:ok, _session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      conn = get(conn, "/api/sessions")

      response = json_response(conn, 200)
      assert length(response["sessions"]) >= 1

      session = Enum.find(response["sessions"], fn s -> s["session_id"] == @test_session_id end)
      assert session != nil
      assert session["year"] == 2024
      assert session["month"] == 12
    end
  end

  describe "GET /api/sessions/:id" do
    test "returns 404 when session does not exist", %{conn: conn} do
      conn = get(conn, "/api/sessions/nonexistent-session")

      assert json_response(conn, 404)["error"] == "Session not found"
    end

    test "returns session when it exists", %{conn: conn} do
      {:ok, _session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      conn = get(conn, "/api/sessions/#{@test_session_id}")

      response = json_response(conn, 200)
      assert response["session_id"] == @test_session_id
      assert response["year"] == 2024
      assert response["month"] == 12
      assert response["day_from"] == 1
      assert response["day_to"] == 5
      assert response["status"] == "pending"
    end
  end

  describe "GET /api/sessions/:id/group/:group" do
    setup do
      {:ok, _session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      :ok
    end

    test "returns 400 for invalid group", %{conn: conn} do
      conn = get(conn, "/api/sessions/#{@test_session_id}/group/4")

      assert json_response(conn, 400)["error"] =~ "Invalid group"
    end

    test "returns 400 for non-numeric group", %{conn: conn} do
      conn = get(conn, "/api/sessions/#{@test_session_id}/group/invalid")

      assert json_response(conn, 400)["error"] =~ "Invalid group"
    end

    test "returns 404 when session does not exist", %{conn: conn} do
      conn = get(conn, "/api/sessions/nonexistent/group/1")

      assert json_response(conn, 404)["error"] == "Session not found"
    end

    test "returns 404 when group file does not exist", %{conn: conn} do
      conn = get(conn, "/api/sessions/#{@test_session_id}/group/1")

      response = json_response(conn, 404)
      assert response["error"] =~ "Group file not found"
    end

    test "returns records when group file exists", %{conn: conn} do
      # Create a group file
      records = [
        %{Title_EN: "Test Law 1", type_code: "uksi", Year: 2024, Number: "1"},
        %{Title_EN: "Test Law 2", type_code: "uksi", Year: 2024, Number: "2"}
      ]

      :ok = Storage.save_json(@test_session_id, :group1, records)

      conn = get(conn, "/api/sessions/#{@test_session_id}/group/1")

      response = json_response(conn, 200)
      assert response["session_id"] == @test_session_id
      assert response["group"] == "1"
      assert response["count"] == 2
      assert length(response["records"]) == 2
    end

    test "returns indexed records for group 3", %{conn: conn} do
      # Group 3 uses indexed map format
      records = %{
        "1" => %{Title_EN: "Excluded Law 1"},
        "2" => %{Title_EN: "Excluded Law 2"}
      }

      :ok = Storage.save_json(@test_session_id, :group3, records)

      conn = get(conn, "/api/sessions/#{@test_session_id}/group/3")

      response = json_response(conn, 200)
      assert response["count"] == 2
      # Records should be normalized to list with _index
      assert is_list(response["records"])
    end
  end

  describe "POST /api/sessions/:id/persist/:group" do
    setup do
      {:ok, session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      {:ok, session: session}
    end

    test "returns 400 for invalid group", %{conn: conn} do
      conn = post(conn, "/api/sessions/#{@test_session_id}/persist/0")

      assert json_response(conn, 400)["error"] =~ "Invalid group"
    end

    test "returns 404 when session does not exist", %{conn: conn} do
      conn = post(conn, "/api/sessions/nonexistent/persist/1")

      assert json_response(conn, 404)["error"] == "Session not found"
    end

    test "returns error when group file does not exist", %{conn: conn} do
      conn = post(conn, "/api/sessions/#{@test_session_id}/persist/1")

      response = json_response(conn, 422)
      assert response["error"] != nil
    end

    # Note: Full persist integration test requires properly configured Ash actions.
    # The Persister module handles the actual persistence logic which is tested separately.
    @tag :skip
    test "persists group when file exists", %{conn: conn} do
      # Create a group file with minimal records
      records = [
        %{
          Title_EN: "Test Persist Law",
          type_code: "uksi",
          Year: 2024,
          Number: "999",
          Family: "test"
        }
      ]

      :ok = Storage.save_json(@test_session_id, :group1, records)

      conn = post(conn, "/api/sessions/#{@test_session_id}/persist/1")

      response = json_response(conn, 200)
      assert response["message"] =~ "persisted successfully"
      assert response["session"]["session_id"] == @test_session_id
    end
  end

  describe "POST /api/sessions/:id/parse/:group" do
    setup do
      {:ok, _session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      :ok
    end

    test "returns 400 for invalid group", %{conn: conn} do
      conn = post(conn, "/api/sessions/#{@test_session_id}/parse/invalid")

      assert json_response(conn, 400)["error"] =~ "Invalid group"
    end

    test "returns 404 when session does not exist", %{conn: conn} do
      conn = post(conn, "/api/sessions/nonexistent/parse/1")

      assert json_response(conn, 404)["error"] == "Session not found"
    end

    test "returns error when group file does not exist", %{conn: conn} do
      conn = post(conn, "/api/sessions/#{@test_session_id}/parse/1")

      response = json_response(conn, 422)
      assert response["error"] != nil
    end

    # Note: We don't test the full parse flow here because it makes HTTP calls
    # to legislation.gov.uk XML API. This would be tested with mocks or stubs.
  end

  describe "DELETE /api/sessions/:id" do
    test "returns 404 when session does not exist", %{conn: conn} do
      conn = delete(conn, "/api/sessions/nonexistent-session")

      assert json_response(conn, 404)["error"] == "Session not found"
    end

    test "deletes session when it exists", %{conn: conn} do
      {:ok, _session} =
        ScrapeSession.create(%{
          session_id: @test_session_id,
          year: 2024,
          month: 12,
          day_from: 1,
          day_to: 5
        })

      # Create some files
      Storage.save_json(@test_session_id, :raw, [%{test: true}])
      assert Storage.session_exists?(@test_session_id)

      conn = delete(conn, "/api/sessions/#{@test_session_id}")

      assert json_response(conn, 200)["message"] == "Session deleted"

      # Verify session and files are deleted
      refute Storage.session_exists?(@test_session_id)
    end
  end

  describe "parameter validation" do
    # Note: Full scrape integration test requires HTTP mocking.
    # Parameter validation is tested via the 400 error tests above.
    # This test would make actual HTTP calls to legislation.gov.uk.
    @tag :skip
    test "accepts integer parameters as strings", %{conn: conn} do
      # This should not error on parameter parsing
      conn = post(conn, "/api/scrape", %{"year" => "2024", "month" => "12", "day_from" => "1", "day_to" => "5"})

      # Will fail due to HTTP call, but not due to parameter parsing
      # The error should be about the scrape failing, not about invalid parameters
      response = json_response(conn, 422)
      refute response["error"] =~ "Invalid year"
      refute response["error"] =~ "Invalid month"
    end

    test "rejects non-integer year string", %{conn: conn} do
      conn = post(conn, "/api/scrape", %{"year" => "abc", "month" => "12", "day_from" => "1", "day_to" => "5"})

      assert json_response(conn, 400)["error"] =~ "Invalid year"
    end

    # Note: Testing that valid params proceed to scrape requires HTTP mocking.
    # The rejection tests above validate the parameter parsing logic.
  end
end

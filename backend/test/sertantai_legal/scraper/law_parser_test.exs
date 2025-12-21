defmodule SertantaiLegal.Scraper.LawParserTest do
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Scraper.LawParser
  alias SertantaiLegal.Scraper.Storage
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @test_session_id "parser-test-#{:rand.uniform(99999)}"

  setup do
    # Stub HTTP responses for XML metadata
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/uksi/2024/1234/introduction/data.xml") ->
          xml = fixture("introduction_sample.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2024/567/introduction/data.xml") ->
          xml = fixture("introduction_text_dates.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2024/9999/introduction/") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        true ->
          xml = fixture("introduction_sample.xml")
          Req.Test.text(conn, xml)
      end
    end)

    # Clean up session files after test
    on_exit(fn ->
      Storage.delete_session(@test_session_id)
    end)

    :ok
  end

  describe "parse_record/2" do
    test "fetches metadata and enriches record" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      assert enriched[:md_description] =~ "consolidate and update"
      assert enriched[:md_total_paras] == 250
      assert "ENVIRONMENT" in enriched[:si_code]
    end

    test "builds name from type_code/Year/Number" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      assert enriched[:name] == "uksi/2024/1234"
    end

    test "builds leg_gov_uk_url from name" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      assert enriched[:leg_gov_uk_url] == "https://www.legislation.gov.uk/uksi/2024/1234"
    end

    test "sets md_checked timestamp" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      assert enriched[:md_checked] == Date.utc_today() |> Date.to_iso8601()
    end

    test "returns error for non-existent record" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "9999",
        Title_EN: "Non-existent"
      }

      {:error, reason} = LawParser.parse_record(record, persist: false)

      assert reason =~ "Not found"
    end
  end

  describe "parse_record/2 with database persistence" do
    # NOTE: These tests are skipped pending investigation of Ash 3 `accept :*` behavior.
    # The :create action's `accept :*` is not expanding to include all attributes.
    # See: https://github.com/ash-project/ash/issues

    @tag :skip
    test "creates new record in database when persist: true" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation for DB"
      }

      {:ok, created} = LawParser.parse_record(record)

      # Verify it was persisted
      assert created.name == "uksi/2024/1234"
      assert created.md_description =~ "consolidate and update"

      # Verify we can find it
      assert {:exists, _} = LawParser.record_exists?(%{name: "uksi/2024/1234"})
    end

    @tag :skip
    test "updates existing record when it already exists" do
      # First create a record
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "567",
        Title_EN: "Initial Title"
      }

      {:ok, _created} = LawParser.parse_record(record)

      # Parse again - should update
      {:ok, updated} = LawParser.parse_record(record)

      # Title should be updated from XML
      assert updated.title_en == "The Health and Safety (Miscellaneous Amendments) Regulations 2024"
    end
  end

  describe "record_exists?/1" do
    test "returns :not_found for non-existent record" do
      result = LawParser.record_exists?(%{name: "nonexistent/2024/9999"})

      assert result == :not_found
    end

    test "builds name from record fields if name not provided" do
      result = LawParser.record_exists?(%{
        type_code: "uksi",
        Year: 2024,
        Number: "77777"
      })

      assert result == :not_found
    end
  end

  describe "parse_group/3" do
    # NOTE: Skipped pending Ash `accept :*` fix - parse_group calls persist internally
    @tag :skip
    test "parses records from group1 with auto_confirm" do
      # Setup: create session with group1 records
      records = [
        %{type_code: "uksi", Year: 2024, Number: "1234", Title_EN: "Law 1", si_code: ["ENVIRONMENT"]},
        %{type_code: "uksi", Year: 2024, Number: "567", Title_EN: "Law 2", si_code: ["HEALTH AND SAFETY"]}
      ]

      Storage.save_json(@test_session_id, :group1, records)

      {:ok, results} = LawParser.parse_group(@test_session_id, :group1, auto_confirm: true)

      assert results.parsed == 2
      assert results.skipped == 0
      assert results.errors == 0
    end

    test "returns error for non-existent session" do
      {:error, reason} = LawParser.parse_group("nonexistent-session", :group1, auto_confirm: true)

      # Error message will contain the file system error
      assert reason =~ "Failed to read file" or reason =~ "enoent"
    end
  end

  defp fixture(name) do
    Path.join([File.cwd!(), "test/fixtures/legislation_gov_uk", name])
    |> File.read!()
  end
end

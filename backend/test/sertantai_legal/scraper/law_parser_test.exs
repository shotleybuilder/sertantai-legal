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

    test "builds name in UK_{type_code}_{year}_{number} format" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      assert enriched[:name] == "UK_uksi_2024_1234"
    end

    # Note: leg_gov_uk_url is now a PostgreSQL generated column, not set by parser

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

    test "includes md_date (primary date) from metadata" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation"
      }

      {:ok, enriched} = LawParser.parse_record(record, persist: false)

      # md_date should be calculated from enactment/coming_into_force/made dates
      # introduction_sample.xml has md_enactment_date = "2024-12-01"
      assert enriched[:md_date] == "2024-12-01"
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
    test "creates new record in database when persist: true" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation for DB"
      }

      {:ok, created} = LawParser.parse_record(record)

      # Verify it was persisted with correct name format
      assert created.name == "UK_uksi_2024_1234"
      assert created.md_description =~ "consolidate and update"

      # Verify we can find it
      assert {:exists, _} = LawParser.record_exists?(%{name: "UK_uksi_2024_1234"})
    end

    test "persists md_date to database" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation with md_date"
      }

      {:ok, created} = LawParser.parse_record(record)

      # md_date should be persisted (from introduction_sample.xml enactment_date)
      assert created.md_date == ~D[2024-12-01]
    end

    test "persists si_code as JSONB map to database" do
      record = %{
        type_code: "uksi",
        Year: 2024,
        Number: "1234",
        Title_EN: "Test Regulation with SI Code"
      }

      {:ok, created} = LawParser.parse_record(record)

      # si_code should be persisted as JSONB with "values" key
      # introduction_sample.xml has SIheading: "ENVIRONMENT; POLLUTION"
      assert created.si_code == %{"values" => ["ENVIRONMENT", "POLLUTION"]}
    end

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

      # Title should be preserved from original record (not overwritten by XML)
      # This behavior was fixed to prevent "The " prefix from XML being used
      assert updated.title_en == "Initial Title"
    end
  end

  describe "record_exists?/1" do
    test "returns :not_found for non-existent record" do
      result = LawParser.record_exists?(%{name: "nonexistent/2024/9999"})

      assert result == :not_found
    end

    test "builds name from record fields if name not provided" do
      result =
        LawParser.record_exists?(%{
          type_code: "uksi",
          Year: 2024,
          Number: "77777"
        })

      assert result == :not_found
    end
  end

  describe "parse_group/3" do
    test "parses records from group1 with auto_confirm" do
      # Setup: create session with group1 records
      records = [
        %{
          type_code: "uksi",
          Year: 2024,
          Number: "1234",
          Title_EN: "Law 1",
          si_code: ["ENVIRONMENT"]
        },
        %{
          type_code: "uksi",
          Year: 2024,
          Number: "567",
          Title_EN: "Law 2",
          si_code: ["HEALTH AND SAFETY"]
        }
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

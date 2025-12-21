defmodule SertantaiLegal.Scraper.NewLawsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.NewLaws
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  setup do
    # Stub HTTP responses for this test module
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/new/") ->
          html = fixture("new_laws_sample.html")
          Req.Test.html(conn, html)

        true ->
          Plug.Conn.send_resp(conn, 404, "Not found")
      end
    end)

    :ok
  end

  describe "fetch/1" do
    test "fetches and parses laws for a single date" do
      {:ok, records} = NewLaws.fetch(2024, 12, 1)

      assert length(records) == 10
      assert Enum.all?(records, fn r -> Map.has_key?(r, :name) end)
      assert Enum.all?(records, fn r -> Map.has_key?(r, :Title_EN) end)
    end

    test "adds name field in correct format" do
      {:ok, records} = NewLaws.fetch(2024, 12, 1)

      record = Enum.find(records, fn r -> r[:Number] == "1001" end)

      assert record[:name] == "uksi/2024/1001"
    end

    test "adds leg_gov_uk_url field" do
      {:ok, records} = NewLaws.fetch(2024, 12, 1)

      record = Enum.find(records, fn r -> r[:Number] == "1001" end)

      assert record[:leg_gov_uk_url] == "https://www.legislation.gov.uk/uksi/2024/1001"
    end
  end

  describe "fetch_range/4" do
    test "fetches laws for a date range" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 3, nil, fetch_metadata: false)

      # Same fixture returned for each day, so we get 3x10 = 30 records
      # (publication_date differs so they're not deduplicated)
      assert length(records) == 30
    end

    test "adds publication_date for each day" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 3, nil, fetch_metadata: false)

      # Each record should have publication_date
      assert Enum.all?(records, fn r -> Map.has_key?(r, :publication_date) end)

      # We should have records from multiple days
      dates = records |> Enum.map(& &1[:publication_date]) |> Enum.uniq()
      assert length(dates) == 3
    end
  end

  describe "fetch_range/5 with type_code filter" do
    test "includes all types when type_code is nil" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, nil, fetch_metadata: false)

      type_codes = records |> Enum.map(& &1[:type_code]) |> Enum.uniq()

      # Should have both uksi and ukpga from our fixture
      assert "uksi" in type_codes
      assert "ukpga" in type_codes
    end

    test "passes type_code in URL" do
      # This test just verifies the function accepts a type_code parameter
      # The mock returns all records regardless of URL path
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, "uksi", fetch_metadata: false)

      # Still returns 10 records (mock doesn't filter)
      assert length(records) == 10
    end
  end

  describe "fetch_range with metadata enrichment" do
    setup do
      # Add mock for metadata XML endpoints
      Req.Test.stub(Client, fn conn ->
        path = conn.request_path

        cond do
          String.contains?(path, "/new/") ->
            html = fixture("new_laws_sample.html")
            Req.Test.html(conn, html)

          String.contains?(path, "/introduction/data.xml") ->
            xml = fixture("introduction_sample.xml")
            Req.Test.text(conn, xml)

          true ->
            Plug.Conn.send_resp(conn, 404, "Not found")
        end
      end)

      :ok
    end

    test "enriches records with metadata when fetch_metadata: true" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, nil, fetch_metadata: true)

      # Records should have metadata fields from XML
      record = hd(records)
      assert record[:si_code] != nil
      assert record[:SICode] != nil
      assert is_list(record[:SICode])
    end

    test "si_code is comma-separated string" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, nil, fetch_metadata: true)

      record = hd(records)
      # From fixture: "ENVIRONMENT; POLLUTION" becomes "ENVIRONMENT,POLLUTION"
      assert record[:si_code] == "ENVIRONMENT,POLLUTION"
    end

    test "SICode is list of codes" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, nil, fetch_metadata: true)

      record = hd(records)
      assert "ENVIRONMENT" in record[:SICode]
      assert "POLLUTION" in record[:SICode]
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

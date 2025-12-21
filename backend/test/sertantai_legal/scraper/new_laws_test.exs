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
      assert Enum.all?(records, fn r -> Map.has_key?(r, :title_en) end)
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
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 3)

      # Same fixture returned for each day, so we get 3x the records
      # (In reality, records would be different per day)
      assert length(records) > 0
    end

    test "deduplicates records across days" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 3)

      # Should deduplicate by :name
      names = Enum.map(records, & &1[:name])
      assert names == Enum.uniq(names)
    end
  end

  describe "fetch_range/5 with type_code filter" do
    test "filters by type_code when provided" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, "uksi")

      # All records should be uksi
      assert Enum.all?(records, fn r -> r[:type_code] == "uksi" end)
    end

    test "includes all types when type_code is nil" do
      {:ok, records} = NewLaws.fetch_range(2024, 12, 1, 1, nil)

      type_codes = records |> Enum.map(& &1[:type_code]) |> Enum.uniq()

      # Should have both uksi and ukpga from our fixture
      assert "uksi" in type_codes
      assert "ukpga" in type_codes
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

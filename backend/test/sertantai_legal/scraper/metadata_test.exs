defmodule SertantaiLegal.Scraper.MetadataTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Metadata
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  setup do
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/uksi/2024/1234/introduction/data.xml") ->
          xml = fixture("introduction_sample.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2024/567/introduction/data.xml") ->
          xml = fixture("introduction_text_dates.xml")
          Req.Test.text(conn, xml)

        String.contains?(path, "/uksi/2024/9999/introduction/data.xml") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/redirect-test/") and not String.contains?(path, "/made/") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/redirect-test/") and String.contains?(path, "/made/") ->
          xml = fixture("introduction_sample.xml")
          Req.Test.text(conn, xml)

        true ->
          Plug.Conn.send_resp(conn, 404, "Not found")
      end
    end)

    :ok
  end

  describe "fetch/1" do
    test "fetches metadata for a record with atom keys" do
      record = %{type_code: "uksi", Year: 2024, Number: "1234"}

      {:ok, metadata} = Metadata.fetch(record)

      assert metadata[:md_description] =~ "consolidate and update"
      assert metadata[:Title_EN] == "The Environmental Permitting (England and Wales) Regulations 2024"
    end

    test "fetches metadata for a record with string keys" do
      record = %{"type_code" => "uksi", "Year" => 2024, "Number" => "567"}

      {:ok, metadata} = Metadata.fetch(record)

      assert metadata[:md_description] =~ "miscellaneous amendments"
    end

    test "returns error for non-existent record" do
      record = %{type_code: "uksi", Year: 2024, Number: "9999"}

      {:error, reason} = Metadata.fetch(record)

      assert reason =~ "Not found"
    end
  end

  describe "introduction_path/3" do
    test "builds correct path with integer year" do
      assert Metadata.introduction_path("uksi", 2024, "1234") ==
               "/uksi/2024/1234/introduction/data.xml"
    end

    test "builds correct path with string year" do
      assert Metadata.introduction_path("ukpga", "2023", "45") ==
               "/ukpga/2023/45/introduction/data.xml"
    end
  end

  describe "parse_xml/1 - Dublin Core elements" do
    test "extracts dc:title" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:Title_EN] == "The Environmental Permitting (England and Wales) Regulations 2024"
    end

    test "extracts dc:description" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_description] == "These Regulations consolidate and update the environmental permitting regime."
    end

    test "extracts dc:modified" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_modified] == "2024-12-15"
    end

    test "extracts and cleans dc:subject (removes geographic qualifiers)" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert "environment" in metadata[:md_subjects]
      assert "pollution" in metadata[:md_subjects]
      assert "waste management" in metadata[:md_subjects]
      # Should NOT contain ", england and wales"
      refute Enum.any?(metadata[:md_subjects], &String.contains?(&1, "england"))
    end
  end

  describe "parse_xml/1 - SI codes" do
    test "extracts and cleans SI codes from dc:subject with scheme" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert "ENVIRONMENT" in metadata[:si_code]
      assert "POLLUTION" in metadata[:si_code]
    end

    test "splits semicolon-separated SI codes" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      # "ENVIRONMENT; POLLUTION" should be split into two entries
      assert length(metadata[:si_code]) == 2
    end
  end

  describe "parse_xml/1 - statistics" do
    test "extracts paragraph counts" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_total_paras] == 250
      assert metadata[:md_body_paras] == 180
      assert metadata[:md_schedule_paras] == 60
      assert metadata[:md_attachment_paras] == 10
    end

    test "extracts image count" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_images] == 5
    end

    test "handles missing statistics gracefully" do
      xml = fixture("introduction_text_dates.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      # This fixture doesn't have attachment paras or images
      assert metadata[:md_attachment_paras] == nil
      assert metadata[:md_images] == nil
    end
  end

  describe "parse_xml/1 - dates" do
    test "extracts ISO date from ukm:EnactmentDate" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_enactment_date] == "2024-12-01"
    end

    test "extracts ISO date from ukm:Made" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_made_date] == "2024-11-15"
    end

    test "extracts ISO date from ukm:ComingIntoForce/ukm:DateTime" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_coming_into_force_date] == "2024-12-15"
    end

    test "parses text date from MadeDate/DateText" do
      xml = fixture("introduction_text_dates.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      # "at 3.32 p.m. on 10th September 2024" should become "2024-09-10"
      assert metadata[:md_made_date] == "2024-09-10"
    end

    test "parses text date from ComingIntoForce/DateText" do
      xml = fixture("introduction_text_dates.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      # "1st October 2024" should become "2024-10-01"
      assert metadata[:md_coming_into_force_date] == "2024-10-01"
    end
  end

  describe "parse_xml/1 - extent" do
    test "extracts RestrictExtent from Legislation element" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_restrict_extent] == "E+W"
    end

    test "extracts RestrictStartDate from Legislation element" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:md_restrict_start_date] == "2024-01-01"
    end
  end

  describe "parse_xml/1 - PDF link" do
    test "extracts PDF href from atom:link" do
      xml = fixture("introduction_sample.xml")

      {:ok, metadata} = Metadata.parse_xml(xml)

      assert metadata[:pdf_href] == "https://www.legislation.gov.uk/uksi/2024/1234/pdfs/uksi_20241234_en.pdf"
    end
  end

  describe "fetch_from_path/1 - redirect handling" do
    test "tries /made/ path on 404" do
      # This should 404 on the normal path and retry with /made/
      {:ok, metadata} = Metadata.fetch_from_path("/redirect-test/2024/1/introduction/data.xml")

      # Should get the sample fixture from the /made/ path
      assert metadata[:Title_EN] =~ "Environmental Permitting"
    end
  end

  defp fixture(name) do
    Path.join([File.cwd!(), "test/fixtures/legislation_gov_uk", name])
    |> File.read!()
  end
end

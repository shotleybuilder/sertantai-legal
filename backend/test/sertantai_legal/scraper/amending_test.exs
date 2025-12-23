defmodule SertantaiLegal.Scraper.AmendingTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amending
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  setup do
    Req.Test.stub(Client, fn conn ->
      path = conn.request_path

      cond do
        String.contains?(path, "/changes/affecting/uksi/2024/100") ->
          html = fixture("amendments_affecting.html")
          Req.Test.text(conn, html)

        String.contains?(path, "/changes/affected/uksi/2024/100") ->
          # Return empty results for affected (no laws amend this law yet)
          Req.Test.text(conn, "<html><body><table><tbody></tbody></table></body></html>")

        String.contains?(path, "/changes/affecting/uksi/2024/999") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        String.contains?(path, "/changes/affected/uksi/2024/999") ->
          Plug.Conn.send_resp(conn, 404, "Not found")

        true ->
          Plug.Conn.send_resp(conn, 404, "Not found")
      end
    end)

    :ok
  end

  describe "affecting_path/1" do
    test "builds correct path with atom keys" do
      record = %{type_code: "uksi", Year: 2024, Number: "1001"}
      path = Amending.affecting_path(record)

      assert path == "/changes/affecting/uksi/2024/1001?results-count=1000&sort=affecting-year-number"
    end

    test "builds correct path with string keys" do
      record = %{"type_code" => "uksi", "Year" => 2024, "Number" => "1001"}
      path = Amending.affecting_path(record)

      assert path == "/changes/affecting/uksi/2024/1001?results-count=1000&sort=affecting-year-number"
    end
  end

  describe "affected_path/1" do
    test "builds correct path" do
      record = %{type_code: "uksi", Year: 2024, Number: "1001"}
      path = Amending.affected_path(record)

      assert path == "/changes/affected/uksi/2024/1001?results-count=1000&sort=affected-year-number"
    end
  end

  describe "parse_amendments_html/1" do
    test "parses amendment rows from HTML" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      assert length(amendments) == 5
    end

    test "extracts title from first column" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.title_en == "Environmental Permitting Regulations 2016"
    end

    test "extracts law path and type_code" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.path == "/id/uksi/2016/1154"
      assert first.type_code == "uksi"
      assert first.year == 2016
      assert first.number == "1154"
    end

    test "extracts target section" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.target == "reg. 5(1)"
    end

    test "extracts affect type" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      affects = Enum.map(amendments, & &1.affect)

      assert "words substituted" in affects
      assert "inserted" in affects
      assert "amended" in affects
      assert "revoked" in affects
      assert "repealed in part" in affects
    end

    test "extracts applied status" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      statuses = Enum.map(amendments, & &1.applied?)

      assert "Yes" in statuses
      assert "Not yet" in statuses
    end

    test "builds name in UK_type_code_year_number format" do
      html = fixture("amendments_affecting.html")
      [first | _] = Amending.parse_amendments_html(html)

      assert first.name == "UK_uksi_2016_1154"
    end

    test "handles ukpga type code" do
      html = fixture("amendments_affecting.html")
      amendments = Amending.parse_amendments_html(html)

      # Find the HSWA 1974 entry
      hswa = Enum.find(amendments, fn a -> a.year == 1974 end)

      assert hswa.type_code == "ukpga"
      assert hswa.number == "37"
      assert hswa.name == "UK_ukpga_1974_37"
    end

    test "returns empty list for empty HTML" do
      html = "<html><body><table><tbody></tbody></table></body></html>"
      amendments = Amending.parse_amendments_html(html)

      assert amendments == []
    end
  end

  describe "get_laws_amended_by_this_law/1" do
    test "returns parsed amendments" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Should have 2 unique amended laws (uksi/2016/1154 appears twice but is deduped)
      # And 2 revoked laws
      assert length(result.amending) == 2
      assert length(result.rescinding) == 2
    end

    test "separates revocations from amendments" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      # Amending should contain non-revoked laws (unique) in UK_type_year_number format
      assert "UK_uksi_2016_1154" in result.amending
      assert "UK_ukpga_1974_37" in result.amending

      # Rescinding should contain revoked/repealed laws
      assert "UK_uksi_2010_500" in result.rescinding
      assert "UK_ukpga_2005_10" in result.rescinding
    end

    test "returns stats" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      assert result.stats.total_changes == 5
      assert result.stats.amendments_count == 3  # Raw count including duplicates
      assert result.stats.revocations_count == 2
      assert result.stats.amended_laws_count == 2  # Unique laws
      assert result.stats.revoked_laws_count == 2
    end

    test "returns ok with empty lists for 404" do
      record = %{type_code: "uksi", Year: 2024, Number: "999"}

      {:ok, result} = Amending.get_laws_amended_by_this_law(record)

      assert result.amending == []
      assert result.rescinding == []
      assert result.stats.amendments_count == 0
      assert result.stats.revocations_count == 0
    end
  end

  describe "get_laws_amending_this_law/1" do
    test "returns amended_by field" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # Our mock returns empty results
      assert result.amended_by == []
      assert result.rescinded_by == []
    end

    test "includes live status" do
      record = %{type_code: "uksi", Year: 2024, Number: "100"}

      {:ok, result} = Amending.get_laws_amending_this_law(record)

      # No revocations means in force
      assert result.live == "✔ In force"
    end
  end

  defp fixture(name) do
    Path.join([File.cwd!(), "test/fixtures/legislation_gov_uk", name])
    |> File.read!()
  end
end

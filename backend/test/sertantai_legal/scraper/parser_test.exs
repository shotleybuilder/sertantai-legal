defmodule SertantaiLegal.Scraper.ParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.Parser

  describe "parse_new_laws/1" do
    test "parses HTML with multiple law entries" do
      html = fixture("new_laws_sample.html")
      {:ok, records} = Parser.parse_new_laws(html)

      assert length(records) == 10
    end

    test "extracts title, type_code, year, and number correctly" do
      html = fixture("new_laws_sample.html")
      {:ok, records} = Parser.parse_new_laws(html)

      # Records are returned in reverse order (prepended to list)
      first = Enum.find(records, fn r -> r[:Number] == "1001" end)

      # title_clean removes "The " prefix and trailing year
      assert first[:Title_EN] == "Environmental Protection (Test) Regulations"
      assert first[:type_code] == "uksi"
      assert first[:Year] == 2024
      assert first[:Number] == "1001"
    end

    test "extracts descriptions from p tags" do
      html = fixture("new_laws_sample.html")
      {:ok, records} = Parser.parse_new_laws(html)

      first = Enum.find(records, fn r -> r[:Number] == "1001" end)

      assert first[:md_description] =~ "environmental protection"
    end

    test "handles ukpga type codes" do
      html = fixture("new_laws_sample.html")
      {:ok, records} = Parser.parse_new_laws(html)

      # Find the specific ukpga record by number
      ukpga = Enum.find(records, fn r -> r[:type_code] == "ukpga" && r[:Number] == "1" end)

      assert ukpga != nil
      # title_clean removes trailing year
      assert ukpga[:Title_EN] == "Environmental Act"
      assert ukpga[:Number] == "1"
    end

    test "returns empty list for empty content" do
      html = """
      <html><body><div class="p_content"></div></body></html>
      """

      {:ok, records} = Parser.parse_new_laws(html)
      assert records == []
    end

    test "handles missing p_content gracefully" do
      html = "<html><body></body></html>"
      {:ok, records} = Parser.parse_new_laws(html)
      assert records == []
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

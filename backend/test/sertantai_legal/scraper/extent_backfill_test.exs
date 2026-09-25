defmodule SertantaiLegal.Scraper.ExtentBackfillTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ExtentBackfill

  defp row(attrs) do
    Map.merge(
      %{
        name: "UK_ssi_2020_1",
        type_code: "ssi",
        geo_extent: nil,
        geo_region: nil,
        geo_extent_source: nil,
        md_restrict_extent: nil,
        document_status: nil,
        lat_extent_codes: [],
        clause_texts: []
      },
      Map.new(attrs)
    )
  end

  describe "plan/1" do
    test "a legacy UK placeholder on a devolved law becomes the type-code floor" do
      plan =
        ExtentBackfill.plan(
          row(geo_extent: "UK", geo_region: ["England", "Wales", "Scotland", "Northern Ireland"])
        )

      assert plan.change?
      assert plan.resolution == %{geo_extent: "S", geo_region: ["Scotland"], source: "type_code"}
    end

    test "an unverifiable legacy value is kept (unsourced = unverified)" do
      plan =
        ExtentBackfill.plan(row(type_code: "uksi", geo_extent: "UK", geo_region: ["England"]))

      refute plan.change?
      assert plan.resolution.geo_extent == nil
    end

    test "law-level extent wins and records its source" do
      plan =
        ExtentBackfill.plan(
          row(geo_extent: "UK", md_restrict_extent: "S", lat_extent_codes: ["S"])
        )

      assert plan.resolution.source == "law_level"
      assert plan.resolution.geo_extent == "S"
    end

    test "extent clauses are parsed from provision text" do
      plan =
        ExtentBackfill.plan(
          row(
            type_code: "uksi",
            clause_texts: [
              "Part 2 of this Act extends to Scotland only.",
              "(2) These Regulations extend to England and Wales and apply in relation to England only."
            ]
          )
        )

      assert plan.resolution == %{
               geo_extent: "E+W",
               geo_region: ["England", "Wales"],
               source: "text_clause"
             }
    end

    test "an unchanged law is not a change" do
      plan =
        ExtentBackfill.plan(
          row(geo_extent: "S", geo_region: ["Scotland"], geo_extent_source: "type_code")
        )

      refute plan.change?
    end

    test "a worse source never replaces a sourced value" do
      plan =
        ExtentBackfill.plan(
          row(geo_extent: "E+W", geo_region: ["England", "Wales"], geo_extent_source: "law_level")
        )

      refute plan.change?
    end
  end
end

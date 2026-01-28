defmodule SertantaiLegal.Scraper.StatsPerLawTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StagedParser

  describe "build_stats_per_law_jsonb/1" do
    test "handles amendments with atom keys" do
      amendments = [
        %{
          name: "UK_uksi_2020_100",
          title_en: "Test Regulation 2020",
          path: "/uksi/2020/100",
          year: 2020,
          number: "100",
          target: "Sch.1 para.5",
          affect: "words inserted",
          applied?: "Y"
        }
      ]

      result = StagedParser.build_stats_per_law_jsonb_test(amendments)

      assert is_map(result)
      assert Map.has_key?(result, "UK_uksi_2020_100")
      law_entry = result["UK_uksi_2020_100"]
      assert law_entry["name"] == "UK_uksi_2020_100"
      assert law_entry["title"] == "Test Regulation 2020"
      assert law_entry["count"] == 1
    end

    test "handles amendments with string keys" do
      amendments = [
        %{
          "name" => "UK_uksi_2020_200",
          "title_en" => "Test Order 2020",
          "path" => "/uksi/2020/200",
          "year" => 2020,
          "number" => "200",
          "target" => "reg.3",
          "affect" => "words substituted",
          "applied?" => "Y"
        }
      ]

      result = StagedParser.build_stats_per_law_jsonb_test(amendments)

      assert is_map(result)
      assert Map.has_key?(result, "UK_uksi_2020_200")
      law_entry = result["UK_uksi_2020_200"]
      assert law_entry["name"] == "UK_uksi_2020_200"
      assert law_entry["title"] == "Test Order 2020"
    end

    test "filters out amendments with nil name" do
      amendments = [
        %{
          name: "UK_uksi_2020_300",
          title_en: "Valid Amendment",
          path: "/uksi/2020/300"
        },
        %{
          title_en: "Invalid - No Name",
          path: "/uksi/2020/400"
        }
      ]

      result = StagedParser.build_stats_per_law_jsonb_test(amendments)

      assert is_map(result)
      assert Map.has_key?(result, "UK_uksi_2020_300")
      refute Map.has_key?(result, nil)
      # Should only have the valid amendment
      assert map_size(result) == 1
    end

    test "filters out amendments with empty string name" do
      amendments = [
        %{
          name: "",
          title_en: "Invalid - Empty Name",
          path: "/uksi/2020/500"
        }
      ]

      result = StagedParser.build_stats_per_law_jsonb_test(amendments)

      assert result == %{} or is_nil(result)
    end

    test "groups multiple amendments from same law" do
      amendments = [
        %{
          name: "UK_uksi_2020_600",
          title_en: "Test Act",
          path: "/uksi/2020/600",
          target: "s.1",
          affect: "words inserted"
        },
        %{
          name: "UK_uksi_2020_600",
          title_en: "Test Act",
          path: "/uksi/2020/600",
          target: "s.2",
          affect: "words substituted"
        }
      ]

      result = StagedParser.build_stats_per_law_jsonb_test(amendments)

      assert is_map(result)
      law_entry = result["UK_uksi_2020_600"]
      assert law_entry["count"] == 2
      assert length(law_entry["details"]) == 2
    end
  end
end

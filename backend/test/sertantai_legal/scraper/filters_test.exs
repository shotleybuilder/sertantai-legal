defmodule SertantaiLegal.Scraper.FiltersTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Filters

  describe "title_filter/1" do
    test "excludes railway station orders" do
      records = [
        %{Title_EN: "The Railway Station Order 2024"},
        %{Title_EN: "The Environment Test Regulations 2024"}
      ]

      {included, excluded} = Filters.title_filter(records)

      assert length(included) == 1
      assert length(excluded) == 1
      assert hd(included)[:Title_EN] =~ "Environment"
    end

    test "excludes parking places orders" do
      records = [
        %{Title_EN: "The Parking Places Order 2024"},
        %{Title_EN: "The Air Quality Regulations 2024"}
      ]

      {included, excluded} = Filters.title_filter(records)

      assert length(included) == 1
      assert hd(included)[:Title_EN] =~ "Air Quality"
    end

    test "excludes trunk road orders" do
      records = [
        %{Title_EN: "The Trunk Road Order 2024"},
        %{Title_EN: "The Hazardous Substances Regulations 2024"}
      ]

      {included, excluded} = Filters.title_filter(records)

      assert length(included) == 1
      assert hd(excluded)[:Title_EN] =~ "Trunk Road"
    end

    test "excludes drought orders" do
      records = [
        %{Title_EN: "The Drought Order 2024"},
        %{Title_EN: "The Waste Management Regulations 2024"}
      ]

      {included, excluded} = Filters.title_filter(records)

      assert length(included) == 1
      assert hd(included)[:Title_EN] =~ "Waste Management"
    end

    test "includes all records when none match exclusions" do
      records = [
        %{Title_EN: "The Environment Act 2024"},
        %{Title_EN: "The Health and Safety Regulations 2024"}
      ]

      {included, excluded} = Filters.title_filter(records)

      assert length(included) == 2
      assert length(excluded) == 0
    end
  end

  describe "terms_filter/1" do
    test "matches environment terms" do
      records = {
        [
          %{Title_EN: "The Smoke Control Regulations 2024"},
          %{Title_EN: "The Patent Law Act 2024"}
        ],
        []
      }

      {:ok, {matched, excluded}} = Filters.terms_filter(records)

      # Smoke Control should match air quality terms
      assert length(matched) >= 1
      matched_titles = Enum.map(matched, & &1[:Title_EN])
      assert Enum.any?(matched_titles, &String.contains?(&1, "Smoke Control"))
    end

    test "matches health and safety terms" do
      records = {
        [
          %{Title_EN: "The RIDDOR Regulations 2024"},
          %{Title_EN: "The Stamp Duty Act 2024"}
        ],
        []
      }

      {:ok, {matched, excluded}} = Filters.terms_filter(records)

      # RIDDOR should match H&S terms
      matched_titles = Enum.map(matched, & &1[:Title_EN])
      assert Enum.any?(matched_titles, &String.contains?(&1, "RIDDOR"))
    end

    test "matches noise terms" do
      records = {
        [
          %{Title_EN: "The Environmental Noise Regulations 2024"},
          %{Title_EN: "The Copyright Law Act 2024"}
        ],
        []
      }

      {:ok, {matched, excluded}} = Filters.terms_filter(records)

      matched_titles = Enum.map(matched, & &1[:Title_EN])
      assert Enum.any?(matched_titles, &String.contains?(&1, "Noise"))
    end

    test "excludes records with no term matches" do
      # Use titles that definitely won't match any EHS terms
      # Note: Avoid "Regulations" (matches "regulation") and "Order" (matches "order")
      records = {
        [
          %{Title_EN: "The Zzzzzz Act 2024"},
          %{Title_EN: "The Qqqqqq Act 2024"}
        ],
        []
      }

      {:ok, {matched, excluded}} = Filters.terms_filter(records)

      assert length(matched) == 0
      assert length(excluded) == 2
    end

    test "preserves already excluded records" do
      records = {
        [%{Title_EN: "The Environment Act 2024"}],
        [%{Title_EN: "Already Excluded 2024"}]
      }

      {:ok, {matched, excluded}} = Filters.terms_filter(records)

      assert length(matched) == 1
      assert length(excluded) == 1
      assert hd(excluded)[:Title_EN] =~ "Already Excluded"
    end
  end

  describe "si_code_filter/1" do
    test "matches known environmental SI codes" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: ["ENVIRONMENT"]},
        %{Title_EN: "Other Regulations 2024", si_code: ["UNKNOWN"]}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 1
      assert hd(matched)[:si_code] == ["ENVIRONMENT"]
    end

    test "matches health and safety SI codes" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: ["HEALTH AND SAFETY"]},
        %{Title_EN: "Other Regulations 2024", si_code: ["UNKNOWN"]}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 1
      assert hd(matched)[:si_code] == ["HEALTH AND SAFETY"]
    end

    test "handles records with multiple SI codes" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: ["UNKNOWN", "ENVIRONMENT"]},
        %{Title_EN: "Other Regulations 2024", si_code: ["RANDOM", "OTHER"]}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 1
    end

    test "excludes records with no matching SI codes" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: ["UNKNOWN"]},
        %{Title_EN: "Other Regulations 2024", si_code: ["RANDOM"]}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 0
      assert length(excluded) == 2
    end

    test "handles nil si_code" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: nil}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 0
      assert length(excluded) == 1
    end

    test "handles empty si_code list" do
      records = [
        %{Title_EN: "Test Regulations 2024", si_code: []}
      ]

      {:ok, {matched, excluded}} = Filters.si_code_filter(records)

      assert length(matched) == 0
      assert length(excluded) == 1
    end
  end
end

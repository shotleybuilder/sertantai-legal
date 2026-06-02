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

  describe "si_code_filter family assignment" do
    test "ELECTRICITY renewables → ENERGY not Gas & Electrical Safety" do
      records = [
        %{Title_EN: "Renewables Obligation (Amendment) Order", si_code: ["ELECTRICITY"]}
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💚 ENERGY"
    end

    test "ELECTRICITY safety → Gas & Electrical Safety" do
      records = [
        %{
          Title_EN: "Electricity Safety, Quality and Continuity Regulations",
          si_code: ["ELECTRICITY"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 OH&S: Gas & Electrical Safety"
    end

    test "MERCHANT SHIPPING ISM → Maritime Safety" do
      records = [
        %{Title_EN: "Merchant Shipping (ISM Code) Regulations", si_code: ["MERCHANT SHIPPING"]}
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 TRANSPORT: Maritime Safety"
    end

    test "MERCHANT SHIPPING CO2 → POLLUTION" do
      records = [
        %{
          Title_EN: "Merchant Shipping (Carbon Dioxide Emissions) Regulations",
          si_code: ["MERCHANT SHIPPING"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💚 POLLUTION"
    end

    test "ROAD TRAFFIC driving → Road Safety" do
      records = [
        %{Title_EN: "Motor Vehicles (Driving Licences) Regulations", si_code: ["ROAD TRAFFIC"]}
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 TRANSPORT: Road Safety"
    end

    test "ROAD TRAFFIC emissions → Roads & Vehicles (env)" do
      records = [
        %{Title_EN: "Road Traffic (Vehicle Emissions) Regulations", si_code: ["ROAD TRAFFIC"]}
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💚 TRANSPORT: Roads & Vehicles"
    end

    test "TERMS AND CONDITIONS OF EMPLOYMENT → HR: Employment" do
      records = [
        %{
          Title_EN: "Employment Rights (Increase of Limits) Order",
          si_code: ["TERMS AND CONDITIONS OF EMPLOYMENT"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💜 HR: Employment"
    end

    test "FIRE AND RESCUE SERVICES → FIRE" do
      records = [
        %{
          Title_EN: "Fire and Rescue Services (National Framework) Order",
          si_code: ["FIRE AND RESCUE SERVICES"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 FIRE"
    end

    test "HEALTH AND SAFETY → OH&S (unchanged)" do
      records = [
        %{
          Title_EN: "Health and Safety at Work Act (Application) Order",
          si_code: ["HEALTH AND SAFETY"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 OH&S: Occupational / Personal Safety"
    end

    test "multi SI code with FIRE AND RESCUE SERVICES takes priority" do
      records = [
        %{
          Title_EN: "Firefighters' Pension Scheme (Amendment) Order",
          si_code: ["FIRE AND RESCUE SERVICES", "PENSIONS"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 FIRE"
    end

    test "Carbon Capture with HEALTH AND SAFETY SI → OH&S (direct Models mapping)" do
      # HEALTH AND SAFETY has a direct mapping in Models, so disambiguation doesn't override it
      records = [
        %{
          Title_EN: "Carbon Capture (Miscellaneous Amendments) Regulations",
          si_code: ["HEALTH AND SAFETY"]
        }
      ]

      {:ok, {[matched], _}} = Filters.si_code_filter(records)
      assert matched[:Family] == "💙 OH&S: Occupational / Personal Safety"
    end
  end

  describe "si_code_family/2 (public API)" do
    test "returns family for known SI code" do
      assert Filters.si_code_family("HEALTH AND SAFETY", "Some Title") ==
               "💙 OH&S: Occupational / Personal Safety"
    end

    test "returns family for list of SI codes" do
      assert Filters.si_code_family(["HEALTH AND SAFETY"], "Some Title") ==
               "💙 OH&S: Occupational / Personal Safety"
    end

    test "returns nil for unknown SI code" do
      assert Filters.si_code_family("COMPLETELY UNKNOWN", "Some Title") == nil
    end

    test "returns nil for empty list" do
      assert Filters.si_code_family([], "Some Title") == nil
    end

    test "disambiguates ELECTRICITY by title" do
      assert Filters.si_code_family("ELECTRICITY", "Renewables Obligation Order") ==
               "💚 ENERGY"

      assert Filters.si_code_family("ELECTRICITY", "Electrical Safety Regulations") ==
               "💙 OH&S: Gas & Electrical Safety"
    end

    test "falls back to SICodes membership for unmapped codes" do
      # ROAD TRAFFIC is in hs_si_codes but also has disambiguation
      family = Filters.si_code_family("ROAD TRAFFIC", "Motor Vehicles (Driving Licences)")
      assert family == "💙 TRANSPORT: Road Safety"
    end

    test "WEIGHTS AND MEASURES → Consumer / Product Safety" do
      assert Filters.si_code_family("WEIGHTS AND MEASURES", "Measuring Instruments Regulations") ==
               "💙 PUBLIC: Consumer / Product Safety"
    end
  end
end

defmodule SertantaiLegal.Scraper.SICodeDisambiguationTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Terms.SICodeDisambiguation

  describe "disambiguate/2 ELECTRICITY" do
    test "renewables → ENERGY" do
      assert SICodeDisambiguation.disambiguate(
               "ELECTRICITY",
               "Renewables Obligation (Amendment) Order"
             ) ==
               "💚 ENERGY"
    end

    test "supplier payments → ENERGY" do
      assert SICodeDisambiguation.disambiguate(
               "ELECTRICITY",
               "Electricity Supplier Payments (Amendment) Regulations"
             ) ==
               "💚 ENERGY"
    end

    test "network connections → ENERGY" do
      assert SICodeDisambiguation.disambiguate(
               "ELECTRICITY",
               "Electricity Network Connections (Designated Strategic Plans) Regulations"
             ) ==
               "💚 ENERGY"
    end

    test "safety regulations → Gas & Electrical Safety" do
      assert SICodeDisambiguation.disambiguate(
               "ELECTRICITY",
               "Electricity Safety, Quality and Continuity Regulations"
             ) ==
               "💙 OH&S: Gas & Electrical Safety"
    end

    test "generic electricity → defaults to ENERGY" do
      assert SICodeDisambiguation.disambiguate("ELECTRICITY", "Some Electricity Order") ==
               "💚 ENERGY"
    end
  end

  describe "disambiguate/2 GAS" do
    test "gas safety → Gas & Electrical Safety" do
      assert SICodeDisambiguation.disambiguate(
               "GAS",
               "Gas Safety (Installation and Use) Regulations"
             ) ==
               "💙 OH&S: Gas & Electrical Safety"
    end

    test "energy company obligation → ENERGY" do
      assert SICodeDisambiguation.disambiguate(
               "GAS",
               "Electricity and Gas (Energy Company Obligation) Order"
             ) ==
               "💚 ENERGY"
    end

    test "generic gas → defaults to ENERGY" do
      assert SICodeDisambiguation.disambiguate("GAS", "Some Gas Order") ==
               "💚 ENERGY"
    end
  end

  describe "disambiguate/2 MERCHANT SHIPPING" do
    test "ISM code → Maritime Safety" do
      assert SICodeDisambiguation.disambiguate(
               "MERCHANT SHIPPING",
               "Merchant Shipping (ISM Code) Regulations"
             ) ==
               "💙 TRANSPORT: Maritime Safety"
    end

    test "CO2 emissions → POLLUTION" do
      assert SICodeDisambiguation.disambiguate(
               "MERCHANT SHIPPING",
               "Merchant Shipping (MRV of Carbon Dioxide Emissions) Regulations"
             ) ==
               "💚 POLLUTION"
    end

    test "ballast water → POLLUTION" do
      assert SICodeDisambiguation.disambiguate(
               "MERCHANT SHIPPING",
               "Merchant Shipping (Control and Management of Ships' Ballast Water) Regulations"
             ) ==
               "💚 POLLUTION"
    end

    test "EPIRB registration → Maritime Safety" do
      assert SICodeDisambiguation.disambiguate(
               "MERCHANT SHIPPING",
               "Merchant Shipping (EPIRB and PLB Registration) Regulations"
             ) ==
               "💙 TRANSPORT: Maritime Safety"
    end

    test "light dues → defaults to Maritime Safety" do
      assert SICodeDisambiguation.disambiguate(
               "MERCHANT SHIPPING",
               "Merchant Shipping (Light Dues) (Amendment) Regulations"
             ) ==
               "💙 TRANSPORT: Maritime Safety"
    end
  end

  describe "disambiguate/2 ROAD TRAFFIC" do
    test "driving licences → Road Safety" do
      assert SICodeDisambiguation.disambiguate(
               "ROAD TRAFFIC",
               "Motor Vehicles (Driving Licences) (Amendment) Regulations"
             ) ==
               "💙 TRANSPORT: Road Safety"
    end

    test "vehicle emissions → Roads & Vehicles (env)" do
      assert SICodeDisambiguation.disambiguate(
               "ROAD TRAFFIC",
               "Road Traffic (Vehicle Emissions) (Fixed Penalty) Regulations"
             ) ==
               "💚 TRANSPORT: Roads & Vehicles"
    end

    test "permit scheme → Road Safety" do
      assert SICodeDisambiguation.disambiguate(
               "ROAD TRAFFIC",
               "Traffic Management Permit Scheme (Amendment) Regulations"
             ) ==
               "💙 TRANSPORT: Road Safety"
    end
  end

  describe "direct_mapping/1" do
    test "employment terms → HR: Employment" do
      assert SICodeDisambiguation.direct_mapping("TERMS AND CONDITIONS OF EMPLOYMENT") ==
               "💜 HR: Employment"
    end

    test "fire services → FIRE" do
      assert SICodeDisambiguation.direct_mapping("FIRE AND RESCUE SERVICES") == "💙 FIRE"
    end

    test "pensions → HR: Insurance/Compensation" do
      assert SICodeDisambiguation.direct_mapping("PENSIONS") ==
               "💜 HR: Insurance / Compensation / Wages / Benefits"
    end

    test "unknown code → nil" do
      assert SICodeDisambiguation.direct_mapping("UNKNOWN CODE") == nil
    end
  end

  describe "resolve/2" do
    test "ambiguous code uses title" do
      assert SICodeDisambiguation.resolve("ELECTRICITY", "Renewables Obligation Order") ==
               "💚 ENERGY"
    end

    test "non-ambiguous direct mapping ignores title" do
      assert SICodeDisambiguation.resolve("TERMS AND CONDITIONS OF EMPLOYMENT", "Whatever Title") ==
               "💜 HR: Employment"
    end

    test "unknown code returns nil" do
      assert SICodeDisambiguation.resolve("TOTALLY UNKNOWN", "Any Title") == nil
    end
  end
end

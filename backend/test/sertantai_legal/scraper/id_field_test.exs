defmodule SertantaiLegal.Scraper.IdFieldTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.IdField

  describe "set_name/1" do
    test "sets name from type_code, Year, and Number" do
      record = %{type_code: "uksi", Year: 2024, Number: "1234"}
      result = IdField.set_name(record)
      assert result.name == "uksi/2024/1234"
    end

    test "handles string Year" do
      record = %{type_code: "ukpga", Year: "1974", Number: "37"}
      result = IdField.set_name(record)
      assert result.name == "ukpga/1974/37"
    end

    test "returns record unchanged if missing required fields" do
      record = %{Title_EN: "Some Act"}
      assert IdField.set_name(record) == record
    end
  end

  describe "build_name/3" do
    test "builds name with integer year" do
      assert IdField.build_name("uksi", 2024, "1234") == "uksi/2024/1234"
    end

    test "builds name with string year" do
      assert IdField.build_name("ukpga", "1974", "37") == "ukpga/1974/37"
    end

    test "handles different type codes" do
      assert IdField.build_name("asp", 2020, "5") == "asp/2020/5"
      assert IdField.build_name("ssi", 2021, "100") == "ssi/2021/100"
      assert IdField.build_name("nisr", 2022, "50") == "nisr/2022/50"
    end
  end

  describe "build_uk_id/3" do
    test "builds UK-prefixed ID" do
      assert IdField.build_uk_id("uksi", 2024, "1234") == "UK_uksi_2024_1234"
    end

    test "handles string year" do
      assert IdField.build_uk_id("ukpga", "1974", "37") == "UK_ukpga_1974_37"
    end
  end

  describe "set_acronym/1" do
    test "sets Acronym from Title_EN" do
      record = %{Title_EN: "Health and Safety at Work etc. Act 1974"}
      result = IdField.set_acronym(record)
      assert result[:Acronym] == "HSWA"
    end

    test "removes The prefix before extracting" do
      record = %{Title_EN: "The Management of Health and Safety at Work Regulations 1999"}
      result = IdField.set_acronym(record)
      assert result[:Acronym] == "MHSWR"
    end

    test "returns record unchanged if Title_EN is nil" do
      record = %{Title_EN: nil}
      result = IdField.set_acronym(record)
      refute Map.has_key?(result, :Acronym)
    end

    test "returns record unchanged if Title_EN is empty" do
      record = %{Title_EN: ""}
      result = IdField.set_acronym(record)
      refute Map.has_key?(result, :Acronym)
    end
  end

  describe "build_acronym/1" do
    test "extracts uppercase letters" do
      assert IdField.build_acronym("Health and Safety at Work etc. Act 1974") == "HSWA"
    end

    test "removes The prefix" do
      assert IdField.build_acronym("The Control of Substances Hazardous to Health Regulations 2002") ==
               "CSHHR"
    end

    test "handles lowercase-only title" do
      assert IdField.build_acronym("some lowercase title") == ""
    end

    test "handles all uppercase abbreviations" do
      # EU Withdrawal Act -> EUWA (E, U, W, A)
      assert IdField.build_acronym("The EU Withdrawal Act 2018") == "EUWA"
    end

    test "handles complex title" do
      assert IdField.build_acronym("The Environmental Permitting (England and Wales) Regulations 2016") ==
               "EPEWR"
    end

    test "handles Northern Ireland suffix" do
      assert IdField.build_acronym("The Waste Regulations (Northern Ireland) 2011") == "WRNI"
    end
  end
end

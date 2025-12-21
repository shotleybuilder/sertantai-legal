defmodule SertantaiLegal.Scraper.TypeClassTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.TypeClass

  describe "set_type_class/1" do
    test "returns record unchanged if type_class already set" do
      record = %{Title_EN: "Some Act", type_class: "Act"}
      assert TypeClass.set_type_class(record) == record
    end

    test "detects Act from title" do
      record = %{Title_EN: "Health and Safety at Work etc. Act 1974"}
      assert TypeClass.set_type_class(record).type_class == "Act"
    end

    test "detects Act with Northern Ireland suffix" do
      record = %{Title_EN: "Some Test Act (Northern Ireland)"}
      assert TypeClass.set_type_class(record).type_class == "Act"
    end

    test "detects Regulation from title (singular)" do
      record = %{Title_EN: "The Water Supply (Water Quality) Regulation 2016"}
      assert TypeClass.set_type_class(record).type_class == "Regulation"
    end

    test "detects Regulation from title (plural)" do
      record = %{Title_EN: "Control of Substances Hazardous to Health Regulations 2002"}
      assert TypeClass.set_type_class(record).type_class == "Regulation"
    end

    test "detects Order from title" do
      record = %{Title_EN: "The Environmental Permitting Order 2010"}
      assert TypeClass.set_type_class(record).type_class == "Order"
    end

    test "detects Rules from title" do
      record = %{Title_EN: "The Civil Procedure Rules 1998"}
      assert TypeClass.set_type_class(record).type_class == "Rules"
    end

    test "detects Scheme from title" do
      record = %{Title_EN: "The Pension Scheme 2020"}
      assert TypeClass.set_type_class(record).type_class == "Scheme"
    end

    test "detects Byelaws from title" do
      record = %{Title_EN: "The Transport for London Byelaws"}
      assert TypeClass.set_type_class(record).type_class == "Byelaws"
    end

    test "detects EU legislation" do
      record = %{Title_EN: "Regulation (EU) 2019/1148"}
      assert TypeClass.set_type_class(record).type_class == "EU"
    end

    test "detects Council Directive as EU" do
      record = %{Title_EN: "Council Directive 91/271/EEC"}
      assert TypeClass.set_type_class(record).type_class == "EU"
    end

    test "detects Confirmation Instrument" do
      record = %{Title_EN: "The Some Church Confirmation Instrument"}
      assert TypeClass.set_type_class(record).type_class == "Confirmation Instrument"
    end

    test "detects Measure from title" do
      record = %{Title_EN: "The Church of England Measure 2018"}
      assert TypeClass.set_type_class(record).type_class == "Measure"
    end

    test "returns record unchanged if type_class cannot be determined" do
      record = %{Title_EN: "Some Unknown Document 2024"}
      result = TypeClass.set_type_class(record)
      refute Map.has_key?(result, :type_class)
    end

    test "returns record unchanged if Title_EN is nil" do
      record = %{Title_EN: nil}
      assert TypeClass.set_type_class(record) == record
    end

    test "returns record unchanged if Title_EN is empty" do
      record = %{Title_EN: ""}
      assert TypeClass.set_type_class(record) == record
    end
  end

  describe "set_type/1" do
    test "sets Type for UK Public General Act" do
      record = %{type_code: "ukpga"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Public General Act of the United Kingdom Parliament"
    end

    test "sets Type for UK Statutory Instrument" do
      record = %{type_code: "uksi"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "UK Statutory Instrument"
    end

    test "sets Type for Scottish Act" do
      record = %{type_code: "asp"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Act of the Scottish Parliament"
    end

    test "sets Type for Scottish Statutory Instrument" do
      record = %{type_code: "ssi"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Scottish Statutory Instrument"
    end

    test "sets Type for Northern Ireland Statutory Rule" do
      record = %{type_code: "nisr"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Northern Ireland Statutory Rule"
    end

    test "sets Type for Welsh Act (asc)" do
      record = %{type_code: "asc"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Act of the Senedd Cymru 2020-date"
    end

    test "sets Type for Wales Statutory Instrument" do
      record = %{type_code: "wsi"}
      result = TypeClass.set_type(record)
      assert result[:Type] == "Wales Statutory Instrument 2018-date"
    end

    test "sets Type to nil for unknown type_code" do
      record = %{type_code: "unknown"}
      result = TypeClass.set_type(record)
      assert result[:Type] == nil
    end

    test "returns record unchanged if type_code not present" do
      record = %{Title_EN: "Some Act"}
      assert TypeClass.set_type(record) == record
    end
  end
end

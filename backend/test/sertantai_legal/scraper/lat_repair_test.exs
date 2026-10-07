defmodule SertantaiLegal.Scraper.LatRepairTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatRepair

  describe "provision/1" do
    test "the top-level provision of a row id: section, regulation, EU article" do
      assert LatRepair.provision("UK_ukpga_1974_37:s.4(1)(a)") == {:ok, "s.4"}
      assert LatRepair.provision("UK_uksi_1992_3004:reg.2(1)") == {:ok, "reg.2"}
      assert LatRepair.provision("UK_ukpga_1991_56:s.4(6)[E+W]") == {:ok, "s.4"}
      assert LatRepair.provision("UK_ukpga_1991_56:s.12A#2") == {:ok, "s.12A"}
      assert LatRepair.provision("UK_eudr_1991_383:art.Article 3(1)") == {:ok, "art.Article 3"}
    end

    test "schedule, Part, Chapter, heading and table rows are not repaired" do
      for id <- [
            "UK_ukpga_1974_28:sch.1.s.5(2)",
            "UK_asp_2011_9:pt.2",
            "UK_ssi_2006_465:ch.2#41",
            "UK_uksi_2014_1638:h.39",
            "UK_nisr_2010_160:table.15"
          ] do
        assert {:skip, _} = LatRepair.provision(id), id
      end
    end
  end

  describe "provisions/1" do
    test "candidate rows → distinct {law, provision}, skips reported separately" do
      rows = [
        {"UK_uksi_1992_3004", "UK_uksi_1992_3004:reg.2(1)"},
        {"UK_uksi_1992_3004", "UK_uksi_1992_3004:reg.2(4)"},
        {"UK_ukpga_1974_37", "UK_ukpga_1974_37:s.4(1)"},
        {"UK_asp_2011_9", "UK_asp_2011_9:pt.2"}
      ]

      assert LatRepair.provisions(rows) ==
               {[{"UK_ukpga_1974_37", "s.4"}, {"UK_uksi_1992_3004", "reg.2"}],
                ["UK_asp_2011_9:pt.2"]}
    end
  end

  describe "fragment_paths/2" do
    test "sections; regulations falling back to article then rule; EU articles" do
      assert LatRepair.fragment_paths("UK_ukpga_1974_37", "s.4") == ["/ukpga/1974/37/section/4"]

      assert LatRepair.fragment_paths("UK_uksi_1992_3004", "reg.2") == [
               "/uksi/1992/3004/regulation/2",
               "/uksi/1992/3004/article/2",
               "/uksi/1992/3004/rule/2"
             ]

      assert LatRepair.fragment_paths("UK_eudr_1991_383", "art.Article 3") == [
               "/eudr/1991/383/article/3"
             ]
    end
  end

  describe "in_provision?/3" do
    test "the provision row and its descendants, not a sibling that shares the prefix" do
      assert LatRepair.in_provision?("UK_x:s.4", "UK_x", "s.4")
      assert LatRepair.in_provision?("UK_x:s.4(1)(a)", "UK_x", "s.4")
      assert LatRepair.in_provision?("UK_x:s.4[E+W]", "UK_x", "s.4")
      assert LatRepair.in_provision?("UK_x:s.4#2", "UK_x", "s.4")
      refute LatRepair.in_provision?("UK_x:s.40(1)", "UK_x", "s.4")
      refute LatRepair.in_provision?("UK_x:s.4A", "UK_x", "s.4")
    end
  end

  describe "repairs/2" do
    test "rows held in both whose words change; marker/spacing-only and new rows are left alone" do
      stored = %{
        "a" => "“mine” means a mine; In this Part—",
        "b" => "Where a person— and applies",
        "c" => "unchanged text",
        "d" => "Every employer shall—  keep records"
      }

      fresh = %{
        "a" => "In this Part— “mine” means a mine;",
        "b" => "Where a person— … and applies",
        "c" => "unchanged text",
        "d" => "Every employer shall— keep records",
        "e" => "a row the stored LAT doesn't hold"
      }

      assert LatRepair.repairs(stored, fresh) == [
               {"a", "“mine” means a mine; In this Part—", "In this Part— “mine” means a mine;"}
             ]
    end
  end

  describe "cause/2" do
    test "same words reordered or re-spaced: correction (the list-text fix)" do
      assert LatRepair.cause(
               "“mine” means a mine; In this Part—",
               "In this Part— “mine” means a mine;"
             ) ==
               "correction"
    end

    test "other word changes (e.g. an amendment since the last parse): unattributed" do
      assert LatRepair.cause("within 3 months", "within 6 months") == "unattributed"
      assert LatRepair.cause("", "“consumers” includes future consumers;") == "unattributed"
    end
  end

  describe "only_cause/2" do
    test "keeps the repairs whose cause matches; nil keeps all" do
      repairs = [
        {"a", "x; In this Part—", "In this Part— x;"},
        {"b", "within 3 months", "within 6 months"}
      ]

      assert LatRepair.only_cause(repairs, "correction") == [hd(repairs)]
      assert LatRepair.only_cause(repairs, "unattributed") == tl(repairs)
      assert LatRepair.only_cause(repairs, nil) == repairs
    end
  end

  describe "causes/1" do
    @law "UK_wsi_2005_1806"

    test "a move within a provision (section row emptied, subsection gains its words) is a correction" do
      repairs = [
        {"#{@law}:reg.5", "“the Act” means the 1990 Act;", ""},
        {"#{@law}:reg.5(1)", "In these Regulations—",
         "In these Regulations— “the Act” means the 1990 Act;"}
      ]

      assert Enum.map(LatRepair.causes(repairs), &elem(&1, 3)) == ["correction", "correction"]
    end

    test "an amendment beside a move in the same provision stays unattributed" do
      repairs = [
        {"#{@law}:reg.5", "“the Act” means the 1990 Act;", ""},
        {"#{@law}:reg.5(1)", "In these Regulations—",
         "In these Regulations— “the Act” means the 1990 Act;"},
        {"#{@law}:reg.5(3)", "within 3 months", "within 6 months"}
      ]

      assert Enum.map(LatRepair.causes(repairs), &elem(&1, 3)) ==
               ["correction", "correction", "unattributed"]
    end

    test "content restored with nothing lost elsewhere stays unattributed; a reorder is a correction" do
      repairs = [
        {"#{@law}:reg.7", "", "“consumers” includes future consumers;"},
        {"#{@law}:reg.8(1)", "x; In this Part—", "In this Part— x;"}
      ]

      assert Enum.map(LatRepair.causes(repairs), &elem(&1, 3)) == ["unattributed", "correction"]
    end

    test "moves are matched within a provision, not across provisions" do
      repairs = [
        {"#{@law}:reg.5", "“the Act” means the 1990 Act;", ""},
        {"#{@law}:reg.6(1)", "In this regulation—",
         "In this regulation— “the Act” means the 1990 Act;"}
      ]

      assert Enum.map(LatRepair.causes(repairs), &elem(&1, 3)) == ["unattributed", "unattributed"]
    end
  end
end

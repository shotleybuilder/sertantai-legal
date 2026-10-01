defmodule SertantaiLegal.Scraper.LatEffectsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatEffects

  describe "unapplied?/1" do
    test "'Not yet' for the English text is unapplied" do
      assert LatEffects.unapplied?("Not yet")
      refute LatEffects.unapplied?("Yes")
      refute LatEffects.unapplied?("Y")
      refute LatEffects.unapplied?("See note")
      refute LatEffects.unapplied?(nil)
    end

    test "Welsh-language-only gaps don't count (the English text is done or not affected)" do
      refute LatEffects.unapplied?(
               "Not yet made to Welsh language version Applied to English language version"
             )

      refute LatEffects.unapplied?(
               "Not yet made to Welsh language version Not applicable to English language version"
             )
    end
  end

  describe "target_section_id/2" do
    test "sections, regulations and articles" do
      assert LatEffects.target_section_id("s. 104(2)", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:s.104(2)"

      assert LatEffects.target_section_id("reg. 5(3)(a)", "UK_uksi_2015_51") ==
               "UK_uksi_2015_51:reg.5(3)(a)"

      assert LatEffects.target_section_id("reg 5", "UK_uksi_2015_51") == "UK_uksi_2015_51:reg.5"

      assert LatEffects.target_section_id("s. 28 heading", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:s.28"

      assert LatEffects.target_section_id("s. 119A(1) (2)", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:s.119A(1)"

      assert LatEffects.target_section_id("art. 3(1)", "UK_eur_2008_1272") ==
               "UK_eur_2008_1272:art.3(1)"
    end

    test "schedule paragraphs use the provision prefix of the law's type" do
      assert LatEffects.target_section_id("Sch. 1 para. 22", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:sch.1.s.22"

      assert LatEffects.target_section_id("Sch. 4  para. 1(j)  and", "UK_uksi_2015_51") ==
               "UK_uksi_2015_51:sch.4.reg.1(j)"
    end

    test "spot-check fixes: capitalised prefix, domestic art. is reg., 'Sch.5', a whole schedule" do
      assert LatEffects.target_section_id("Art. 10(2)", "UK_eur_2006_166") ==
               "UK_eur_2006_166:art.10(2)"

      assert LatEffects.target_section_id("art. 55(2)", "UK_uksi_2010_768") ==
               "UK_uksi_2010_768:reg.55(2)"

      assert LatEffects.target_section_id("Sch.5  para.1 A", "UK_uksi_1990_2179") ==
               "UK_uksi_1990_2179:sch.5.reg.1"

      assert LatEffects.target_section_id("Sch. 4", "UK_nisr_1997_248") ==
               "UK_nisr_1997_248:sch.4"

      assert LatEffects.target_section_id("rule 7(8)(e)", "UK_uksi_2006_641") ==
               "UK_uksi_2006_641:reg.7(8)(e)"
    end

    test "parts; anything else → nil" do
      assert LatEffects.target_section_id("Pt. 1", "UK_ukpga_1990_43") == "UK_ukpga_1990_43:pt.1"
      assert LatEffects.target_section_id("Regulations title", "UK_uksi_2015_51") == nil
      assert LatEffects.target_section_id("Sch.  para. 1  Table", "UK_uksi_2015_51") == nil
    end
  end

  describe "resolve/2" do
    @ids MapSet.new(["L:s.4", "L:s.4(1)", "L:s.104(2)"])

    test "an exact row, else the deepest existing ancestor (an unapplied insertion has no row yet)" do
      assert LatEffects.resolve("L:s.104(2)", @ids) == {"L:s.104(2)", true}
      assert LatEffects.resolve("L:s.4(5A)", @ids) == {"L:s.4", false}
      assert LatEffects.resolve("L:s.4(1)(b)", @ids) == {"L:s.4(1)", false}
      assert LatEffects.resolve("L:s.99", @ids) == {nil, false}
      assert LatEffects.resolve(nil, @ids) == {nil, false}
    end

    test "a schedule paragraph without a row falls back to its schedule's row" do
      ids = MapSet.new(["L:sch.1"])
      assert LatEffects.resolve("L:sch.1.reg.22", ids) == {"L:sch.1", false}
    end
  end

  describe "unapplied/3" do
    test "unapplied effects from the stored affected_by stats, mapped best-effort" do
      stats = %{
        "UK_asc_2026_5" => %{
          "details" => [
            %{"affect" => "inserted", "target" => "s. 4(5A)", "applied" => "Not yet"},
            %{"affect" => "words substituted", "target" => "s. 104(2)", "applied" => "Yes"}
          ]
        },
        "UK_uksi_2025_9" => %{
          "details" => [
            %{"affect" => "words substituted", "target" => "s. 104(2)", "applied" => "Not yet"}
          ]
        }
      }

      ids = MapSet.new(["UK_ukpga_1990_43:s.4", "UK_ukpga_1990_43:s.104(2)"])

      assert LatEffects.unapplied(stats, "UK_ukpga_1990_43", ids) == [
               %{
                 by: "UK_asc_2026_5",
                 affect: "inserted",
                 target: "s. 4(5A)",
                 section_id: "UK_ukpga_1990_43:s.4",
                 exact: false
               },
               %{
                 by: "UK_uksi_2025_9",
                 affect: "words substituted",
                 target: "s. 104(2)",
                 section_id: "UK_ukpga_1990_43:s.104(2)",
                 exact: true
               }
             ]

      assert LatEffects.unapplied(nil, "UK_x", MapSet.new()) == []
    end

    test "a target qualified beyond its citation (heading, cross-heading, Table) is never exact" do
      stats = %{
        "UK_asc_2026_4" => %{
          "details" => [
            %{"affect" => "inserted", "target" => "s. 7 cross-heading", "applied" => "Not yet"},
            %{"affect" => "words substituted", "target" => "s. 7(1)", "applied" => "Not yet"}
          ]
        }
      }

      ids = MapSet.new(["L:s.7", "L:s.7(1)"])

      assert [%{section_id: "L:s.7", exact: false}, %{section_id: "L:s.7(1)", exact: true}] =
               LatEffects.unapplied(stats, "L", ids)
    end
  end
end

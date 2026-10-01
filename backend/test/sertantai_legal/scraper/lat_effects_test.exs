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
                 exact: false,
                 in_force_date: nil,
                 prospective: nil,
                 saved: nil
               },
               %{
                 by: "UK_uksi_2025_9",
                 affect: "words substituted",
                 target: "s. 104(2)",
                 section_id: "UK_ukpga_1990_43:s.104(2)",
                 exact: true,
                 in_force_date: nil,
                 prospective: nil,
                 saved: nil
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

  describe "ref_section_id/2 (#168: structured AffectedProvisions refs)" do
    test "section, regulation, article, part and numbered schedule refs" do
      assert LatEffects.ref_section_id("section-83-2-a", "UK_anaw_2016_3") ==
               "UK_anaw_2016_3:s.83(2)(a)"

      assert LatEffects.ref_section_id("section-4A", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:s.4A"

      assert LatEffects.ref_section_id("regulation-5-3", "UK_uksi_2015_51") ==
               "UK_uksi_2015_51:reg.5(3)"

      assert LatEffects.ref_section_id("article-3-1", "UK_uksi_2010_768") ==
               "UK_uksi_2010_768:reg.3(1)"

      assert LatEffects.ref_section_id("article-3-1", "UK_eur_2008_1272") ==
               "UK_eur_2008_1272:art.3(1)"

      assert LatEffects.ref_section_id("part-2", "UK_ukpga_1990_43") == "UK_ukpga_1990_43:pt.2"

      assert LatEffects.ref_section_id("schedule-1-paragraph-22-3", "UK_ukpga_1990_43") ==
               "UK_ukpga_1990_43:sch.1.s.22(3)"
    end

    test "unnumbered schedules and anything else → nil (the text parser is the fallback)" do
      assert LatEffects.ref_section_id("schedule-paragraph-20-2", "UK_anaw_2016_3") == nil
      assert LatEffects.ref_section_id("crossheading-general", "UK_anaw_2016_3") == nil
    end
  end

  describe "unapplied/3 with in-force data (#168)" do
    test "structured refs win over the text; in_force_date, prospective and saved are carried" do
      stats = %{
        "UK_ukpga_2021_30" => %{
          "details" => [
            %{
              "affect" => "substituted",
              "target" => "s. 83 heading",
              "applied" => "Not yet",
              "affected_refs" => ["section-83-2-a"],
              "prospective" => true,
              "in_force_date" => nil,
              "savings" => ["section-144"]
            },
            %{
              "affect" => "omitted",
              "target" => "s. 84(4)(a)",
              "applied" => "Not yet",
              "in_force_date" => "2024-11-16",
              "prospective" => false,
              "savings" => []
            }
          ]
        }
      }

      ids = MapSet.new(["L:s.83(2)(a)", "L:s.84(4)(a)"])

      assert [
               %{
                 section_id: "L:s.83(2)(a)",
                 exact: true,
                 prospective: true,
                 in_force_date: nil,
                 saved: true
               },
               %{
                 section_id: "L:s.84(4)(a)",
                 exact: true,
                 prospective: false,
                 in_force_date: "2024-11-16",
                 saved: false
               }
             ] = LatEffects.unapplied(stats, "L", ids)
    end

    test "an exact text match beats a ref that only reaches an ancestor" do
      stats = %{
        "UK_x" => %{
          "details" => [
            %{
              "affect" => "words substituted",
              "target" => "s. 5(2)",
              "applied" => "Not yet",
              "affected_refs" => ["section-5-2-b"]
            }
          ]
        }
      }

      # the ref names s.5(2)(b), which legal doesn't hold: it only reaches s.5(2)'s ancestor chain
      ids = MapSet.new(["L:s.5", "L:s.5(2)"])

      assert [%{section_id: "L:s.5(2)", exact: true}] = LatEffects.unapplied(stats, "L", ids)
    end

    test "details without in-force data (not yet re-fetched) report nil, not false" do
      stats = %{
        "UK_x" => %{
          "details" => [%{"affect" => "inserted", "target" => "s. 1", "applied" => "Not yet"}]
        }
      }

      assert [%{prospective: nil, in_force_date: nil, saved: nil}] =
               LatEffects.unapplied(stats, "L", MapSet.new(["L:s.1"]))
    end
  end

  describe "enrich/2 (#168: attach feed in-force data to unapplied details)" do
    alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

    test "unapplied details gain the matching effect's in-force data; applied ones are untouched" do
      stats = %{
        "UK_ukpga_2021_30" => %{
          "details" => [
            %{"affect" => "substituted", "target" => "s. 83(2)(a)", "applied" => "Not yet"},
            %{"affect" => "omitted", "target" => "s. 84(4)(a)", "applied" => "Yes"},
            %{"affect" => "inserted", "target" => "s. 99", "applied" => "Not yet"}
          ]
        }
      }

      effects = [
        %Effect{
          type: "substituted",
          affecting: "UK_ukpga_2021_30",
          affected_provisions: "s. 83(2)(a)",
          prospective: true,
          savings: ["section-144"],
          affected_refs: ["section-83-2-a"]
        },
        %Effect{
          type: "omitted",
          affecting: "UK_ukpga_2021_30",
          affected_provisions: "s. 84(4)(a)",
          in_force_date: ~D[2024-11-16],
          affected_refs: ["section-84-4-a"]
        }
      ]

      assert {%{"UK_ukpga_2021_30" => %{"details" => [d1, d2, d3]}}, 1, 2} =
               LatEffects.enrich(stats, effects)

      assert d1["prospective"] == true
      assert d1["in_force_date"] == nil
      assert d1["savings"] == ["section-144"]
      assert d1["affected_refs"] == ["section-83-2-a"]
      # applied: untouched
      refute Map.has_key?(d2, "affected_refs")
      # unapplied, no matching effect: untouched (stays "not re-fetched")
      refute Map.has_key?(d3, "prospective")
    end

    test "a commenced effect's date is stored as ISO 8601" do
      stats = %{
        "UK_a" => %{
          "details" => [%{"affect" => "omitted", "target" => "s. 1", "applied" => "Not yet"}]
        }
      }

      effects = [
        %Effect{
          type: "omitted",
          affecting: "UK_a",
          affected_provisions: "s. 1",
          in_force_date: ~D[2025-01-31]
        }
      ]

      assert {%{
                "UK_a" => %{
                  "details" => [%{"in_force_date" => "2025-01-31", "prospective" => false}]
                }
              }, 1, 1} =
               LatEffects.enrich(stats, effects)
    end

    test "no stats or no effects → unchanged" do
      assert LatEffects.enrich(nil, []) == {nil, 0, 0}

      stats = %{
        "UK_a" => %{"details" => [%{"affect" => "x", "target" => "s. 1", "applied" => "Not yet"}]}
      }

      assert LatEffects.enrich(stats, []) == {stats, 0, 1}
    end
  end
end

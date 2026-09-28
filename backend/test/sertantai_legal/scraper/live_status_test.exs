defmodule SertantaiLegal.Scraper.LiveStatusTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LiveStatus
  alias SertantaiLegal.Scraper.LiveStatus.Decision

  @in_force "✔ In force"
  @part "⭕ Part Revocation / Repeal"
  @revoked "❌ Revoked / Repealed / Abolished"

  defp row(by, affect, target \\ "Regulations", applied \\ "Yes"),
    do: %{by: by, affect: affect, target: target, applied: applied}

  defp ctx(law_type, law_extent, revokers \\ %{}),
    do: %{law_type: law_type, law_extent: law_extent, revokers: revokers}

  describe "revocation?/1" do
    test "repeal and revoke affects are revocations" do
      assert LiveStatus.revocation?("revoked")
      assert LiveStatus.revocation?("words repealed")
      assert LiveStatus.revocation?("rev")
    end

    test "a commencement of repeals is not a revocation (Coal Industry Act 1994)" do
      refute LiveStatus.revocation?(
               "Appointed day(s) for spec. repeals in Sch.11, Pt.III (1.3.1995)"
             )
    end

    test "amendments are not revocations" do
      refute LiveStatus.revocation?("substituted")
      refute LiveStatus.revocation?("")
    end
  end

  describe "whole?/1" do
    test "whole-instrument targets and 'in full' are whole" do
      assert LiveStatus.whole?(row("x", "revoked"))
      assert LiveStatus.whole?(row("x", "repealed", "Act"))
      assert LiveStatus.whole?(row("x", "rev", ""))
      assert LiveStatus.whole?(row("x", "revoked (with savings)", "Order"))
      assert LiveStatus.whole?(row("x", "repealed in full", "s. 3"))
    end

    test "section targets and partial markers are not whole" do
      refute LiveStatus.whole?(row("x", "revoked", "reg. 3"))
      refute LiveStatus.whole?(row("x", "revoked in part"))
      refute LiveStatus.whole?(row("x", "revoked in pt"))
      refute LiveStatus.whole?(row("x", "revoked in pt."))
      refute LiveStatus.whole?(row("x", "words repealed", "Act"))
      refute LiveStatus.whole?(row("x", "power to revoke conferred"))
    end

    test "overseas-territory revocations are not UK revocations" do
      refute LiveStatus.whole?(row("x", "revoked (Pitcairn)", "Order"))
      refute LiveStatus.whole?(row("x", "revoked (Sovereign Base Areas)", "Order"))
      refute LiveStatus.whole?(row("x", "revoked (British Indian Ocean Territory)", "Order"))
    end

    test "prospective revocations are not in force" do
      refute LiveStatus.whole?(row("x", "revoked (prosp.)"))
    end

    test "commencement rows are never whole" do
      refute LiveStatus.whole?(
               row("x", "Appointed day(s) for spec. repeals in Sch.11 (1.3.1995)", "Act")
             )
    end
  end

  describe "decide/2" do
    test "no revocation rows: in force" do
      assert %Decision{live: @in_force, kind: :in_force} =
               LiveStatus.decide([row("x", "substituted", "reg. 2")], ctx("uksi", "UK"))
    end

    test "only partial revocations: part revoked" do
      assert %Decision{live: @part, kind: :part_revoked} =
               LiveStatus.decide([row("x", "revoked", "reg. 2")], ctx("uksi", "UK"))
    end

    test "whole revocation by a UK-wide revoker: revoked, with the revoker and its made date" do
      d =
        LiveStatus.decide(
          [row("UK_uksi_2011_1524", "revoked")],
          ctx("uksi", "UK", %{"UK_uksi_2011_1524" => %{extent: "UK", date: ~D[2011-06-20]}})
        )

      assert %Decision{live: @revoked, kind: :revoked} = d

      assert [%{"by" => "UK_uksi_2011_1524", "revoker_made_date" => "2011-06-20"}] =
               d.evidence["revokers"]

      assert d.description == "Revoked by UK_uksi_2011_1524"
    end

    test "unapplied whole revocation is still revoked, recorded as revoked_unapplied" do
      d = LiveStatus.decide([row("UK_uksi_2005_1803", "rev", "", "Not yet")], ctx("uksi", "UK"))
      assert %Decision{live: @revoked, kind: :revoked_unapplied} = d
      assert d.evidence["applied"] == false
      assert d.description == "Revoked by UK_uksi_2005_1803 (not yet applied to the text)"
    end

    test "an English-applied Welsh-pending revocation counts as applied" do
      d =
        LiveStatus.decide(
          [
            row(
              "UK_uksi_2010_1",
              "revoked",
              "Regulations",
              "Not yet made to Welsh language version Applied to English language version"
            )
          ],
          ctx("uksi", "UK")
        )

      assert d.kind == :revoked
    end

    test "with savings is revoked and flagged" do
      d =
        LiveStatus.decide(
          [row("UK_uksi_2013_1119", "revoked (with savings)", "Order")],
          ctx("uksi", "UK")
        )

      assert d.live == @revoked
      assert d.evidence["with_savings"] == true
      assert d.description == "Revoked by UK_uksi_2013_1119, with savings"
    end

    test "commencement row alone leaves the law in force (Coal Industry Act 1994)" do
      d =
        LiveStatus.decide(
          [
            row(
              "UK_uksi_1995_273",
              "Appointed day(s) for spec. repeals in Sch.11, Pt.III (1.3.1995)",
              "Act"
            )
          ],
          ctx("ukpga", "UK")
        )

      assert d.live == @in_force
    end

    test "a devolved revoker revokes only its own jurisdiction: territorial (CoP (Amendment) Act 1989)" do
      d = LiveStatus.decide([row("UK_ssi_2025_165", "repealed", "Act")], ctx("ukpga", "E+W+S"))

      assert %Decision{live: @part, kind: :territorial} = d
      assert d.evidence["revoked_regions"] == ["S"]
      assert d.evidence["remaining_regions"] == ["E", "W"]
      assert d.description == "Revoked in S; in force in E+W"
    end

    test "a UK-level revoker's recorded extent is not trusted by default: revoked, gap kept as evidence" do
      d =
        LiveStatus.decide(
          [row("UK_uksi_2005_894", "revoked"), row("UK_wsi_2005_1806", "revoked")],
          ctx("uksi", "GB", %{"UK_uksi_2005_894" => %{extent: "E+W", date: nil}})
        )

      assert d.kind == :revoked
      assert d.evidence["extent_gap"] == ["S"]

      assert Enum.map(d.evidence["revokers"], & &1["basis"]) |> Enum.sort() ==
               ["devolved_revoker", "uk_level_revoker"]
    end

    test "with trust_revoker_extent: E+W SI plus Welsh WSI leave Scotland in force (Special Waste Regs 1996)" do
      d =
        LiveStatus.decide(
          [row("UK_uksi_2005_894", "revoked"), row("UK_wsi_2005_1806", "revoked")],
          "uksi"
          |> ctx("GB", %{"UK_uksi_2005_894" => %{extent: "E+W", date: nil}})
          |> Map.put(:trust_revoker_extent, true)
        )

      assert d.kind == :territorial
      assert d.evidence["remaining_regions"] == ["S"]

      assert Enum.map(d.evidence["revokers"], & &1["basis"]) |> Enum.sort() ==
               ["devolved_revoker", "revoker_extent"]
    end

    test "a jurisdiction in the law's title bounds it: a (Wales) order revoked by a WSI is revoked" do
      d =
        LiveStatus.decide(
          [row("UK_wsi_2004_1430", "revoked", "Order")],
          "uksi"
          |> ctx("UK")
          |> Map.put(:law_title, "Specified Risk Material (Amendment) (Wales) Order 2000")
        )

      assert d.kind == :revoked
    end

    test "title jurisdiction: the last marker counts, combinations parse, a devolved type wins" do
      scot_revoker = [row("UK_ssi_2023_1", "revoked", "Order")]

      d =
        LiveStatus.decide(
          scot_revoker,
          "uksi"
          |> ctx("UK")
          |> Map.put(
            :law_title,
            "African Swine Fever (Import Controls) (England and Scotland) Order 2022"
          )
        )

      assert d.description == "Revoked in S; in force in E"

      d =
        LiveStatus.decide(
          scot_revoker,
          "ssi"
          |> ctx("E+W+S")
          |> Map.put(:law_title, "Plant Health (Great Britain) Amendment (Scotland) Order 2001")
        )

      assert d.kind == :revoked
    end

    test "territorial revokers that together cover the law: revoked" do
      d =
        LiveStatus.decide(
          [
            row("UK_uksi_2005_894", "revoked"),
            row("UK_ssi_2005_1", "revoked"),
            row("UK_nisr_2005_2", "revoked")
          ],
          "uksi"
          |> ctx("UK", %{"UK_uksi_2005_894" => %{extent: "E+W", date: nil}})
          |> Map.put(:trust_revoker_extent, true)
        )

      assert d.kind == :revoked
    end

    test "a UK-level revoker missing from the DB is assumed to cover the law" do
      assert LiveStatus.decide([row("UK_uksi_2099_1", "revoked")], ctx("uksi", "UK")).kind ==
               :revoked
    end

    test "a devolved law's jurisdiction comes from its type, not its E+W legal extent" do
      d = LiveStatus.decide([row("UK_wsi_2018_433", "revoked")], ctx("wsi", "E+W"))
      assert d.kind == :revoked
    end

    test "an extent marker in the affect limits the revocation" do
      d = LiveStatus.decide([row("UK_uksi_2000_1", "revoked (S.)")], ctx("uksi", "UK"))
      assert d.kind == :territorial
      assert d.evidence["revoked_regions"] == ["S"]
    end

    test "unknown law extent: any whole revocation revokes" do
      assert LiveStatus.decide([row("UK_ssi_2000_1", "revoked")], ctx("eur", nil)).kind ==
               :revoked
    end

    test "evidence is JSON-safe" do
      d = LiveStatus.decide([row("UK_ssi_2025_165", "repealed", "Act")], ctx("ukpga", "UK"))
      assert {:ok, _} = Jason.encode(d.evidence)
    end
  end

  describe "rows_from_stats/1" do
    test "flattens the stored per-law stats JSONB into rows" do
      stats = %{
        "UK_uksi_2011_1524" => %{
          "name" => "UK_uksi_2011_1524",
          "details" => [
            %{"affect" => "revoked", "target" => "Regulations", "applied" => "Not yet"}
          ]
        }
      }

      assert LiveStatus.rows_from_stats(stats) == [
               row("UK_uksi_2011_1524", "revoked", "Regulations", "Not yet")
             ]

      assert LiveStatus.rows_from_stats(nil) == []
    end

    test "legacy-imported rows (effect text in target, no affect) are split at the revocation word" do
      stats = %{
        "UK_x" => %{
          "details" => [
            %{"target" => "revoked"},
            %{"target" => "s. 15(1) repealed (1.10.1994)"},
            %{"target" => "Regulations revoked by S.I. 2019/458, Sch. Para. 64A (as inserted)"},
            %{"target" => "s. 2A added (1.10.1994) and repealed (prosp.)"}
          ]
        }
      }

      rows = LiveStatus.rows_from_stats(stats)

      assert Enum.map(rows, &{&1.target, &1.affect}) == [
               {"", "revoked"},
               {"s. 15(1)", "repealed (1.10.1994)"},
               {"Regulations", "revoked by S.I. 2019/458, Sch. Para. 64A (as inserted)"},
               {"s. 2A added (1.10.1994) and", "repealed (prosp.)"}
             ]

      assert Enum.map(rows, &LiveStatus.whole?/1) == [true, false, true, false]
    end
  end

  describe "from_metadata/2" do
    test "a title marker is revoked with source title" do
      d = LiveStatus.from_metadata(:title, "Revoked")
      assert %Decision{live: @revoked, kind: :revoked} = d
      assert d.evidence["source"] == "title"
      assert d.description == "Revoked (from title)"
    end
  end
end

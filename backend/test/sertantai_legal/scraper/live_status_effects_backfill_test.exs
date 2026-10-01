defmodule SertantaiLegal.Scraper.LiveStatus.EffectsBackfillTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.LiveStatus.EffectsBackfill

  defp effect(by, provisions, type, affected, effect, application) do
    %Effect{
      type: type,
      affecting: by,
      affected_provisions: provisions,
      affected_extent: affected,
      effect_extent: effect,
      territorial_application: application,
      applied: true
    }
  end

  defp effects do
    [
      effect("UK_uksi_2005_894", "Regulations", "revoked", "E+W+S", "E+W", "E"),
      effect("UK_uksi_2005_894", "reg. 2", "words substituted", "E+W+S", "E+W", nil)
    ]
  end

  describe "load/2 (#168 cache compatibility)" do
    test "an older cache entry keeps the struct defaults; a cached in_force_date is a Date again" do
      dir = Path.join(System.tmp_dir!(), "load-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)

      File.write!(
        Path.join(dir, "UK_old.json"),
        Jason.encode!([%{"type" => "repealed", "affecting" => "UK_uksi_2020_1"}])
      )

      File.write!(
        Path.join(dir, "UK_new.json"),
        Jason.encode!([
          %{
            "type" => "omitted",
            "affecting" => "UK_uksi_2021_2",
            "in_force_date" => "2024-11-16",
            "prospective" => false,
            "affected_refs" => ["section-1"],
            "savings" => []
          }
        ])
      )

      assert [%{prospective: false, savings: [], affected_refs: [], in_force_date: nil}] =
               EffectsBackfill.load("UK_old", dir: dir)

      assert [%{in_force_date: ~D[2024-11-16], affected_refs: ["section-1"]}] =
               EffectsBackfill.load("UK_new", dir: dir)
    end
  end

  describe "enrich_stats/2" do
    test "adds effect extents to matching details; legacy rows are split before matching" do
      stats = %{
        "UK_uksi_2005_894" => %{
          "details" => [
            %{"target" => "Regulations", "affect" => "revoked", "applied" => "Yes"},
            %{"target" => "reg. 9", "affect" => "revoked", "applied" => "Yes"}
          ]
        },
        "UK_legacy" => %{"details" => [%{"target" => "revoked"}]}
      }

      effects = [effect("UK_legacy", nil, "revoked", nil, "S", nil) | effects()]
      {new, matched, total} = EffectsBackfill.enrich_stats(stats, effects)

      assert {matched, total} == {2, 3}

      assert [whole, section] = new["UK_uksi_2005_894"]["details"]
      assert whole["territorial_application"] == "E"
      assert whole["affected_extent"] == "E+W+S"
      refute Map.has_key?(section, "effect_extent")
      assert {whole["feed"], section["feed"]} == {"matched", "unmatched"}

      assert [%{"effect_extent" => "S"}] = new["UK_legacy"]["details"]
    end

    test "nil stats stay nil" do
      assert EffectsBackfill.enrich_stats(nil, effects()) == {nil, 0, 0}
    end
  end

  describe "batches/2 and batch/3" do
    test "one batch per tier / cluster, split when over size; Tier 2 numbered" do
      dir = Path.join(System.tmp_dir!(), "batches-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      File.write!(Path.join(dir, "UK_b.json"), "[]")

      targets = [
        {"0", "revoked", "UK_a"},
        {"1a", "revoked", "UK_b"},
        {"1a", "unsourced", "UK_c"},
        {"1a", "unsourced", "UK_d"},
        {"2", "revoked", "UK_e"},
        {"2", "revoked", "UK_f"},
        {"2", "type_floor", "UK_g"},
        {"2n", "revoked", "UK_h"}
      ]

      plan = EffectsBackfill.batches(targets, size: 2, dir: dir)

      assert Enum.map(plan, &{&1.batch, &1.names}) == [
               {"0", ["UK_a"]},
               {"1a.1", ["UK_b", "UK_c"]},
               {"1a.2", ["UK_d"]},
               {"2.01", ["UK_e", "UK_f"]},
               {"2.02", ["UK_g"]},
               {"2n.01", ["UK_h"]}
             ]

      assert %{groups: ["revoked", "unsourced"], cached: 1} = Enum.at(plan, 1)
      assert EffectsBackfill.batch(targets, "2.02", size: 2, dir: dir) == ["UK_g"]
      assert EffectsBackfill.batch(targets, "9", size: 2, dir: dir) == nil
    end
  end

  describe "plan/1 and apply!/2" do
    setup do
      dir = Path.join(System.tmp_dir!(), "effects-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test",
        type_code: "uksi",
        year: 2099,
        number: "1",
        geo_extent: "UK",
        rescinded_by_stats_per_law: %{
          "UK_uksi_2005_894" => %{
            "details" => [%{"target" => "Regulations", "affect" => "revoked", "applied" => "Yes"}]
          }
        }
      })
      |> Ash.create!()

      File.write!(
        Path.join(dir, name <> ".json"),
        Jason.encode!(Enum.map(effects(), &Map.from_struct/1))
      )

      %{dir: dir, name: name}
    end

    test "a legacy UK extent is re-resolved from AffectedExtent; details gain extents", ctx do
      [c] = EffectsBackfill.plan(dir: ctx.dir)

      assert c.name == ctx.name
      assert {c.old_extent, c.old_source} == {"UK", nil}
      assert {c.new_extent, c.new_source} == {"GB", "affected_effects"}
      assert EffectsBackfill.extent_change?(c)

      assert %{stats: 1, extent: 1} =
               EffectsBackfill.apply!([c], "effects_backfill_snapshot_test")

      %{rows: [[extent, source, stats]]} =
        Repo.query!(
          ~s|SELECT geo_extent, geo_extent_source, "🔻_rescinded_by_stats_per_law" FROM legal_register WHERE name = $1|,
          [ctx.name]
        )

      assert {extent, source} == {"GB", "affected_effects"}
      assert [%{"territorial_application" => "E"}] = stats["UK_uksi_2005_894"]["details"]

      %{rows: [[old]]} =
        Repo.query!("SELECT geo_extent FROM effects_backfill_snapshot_test WHERE name = $1", [
          ctx.name
        ])

      assert old == "UK"
    end
  end
end

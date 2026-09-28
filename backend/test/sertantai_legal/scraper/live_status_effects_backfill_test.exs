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

      assert [%{"effect_extent" => "S"}] = new["UK_legacy"]["details"]
    end

    test "nil stats stay nil" do
      assert EffectsBackfill.enrich_stats(nil, effects()) == {nil, 0, 0}
    end
  end

  describe "batch/3 and batches/2" do
    test "slice the priority-ordered targets; batches report groups and cached laws" do
      dir = Path.join(System.tmp_dir!(), "batches-#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      File.write!(Path.join(dir, "UK_b.json"), "[]")

      targets = [{"revoked", "UK_a"}, {"revoked", "UK_b"}, {"unsourced", "UK_c"}]

      assert EffectsBackfill.batch(targets, 1, 2) == ["UK_a", "UK_b"]
      assert EffectsBackfill.batch(targets, 2, 2) == ["UK_c"]

      assert [
               %{batch: 1, laws: 2, groups: ["revoked"], cached: 1},
               %{batch: 2, laws: 1, groups: ["unsourced"], cached: 0}
             ] = EffectsBackfill.batches(targets, size: 2, dir: dir)
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

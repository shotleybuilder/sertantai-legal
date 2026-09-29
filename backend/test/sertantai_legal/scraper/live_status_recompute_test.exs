defmodule SertantaiLegal.Scraper.LiveStatus.RecomputeTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LiveStatus.Recompute

  @in_force "✔ In force"
  @part "⭕ Part Revocation / Repeal"
  @revoked "❌ Revoked / Repealed / Abolished"

  defp law(type, attrs) do
    n = System.unique_integer([:positive])
    name = "UK_#{type}_2099_#{n}"

    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          country: "uk",
          name: name,
          title_en: "Test",
          type_code: type,
          year: 2099,
          number: "#{n}"
        },
        attrs
      )
    )
    |> Ash.create!()

    name
  end

  defp stats(by, affect, target \\ "Act"),
    do: %{
      by => %{
        "name" => by,
        "details" => [%{"affect" => affect, "target" => target, "applied" => "Yes"}]
      }
    }

  defp outcome(changes, name), do: Enum.find(changes, &(&1.name == name))

  defp db(name) do
    %{rows: [row]} =
      Repo.query!(
        "SELECT live, live_description, live_evidence->>'kind', coalesce(array_length(record_change_log, 1), 0) FROM legal_register WHERE name = $1",
        [name]
      )

    row
  end

  setup do
    coal =
      law("ukpga", %{
        geo_extent: "E+W+S",
        live: @revoked,
        rescinded_by_stats_per_law:
          stats("UK_uksi_1995_273", "Appointed day(s) for spec. repeals in Sch.11 (1.3.1995)")
      })

    scot =
      law("ukpga", %{
        geo_extent: "E+W+S",
        live: @revoked,
        rescinded_by_stats_per_law: stats("UK_ssi_2025_165", "repealed")
      })

    # Revoked by a legacy import: no whole-revocation row reproduces it.
    legacy =
      law("uksi", %{
        geo_extent: "UK",
        live: @revoked,
        live_description: "Current legislation",
        rescinded_by_stats_per_law: stats("UK_uksi_2000_1", "revoked", "reg. 3")
      })

    no_rows = law("uksi", %{live: @revoked, live_description: "Current legislation"})

    good =
      law("uksi", %{
        geo_extent: "UK",
        live: @revoked,
        rescinded_by_stats_per_law: stats("UK_uksi_2011_1524", "revoked", "Regulations")
      })

    # Same repeal, but the law's own application clause (read from LAT) is known
    scot_applied =
      law("ukpga", %{
        geo_extent: "E+W+S",
        live: @revoked,
        rescinded_by_stats_per_law: stats("UK_ssi_2025_165", "repealed"),
        application_clause: %{"regions" => ["E", "W", "S"], "clauses" => []}
      })

    %{
      coal: coal,
      scot: scot,
      scot_applied: scot_applied,
      legacy: legacy,
      no_rows: no_rows,
      good: good
    }
  end

  test "plan: the guard changes only laws the old rule explains", ctx do
    plan = Recompute.plan()

    assert %{action: :change, new_live: @in_force} = outcome(plan, ctx.coal)
    # territorial on extent alone is not a determination: held for the application clause
    assert %{action: :needs_application, new_live: @revoked, kind: :territorial} =
             outcome(plan, ctx.scot)

    assert %{action: :change, new_live: @part, kind: :territorial} =
             outcome(plan, ctx.scot_applied)

    # both rules read Part revoked from the rows; the legacy Revoked is replaced
    assert %{action: :change, new_live: @part, description: "Part revoked"} =
             outcome(plan, ctx.legacy)

    assert %{action: :describe, new_live: @revoked, description: "Revoked (source not recorded)"} =
             outcome(plan, ctx.no_rows)

    assert %{action: :describe, new_live: @revoked, description: "Revoked by UK_uksi_2011_1524"} =
             outcome(plan, ctx.good)
  end

  test "law_application: LAT clause, then the preamble's makers, then fractalaw's text/title" do
    preamble = %{"application" => %{"regions" => ["E", "W"], "source" => "preamble"}}

    assert Recompute.law_application(%{"regions" => ["E"]}, nil, nil, preamble) == ["E"]

    assert Recompute.law_application(%{"regions" => nil}, ["wales"], "title", preamble) == [
             "E",
             "W"
           ]

    assert Recompute.law_application(nil, ["wales"], "title", nil) == ["W"]
    assert Recompute.law_application(nil, ["wales"], "extent_fallback", nil) == nil
  end

  test "a true conflict: the rules disagree with each other and with the current value" do
    # old rule: Revoked (blank-target repeal); new rule: Part (feed shows no whole revocation)
    name =
      law("eur", %{
        live: @in_force,
        rescinded_by_stats_per_law: %{
          "UK_eur_2008_1272" => %{
            "details" => [%{"affect" => "repeal", "target" => "", "feed" => "unmatched"}]
          }
        }
      })

    assert %{action: :conflict, live: @in_force, old_rule_live: @revoked, kind: :part_revoked} =
             outcome(Recompute.plan(names: [name]), name)
  end

  test "apply!: snapshots, writes live/description/evidence together and logs live changes",
       ctx do
    Recompute.plan() |> Recompute.apply!("live_status_snapshot_test")

    assert [@in_force, "In force", "in_force", 1] = db(ctx.coal)
    assert [@revoked, "Revoked", "territorial", 0] = db(ctx.scot)
    assert [@part, "Revoked in S; in force in E+W", "territorial", 1] = db(ctx.scot_applied)
    assert [@part, "Part revoked", "part_revoked", 1] = db(ctx.legacy)
    assert [@revoked, "Revoked (source not recorded)", nil, 0] = db(ctx.no_rows)
    assert [@revoked, "Revoked by UK_uksi_2011_1524", "revoked", 0] = db(ctx.good)

    %{rows: [[live]]} =
      Repo.query!("SELECT live FROM live_status_snapshot_test WHERE name = $1", [ctx.coal])

    assert live == @revoked
  end
end

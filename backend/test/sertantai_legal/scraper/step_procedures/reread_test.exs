defmodule SertantaiLegal.Scraper.StepProcedures.RereadTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StepProcedures.Reread
  alias SertantaiLegal.Scraper.StepProcedures.Reread.Step

  defp rule(source, commences, treatment, lat? \\ true),
    do: %{source_law: source, commences: commences, treatment: treatment, lat?: lat?}

  describe "chain/2" do
    test "nothing stale is no chain" do
      assert Reread.chain([], "F") == []
      assert Reread.chain([], "F", []) == []
      assert Reread.chain([], "F", [], []) == []
    end

    test "stale amending laws: their read first, before the commencement and extent re-reads" do
      assert [
               %Step{substep: :amendments, laws: ["UK_x", "UK_y"]} = am,
               %Step{substep: :own},
               %Step{substep: :extents},
               %Step{substep: :build},
               %Step{substep: :stale}
             ] =
               Reread.chain([rule("UK_c", "UK_c", "clause_date")], "F", ["UK_a"], [
                 "UK_y",
                 "UK_x",
                 "UK_y"
               ])

      assert am.args == ~w(lat.amending --read --amending UK_x,UK_y)

      assert [%Step{substep: :amendments}, %Step{substep: :build}, %Step{substep: :stale}] =
               Reread.chain([], "F", [], ["UK_x"])
    end

    test "stale extent readings: their substep after the commencement ones, before the build" do
      assert [
               %Step{substep: :own},
               %Step{substep: :extents, laws: ["UK_a", "UK_b"]} = ext,
               %Step{substep: :build},
               %Step{substep: :stale}
             ] =
               Reread.chain([rule("UK_c", "UK_c", "clause_date")], "F", ["UK_b", "UK_a", "UK_b"])

      assert ext.args ==
               ~w(lat.amending --extents --amending UK_a,UK_b --cached --workers 1)

      assert [%Step{substep: :extents}, %Step{substep: :build}, %Step{substep: :stale}] =
               Reread.chain([], "F", ["UK_a"])
    end

    test "each stale rule goes to the substep that re-reads it, in order, then build and stale" do
      stale = [
        rule("UK_uksi_2020_1", "UK_uksi_2020_1", "clause_date"),
        rule("UK_uksi_2019_9", "UK_ukpga_1990_43", "order_date"),
        rule("UK_ukpga_1974_37", "UK_ukpga_1974_37", "feed_commencement"),
        rule("UK_uksi_1999_3", "UK_uksi_1999_3", "provision_dated", false),
        rule("UK_uksi_2019_8", "UK_ukpga_1990_43", "order_schedule"),
        rule("UK_uksi_2020_1", "UK_uksi_2020_1", "schedule_effect")
      ]

      assert [
               %Step{substep: :own, laws: ["UK_uksi_2020_1"]} = own,
               %Step{substep: :amending, laws: ["UK_uksi_1999_3"]} = am,
               %Step{substep: :orders, laws: ["UK_ukpga_1990_43"]} = ord,
               %Step{substep: :effects, laws: ["UK_ukpga_1974_37"]} = eff,
               %Step{substep: :build} = build,
               %Step{substep: :stale} = stale_step
             ] = Reread.chain(stale, "Waste, Water and Climate")

      assert own.args == ["lat.commencement", "--read", "--law", "UK_uksi_2020_1"]

      assert am.args ==
               [
                 "lat.commencement",
                 "--read-amending",
                 "--law",
                 "UK_uksi_1999_3",
                 "--workers",
                 "1"
               ]

      assert ord.args ==
               ["lat.commencement", "--read-orders", "--law", "UK_ukpga_1990_43", "--held"]

      assert eff.args == ["lat.commencement", "--effects", "--law", "UK_ukpga_1974_37"]
      assert build.args == ["lat.vocabulary", "--build", "--family", "Waste, Water and Climate"]
      assert stale_step.args == ["lat.stale", "--family", "Waste, Water and Climate"]
    end

    test "a substep with no stale rules is left out; laws are sorted and unique" do
      stale = [
        rule("UK_b", "UK_b", "clause_date"),
        rule("UK_a", "UK_a", "provision_dated"),
        rule("UK_b", "UK_b", "provision_dated")
      ]

      assert [%Step{substep: :own, laws: ["UK_a", "UK_b"]}, %Step{substep: :build}, _] =
               Reread.chain(stale, "F")
    end
  end

  describe "run/2" do
    test "runs each step in turn and stops at the first failure" do
      steps =
        Reread.chain([rule("UK_a", "UK_a", "clause_date"), rule("UK_c", "UK_c", "x", false)], "F")

      me = self()

      runner = fn %Step{substep: s} ->
        send(me, {:ran, s})
        if s == :amending, do: {1, 3}, else: {0, 2}
      end

      assert [{:own, 0, 2}, {:amending, 1, 3}] = Reread.run(steps, runner)
      assert_received {:ran, :own}
      assert_received {:ran, :amending}
      refute_received {:ran, :build}
    end

    test "every step runs when all pass" do
      steps = Reread.chain([rule("UK_a", "UK_a", "clause_date")], "F")

      assert [{:own, 0, _}, {:build, 0, _}, {:stale, 0, _}] =
               Reread.run(steps, fn _ -> {0, 1} end)
    end
  end
end

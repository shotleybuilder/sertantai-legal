defmodule SertantaiLegal.Scraper.Amendment.RuleTest do
  @moduledoc """
  AR-01: an amendment rule — what an amending provision changes: the law,
  its targets (expanded at read time), the operation and its level, the
  provision read. No new text, no position: we label which rows changed,
  never rebuild text (Jason 2026-10-19).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Rule

  defp block,
    do:
      Rule.new(
        amends: "UK_uksi_2014_1638",
        targets: ["reg.69", "reg.70"],
        operation: :substituted,
        level: :provision,
        source: %{
          law: "UK_uksi_2019_696",
          ref: "sch.16.para.28",
          text:
            "For Part 13, Sub-Part C (notification of conformity assessment bodies) substitute—"
        },
        treatment: :instruction
      )

  test "new/1 validates operation, level, targets and treatment" do
    assert %Rule{operation: :substituted, level: :provision} = block()

    for bad <- [
          [operation: :amended],
          [level: :part],
          [targets: []],
          [targets: [:s1]],
          [treatment: :note]
        ] do
      assert_raise ArgumentError, fn ->
        block() |> Map.from_struct() |> Map.merge(Map.new(bad)) |> Rule.new()
      end
    end
  end

  test "renumbered is an operation; words-level reaches the named provision only" do
    assert %Rule{operation: :renumbered} =
             %{block() | operation: :renumbered} |> Map.from_struct() |> Rule.new()

    assert %Rule{level: :words} = %{block() | level: :words} |> Map.from_struct() |> Rule.new()
  end

  test "to_text/1: one readable line — targets — operation (level) — treatment — source" do
    assert Rule.to_text(block()) ==
             "UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C (notification of conformity assessment bodies) substitute—”"

    words = %{
      block()
      | level: :words,
        targets: ["s.40"],
        treatment: :repeal_table,
        operation: :repealed
    }

    assert Rule.to_text(words) =~ "UK_uksi_2014_1638 s.40 — words repealed — repeal_table — "
  end

  test "to_row/1 and from_row/1 round-trip" do
    r = block()
    assert r |> Rule.to_row() |> Rule.from_row() == r
  end

  test "every treatment round-trips through a row (CV-S06 round 4: :in_definition)" do
    for t <- [:instruction, :quoted, :repeal_table, :in_definition] do
      r = %{block() | treatment: t}
      assert r |> Rule.to_row() |> Rule.from_row() == r
    end
  end
end

defmodule SertantaiLegal.Scraper.Amendment.RuleTest do
  @moduledoc """
  AR-01: an amendment rule — what an amending provision changes: the law,
  its targets (expanded at read time), the operation and its level, the
  provision read. No new text, no position: we label which rows changed,
  never rebuild text (Jason 2026-10-19).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw

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

  describe "a rule's targets as the change vocabulary's held rows" do
    defp rule(targets, treatment, level \\ :provision),
      do:
        Rule.new(
          amends: "UK_ukpga_1974_37",
          targets: targets,
          operation: :repealed,
          level: level,
          source: %{law: "UK_ukpga_2008_20", ref: "schedule-3-paragraph-2-1", text: nil},
          treatment: treatment
        )

    defp targets(rules, known),
      do: for({_key, t, _claims} <- AmendingLaw.read(rules, %{}, known), do: t)

    test "a named place is its deepest held reading: \"subsection (6)(e) is omitted\" is s.15(6)(e), never s.15(6)" do
      r = rule(["s.15(6)", "s.15(e)", "s.15(6)(e)"], :instruction)
      assert targets([r], ["s.15", "s.15(6)", "s.15(6)(e)"]) == ["s.15(6)(e)"]
    end

    test "a range is each provision held in it, at its depth (HSWA ss.61–74, Building Act 1984 Sch. 7)" do
      r = rule(["s.61..s.74"], :repeal_table)
      known = ["s.60", "s.61", "s.61(1)", "s.62", "s.74", "s.75"]
      assert targets([r], known) |> Enum.sort() == ["s.61", "s.62", "s.74"]
    end

    test "a reading the law doesn't hold falls back to the place it does" do
      r = rule(["s.15(6)", "s.15(e)", "s.15(6)(e)"], :instruction)
      assert targets([r], ["s.15", "s.15(6)"]) == ["s.15(6)"]
    end

    test "siblings named stay apart: \"subsections (5) and (6)\"" do
      r = rule(["s.47(5)", "s.47(6)"], :instruction)
      assert Enum.sort(targets([r], ["s.47(5)", "s.47(6)"])) == ["s.47(5)", "s.47(6)"]
    end

    test "a reading held only under a skipped-level spelling is that spelling alone (HSWA s.28(3)(f)(i) as section-28-f-i)" do
      r =
        rule(
          [
            "s.28(3)",
            "s.28(f)",
            "s.28(i)",
            "s.28(3)(f)",
            "s.28(3)(i)",
            "s.28(f)(i)",
            "s.28(3)(f)(i)"
          ],
          :instruction,
          :words
        )

      assert targets([r], ["s.28", "s.28(3)", "s.28(f)", "s.28(f)(i)"]) == ["s.28(f)(i)"]
    end

    test "a quote's provisions follow its top: an inserted s.51A is s.51A" do
      r = rule(["s.51A", "s.51A(1)", "s.51A(2)"], :quoted)
      assert targets([r], ["s.51A", "s.51A(1)", "s.51A(2)"]) == ["s.51A"]
    end
  end
end

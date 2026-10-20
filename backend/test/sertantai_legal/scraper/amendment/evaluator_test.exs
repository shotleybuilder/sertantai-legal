defmodule SertantaiLegal.Scraper.Amendment.EvaluatorTest do
  @moduledoc """
  AR-02: which row of the amended law a rule reaches — the target that
  covers the row: the row itself, else (whole-provision level) its nearest
  covering ancestor, as the row-driven matcher placed records (LR-08: a
  whole-provision instruction on a sub-provision row targets the
  provision's own row). Golden cases from LR-08, LR-41, LR-43.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Rule}
  alias SertantaiLegal.Scraper.LatRef

  @law "UK_ukpga_1989_29"

  defp rule(targets, op, level, amends \\ @law),
    do:
      Rule.new(
        amends: amends,
        targets: targets,
        operation: op,
        level: level,
        source: %{law: "UK_ukpga_2000_27", ref: "s.60(5)", text: nil},
        treatment: :instruction
      )

  defp reach(rule, sid, ctx \\ %{}), do: Evaluator.reach(rule, "#{rule.amends}:#{sid}", ctx)

  test "an inserted subsection reaches its own row (LR-08: s.25(5A))" do
    r = rule(["s.25(5A)"], :inserted, :provision)
    assert reach(r, "s.25(5A)") == {:ok, "#{@law}:s.25(5A)"}
    assert reach(r, "s.25(5)") == :no_match
  end

  test "a whole-provision instruction on a sub-provision row targets the provision's own row" do
    r = rule(["s.36"], :substituted, :provision)
    assert reach(r, "s.36(1)") == {:ok, "#{@law}:s.36"}
    assert reach(r, "s.36") == {:ok, "#{@law}:s.36"}
    assert reach(r, "s.37") == :no_match
  end

  test "words-level lands on the provision it names, as whole provisions do — never on its children (AR-03 parity: \"In regulation 31— after “x” insert “y”\")" do
    r = rule(["s.40(2)"], :substituted, :words)
    assert reach(r, "s.40(2)") == {:ok, "#{@law}:s.40(2)"}
    # a note on a child row: the change is to the named provision
    assert reach(r, "s.40(2)(a)") == {:ok, "#{@law}:s.40(2)"}
    assert reach(r, "s.40") == :no_match

    assert Evaluator.rows(r, Enum.map(["s.40(2)", "s.40(2)(a)", "s.40(2)(b)"], &"#{@law}:#{&1}")) ==
             ["#{@law}:s.40(2)"]
  end

  test "a block's quoted provisions (LR-43: SI 2019/696 on SI 2014/1638 Pt. 13 Sub-Pt. C)" do
    r =
      rule(
        ["reg.69", "reg.69(1)", "reg.69(1)(a)", "reg.76", "reg.76(1)"],
        :substituted,
        :provision,
        "UK_uksi_2014_1638"
      )

    assert reach(r, "reg.69(1)(a)") == {:ok, "UK_uksi_2014_1638:reg.69(1)(a)"}
    # a row deeper than the quote: its nearest quoted ancestor
    assert reach(r, "reg.76(1)(b)") == {:ok, "UK_uksi_2014_1638:reg.76(1)"}
    assert reach(r, "reg.80") == :no_match
  end

  test "a repeals table's range: \"Sections 41 to 43.\" (by number, or document order)" do
    r = rule(["s.41..s.43"], :repealed, :provision)
    assert reach(r, "s.42(1)") == {:ok, "#{@law}:s.42"}
    assert reach(r, "s.44") == :no_match

    ctx = %{order: ["s.41", "s.41A", "s.42", "s.43"]}
    assert reach(r, "s.41A", ctx) == {:ok, "#{@law}:s.41A"}
  end

  test "a row with an extent suffix or a duplicate disambiguator is its provision" do
    r = rule(["s.36"], :substituted, :provision)
    assert reach(r, "s.36(1)[E+W]") == {:ok, "#{@law}:s.36"}
    w = rule(["s.40(2)"], :substituted, :words)
    assert reach(w, "s.40(2)[S]") == {:ok, "#{@law}:s.40(2)[S]"}
  end

  test "another law's row is never reached" do
    r = rule(["s.36"], :substituted, :provision)
    assert Evaluator.reach(r, "UK_ukpga_1990_43:s.36", %{}) == :no_match
  end

  test "rows/3: the targets a rule reaches among a law's rows" do
    r = rule(["s.36"], :substituted, :provision)
    sids = Enum.map(["s.35", "s.36", "s.36(1)", "s.36(2)", "s.37"], &"#{@law}:#{&1}")
    assert Evaluator.rows(r, sids, %{}) == ["#{@law}:s.36"]
  end

  test "LatRef.chain/2: the ref, its bracket ancestors, then its containers" do
    ctx = %{ancestors: fn "s.12" -> ["pt.2.ch.1", "pt.2"] end}

    assert LatRef.chain("UK_x:s.12(3)(a)[E+W]", ctx) == [
             "s.12(3)(a)",
             "s.12(3)",
             "s.12",
             "pt.2.ch.1",
             "pt.2"
           ]

    assert LatRef.chain("UK_x:s.33(2)(a)n1", %{}) == ["s.33(2)(a)", "s.33(2)", "s.33"]
  end
end

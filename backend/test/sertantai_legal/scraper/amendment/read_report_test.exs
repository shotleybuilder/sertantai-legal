defmodule SertantaiLegal.Scraper.Amendment.ReadReportTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.{ReadReport, Rule}

  defp rule(amends, target, ref, op \\ :inserted),
    do: %Rule{
      amends: amends,
      targets: [target],
      operation: op,
      level: :provision,
      source: %{law: "UK_x_2019_1", ref: ref, text: nil},
      treatment: :instruction
    }

  test "no change: nothing to report" do
    rules = [rule("UK_a", "s.1", "section-1")]
    diff = ReadReport.diff(rules, rules)
    assert ReadReport.changed?(diff) == false
    assert ReadReport.lines("UK_x_2019_1", diff) == []
  end

  test "rules moved from one amended law to another, counted per law and provision" do
    old = [rule("UK_a", "s.1", "section-1"), rule("UK_a", "s.2", "section-2")]
    new = [rule("UK_b", "s.1", "section-1"), rule("UK_a", "s.2", "section-2")]

    diff = ReadReport.diff(old, new)

    assert ReadReport.changed?(diff)
    assert diff.removed == %{"UK_a" => 1}
    assert diff.added == %{"UK_b" => 1}
    assert diff.provisions == ["section-1"]

    assert ReadReport.lines("UK_x_2019_1", diff) == [
             "UK_x_2019_1: −1 UK_a, +1 UK_b (1 provision: section-1)"
           ]
  end

  test "the same rules in another order are no change; text is not compared" do
    a = rule("UK_a", "s.1", "section-1")

    b = %{
      rule("UK_a", "s.2", "section-2")
      | source: %{law: "UK_x_2019_1", ref: "section-2", text: "x"}
    }

    c = %{b | source: %{b.source | text: "y"}}
    refute ReadReport.changed?(ReadReport.diff([a, b], [c, a]))
  end

  test "the summary: laws read, laws changed, rules before and after" do
    diffs = %{
      "UK_x" => ReadReport.diff([rule("UK_a", "s.1", "section-1")], []),
      "UK_y" => ReadReport.diff([], [])
    }

    assert ReadReport.summary(diffs) == "2 laws read, 1 changed; rules 1 → 0"
  end
end

defmodule SertantaiLegal.Scraper.StepProcedures.RuleDiffTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.StepProcedures.RuleDiff

  defp rule(ref, date) do
    Rule.new(
      commences: "UK_a",
      scope: [ref],
      when: {:date, date},
      source: %{law: "UK_a", ref: "s.9", text: "t"},
      treatment: :clause_date
    )
  end

  test "an unchanged reading changes nothing" do
    rules = [rule("s.1", ~D[2020-01-01]), rule("s.2", ~D[2020-01-01])]
    assert RuleDiff.diff(rules, Enum.reverse(rules)) |> RuleDiff.same?()
  end

  test "the rules added and gone, each counted as often as it appears" do
    a = rule("s.1", ~D[2020-01-01])
    b = rule("s.2", ~D[2020-01-01])
    b2 = rule("s.2", ~D[2021-01-01])

    assert RuleDiff.diff([a, a, b], [a, b2]) == %{added: [b2], gone: [a, b]}
    refute RuleDiff.diff([a], [a, a]) |> RuleDiff.same?()
  end
end

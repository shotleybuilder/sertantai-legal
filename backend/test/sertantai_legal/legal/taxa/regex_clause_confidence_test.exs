defmodule SertantaiLegal.Legal.Taxa.RegexClauseConfidenceTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.RegexClauseConfidence

  describe "score/2" do
    test "nil clause returns 0.0" do
      assert RegexClauseConfidence.score(nil, []) == 0.0
    end

    test "empty clause returns 0.0" do
      assert RegexClauseConfidence.score("", []) == 0.0
    end

    test "high confidence: captured action, clean ending, adequate length, strong modal" do
      clause = "The employer shall ensure that all workers receive adequate training."
      score = RegexClauseConfidence.score(clause, captured_action: true)
      # All 4 signals: 0.25 + 0.25 + 0.20 + 0.15 = 0.85
      assert score == 0.85
    end

    test "low confidence: no capture, truncated, short, weak modal" do
      clause = "may..."
      score = RegexClauseConfidence.score(clause, captured_action: false)
      # No signals: 0.0
      assert score == 0.0
    end

    test "captured_action adds 0.25" do
      clause = "the authority must..."
      without = RegexClauseConfidence.score(clause, captured_action: false)
      with_capture = RegexClauseConfidence.score(clause, captured_action: true)
      assert with_capture - without == 0.25
    end

    test "clean ending (no ellipsis) adds 0.25" do
      # Same length (>30), same modal — only difference is trailing "..."
      clause_truncated = "The employer shall ensure that all workers..."
      clause_clean = "The employer shall ensure that all workers."

      truncated = RegexClauseConfidence.score(clause_truncated, [])
      clean = RegexClauseConfidence.score(clause_clean, [])

      assert_in_delta clean - truncated, 0.25, 0.001
    end

    test "adequate length (>30 chars) adds 0.20" do
      short = "the authority must..."
      long = "The planning authority must consult the relevant bodies."

      short_score = RegexClauseConfidence.score(short, [])
      long_score = RegexClauseConfidence.score(long, [])

      # Long has: clean ending (+0.25) + adequate length (+0.20) + strong modal (+0.15)
      # Short has: strong modal (+0.15) only (truncated, <30 chars)
      assert long_score > short_score
    end

    test "strong modal (shall/must) adds 0.15" do
      with_must = "The employer must ensure safety."
      with_may = "The employer may determine the scope."

      must_score = RegexClauseConfidence.score(with_must, [])
      may_score = RegexClauseConfidence.score(with_may, [])

      assert_in_delta must_score - may_score, 0.15, 0.001
    end

    test "defaults captured_action to false" do
      clause = "The employer shall ensure safety."

      assert RegexClauseConfidence.score(clause, []) ==
               RegexClauseConfidence.score(clause, captured_action: false)
    end
  end
end

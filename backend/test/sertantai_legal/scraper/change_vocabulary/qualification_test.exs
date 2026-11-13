defmodule SertantaiLegal.Scraper.ChangeVocabulary.QualificationTest do
  @moduledoc """
  A feed stage's qualification read into classes, and whether it limits
  the commencement's scope (CV-S02b review E).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Qualification

  test "a power to make regulations is a purpose: partial (CJA 2003 s.254(6A); Jason 2026-11-04)" do
    q = "for enabling the exercise of power to make regulations"
    assert Qualification.classes(q) == ["purposes"]
    assert Qualification.partial?(q)
  end

  test "specified purposes partial; wholly in force not" do
    assert Qualification.partial?("for specified purposes")
    refute Qualification.partial?("wholly in force")
  end

  test "a completing qualification that names a territory is partial: complete there only" do
    for q <- [
          "for W. in so far as not already in force",
          "for E. In so far as not already in force",
          "wholly in force for W.",
          "in so far as not already in force, except in relation to W."
        ] do
      assert "complete" in Qualification.classes(q), q
      assert "territory" in Qualification.classes(q), q
      assert Qualification.partial?(q), q
    end
  end

  test "a completing qualification naming no territory is not partial" do
    refute Qualification.partial?("in so far as not already in force")
    refute Qualification.partial?("so far as not already in force for specified purposes")
    refute Qualification.partial?(nil)
  end
end

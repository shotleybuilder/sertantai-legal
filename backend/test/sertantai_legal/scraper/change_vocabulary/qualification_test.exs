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
end

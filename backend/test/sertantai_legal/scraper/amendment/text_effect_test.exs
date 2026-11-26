defmodule SertantaiLegal.Scraper.Amendment.TextEffectTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.TextEffect

  test "a text change is one the reader reads" do
    for type <- ["substituted", "inserted", "repealed", "words repealed", "renumbered", "amended"] do
      assert {type, TextEffect.text_effect?(%{type: type})} == {type, true}
    end
  end

  test "a coming into force or a modification is not" do
    for type <- ["coming into force", "modified", "applied"] do
      assert {type, TextEffect.text_effect?(%{type: type})} == {type, false}
    end
  end
end

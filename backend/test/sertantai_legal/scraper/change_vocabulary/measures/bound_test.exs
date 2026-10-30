defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.BoundTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Bound

  # The 95% upper bounds the step sessions published, worked out by hand
  # before this module (CV-S05 to CV-S09), as percentages to two places.
  @published [
    {0, 150, 1.98},
    {0, 73, 4.02},
    {3, 150, 5.09},
    {0, 160, 1.85},
    {0, 86, 3.42},
    {0, 112, 2.64},
    {0, 81, 3.63},
    {10, 300, 5.59},
    {1, 300, 1.57}
  ]

  describe "upper/2" do
    test "reproduces every published bound" do
      for {wrong, n, percent} <- @published do
        assert Float.round(100 * Bound.upper(wrong, n), 2) == percent,
               "#{wrong}/#{n}: expected #{percent}%"
      end
    end

    test "none wrong has the closed form 1 - 0.05^(1/n)" do
      assert_in_delta Bound.upper(0, 150), 1 - :math.pow(0.05, 1 / 150), 1.0e-9
    end

    test "all wrong is 1" do
      assert Bound.upper(5, 5) == 1.0
    end

    test "grows with the wrong count and shrinks with the sample" do
      assert Bound.upper(1, 150) > Bound.upper(0, 150)
      assert Bound.upper(0, 300) < Bound.upper(0, 150)
    end

    test "takes another confidence" do
      assert Bound.upper(0, 150, 0.99) > Bound.upper(0, 150)
    end

    test "an empty sample has no bound" do
      assert Bound.upper(0, 0) == nil
    end
  end

  describe "passes?/3" do
    test "under the limit passes" do
      assert Bound.passes?(0, 150, 0.02)
      assert Bound.passes?(0, 73, 0.05)
    end

    test "149 clean items do not reach under 2%" do
      refute Bound.passes?(0, 148, 0.02)
      assert Bound.passes?(0, 149, 0.02)
    end

    test "CV-S05's law bound misses 5% (accepted as marginal by Jason, 2026-10-28)" do
      refute Bound.passes?(3, 150, 0.05)
    end
  end
end

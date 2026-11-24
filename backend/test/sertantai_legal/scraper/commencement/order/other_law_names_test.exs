defmodule SertantaiLegal.Scraper.Commencement.Order.OtherLawNamesTest do
  @moduledoc "Whether an item's law is the Act commenced, or another (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.OtherLaw

  @aliases ["the act", "the environment act 1995"]

  test "own_law?/2: \"the Act\", an alias, or its short title" do
    assert OtherLaw.own_law?("the Act", @aliases)
    assert OtherLaw.own_law?("the Environment Act", @aliases)
    refute OtherLaw.own_law?("the Gas Act 1986", @aliases)
  end
end

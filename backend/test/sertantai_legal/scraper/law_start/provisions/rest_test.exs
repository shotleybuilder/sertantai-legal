defmodule SertantaiLegal.Scraper.LawStart.Provisions.RestTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Rest

  test "a statement of the whole law" do
    assert Rest.whole_law?("These Regulations come into force on 1st May 2008.")
    assert Rest.whole_law?("(c) comes into force on 1st May 2008")
    refute Rest.whole_law?("Regulation 2 comes into force on 1st May 2008")
  end
end

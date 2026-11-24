defmodule SertantaiLegal.Scraper.LawStart.Provisions.MentionedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Mentioned

  test "a subject with no Schedule is left as it is" do
    assert Mentioned.schedule_part_first("regulation 4") == "regulation 4"
  end

  test "nothing mentioned, no refs" do
    assert Mentioned.mentioned_items("regulation 4", [], "UK_x:reg.1") == {[], [], []}
  end
end

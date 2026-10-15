defmodule SertantaiLegal.Scraper.LatStatusTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatStatus

  @law "UK_ukpga_2006_46"

  describe "repealed_text?/1" do
    test "dotted text and the parser's markers are repealed" do
      assert LatStatus.repealed_text?(". . . . . . . . . . . . . . . . . . . . ")
      assert LatStatus.repealed_text?("  . . . ")
      assert LatStatus.repealed_text?("[Repealed]")
      assert LatStatus.repealed_text?("[Revoked]")
    end

    test "text that starts with dots but continues is live" do
      refute LatStatus.repealed_text?(". . . , a person guilty of an offence against this Part")
      refute LatStatus.repealed_text?("The employer shall ensure . . . that")
      refute LatStatus.repealed_text?("")
      refute LatStatus.repealed_text?(nil)
      refute LatStatus.repealed_text?("...")
    end
  end

  describe "covers?/2" do
    test "a note's target covers itself, its sub-provisions and its extent versions" do
      assert LatStatus.covers?("#{@law}:s.6", "#{@law}:s.6")
      assert LatStatus.covers?("#{@law}:s.6", "#{@law}:s.6(1)(a)")
      assert LatStatus.covers?("#{@law}:s.6", "#{@law}:s.6[S]")
      refute LatStatus.covers?("#{@law}:s.6", "#{@law}:s.60")
      refute LatStatus.covers?("#{@law}:s.6", "#{@law}:s.6A")
    end
  end

  describe "statuses/0" do
    test "the five agreed values" do
      assert LatStatus.statuses() ==
               ~w(in_force in_force_partial repealed repealed_saved prospective)
    end
  end

  test "note_targets/1 is every row the note is placed on" do
    assert LatStatus.note_targets(%{affected_sections: ["L:s.1", "L:s.2"]}) == [
             "L:s.1",
             "L:s.2"
           ]

    assert LatStatus.note_targets(%{affected_sections: nil}) == []
  end

  test "ancestors/1 keeps the extent tag at every level (a note on reg.33[S] covers reg.33(1)[S])" do
    assert LatStatus.ancestors("L:reg.33(1)(a)[S]") ==
             [
               "L:reg.33(1)(a)[S]",
               "L:reg.33(1)[S]",
               "L:reg.33[S]",
               "L:reg.33(1)(a)",
               "L:reg.33(1)",
               "L:reg.33"
             ]
  end
end

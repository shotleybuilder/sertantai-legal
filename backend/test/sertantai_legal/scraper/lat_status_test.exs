defmodule SertantaiLegal.Scraper.LatStatusTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatStatus

  @law "UK_ukpga_2006_46"

  defp row(sid, text, status \\ nil),
    do: %{section_id: "#{@law}:#{sid}", text: text, status: status}

  defp note(targets, text, code_type \\ "commencement"),
    do: %{
      affected_sections: Enum.map(targets, &"#{@law}:#{&1}"),
      text: text,
      code_type: code_type
    }

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

  describe "note_target/1" do
    test "the last (deepest) affected section is the target; ancestors are context" do
      assert LatStatus.note_target(note(["pt.II", "h.63", "s.76A"], "x")) == "#{@law}:s.76A"
      assert LatStatus.note_target(%{affected_sections: []}) == nil
      assert LatStatus.note_target(%{affected_sections: nil}) == nil
    end
  end

  describe "resolve/2" do
    test "live text is in_force; dotted text is repealed" do
      rows = [row("s.1", "The employer must keep records."), row("s.2", ". . . . . ")]

      assert LatStatus.resolve(rows, []) == %{
               "#{@law}:s.1" => "in_force",
               "#{@law}:s.2" => "repealed"
             }
    end

    test "a parser-set prospective status is kept" do
      assert LatStatus.resolve([row("s.3", "New duty.", "prospective")], []) ==
               %{"#{@law}:s.3" => "prospective"}
    end

    test "commenced for specified purposes only → in_force_partial, inherited by sub-provisions" do
      rows = [row("s.6", "Heading"), row("s.6(1)", "A duty."), row("s.7", "Other.")]

      notes = [
        note(
          ["pt.1", "s.6"],
          "S. 6 in force at 20.1.2009 for specified purposes by , S.I. 2009/39 art. 2(1)(e)"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.6" => "in_force_partial",
               "#{@law}:s.6(1)" => "in_force_partial",
               "#{@law}:s.7" => "in_force"
             }
    end

    test "a later full commencement overrides partial" do
      rows = [row("s.366", "A duty.")]

      notes = [
        note(
          ["s.366"],
          "S. 366 wholly in force at 1.10.2008; s. 366 in force for certain purposes at 1.10.2007"
        ),
        note(["s.366"], "S. 366 in force at 1.10.2007 for specified purposes by S.I. 2007/2194")
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.366" => "in_force"}
    end

    test "'in so far as not already in force' is full commencement" do
      rows = [row("s.57(1D)", "A duty.")]

      notes = [
        note(
          ["s.57(1D)"],
          "S. 57(1D) inserted (31.1.2017 for specified purposes, 2.5.2017 in so far as not already in force) by Policing and Crime Act 2017 (c. 3)",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.57(1D)" => "in_force"}
    end

    test "'... and otherwise <date>' is full commencement (spot check, WIA 1991 s.101A)" do
      rows = [row("s.101A(4)(b)", "A duty."), row("s.33BA", "Another.")]

      notes = [
        note(
          ["s.101A"],
          "S. 101A inserted (1.2.1996 for specified purposes and otherwise 1.4.1996) by 1995 c. 25",
          "amendment"
        ),
        note(
          ["s.33BA"],
          "S. 33BA inserted (16.5.2001 for certain purposes and otherwise 1.10.2001) by 2000 c. 27",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.101A(4)(b)" => "in_force",
               "#{@law}:s.33BA" => "in_force"
             }
    end

    test "a modification note's 'specified purposes' is not commencement (WIA 1991 s.37A)" do
      rows = [row("s.37A", "A duty.")]

      notes = [
        note(
          ["s.37A"],
          "Ss. 37A-37D modified (1.10.2004 for specified purposes) by S.I. 2004/2528",
          "modification"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.37A" => "in_force"}
    end

    test "repealed with a savings note → repealed_saved (D2: only with a note)" do
      rows = [row("s.30", ". . . "), row("s.31", ". . . ")]

      notes = [
        note(
          ["s.30"],
          "S. 30 repealed (1.4.1996) by , (with transitional provisions and savings in Sch. 2) 1994 c. 19",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.30" => "repealed_saved",
               "#{@law}:s.31" => "repealed"
             }
    end

    test "'Savings' in an instrument title is not a savings note" do
      rows = [row("s.43", ". . . ")]

      notes = [
        note(
          ["s.43"],
          "S. 43 repealed (1.4.2014) by The Enterprise and Regulatory Reform Act 2013 (Competition) (Consequential, Transitional and Saving Provisions) Order 2014",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.43" => "repealed"}
    end

    test "savings on a non-repeal note don't save anything; a live row stays in_force" do
      rows = [row("s.86D", "Words substituted.")]

      notes = [
        note(
          ["s.86D"],
          "Words in s. 86D substituted (1.4.2013) by , ; (with transitional provisions and savings in ) Police and Fire Reform (Scotland) Act 2012",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.86D" => "in_force"}
    end

    test "partial commencement never revives a repealed or prospective row" do
      rows = [row("s.6", ". . . "), row("s.8", "Future duty.", "prospective")]

      notes = [
        note(["s.6"], "S. 6 in force at 20.1.2009 for specified purposes"),
        note(["s.8"], "S. 8 in force at 1.1.2030 for specified purposes")
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.6" => "repealed",
               "#{@law}:s.8" => "prospective"
             }
    end
  end

  describe "statuses/0" do
    test "the five agreed values" do
      assert LatStatus.statuses() ==
               ~w(in_force in_force_partial repealed repealed_saved prospective)
    end
  end
end

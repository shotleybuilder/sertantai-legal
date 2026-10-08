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

    test "'in so far as it is / they are not already in force' is full commencement (RTA 1988 s.184)" do
      rows = [row("s.184(1)", "A duty."), row("s.184(2)", "Another.")]

      notes = [
        note(
          ["s.184(1)"],
          "Words in s. 184(1) substituted (28.3.2009 for certain purposes, 31.10.2009 in so far as it is not already in force) by Armed Forces Act 2006 (c. 52)",
          "amendment"
        ),
        note(
          ["s.184(2)"],
          "Words in s. 184(2) substituted (28.3.2009 for certain purposes, 31.10.2009 in so far as they are not already in force) by Armed Forces Act 2006 (c. 52)",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.184(1)" => "in_force",
               "#{@law}:s.184(2)" => "in_force"
             }
    end

    test "a retained repeal covering the row's whole extent is repealed_saved; part of it stays in force" do
      rows = [
        Map.merge(row("reg.5", "Saved rule."), %{excluded_extent: "E+W+S", extent_code: "E+W+S"}),
        Map.merge(row("reg.6", "Scottish rule."), %{excluded_extent: "S", extent_code: "E+W+S"}),
        Map.merge(row("reg.7", "No extent."), %{excluded_extent: "S", extent_code: nil})
      ]

      assert LatStatus.resolve(rows, []) == %{
               "#{@law}:reg.5" => "repealed_saved",
               "#{@law}:reg.6" => "in_force",
               "#{@law}:reg.7" => "in_force"
             }
    end

    test "a partial note about another provision doesn't make the row partial (NPA 2017)" do
      rows = [row("s.44(2)(b)", "A duty."), row("s.2", "Notification.")]

      notes = [
        note(["s.44(2)(b)"], "S. 2 in force for specified purposes at Royal Assent, see s. 46"),
        note(["s.2"], "S. 2 in force for specified purposes at Royal Assent, see s. 46")
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.44(2)(b)" => "in_force",
               "#{@law}:s.2" => "in_force_partial"
             }
    end

    test "a range in the note's subject covers its provisions" do
      rows = [row("s.44", "A."), row("s.48", "B.")]

      notes = [
        note(["s.44"], "Ss. 43-45 in force for specified purposes at 1.1.2020 by S.I. 2019/1"),
        note(["s.48"], "Ss. 43-45 in force for specified purposes at 1.1.2020 by S.I. 2019/1")
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.44" => "in_force_partial",
               "#{@law}:s.48" => "in_force"
             }
    end

    test "\"for specified purposes\" in an except clause or after \"by\" isn't partial commencement" do
      rows = [row("s.50", "A."), row("s.82(1)", "B.")]

      notes = [
        note(
          ["s.50"],
          "Act repealed (except for ss. 49(1) for specified purposes and s. 51) (E.W.) (1.10.2010) by x",
          "amendment"
        ),
        note(
          ["s.82(1)"],
          "“41(8)” inserted (temp.) by Planning (Consequential Provisions) Act 1990 (c. 11), s. 6 (in force for specified purposes)",
          "amendment"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.50" => "in_force",
               "#{@law}:s.82(1)" => "in_force"
             }
    end

    test "\"except for certain purposes\" on an insertion and \"partly in force\" are partial (TCPA 1990 s.322A, EPA 1990 s.162)" do
      rows = [row("s.322A(2)", "A."), row("s.162(3)", "B.")]

      notes = [
        note(
          ["s.322A(2)"],
          "S. 322A inserted (2.1.1992 except for certain purposes which exception is prosp.) by Planning and Compensation Act 1991 (c. 34)",
          "amendment"
        ),
        note(
          ["s.162(3)"],
          "S. 162 partly in force; s. 162 partly in force at: 1.1.1991 by S.I. 1990/2635, art. 3; 14.1.1991 for specified purposes by S.I. 1990/2635, art. 4"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.322A(2)" => "in_force_partial",
               "#{@law}:s.162(3)" => "in_force_partial"
             }
    end

    test "a commencement history that names no purposes is not partial (\"partly in force\" alone)" do
      rows = [row("s.32(1)", "A.")]

      notes = [
        note(
          ["s.32(1)"],
          "S. 32 partly in force; s. 32(10)(11) in force at Royal Assent; s. 32(1)-(9) in force 13.1.2004 see s. 40(6)"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{"#{@law}:s.32(1)" => "in_force"}
    end

    test "other full-commencement wordings found in the corpus" do
      for tail <- [
            "1.7.1999 for remaining purposes",
            "3.7.2000 for all remaining purposes",
            "1.4.2010 in so far as not already in operation",
            "1.4.2010 in so far as not alrady in force",
            "1.4.2010 in so far as not in force"
          ] do
        notes = [
          note(
            ["s.5"],
            "S. 5 in force at 1.1.1999 for specified purposes, #{tail}",
            "commencement"
          )
        ]

        assert LatStatus.resolve([row("s.5", "A duty.")], notes) == %{"#{@law}:s.5" => "in_force"},
               tail
      end
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

  describe "notes covering several rows (LH-01)" do
    test "a partial note placed on several rows applies to each of them and their descendants" do
      rows = [
        row("s.78(4)", "A."),
        row("s.78(5)", "B."),
        row("s.78(5)(a)", "C."),
        row("s.79", "D.")
      ]

      notes = [
        note(
          ["s.78(4)", "s.78(5)"],
          "S. 78(4)(5) in force at 6.4.2023 for specified purposes by S.I. 2023/362"
        )
      ]

      assert LatStatus.resolve(rows, notes) == %{
               "#{@law}:s.78(4)" => "in_force_partial",
               "#{@law}:s.78(5)" => "in_force_partial",
               "#{@law}:s.78(5)(a)" => "in_force_partial",
               "#{@law}:s.79" => "in_force"
             }
    end

    test "note_targets/1 is every row the note is placed on" do
      assert LatStatus.note_targets(%{affected_sections: ["L:s.1", "L:s.2"]}) == [
               "L:s.1",
               "L:s.2"
             ]

      assert LatStatus.note_targets(%{affected_sections: nil}) == []
    end
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

  test "a later unqualified dated commencement completes an earlier partial one (LH-06: 2006/28 s.43)" do
    rows = [row("s.43(1)", "A."), row("s.44", "B.")]

    notes = [
      note(["s.43"], "S. 43 in force for certain purposes at Royal Assent, see s. 83"),
      note(["s.43"], "S. 43 in force at 1.5.2008 by S.I. 2008/1147, art. 2"),
      note(["s.44"], "S. 44 in force for certain purposes at Royal Assent, see s. 83"),
      note(
        ["s.44"],
        "S. 44 in force at 1.5.2008 for specified purposes by S.I. 2008/1147, art. 2"
      )
    ]

    assert LatStatus.resolve(rows, notes) == %{
             "#{@law}:s.43(1)" => "in_force",
             "#{@law}:s.44" => "in_force_partial"
           }
  end
end

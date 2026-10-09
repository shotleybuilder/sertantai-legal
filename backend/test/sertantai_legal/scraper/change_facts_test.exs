defmodule SertantaiLegal.Scraper.ChangeFactsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{AmendmentNote, ChangeFacts}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @today ~D[2026-10-09]

  defp fx(fields),
    do:
      struct!(
        Effect,
        Keyword.merge([type: "inserted", affecting: "UK_x", applied: true], fields)
      )

  defp at(date, q \\ nil),
    do: %{date: date, prospective: false, qualification: q, applied: true}

  defp parsed(text, code_type \\ "amendment"),
    do: AmendmentNote.parse(text, code_type, "UK_ukpga_1995_21")

  describe "kind/2" do
    test "the note's code_type decides commencement and modification; else the type's first verb" do
      assert ChangeFacts.kind("coming into force", "commencement") == "commenced"
      assert ChangeFacts.kind("applied (with modifications)", "modification") == "modified"
      assert ChangeFacts.kind("words substituted", "amendment") == "substituted"
      assert ChangeFacts.kind("Words added", "amendment") == "inserted"
      assert ChangeFacts.kind("word omitted", "amendment") == "repealed"
      assert ChangeFacts.kind("coming into force", nil) == "commenced"
      assert ChangeFacts.kind("expires", "amendment") == "other"
    end
  end

  describe "note/3" do
    test "staged: every dated InForce, effective_from the latest (1995/21 s.297(4); Jason 2026-10-09)" do
      text =
        "Words in s. 297(4) inserted (10.3.2022 for specified purposes, 10.5.2022 in so far as not already in force) by Public Service Pensions and Judicial Offices Act 2022 (c. 7)"

      e =
        fx(
          type: "words inserted",
          affecting: "UK_ukpga_2022_7",
          in_force: [
            at(~D[2022-03-10], "for specified purposes"),
            at(~D[2022-05-10], "in force in so far as not already in force")
          ]
        )

      fact = ChangeFacts.note(parsed(text), "amendment", [e])

      assert %{
               effect: "inserted",
               effective_dates: [~D[2022-03-10], ~D[2022-05-10]],
               effective_from: ~D[2022-05-10],
               changed_by: "UK_ukpga_2022_7",
               source: :effect
             } = fact

      assert fact.change_id == parsed(text).change_id
    end

    test "changed_by from the effect, not the citation (a Welsh SI cited \"S.I. 2013/755\")" do
      text =
        "Words in s. 206(4)(a) inserted (1.4.2013) by The Natural Resources Body for Wales (Functions) Order 2013 (S.I. 2013/755)"

      e = fx(type: "words inserted", affecting: "UK_wsi_2013_755", in_force: [at(~D[2013-04-01])])
      assert %{changed_by: "UK_wsi_2013_755"} = ChangeFacts.note(parsed(text), "amendment", [e])
    end

    test "one note, several effects: the dates of all; changed_by of the one that took effect last" do
      text =
        "Regs. 3, 4 omitted (E.W.) (6.4.2008) by S.I. 2007/3538; and revoked (S.) (1.11.2025) by S.S.I. 2025/1"

      ew = fx(type: "omitted", affecting: "UK_uksi_2007_3538", in_force: [at(~D[2008-04-06])])
      s = fx(type: "revoked", affecting: "UK_ssi_2025_1", in_force: [at(~D[2025-11-01])])

      assert %{effective_from: ~D[2025-11-01], changed_by: "UK_ssi_2025_1", effect: "repealed"} =
               ChangeFacts.note(parsed(text), "amendment", [ew, s])
    end

    test "a commencement note with no instrument in its text takes the effect's (\"see s. 99\")" do
      text = "S. 6 in force at 1.4.2010, see s. 99(2)"
      assert parsed(text, "commencement").changed_by == nil

      e =
        fx(
          type: "coming into force",
          affecting: "UK_ukpga_2009_1",
          in_force: [at(~D[2010-04-01])]
        )

      assert %{effect: "commenced", changed_by: "UK_ukpga_2009_1", source: :effect} =
               ChangeFacts.note(parsed(text, "commencement"), "commencement", [e])
    end

    test "no effect: the text, marked as the note's" do
      text = "S. 52(6) substituted (1.4.2006) by Water Act 2003 (c. 37)"

      assert %{effect: "substituted", effective_from: ~D[2006-04-01], source: :note} =
               ChangeFacts.note(parsed(text), "amendment", [])
    end

    test "prospective: no dates" do
      e =
        fx(
          prospective: true,
          in_force: [%{date: nil, prospective: true, qualification: nil, applied: false}]
        )

      assert %{effective_dates: [], effective_from: nil, changed_by: "UK_x"} =
               ChangeFacts.note(parsed("S. 9 inserted by X"), "amendment", [e])
    end
  end

  test "effect_fact/1: an effect no note carries, keyed by its effect id" do
    e =
      fx(
        effect_id: "effect-1",
        type: "coming into force",
        affecting: "UK_uksi_2010_1",
        in_force: [at(~D[2010-10-01])]
      )

    assert %{
             effect: "commenced",
             effective_from: ~D[2010-10-01],
             changed_by: "UK_uksi_2010_1",
             change_id: "effect-1",
             source: :effect
           } = ChangeFacts.effect_fact(e)
  end

  describe "partial?/3" do
    test "for specified purposes, nothing completing it: partial" do
      e = fx(type: "coming into force", in_force: [at(~D[2015-01-01], "for specified purposes")])
      assert ChangeFacts.partial?([e], "E+W", @today)
    end

    test "completed by a later entry or a separate commencement effect" do
      staged =
        fx(
          in_force: [
            at(~D[2015-01-01], "for specified purposes"),
            at(~D[2016-01-01], "in force in so far as not already in force")
          ]
        )

      refute ChangeFacts.partial?([staged], "E+W", @today)

      first =
        fx(type: "coming into force", in_force: [at(~D[2015-01-01], "for specified purposes")])

      rest = fx(type: "coming into force", in_force: [at(~D[2016-01-01], "wholly in force")])
      refute ChangeFacts.partial?([first, rest], "E+W", @today)

      unqualified = fx(type: "coming into force", in_force: [at(~D[2016-01-01])])
      refute ChangeFacts.partial?([first, unqualified], "E+W", @today)
    end

    test "a completing step after today hasn't happened yet" do
      e =
        fx(
          in_force: [
            at(~D[2026-01-01], "for specified purposes"),
            at(~D[2027-04-01], "in force in so far as not already in force")
          ]
        )

      assert ChangeFacts.partial?([e], "E+W", @today)
    end

    test "territorial commencement is partial until the extent is covered (Building Safety Act; Jason 2026-10-09)" do
      e_only = fx(in_force: [at(~D[2022-06-28], "for E.")])
      assert ChangeFacts.partial?([e_only], "E+W", @today)

      both = fx(in_force: [at(~D[2022-06-28], "for E."), at(~D[2023-09-05], "for W.")])
      refute ChangeFacts.partial?([both], "E+W", @today)

      # "for E. in so far as not already in force" completes E only
      e_rest = fx(in_force: [at(~D[2022-06-28], "for E. in so far as not already in force")])
      assert ChangeFacts.partial?([e_rest], "E+W", @today)
      refute ChangeFacts.partial?([e_rest], "E", @today)
    end

    test "modifications and repeals don't commence anything; unreadable qualifiers count neither way" do
      applied =
        fx(
          type: "applied (with modifications)",
          in_force: [at(~D[2015-01-01], "for specified purposes")]
        )

      refute ChangeFacts.partial?([applied], "E+W", @today)

      repeal = fx(type: "repealed", in_force: [at(~D[2015-01-01], "for specified purposes")])
      refute ChangeFacts.partial?([repeal], "E+W", @today)

      pilot = fx(in_force: [at(~D[2015-01-01], "for E. in relation to the pilot areas")])
      refute ChangeFacts.partial?([pilot], "E+W", @today)
    end
  end

  test "saved?/1: a repeal naming savings" do
    assert ChangeFacts.saved?([fx(type: "repealed", savings: ["section-144"])])
    refute ChangeFacts.saved?([fx(type: "repealed")])
    refute ChangeFacts.saved?([fx(type: "inserted", savings: ["section-144"])])
  end

  describe "resolve/5" do
    @law "UK_ukpga_2000_1"

    defp row(id, fields \\ []),
      do:
        Map.merge(
          %{section_id: "#{@law}:#{id}", status: "in_force", text: "Text.", extent_code: "E+W"},
          Map.new(fields)
        )

    defp nt(text, sections, fields \\ []),
      do:
        Map.merge(
          %{
            text: text,
            code_type: "amendment",
            affected_sections: Enum.map(sections, &"#{@law}:#{&1}")
          },
          Map.new(fields)
        )

    test "a row's change facts from its notes' effects and the effects no note carries" do
      ins =
        fx(
          effect_id: "e-ins",
          type: "inserted",
          affecting: "UK_uksi_2010_5",
          in_force: [at(~D[2010-04-01])]
        )

      cif =
        fx(
          effect_id: "e-cif",
          type: "coming into force",
          affecting: "UK_uksi_2012_9",
          in_force: [at(~D[2012-10-01])]
        )

      rows = [row("s.6", effect_ids: ["e-ins", "e-cif"]), row("s.6(1)")]
      notes = [nt("S. 6 inserted (1.4.2010) by S.I. 2010/5", ["s.6"], effect_ids: ["e-ins"])]

      {[fact], out} =
        ChangeFacts.resolve(rows, notes, %{"e-ins" => ins, "e-cif" => cif}, @law, today: @today)

      assert fact.source == :effect
      # the commencement effect has no note, and is the latest; s.6(1) inherits
      assert %{
               effective_from: ~D[2012-10-01],
               changed_by: "UK_uksi_2012_9",
               change_source: :effect
             } =
               out["#{@law}:s.6"]

      assert %{effective_from: ~D[2012-10-01]} = out["#{@law}:s.6(1)"]
    end

    test "status: partial from a commencing effect on an ancestor; the effect outranks a note" do
      partly =
        fx(
          effect_id: "e-1",
          type: "coming into force",
          in_force: [at(~D[2015-01-01], "for specified purposes")]
        )

      rows = [row("s.6", effect_ids: ["e-1"]), row("s.6(1)")]

      {_, out} = ChangeFacts.resolve(rows, [], %{"e-1" => partly}, @law, today: @today)
      assert %{status: "in_force_partial", status_source: :effect} = out["#{@law}:s.6(1)"]

      wholly = fx(effect_id: "e-2", type: "coming into force", in_force: [at(~D[2015-01-01])])

      note =
        nt("S. 6 in force at 1.1.2015 for specified purposes by S.I. 2015/1", ["s.6"],
          code_type: "commencement",
          effect_ids: ["e-2"]
        )

      {_, out} =
        ChangeFacts.resolve([row("s.6", effect_ids: ["e-2"])], [note], %{"e-2" => wholly}, @law,
          today: @today
        )

      assert %{status: "in_force", status_source: :effect} = out["#{@law}:s.6"]
    end

    test "status: with no commencing effect, a note no effect joined is the fallback, marked :note" do
      note =
        nt("S. 6 in force at 1.1.2015 for specified purposes by S.I. 2015/1", ["s.6"],
          code_type: "commencement"
        )

      {[fact], out} = ChangeFacts.resolve([row("s.6")], [note], %{}, @law, today: @today)
      assert fact.source == :note
      assert %{status: "in_force_partial", status_source: :note} = out["#{@law}:s.6"]
    end

    test "status: a repealed row is repealed_saved when its repeal effect names savings" do
      saved =
        fx(
          effect_id: "e-r",
          type: "repealed",
          savings: ["section-9"],
          in_force: [at(~D[2015-01-01])]
        )

      bare = fx(effect_id: "e-b", type: "repealed", in_force: [at(~D[2015-01-01])])

      {_, out} =
        ChangeFacts.resolve(
          [
            row("s.6", status: "repealed", text: ". . .", effect_ids: ["e-r"]),
            row("s.7", status: "repealed", text: ". . .", effect_ids: ["e-b"])
          ],
          [],
          %{"e-r" => saved, "e-b" => bare},
          @law,
          today: @today
        )

      assert %{status: "repealed_saved", status_source: :effect} = out["#{@law}:s.6"]
      assert %{status: "repealed", status_source: :markup} = out["#{@law}:s.7"]
    end

    test "prospective and retained-everywhere rows keep the parser's status" do
      {_, out} =
        ChangeFacts.resolve(
          [
            row("s.1", status: "prospective"),
            row("s.2", status: "repealed_saved", excluded_extent: "E+W")
          ],
          [],
          %{},
          @law,
          today: @today
        )

      assert %{status: "prospective", status_source: :markup} = out["#{@law}:s.1"]
      assert %{status: "repealed_saved", status_source: :markup} = out["#{@law}:s.2"]
    end
  end
end

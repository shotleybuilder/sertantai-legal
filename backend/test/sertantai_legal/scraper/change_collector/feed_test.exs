defmodule SertantaiLegal.Scraper.ChangeCollector.FeedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector.{Feed, Record}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @law "UK_ukpga_1990_43"

  defp effect(id, type, extra \\ []) do
    struct!(
      Effect,
      [
        effect_id: id,
        type: type,
        affecting: "UK_ukpga_1995_25",
        affecting_provisions: "Sch. 22 para. 3",
        affected_provisions: "s. 6(6A)",
        applied: true,
        in_force: [%{date: ~D[1996-04-01], applied: true, qualification: nil, prospective: false}]
      ] ++ extra
    )
  end

  test "a row joined by markup: one record with the effect's facts, source effect" do
    rows = [%{section_id: "#{@law}:s.6(6A)", effect_joins: [{"key-a", :markup}]}]

    assert [%Record{} = r] = Feed.records(@law, rows, [], [effect("key-a", "inserted")])

    assert %{
             law_name: @law,
             section_id: "#{@law}:s.6(6A)",
             via: ["markup"],
             pointer: nil,
             source: "effect",
             evidence: "key-a",
             operation: "inserted",
             effect_type: "inserted",
             affecting_law: "UK_ukpga_1995_25",
             affecting_ref: "Sch. 22 para. 3",
             affected_ref: "s. 6(6A)",
             effective_from: ~D[1996-04-01],
             applied: true,
             prospective: false
           } = r
  end

  test "one record per effect and row; a note join that only corroborates a direct one is dropped (D4)" do
    sid = "#{@law}:s.6"
    rows = [%{section_id: sid, effect_joins: [{"key-a", :ref}]}]
    notes = [%{code: "F12", affected_sections: [sid], effect_joins: [{"key-a", :cited, sid}]}]

    assert [%Record{section_id: ^sid, via: ["ref"], pointer: nil}] =
             Feed.records(@law, rows, notes, [effect("key-a", "words substituted")])
  end

  test "a note's joined effect reaches every provision the note sits on" do
    notes = [
      %{
        code: "C3",
        affected_sections: ["#{@law}:s.1", "#{@law}:s.2"],
        effect_joins: [{"key-m", :own}]
      }
    ]

    assert Feed.records(@law, [], notes, [effect("key-m", "applied (with modifications)")])
           |> Enum.map(&{&1.section_id, &1.via, &1.operation}) == [
             {"#{@law}:s.1", ["note_own"], "other"},
             {"#{@law}:s.2", ["note_own"], "other"}
           ]
  end

  test "an effect on a provision LAT holds that reached no row is kept, with no row: a visible gap" do
    rows = [%{section_id: "#{@law}:s.9", xml_id: "section-9", effect_joins: []}]

    assert [%Record{section_id: nil, via: [], evidence: "key-z"}] =
             Feed.records(@law, rows, [], [
               effect("key-z", "words repealed", affected_refs: ["section-9-2"])
             ])
  end

  test "D5: an effect on a provision LAT doesn't hold (Schedule, out of scope, annex) is not recorded" do
    rows = [%{section_id: "#{@law}:s.9", xml_id: "section-9", effect_joins: []}]

    effects = [
      effect("key-s", "words substituted", affected_refs: ["schedule-2-paragraph-3"]),
      effect("key-o", "repealed", affected_refs: ["section-40"]),
      effect("key-r", "applied", affected_ranges: [{"section-30", "section-35"}])
    ]

    assert Feed.records(@law, rows, [], effects) == []
  end

  test "D5: an effect naming no provision (specified provisions, blanket, definitions) is kept as a gap" do
    e =
      effect("key-u", "Commencement Order", affected_provisions: "specified amended provision(s)")

    assert [%Record{section_id: nil, evidence: "key-u"}] = Feed.records(@law, [], [], [e])
  end

  test "D5: a whole-instrument effect reaches every row of the law (a range over the law)" do
    rows =
      for s <- ["pt.1", "s.1", "s.1(1)", "s.2"],
          do: %{section_id: "#{@law}:#{s}", effect_joins: []}

    e = effect("key-act", "applied (with modifications)", affected_provisions: "Act")

    assert Feed.records(@law, rows, [], [e]) |> Enum.map(&{&1.section_id, &1.via}) ==
             for(r <- rows, do: {r.section_id, ["instrument"]})
  end

  test "a note's text is never read: a note joining no effect makes no record" do
    notes = [
      %{
        code: "F1",
        text: "S. 3 substituted (1.1.2000) by S.I. 2000/1",
        affected_sections: ["#{@law}:s.3"],
        effect_joins: []
      }
    ]

    assert Feed.records(@law, [], notes, []) == []
  end

  test "a prospective effect not applied: no date, flagged prospective" do
    e =
      effect("key-p", "repealed",
        prospective: true,
        applied: false,
        in_force: [%{date: nil, applied: false, qualification: nil, prospective: true}]
      )

    rows = [%{section_id: "#{@law}:s.4", effect_joins: [{"key-p", :ref}]}]

    assert [%Record{effective_from: nil, prospective: true, applied: false}] =
             Feed.records(@law, rows, [], [e])
  end

  test "a pointer join reaches only the provision its effect was found on (1990/43 Pt. 2A)" do
    notes = [
      %{
        code: "F99",
        affected_sections: ["#{@law}:s.78A(1)", "#{@law}:s.78A(2)", "#{@law}:s.78B"],
        effect_joins: [{"key-i", :cited, "#{@law}:s.78B"}]
      }
    ]

    assert [%Record{section_id: "UK_ukpga_1990_43:s.78B", via: ["note_cited"]}] =
             Feed.records(@law, [], notes, [effect("key-i", "inserted")])
  end

  test "a note's markup join reaches only rows whose own markup carries the change (1991/56 blanket note)" do
    rows = [
      %{section_id: "#{@law}:s.1", effect_joins: [{"key-w", :markup}]},
      %{section_id: "#{@law}:s.2", effect_joins: []}
    ]

    notes = [
      %{
        code: "M_F_1",
        affected_sections: ["#{@law}:s.1", "#{@law}:s.2"],
        effect_joins: [{"key-w", :markup}]
      }
    ]

    assert [%Record{section_id: "UK_ukpga_1990_43:s.1", via: ["markup"], pointer: nil}] =
             Feed.records(@law, rows, notes, [effect("key-w", "words substituted")])
  end

  test "two note joins and no direct one: both kept, the strongest note's pointer" do
    sid = "#{@law}:s.7"

    notes = [
      %{code: "C1", affected_sections: [sid], effect_joins: [{"key-c", :own}]},
      %{code: "F2", affected_sections: [sid], effect_joins: [{"key-c", :cited, sid}]}
    ]

    assert [%Record{via: ["note_own", "note_cited"], pointer: "C1"}] =
             Feed.records(@law, [], notes, [effect("key-c", "coming into force")])
  end
end

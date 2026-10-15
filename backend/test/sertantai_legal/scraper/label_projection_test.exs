defmodule SertantaiLegal.Scraper.LabelProjectionTest do
  @moduledoc """
  LR-24 golden cases: a provision's labels as a timeline from its changes
  (lat_change_log rows). Shaped on real provisions (effect ids replaced).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelProjection
  alias SertantaiLegal.Scraper.LabelProjection.Period

  @today ~D[2026-10-13]

  defp row(law, sid, extra \\ []),
    do:
      Map.merge(
        %{section_id: "#{law}:#{sid}", extent_code: "E+W+S", markup_status: nil},
        Map.new(extra)
      )

  defp change(law, sid, ev, op, type, by, entries, extra \\ []) do
    entries =
      for {date, q} <- entries,
          do: %{
            "date" => date && Date.to_iso8601(date),
            "qualification" => q,
            "prospective" => date == nil,
            "applied" => true
          }

    dated = for {d, _} <- List.wrap(entries_dates(entries)), d != nil, do: d

    Map.merge(
      %{
        section_id: "#{law}:#{sid}",
        evidence: ev,
        operation: op,
        effect_type: type,
        affecting_law: by,
        in_force: entries,
        effective_from: Enum.max(dated, Date, fn -> nil end),
        savings: [],
        prospective: dated == [],
        via: ["ref"]
      },
      Map.new(extra)
    )
  end

  defp entries_dates(entries),
    do: for(e <- entries, do: {e["date"] && Date.from_iso8601!(e["date"]), e["qualification"]})

  defp periods(law, rows, changes, opts \\ []) do
    %{periods: periods} =
      LabelProjection.timeline(law, rows, changes, Keyword.merge([today: @today], opts))

    Enum.map(periods, &{&1.valid_from, &1.valid_to, &1.status, &1.in_force_from, &1.changed_by})
  end

  test "text changes on several dates: a period per version; nothing before an insertion (1990/43 s.6(6A))" do
    law = "UK_ukpga_1990_43"

    changes = [
      change(law, "s.6(6A)", "e1", "inserted", "inserted", "UK_ukpga_1995_25", [
        {~D[1996-04-01], nil}
      ]),
      change(law, "s.6(6A)", "e2", "substituted", "words substituted", "UK_uksi_2010_675", [
        {~D[2010-04-06], nil}
      ])
    ]

    assert periods(law, [row(law, "s.6(6A)")], changes, law_start: ~D[1991-01-01]) == [
             {~D[1996-04-01], ~D[2010-04-06], "in_force", ~D[1996-04-01], "UK_ukpga_1995_25"},
             {~D[2010-04-06], nil, "in_force", ~D[2010-04-06], "UK_uksi_2010_675"}
           ]
  end

  test "repeal with savings: in force from the law's commencement, repealed_saved from the repeal (1986/44 s.8F(4))" do
    law = "UK_ukpga_1986_44"

    changes = [
      change(
        law,
        "s.8F(4)",
        "e1",
        "repealed",
        "omitted",
        "UK_uksi_2019_1393",
        [{~D[2020-12-31], nil}],
        savings: ["reg. 3"]
      )
    ]

    assert periods(law, [row(law, "s.8F(4)")], changes, law_start: ~D[1986-08-25]) == [
             {~D[1986-08-25], ~D[2020-12-31], "in_force", ~D[1986-08-25], nil},
             {~D[2020-12-31], nil, "repealed_saved", ~D[2020-12-31], "UK_uksi_2019_1393"}
           ]
  end

  test "partial commencement: prospective, then partly in force, then in force (1990/43 s.162(2))" do
    law = "UK_ukpga_1990_43"

    changes = [
      change(law, "s.162(2)", "c1", "commenced", "coming into force", "UK_uksi_2012_1", [
        {~D[2012-04-01], "for specified purposes"},
        {~D[2016-04-01], "in so far as not already in force"}
      ])
    ]

    assert periods(law, [row(law, "s.162(2)")], changes, law_start: ~D[1991-01-01]) == [
             {~D[1991-01-01], ~D[2012-04-01], "prospective", nil, nil},
             {~D[2012-04-01], ~D[2016-04-01], "in_force_partial", nil, nil},
             {~D[2016-04-01], nil, "in_force", ~D[2016-04-01], "UK_uksi_2012_1"}
           ]
  end

  test "a prospective insertion with no date: prospective from the law's start (1996/18 s.201(1))" do
    law = "UK_ukpga_1996_18"

    changes = [
      change(law, "s.201(1)", "p1", "inserted", "inserted", "UK_ukpga_2008_25", [{nil, nil}],
        applied: false
      )
    ]

    rows = [row(law, "s.201(1)", markup_status: "prospective")]

    assert periods(law, rows, changes, law_start: ~D[1996-08-22]) == [
             {~D[1996-08-22], nil, "prospective", nil, nil}
           ]
  end

  test "whole-instrument revocation reaches every row: repealed from its date (1995/288)" do
    law = "UK_uksi_1995_288"

    changes =
      for sid <- ["reg.1", "reg.2"],
          do:
            change(
              law,
              sid,
              "w1",
              "repealed",
              "revoked",
              "UK_uksi_2012_632",
              [{~D[2012-04-06], nil}],
              via: ["instrument"]
            )

    assert periods(law, [row(law, "reg.1"), row(law, "reg.2")], changes,
             law_start: ~D[1995-03-01]
           ) ==
             List.duplicate(
               [
                 {~D[1995-03-01], ~D[2012-04-06], "in_force", ~D[1995-03-01], nil},
                 {~D[2012-04-06], nil, "repealed", ~D[2012-04-06], "UK_uksi_2012_632"}
               ],
               2
             )
             |> List.flatten()
  end

  test "a future repeal is in the timeline now and takes effect on its date (2008/2164 pt.1)" do
    law = "UK_uksi_2008_2164"

    changes = [
      change(law, "pt.1", "f1", "repealed", "revoked", "UK_uksi_2026_9", [{~D[2026-10-17], nil}])
    ]

    %{periods: p} =
      LabelProjection.timeline(law, [row(law, "pt.1")], changes,
        today: @today,
        law_start: ~D[2008-09-01]
      )

    assert %Period{status: "in_force"} = LabelProjection.as_at(p, @today)["#{law}:pt.1"]
    assert %Period{status: "repealed"} = LabelProjection.as_at(p, ~D[2026-10-17])["#{law}:pt.1"]
    assert %Period{status: "in_force"} = LabelProjection.as_at(p, ~D[2026-10-16])["#{law}:pt.1"]
    assert LabelProjection.as_at(p, ~D[2001-01-01])["#{law}:pt.1"] == nil
  end

  test "a modification never starts a version (D1)" do
    law = "UK_ukpga_1974_37"

    changes = [
      change(law, "s.2(3)", "m1", "other", "applied (with modifications)", "UK_uksi_2015_51", [
        {~D[2015-04-06], nil}
      ])
    ]

    assert periods(law, [row(law, "s.2(3)")], changes, law_start: ~D[1975-04-01]) == [
             {~D[1975-04-01], nil, "in_force", ~D[1975-04-01], nil}
           ]
  end

  test "an ancestor's whole-provision repeal reaches the row; its words-level change doesn't" do
    law = "UK_ukpga_1974_37"

    changes = [
      change(law, "s.9", "w1", "substituted", "words substituted", "UK_ukpga_1999_1", [
        {~D[1999-01-01], nil}
      ]),
      change(law, "s.9", "r1", "repealed", "repealed", "UK_ukpga_2005_1", [{~D[2005-01-01], nil}])
    ]

    assert periods(law, [row(law, "s.9(1)")], changes, law_start: ~D[1975-04-01]) == [
             {~D[1975-04-01], ~D[2005-01-01], "in_force", ~D[1975-04-01], nil},
             {~D[2005-01-01], nil, "repealed", ~D[2005-01-01], "UK_ukpga_2005_1"}
           ]
  end

  test "J1: no evidence of a start (no law date, no change): no periods, a gap" do
    law = "UK_uksi_1999_1"

    assert %{periods: [], gaps: [{"UK_uksi_1999_1:reg.4", :no_start}]} =
             LabelProjection.timeline(law, [row(law, "reg.4")], [], today: @today)
  end

  test "J1: no law date: the timeline starts at the earliest change held" do
    law = "UK_uksi_1999_1"

    changes = [
      change(law, "reg.4", "e1", "substituted", "words substituted", "UK_uksi_2004_2", [
        {~D[2004-06-01], nil}
      ])
    ]

    assert periods(law, [row(law, "reg.4")], changes) == [
             {~D[2004-06-01], nil, "in_force", ~D[2004-06-01], "UK_uksi_2004_2"}
           ]
  end

  test "J2: the CLML markup wins today's period when no dated change explains it; the conflict is a gap" do
    law = "UK_ukpga_1974_37"

    %{periods: p, gaps: gaps} =
      LabelProjection.timeline(law, [row(law, "s.5", markup_status: "repealed")], [],
        today: @today,
        law_start: ~D[1975-04-01]
      )

    assert [%Period{valid_from: ~D[1975-04-01], valid_to: nil, status: "repealed"}] = p
    assert gaps == [{"UK_ukpga_1974_37:s.5", :markup_conflict}]
  end

  test "a commencement by the law itself: no changed_by" do
    law = "UK_uksi_2017_1013"

    changes = [
      change(law, "reg.38", "c1", "commenced", "coming into force", "UK_uksi_2017_1013", [
        {~D[2018-01-01], nil}
      ])
    ]

    assert periods(law, [row(law, "reg.38")], changes, law_start: ~D[2017-11-01]) == [
             {~D[2017-11-01], ~D[2018-01-01], "prospective", nil, nil},
             {~D[2018-01-01], nil, "in_force", ~D[2018-01-01], nil}
           ]
  end

  test "uk_today/1: the UK date — BST from the last Sunday of March to the last of October" do
    # 00:30 BST on 14 Oct is 23:30 UTC on 13 Oct
    assert LabelProjection.uk_today(~U[2026-10-13 23:30:00Z]) == ~D[2026-10-14]
    # GMT in winter: UTC is the UK time
    assert LabelProjection.uk_today(~U[2026-12-01 23:30:00Z]) == ~D[2026-12-01]
    # the change days (2026: 29 March, 25 October), at 01:00 UTC
    assert LabelProjection.uk_today(~U[2026-03-29 23:30:00Z]) == ~D[2026-03-30]
    assert LabelProjection.uk_today(~U[2026-03-29 00:30:00Z]) == ~D[2026-03-29]
    assert LabelProjection.uk_today(~U[2026-10-25 00:30:00Z]) == ~D[2026-10-25]
    assert LabelProjection.uk_today(~U[2026-10-25 23:30:00Z]) == ~D[2026-10-25]
  end

  test "undated change markup and an applied undated change say nothing about commencement, nor give the law's start (1990/43 s.78B(2))" do
    law = "UK_ukpga_1990_43"

    changes = [
      change(law, "s.78B(2)", "d29p1", "inserted", nil, nil, [],
        via: ["markup"],
        prospective: nil
      ),
      change(law, "s.78B(2)", "e1", "inserted", "added", "UK_ukpga_1995_25", [{nil, nil}],
        applied: true
      )
    ]

    # never prospective (it's in the text); and (LR-30, Jason 2026-10-15) its
    # start is unknown, not the law's: it was inserted in 1995 on a date no
    # source gives, so "in force since 1991" would be wrong
    %{periods: p, gaps: gaps} =
      LabelProjection.timeline(law, [row(law, "s.78B(2)")], changes,
        today: @today,
        law_start: ~D[1991-01-01]
      )

    assert p == []
    assert {"UK_ukpga_1990_43:s.78B(2)", :insertion_not_in_register} in gaps
  end

  test "a repeal for part of the row's extent leaves it in force (territory narrows: LR-26) (1974/37 s.1(3))" do
    law = "UK_ukpga_1974_37"

    changes = [
      change(
        law,
        "s.1(3)",
        "r1",
        "repealed",
        "repealed",
        "UK_asp_2018_1",
        [{~D[2019-04-01], nil}],
        effect_extent: "S"
      )
    ]

    assert periods(law, [row(law, "s.1(3)", extent_code: "E+W+S+NI")], changes,
             law_start: ~D[1975-04-01]
           ) == [
             {~D[1975-04-01], nil, "in_force", ~D[1975-04-01], nil}
           ]
  end

  test "a repeal whose extent is 'same as affected' (the feed's S+A+M+E+… spelling) covers the row" do
    law = "UK_ukpga_1974_40"

    changes = [
      change(
        law,
        "s.3(3)",
        "r1",
        "repealed",
        "repealed",
        "UK_ukpga_1995_25",
        [{~D[1996-04-01], nil}],
        effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D"
      )
    ]

    assert periods(law, [row(law, "s.3(3)", extent_code: "E+W+S")], changes,
             law_start: ~D[1974-07-31]
           ) == [
             {~D[1974-07-31], ~D[1996-04-01], "in_force", ~D[1974-07-31], nil},
             {~D[1996-04-01], nil, "repealed", ~D[1996-04-01], "UK_ukpga_1995_25"}
           ]
  end

  test "a whole-instrument words-level change doesn't start a version on every row" do
    law = "UK_nisr_2007_247"

    changes = [
      change(
        law,
        "reg.23(2)(a)",
        "b1",
        "substituted",
        "words substituted",
        "UK_nisr_2016_1",
        [{~D[2016-12-19], nil}],
        via: ["instrument"]
      )
    ]

    assert periods(law, [row(law, "reg.23(2)(a)")], changes, law_start: ~D[2007-05-21]) == [
             {~D[2007-05-21], nil, "in_force", ~D[2007-05-21], nil}
           ]
  end

  test "a repeal 'in part' or with exceptions isn't a repeal of the provision (LR-06 'revoked in part')" do
    law = "UK_ukpga_1986_62"

    changes = [
      change(
        law,
        "s.41(4)",
        "r1",
        "repealed",
        "repealed in part (except s. 31)",
        "UK_ukpga_2006_46",
        [{~D[2006-11-15], nil}],
        via: ["instrument"]
      )
    ]

    assert periods(law, [row(law, "s.41(4)")], changes, law_start: ~D[1986-09-01]) == [
             {~D[1986-09-01], nil, "in_force", ~D[1986-09-01], nil}
           ]
  end

  test "J4: a repeal in force but not applied to the text counts; the row is an outstanding effect" do
    law = "UK_ukpga_1977_39"

    changes = [
      change(
        law,
        "s.14",
        "r1",
        "repealed",
        "repealed",
        "UK_ukpga_2004_5",
        [{~D[2004-03-27], nil}],
        applied: false
      )
    ]

    %{periods: p, gaps: gaps} =
      LabelProjection.timeline(law, [row(law, "s.14")], changes,
        today: @today,
        law_start: ~D[1977-07-29]
      )

    assert %Period{status: "repealed"} = LabelProjection.as_at(p, @today)["UK_ukpga_1977_39:s.14"]
    assert gaps == [{"UK_ukpga_1977_39:s.14", :outstanding_effect}]
  end

  test "clml_start/2: earliest ComingIntoForce; else Royal Assent for an Act; else nil" do
    si =
      ~s(<ukm:ComingIntoForce> <ukm:DateTime Date="1997-06-20"/> <ukm:DateTime Date="1995-10-09"/> </ukm:ComingIntoForce>)

    assert LabelProjection.clml_start(si, "nisr") == ~D[1995-10-09]
    act = ~s(<ukm:EnactmentDate Date="1974-07-31"/>)
    assert LabelProjection.clml_start(act, "ukpga") == ~D[1974-07-31]
    assert LabelProjection.clml_start(act, "uksi") == nil
    assert LabelProjection.clml_start("<x/>", "ukpga") == nil
  end

  test "J5: a provision a note points to as inserted never takes the law's start (1996/18 s.27V)" do
    law = "UK_ukpga_1996_18"
    rows = [row(law, "s.27V", inserted_pointer: true)]

    assert %{periods: [], gaps: [{"UK_ukpga_1996_18:s.27V", :insertion_not_in_register}]} =
             LabelProjection.timeline(law, rows, [], today: @today, law_start: ~D[1996-05-22])

    # a whole-instrument change doesn't show the provision existed; its own does
    act =
      change(law, "s.27V", "m1", "other", "modified", "UK_uksi_2004_1", [{~D[2004-07-01], nil}],
        via: ["instrument"]
      )

    own =
      change(law, "s.27V", "w1", "substituted", "words substituted", "UK_ukpga_2025_1", [
        {~D[2025-01-01], nil}
      ])

    assert %{periods: []} =
             LabelProjection.timeline(law, rows, [act], today: @today, law_start: ~D[1996-05-22])

    assert periods(law, rows, [act, own], law_start: ~D[1996-05-22]) == [
             {~D[2025-01-01], nil, "in_force", ~D[2025-01-01], "UK_ukpga_2025_1"}
           ]
  end

  test "T1: a text change no source dates empties in_force_from (changed, date unknown); the status stands" do
    law = "UK_ukpga_1990_43"
    rows = [row(law, "s.10(2)", undated_change: true)]

    changes = [
      change(law, "s.10(2)", "r1", "repealed", "repealed", "UK_ukpga_2020_1", [
        {~D[2021-01-01], nil}
      ])
    ]

    %{periods: p, gaps: gaps} =
      LabelProjection.timeline(law, rows, changes, today: @today, law_start: ~D[1991-01-01])

    assert Enum.map(p, &{&1.valid_from, &1.status, &1.in_force_from, &1.changed_by}) == [
             {~D[1991-01-01], "in_force", nil, nil},
             {~D[2021-01-01], "repealed", ~D[2021-01-01], "UK_ukpga_2020_1"}
           ]

    assert gaps == [{"UK_ukpga_1990_43:s.10(2)", :undated_change}]
  end

  describe "territory (LR-26 D1′)" do
    defp terr(law, rows, changes, opts \\ []) do
      %{periods: periods} =
        LabelProjection.timeline(law, rows, changes, Keyword.merge([today: @today], opts))

      Enum.map(periods, &{&1.valid_from, &1.valid_to, &1.status, &1.territory})
    end

    test "today's territory is the extent minus the excluded extent" do
      law = "UK_ukpga_1974_37"
      rows = [row(law, "s.1", extent_code: "E+W+S", excluded_extent: "S", claims: [])]

      assert terr(law, rows, [], law_start: ~D[1975-04-01]) == [
               {~D[1975-04-01], nil, "in_force", "E+W"}
             ]
    end

    test "a dated territorial repeal is rolled back before its date (a removal)" do
      law = "UK_ukpga_1974_40"

      rep =
        change(
          law,
          "s.13",
          "r1",
          "repealed",
          "repealed",
          "UK_asp_2003_1",
          [{~D[2003-04-01], nil}],
          effect_extent: "S"
        )

      rows = [
        row(law, "s.13",
          extent_code: "E+W+S",
          excluded_extent: "S",
          claims: [%{effect_id: "r1", territory: "S"}]
        )
      ]

      assert terr(law, rows, [rep], law_start: ~D[1974-07-31]) == [
               {~D[1974-07-31], ~D[2003-04-01], "in_force", "E+W+S"},
               {~D[2003-04-01], nil, "in_force", "E+W"}
             ]
    end

    test "an exclusion behind an undated claim: earlier periods unknown, never today's carried back" do
      law = "UK_ukpga_1974_40"

      ins =
        change(law, "s.14", "i1", "inserted", "words inserted", "UK_ukpga_1995_25", [
          {~D[1996-04-01], nil}
        ])

      rows = [
        row(law, "s.14",
          extent_code: "E+W+S",
          excluded_extent: "S",
          claims: [%{effect_id: nil, territory: "E+W"}]
        )
      ]

      assert terr(law, rows, [ins], law_start: ~D[1974-07-31]) == [
               {~D[1974-07-31], ~D[1996-04-01], "in_force", nil},
               {~D[1996-04-01], nil, "in_force", "E+W"}
             ]
    end

    test "an exclusion behind a narrowing insertion: earlier periods unknown" do
      law = "UK_ukpga_1990_43"

      ins =
        change(law, "s.6(6A)(c)", "i1", "inserted", "inserted", "UK_ukpga_1995_25", [
          {~D[1996-04-01], nil}
        ])

      rows = [
        row(law, "s.6(6A)(c)",
          extent_code: "E+W+S",
          excluded_extent: "S",
          claims: [%{effect_id: "i1", territory: "E+W"}]
        )
      ]

      assert [{~D[1996-04-01], nil, "in_force", "E+W"}] =
               terr(law, rows, [ins], law_start: ~D[1991-01-01])

      words =
        change(law, "s.7", "w1", "substituted", "words substituted", "UK_ukpga_1995_25", [
          {~D[1996-04-01], nil}
        ])

      rows = [
        row(law, "s.7",
          extent_code: "E+W+S",
          excluded_extent: "S",
          claims: [%{effect_id: "w1", territory: "E+W"}]
        )
      ]

      assert terr(law, rows, [words], law_start: ~D[1991-01-01]) == [
               {~D[1991-01-01], ~D[1996-04-01], "in_force", nil},
               {~D[1996-04-01], nil, "in_force", "E+W"}
             ]
    end

    test "a future territorial repeal narrows the territory from its date" do
      law = "UK_uksi_2011_988"

      rep =
        change(
          law,
          "reg.13(4)",
          "r1",
          "repealed",
          "omitted",
          "UK_ssi_2025_1",
          [{~D[2026-12-31], nil}],
          effect_extent: "S"
        )

      rows = [row(law, "reg.13(4)", extent_code: "E+W+S", claims: [])]

      assert terr(law, rows, [rep], law_start: ~D[2011-04-06]) == [
               {~D[2011-04-06], ~D[2026-12-31], "in_force", "E+W+S"},
               {~D[2026-12-31], nil, "in_force", "E+W"}
             ]
    end

    test "nothing left: status repealed, territory empty (nowhere); a repealed period has no territory" do
      law = "UK_ukpga_1974_40"

      rep =
        change(
          law,
          "s.20",
          "r1",
          "repealed",
          "repealed",
          "UK_asp_2003_1",
          [{~D[2003-04-01], nil}],
          effect_extent: "S"
        )

      rows = [
        row(law, "s.20",
          extent_code: "S",
          excluded_extent: "S",
          claims: [%{effect_id: "r1", territory: "S"}]
        )
      ]

      assert terr(law, rows, [rep], law_start: ~D[1974-07-31]) == [
               {~D[1974-07-31], ~D[2003-04-01], "in_force", "S"},
               {~D[2003-04-01], nil, "repealed", nil}
             ]
    end

    test "a staged removal (different dates per territory) can't be rolled back: unknown before today" do
      law = "UK_ukpga_1990_43"

      rep =
        change(law, "s.33", "r1", "repealed", "repealed", "UK_ukpga_1995_25", [
          {~D[2001-01-01], "for E."},
          {~D[2002-01-01], "for W."}
        ])

      rows = [
        row(law, "s.33",
          extent_code: "E+W+S",
          excluded_extent: "E+W",
          claims: [%{effect_id: "r1", territory: "E+W"}]
        )
      ]

      # unknown before the last stage; today S (repealed for E and W only)
      assert terr(law, rows, [rep], law_start: ~D[1991-01-01]) == [
               {~D[1991-01-01], ~D[2002-01-01], "in_force", nil},
               {~D[2002-01-01], nil, "in_force", "S"}
             ]
    end

    test "two future territorial repeals: nothing left after the second (uksi 2007/79)" do
      law = "UK_uksi_2007_79"

      r1 =
        change(
          law,
          "reg.5",
          "r1",
          "repealed",
          "revoked",
          "UK_wsi_2026_1",
          [{~D[2026-12-01], nil}],
          effect_extent: "W"
        )

      r2 =
        change(
          law,
          "reg.5",
          "r2",
          "repealed",
          "revoked",
          "UK_uksi_2027_1",
          [{~D[2027-04-01], nil}],
          effect_extent: "E"
        )

      r3 =
        change(
          law,
          "reg.5",
          "r3",
          "repealed",
          "revoked",
          "UK_uksi_2028_1",
          [{~D[2028-04-01], nil}],
          effect_extent: "E"
        )

      assert terr(law, [row(law, "reg.5", extent_code: "E+W", claims: [])], [r1, r2, r3],
               law_start: ~D[2007-02-01]
             ) == [
               {~D[2007-02-01], ~D[2026-12-01], "in_force", "E+W"},
               {~D[2026-12-01], ~D[2027-04-01], "in_force", "E"},
               {~D[2027-04-01], nil, "repealed", nil}
             ]
    end

    test "a provision not yet in force anywhere: territory unknown in every period, never 'nowhere' (2006/28 s.36(1))" do
      law = "UK_ukpga_2006_28"

      com =
        change(law, "s.36(1)", "c1", "commenced", "coming into force", "UK_uksi_2027_1", [
          {~D[2027-06-01], nil}
        ])

      rows = [
        row(law, "s.36(1)",
          extent_code: "E+W",
          excluded_extent: "E+W",
          markup_status: "prospective",
          claims: []
        )
      ]

      assert terr(law, rows, [com], law_start: ~D[2007-03-01]) == [
               {~D[2007-03-01], ~D[2027-06-01], "prospective", nil},
               {~D[2027-06-01], nil, "in_force", nil}
             ]
    end

    test "no extent known: territory unknown" do
      law = "UK_ukpga_1974_37"

      assert terr(law, [row(law, "s.2", extent_code: nil, claims: [])], [],
               law_start: ~D[1975-04-01]
             ) == [
               {~D[1975-04-01], nil, "in_force", nil}
             ]
    end
  end

  test "two laws changing a provision on the same day: the same label whatever the input order (LR-29 dry runs)" do
    law = "UK_uksi_2010_2214"

    changes = [
      change(law, "reg.14", "key-a", "substituted", "substituted", "UK_uksi_2023_911", [
        {~D[2023-10-01], nil}
      ]),
      change(law, "reg.14", "key-b", "inserted", "inserted", "UK_uksi_2026_1034", [
        {~D[2026-10-01], nil}
      ]),
      change(law, "reg.14", "key-c", "inserted", "inserted", "UK_uksi_2025_1236", [
        {~D[2026-10-01], nil}
      ])
    ]

    rows = [row(law, "reg.14")]
    forward = periods(law, rows, changes, law_start: ~D[2010-10-01], today: ~D[2026-12-01])

    reverse =
      periods(law, rows, Enum.reverse(changes), law_start: ~D[2010-10-01], today: ~D[2026-12-01])

    assert forward == reverse
  end

  describe "LR-30: an insertion no source dates withholds the law's start" do
    @law "UK_ukpga_1968_73"

    # change markup marks the provision inserted; no effect or law dates it
    defp undated_insertion(sid),
      do:
        change(@law, sid, "d29p16361", "inserted", nil, nil, [],
          source: "markup",
          prospective: nil,
          via: ["markup"]
        )

    defp tl(rows, changes),
      do: LabelProjection.timeline(@law, rows, changes, today: @today, law_start: ~D[1968-10-25])

    test "under an ancestor whose insertion is undated: no start, a gap (1968/73 s.10(1)(i)[S])" do
      rows = [row(@law, "s.10(1)[S]"), row(@law, "s.10(1)(i)[S]")]

      assert %{periods: [], gaps: gaps} = tl(rows, [undated_insertion("s.10(1)[S]")])

      assert {"UK_ukpga_1968_73:s.10(1)(i)[S]", :insertion_not_in_register} in gaps
      assert {"UK_ukpga_1968_73:s.10(1)[S]", :insertion_not_in_register} in gaps
    end

    test "under an ancestor inserted on a known date: the row starts then, not at the law's start" do
      changes = [
        change(@law, "s.10(1)", "key-i", "inserted", "inserted", "UK_ukpga_2008_26", [
          {~D[2009-02-09], nil}
        ])
      ]

      assert %{periods: [first | _]} = tl([row(@law, "s.10(1)(i)")], changes)
      assert first.valid_from == ~D[2009-02-09]
    end

    test "a prospective insertion (not yet in force) keeps its approved reading: prospective from the law's start" do
      changes = [
        change(@law, "s.20", "p1", "inserted", "inserted", "UK_ukpga_2008_25", [{nil, nil}],
          applied: false
        )
      ]

      assert %{periods: [p]} = tl([row(@law, "s.20", markup_status: "prospective")], changes)
      assert {p.valid_from, p.status} == {~D[1968-10-25], "prospective"}
    end
  end

  describe "LR-32: a change for one territory never dates another territory's version" do
    @law32 "UK_ukpga_1995_25"

    test "an S change doesn't date the E+W version (1995/25 s.114(2)(a)(ix)[E+W]: ssi 2006/181 inserted the S text)" do
      changes = [
        change(
          @law32,
          "s.114(2)(a)(ix)[E+W]",
          "key-ew",
          "inserted",
          "inserted",
          "UK_ukpga_2003_37",
          [
            {~D[2006-04-01], nil}
          ]
        ),
        change(
          @law32,
          "s.114(2)(a)(ix)[E+W]",
          "key-s",
          "inserted",
          "inserted",
          "UK_ssi_2006_181",
          [
            {~D[2006-04-01], nil}
          ],
          effect_extent: "S"
        ),
        change(
          @law32,
          "s.114(2)(a)(ix)[E+W]",
          "key-s2",
          "substituted",
          "substituted",
          "UK_ssi_2010_1",
          [
            {~D[2010-06-01], nil}
          ],
          effect_extent: "S"
        )
      ]

      rows = [row(@law32, "s.114(2)(a)(ix)[E+W]", extent_code: "E+W")]

      assert periods(@law32, rows, changes, law_start: ~D[1995-07-19]) == [
               {~D[2006-04-01], nil, "in_force", ~D[2006-04-01], "UK_ukpga_2003_37"}
             ]
    end

    test "an E-only change to an E+W provision does date it (the territories overlap)" do
      changes = [
        change(
          @law32,
          "s.5",
          "key-e",
          "substituted",
          "words substituted",
          "UK_uksi_2012_9",
          [
            {~D[2012-03-01], nil}
          ],
          effect_extent: "E"
        )
      ]

      assert [_, {~D[2012-03-01], nil, "in_force", ~D[2012-03-01], "UK_uksi_2012_9"}] =
               periods(@law32, [row(@law32, "s.5", extent_code: "E+W")], changes,
                 law_start: ~D[1995-07-19]
               )
    end
  end

  test "same day, a change and its commencement: changed_by is the law that made the change, not the order (anaw 2017/3 s.42(1A))" do
    law = "UK_anaw_2017_3"

    changes = [
      change(law, "s.42(1A)", "key-i", "inserted", "inserted", "UK_wsi_2018_101", [
        {~D[2018-04-01], nil}
      ]),
      change(law, "s.42(1A)", "key-c", "commenced", "coming into force", "UK_wsi_2018_35", [
        {~D[2018-04-01], nil}
      ])
    ]

    for cs <- [changes, Enum.reverse(changes)] do
      assert [{~D[2018-04-01], nil, "in_force", ~D[2018-04-01], "UK_wsi_2018_101"}] =
               periods(law, [row(law, "s.42(1A)")], cs, law_start: ~D[2017-06-01])
    end
  end
end

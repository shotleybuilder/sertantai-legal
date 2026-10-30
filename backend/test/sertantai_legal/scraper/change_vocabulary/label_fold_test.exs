defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelFoldTest do
  @moduledoc """
  The label fold's rules found by CV-S09 round 1 (`Label`, `Label.Start`,
  `Label.Day`): a provision labelled from when it exists, a commencement for
  one territory (C13), a partial commencement on the start day, a whole
  substitution ending a partial status, a removal in part with its words
  gone, a version's split on its own day (C3), and `commenced_by` its own
  label (Jason 2026-10-30).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Label}

  @law "UK_ukpga_1984_3"

  defp change(target, op, date, opts \\ []) do
    %Change{
      key: Keyword.get(opts, :key, "k-#{target}-#{op}-#{date}"),
      target: target,
      claims:
        for(
          {s, a, v} <- Keyword.get(opts, :claims, []),
          do: %Claim{source: s, attribute: a, value: v, ref: "k"}
        ),
      resolved: %Evidence.Resolved{
        operation: op,
        level: Keyword.get(opts, :level, :provision),
        territory: Keyword.get(opts, :territory),
        date: date,
        by: Keyword.get(opts, :by),
        commenced_by: Keyword.get(opts, :commenced_by),
        retained: Keyword.get(opts, :retained, false),
        partial: Keyword.get(opts, :partial, false),
        saved: false,
        sources: Keyword.get(opts, :sources, %{operation: :law_text})
      }
    }
  end

  defp fold(id, changes, provision \\ %{}),
    do:
      id
      |> Label.fold(
        Map.merge(%{law: @law, extent: "E+W", start: ~D[1984-05-13]}, provision),
        changes
      )
      |> Enum.map(&Map.delete(&1, :tiers))

  defp p(from, to, status, iff, by, territory, commenced_by \\ []),
    do: %{
      valid_from: from,
      valid_to: to,
      status: status,
      in_force_from: iff,
      changed_by: by,
      commenced_by: commenced_by,
      territory: territory
    }

  describe "a provision is labelled from when it exists (KI-insert)" do
    test "inserted later: from its insertion, never its law's start; the law's own commencement doesn't reach it" do
      changes = [
        change("s.1A", :commenced, ~D[1984-05-13], by: @law, commenced_by: @law),
        change("s.1A", :inserted, ~D[2004-09-19], by: "UK_ukpga_2000_37")
      ]

      assert fold("s.1A(b)", changes) == [
               p(~D[2004-09-19], nil, :in_force, ~D[2004-09-19], ["UK_ukpga_2000_37"], "E+W")
             ]
    end

    test "its insertion's territory (C14)" do
      changes = [
        change("reg.2A", :inserted, ~D[2020-12-31], by: "UK_uksi_2019_696", territory: "E+W+S")
      ]

      assert [%{valid_from: ~D[2020-12-31], territory: "E+W+S"}] =
               fold("reg.2A(11)", changes, %{extent: "E+W+S+NI"})
    end

    test "a legacy markup Addition alone never moves it (OSRPA ss.4–16)" do
      changes = [
        change("s.9", :inserted, ~D[1996-01-01],
          key: "d30p542",
          by: "UK_uksi_1992_3004",
          sources: %{operation: :markup}
        )
      ]

      assert [%{valid_from: ~D[1984-05-13]} | _] = fold("s.9(3)", changes)
    end
  end

  describe "a commencement for one territory (C13)" do
    defp for_territory(t), do: [{:feed, :in_force_for, t}, {:feed, :qualification, "territory"}]

    test "in force there, each commencement a version; commenced_by the orders" do
      changes = [
        change("s.1A", :inserted, ~D[2004-09-19],
          by: "UK_ukpga_2000_37",
          commenced_by: "UK_uksi_2004_2173",
          partial: true,
          claims: for_territory("E")
        ),
        change("s.1A", :commenced, ~D[2005-05-28],
          key: "k@2005",
          by: "UK_ukpga_2000_37",
          commenced_by: "UK_wsi_2005_423",
          partial: true,
          claims: for_territory("W")
        )
      ]

      assert fold("s.1A(b)", changes) == [
               p(
                 ~D[2004-09-19],
                 ~D[2005-05-28],
                 :in_force,
                 ~D[2004-09-19],
                 ["UK_ukpga_2000_37"],
                 "E",
                 ["UK_uksi_2004_2173"]
               ),
               p(
                 ~D[2005-05-28],
                 nil,
                 :in_force,
                 ~D[2005-05-28],
                 ["UK_ukpga_2000_37"],
                 "E+W",
                 ["UK_wsi_2005_423"]
               )
             ]
    end

    test "prospective, then in force for E+W+S, then NI (2007/19 s.2(1)(d))" do
      changes = [
        change("s.2(1)(d)", :commenced, ~D[2011-09-01],
          commenced_by: "UK_uksi_2011_1867",
          partial: true,
          claims: for_territory("E+W+S")
        ),
        change("s.2(1)(d)", :commenced, ~D[2012-09-03],
          commenced_by: "UK_nisr_2012_286",
          partial: true,
          claims: for_territory("NI")
        )
      ]

      assert [
               %{status: :prospective, territory: "E+W+S+NI"},
               %{status: :in_force, territory: "E+W+S", commenced_by: ["UK_uksi_2011_1867"]},
               %{status: :in_force, territory: "E+W+S+NI", commenced_by: ["UK_nisr_2012_286"]}
             ] =
               fold("s.2(1)(d)", changes, %{
                 law: "UK_ukpga_2007_19",
                 extent: "E+W+S+NI",
                 start: ~D[2007-07-26]
               })
    end
  end

  test "a partial commencement on the start day: partly in force, not prospective (SI 1992/3004 reg.20(2))" do
    changes = [
      change("reg.20(2)", :commenced, ~D[1993-01-01], partial: true),
      change("reg.20(2)", :commenced, ~D[1996-01-01])
    ]

    assert [
             %{status: :in_force_partial, valid_to: ~D[1996-01-01]},
             %{status: :in_force, in_force_from: ~D[1996-01-01]}
           ] = fold("reg.20(2)", changes, %{start: ~D[1993-01-01], law: "UK_uksi_1992_3004"})
  end

  test "a whole substitution fully in force ends a partial status (HSWA s.10, SI 2008/960)" do
    changes = [
      change("s.10", :commenced, ~D[1974-10-01], partial: true),
      change("s.10", :substituted, ~D[2008-04-01], by: "UK_uksi_2008_960")
    ]

    assert [
             %{status: :prospective},
             %{status: :in_force_partial},
             %{status: :in_force, in_force_from: ~D[2008-04-01], changed_by: ["UK_uksi_2008_960"]}
           ] = fold("s.10(1)", changes, %{start: ~D[1974-07-31], law: "UK_ukpga_1974_37"})
  end

  describe "a removal in part (C7)" do
    test "its words gone: a words repeal, a version (Factories Act 1961 s.125(2)(j))" do
      changes = [
        change("s.125(2)(j)", :repealed_in_part, ~D[1996-01-01], by: "UK_uksi_1995_2923")
      ]

      assert [
               _,
               %{
                 status: :in_force,
                 in_force_from: ~D[1996-01-01],
                 changed_by: ["UK_uksi_1995_2923"]
               }
             ] =
               fold("s.125(2)(j)", changes)
    end

    test "its text retained: partly in force" do
      changes = [change("reg.1A", :repealed_in_part, ~D[2021-01-01], retained: true)]
      assert [_, %{status: :in_force_partial}] = fold("reg.1A", changes)
    end
  end

  test "a version splits on the day the versions split; the other's repeal never reaches it (C3)" do
    changes = [
      change("reg.19", :repealed, ~D[2027-01-20], by: "UK_uksi_2026_867", territory: "NI")
    ]

    changes = [%{hd(changes) | resolved: %{hd(changes).resolved | saved: true}}]

    assert fold("reg.19(1)(b)(ii)[NI]", changes, %{
             law: "UK_uksi_2008_1597",
             extent: "E+W+S+NI",
             start: ~D[2009-12-29],
             version: "NI",
             version_start: ~D[2020-12-31]
           }) == [
             p(~D[2009-12-29], ~D[2020-12-31], :in_force, ~D[2009-12-29], [], "E+W+S+NI"),
             p(~D[2020-12-31], ~D[2027-01-20], :in_force, ~D[2009-12-29], [], "NI"),
             p(~D[2027-01-20], nil, :repealed_saved, nil, ["UK_uksi_2026_867"], "NI")
           ]
  end

  test "the most specific commencement governs: an ancestor's never reaches a provision commenced in its own right (2007/19 s.2(1)(d))" do
    changes = [
      change("s.2(1)", :commenced, ~D[2008-04-06], commenced_by: "UK_uksi_2008_401"),
      change("s.2(1)(d)", :commenced, ~D[2011-09-01], commenced_by: "UK_uksi_2011_1867")
    ]

    assert [%{status: :prospective, valid_to: ~D[2011-09-01]}, %{status: :in_force}] =
             fold("s.2(1)(d)", changes, %{law: "UK_ukpga_2007_19", start: ~D[2007-07-26]})
  end

  test "commenced_by: a commencing order, apart from the laws that made the text (HSWA s.78)" do
    changes = [change("s.78", :commenced, ~D[1975-04-01], commenced_by: "UK_uksi_1974_1439")]

    assert [
             %{status: :prospective},
             %{changed_by: [], commenced_by: ["UK_uksi_1974_1439"], in_force_from: ~D[1975-04-01]}
           ] = fold("s.78", changes, %{law: "UK_ukpga_1974_37", start: ~D[1974-07-31]})
  end

  test "the markup's Prospective holds only as at the text's valid day (NISR 1997/248, a made version)" do
    changes = [change("reg.11", :commenced, ~D[1997-07-01])]

    assert [%{status: :in_force}] =
             fold("reg.11(9)", changes, %{
               law: "UK_nisr_1997_248",
               extent: "NI",
               start: ~D[1997-07-01],
               prospective: true,
               valid: ~D[1997-05-20]
             })
  end

  describe "batch 2 (CV-S09 round 2)" do
    test "an undated whole insertion on an ancestor: the inserting law, no date when the start is only the law's (HSWA s.25A(1))" do
      changes = [change("s.25A", :inserted, nil, by: "UK_ukpga_1987_43")]

      assert [
               %{
                 status: :in_force,
                 in_force_from: nil,
                 changed_by: ["UK_ukpga_1987_43"]
               }
             ] =
               fold("s.25A(1)", changes, %{
                 law: "UK_ukpga_1974_37",
                 start: ~D[1974-07-31],
                 start_from_law: true
               })
    end

    test "a repealed provision comes back with its ancestor's later whole substitution, where it shows text (SI 2022/1378 reg.9(9))" do
      changes = [
        change("reg.9(9)", :repealed, ~D[2023-04-01], by: "UK_uksi_2023_247"),
        change("reg.9", :substituted, ~D[2024-04-01], by: "UK_uksi_2024_322")
      ]

      provision = %{law: "UK_uksi_2022_1378", start: ~D[2022-12-21], extent: "E+W+S"}

      assert [_, %{status: :repealed}, %{status: :in_force, changed_by: ["UK_uksi_2024_322"]}] =
               fold("reg.9(9)", changes, Map.put(provision, :shows_text, true))

      assert [_, %{status: :repealed}] = fold("reg.9(9)", changes, provision)
    end

    test "an undated substitution after an undated insertion made its text (CLP Art 25(7))" do
      changes = [
        change("art.Article 25(7)", :inserted, nil, by: "UK_eur_2017_542"),
        change("art.Article 25(7)", :substituted, nil, by: "UK_eur_2020_11")
      ]

      assert [%{changed_by: ["UK_eur_2020_11"]}] =
               fold("art.Article 25(7)", changes, %{law: "UK_eur_2008_1272"})
    end

    test "an unknown extent leaves no remainder to a territorial repeal (SI 1987/605)" do
      changes = [
        change("*", :repealed, ~D[1988-05-17], by: "UK_uksi_1988_712", territory: "E+W+S")
      ]

      assert [_, %{status: :repealed, territory: "nowhere"}] =
               fold("reg.5", changes, %{
                 law: "UK_uksi_1987_605",
                 extent: nil,
                 start: ~D[1987-05-01]
               })
    end

    test "a change the markup marks in the text with no operation of its own is a version (Factories Act 1961 s.125(6))" do
      c =
        change("s.125(6)", nil, ~D[1989-01-01],
          level: :words,
          by: "UK_uksi_1988_1655",
          claims: [{:markup, :level, :words}]
        )

      assert [_, %{in_force_from: ~D[1989-01-01], changed_by: ["UK_uksi_1988_1655"]}] =
               fold("s.125(6)", [c])
    end

    test "an earlier amendment to the amending law made the text too (C5; REACH Art 127E)" do
      changes = [
        change("art.Article 127E", :inserted, ~D[2020-12-31], by: "UK_uksi_2019_758"),
        change("art.Article 127E", nil, ~D[2020-12-31],
          key: "earlier",
          by: "UK_uksi_2019_858",
          claims: [{:feed, :earlier_amendment, true}]
        )
      ]

      assert [%{changed_by: ["UK_uksi_2019_758", "UK_uksi_2019_858"]}] =
               fold("art.Article 127E(8)(c)(i)", changes, %{
                 law: "UK_eur_2006_1907",
                 start: ~D[2006-12-18]
               })
    end

    test "a change whose level no source states never reaches what lies under it" do
      c = change("s.1", :inserted, ~D[2004-09-19], sources: %{operation: :feed, level: nil})
      assert [%{valid_from: ~D[1984-05-13]}] = fold("s.1(1)(a)", [c])
    end

    test "the start's tiers come from the changes behind it" do
      c =
        change("reg.2A", :inserted, ~D[2020-12-31], by: "UK_uksi_2019_696")
        |> then(&%{&1 | resolved: %{&1.resolved | tiers: %{date: :derived, by: :primary}}})

      [first] =
        Label.fold(
          "reg.2A(1)",
          %{law: "UK_uksi_2008_1597", extent: "E+W+S", start: ~D[2009-12-29]},
          [c]
        )

      assert first.tiers.in_force_from == :derived
      assert first.tiers.changed_by == :primary
    end
  end

  describe "batch 3 (CV-S09 round 3)" do
    test "it exists once everything holding it exists: the latest insertion starts it (HSWA s.51A(2E)(b))" do
      changes = [
        change("s.51A", :inserted, ~D[1998-07-01], by: "UK_ukpga_1997_42"),
        change("s.51A(2E)", :inserted, ~D[2005-04-07], by: "UK_ukpga_2005_15")
      ]

      assert [%{valid_from: ~D[2005-04-07], changed_by: ["UK_ukpga_2005_15"]}] =
               fold("s.51A(2E)(b)", changes, %{law: "UK_ukpga_1974_37", start: ~D[1974-07-31]})
    end

    test "an undated insertion by another law: its law's own commencements never reach it (HSWA s.34(6), Gas Act 1986)" do
      changes = [
        change("s.34(6)", :inserted, nil, by: "UK_ukpga_1986_44", territory: "E+W+S"),
        change("s.34(6)", :commenced, ~D[1975-01-01],
          key: "UK_ukpga_1974_37:commencement:s.34(6)@1975-01-01",
          commenced_by: "UK_uksi_1974_1439"
        )
      ]

      assert [
               %{
                 status: :in_force,
                 in_force_from: nil,
                 changed_by: ["UK_ukpga_1986_44"],
                 commenced_by: [],
                 territory: "E+W+S"
               }
             ] =
               fold("s.34(6)", changes, %{
                 law: "UK_ukpga_1974_37",
                 start: ~D[1974-07-31],
                 extent: "E+W+S+NI",
                 start_from_law: true
               })
    end

    test "an undated whole repeal with its text gone: repealed (CLP Art 25(5))" do
      changes = [change("art.Article 25(5)", :repealed, nil, by: "UK_eur_2011_286")]

      assert [%{status: :repealed, territory: "nowhere", changed_by: ["UK_eur_2011_286"]}] =
               fold("art.Article 25(5)", changes, %{
                 law: "UK_eur_2008_1272",
                 start: ~D[1900-01-01],
                 start_dated: false,
                 shows_text: false
               })
    end

    test "it comes back only where the text was revised after the change (NISR 1993/37 reg.3(1)(d))" do
      changes = [
        change("reg.3(1)(d)", :repealed, ~D[2015-06-01], by: "UK_nisr_2015_223"),
        change("reg.3", :substituted, ~D[2017-02-01], by: "UK_nisr_2016_427")
      ]

      p = %{law: "UK_nisr_1993_37", start: ~D[1993-03-08], extent: "NI", shows_text: true}

      assert [_, %{status: :repealed}] =
               fold("reg.3(1)(d)", changes, Map.put(p, :valid, ~D[1993-02-01]))

      assert [_, _, %{status: :in_force}] =
               fold("reg.3(1)(d)", changes, Map.put(p, :valid, ~D[2026-01-01]))
    end

    test "an undated words change on an undated start made its text (REACH Art 118(2)(c))" do
      c =
        change("art.Article 118(2)(c)", :substituted, nil, level: :words, by: "UK_eur_2008_1272")

      assert [%{changed_by: ["UK_eur_2008_1272"], in_force_from: nil}] =
               fold("art.Article 118(2)(c)", [c], %{
                 law: "UK_eur_2006_1907",
                 start: ~D[1900-01-01],
                 start_dated: false
               })
    end

    test "a field's tier changes only with its value; an emptied field has none" do
      commenced =
        change("reg.2", :commenced, ~D[1997-07-01])
        |> then(&%{&1 | resolved: %{&1.resolved | tiers: %{date: :primary}}})

      repeal =
        change("reg.2", :repealed, ~D[2006-08-01], by: "UK_nisr_2006_173")
        |> then(
          &%{
            &1
            | resolved: %{
                &1.resolved
                | tiers: %{date: :derived, by: :derived, operation: :derived}
              }
          }
        )

      [_, gone] =
        Label.fold(
          "reg.2(4)(b)(iv)",
          %{law: "UK_nisr_1997_248", extent: "NI", start: ~D[1997-07-01]},
          [
            commenced,
            repeal
          ]
        )

      assert gone.status == :repealed
      assert gone.tiers.commenced_by == nil
      assert gone.tiers.in_force_from == nil
      assert gone.tiers.changed_by == :derived
    end
  end
end

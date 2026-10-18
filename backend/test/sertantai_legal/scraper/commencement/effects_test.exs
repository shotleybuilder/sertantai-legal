defmodule SertantaiLegal.Scraper.Commencement.EffectsTest do
  @moduledoc """
  CR-04 (re-scoped): an Act's "coming into force" effects as rules — Water
  Act 2014 s.8, commenced in stages (2015 for the insertion of s.40J, 2016
  for specified purposes, 2018 for E. for specified purposes, 2019 for W.
  in so far as not already in force).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Effects, Evaluator, Order, Rule}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @act "UK_ukpga_2014_21"

  defp cif(by, art, refs, date, q),
    do: %Effect{
      type: "coming into force",
      affecting: by,
      affecting_provisions: art,
      affected_provisions: "s. 8",
      affected_refs: refs,
      in_force: [%{date: date, prospective: false, qualification: q, applied: true}]
    }

  defp effects,
    do: [
      cif(
        "UK_uksi_2015_773",
        "art. 2(1)(a)(i)",
        ["section-8-1"],
        ~D[2015-04-06],
        "for the insertion of s. 40J"
      ),
      cif(
        "UK_uksi_2016_1007",
        "art. 2(b)",
        ["section-8-1"],
        ~D[2016-11-01],
        "for specified purposes"
      ),
      cif(
        "UK_uksi_2018_397",
        "art. 2(a)",
        ["section-8"],
        ~D[2018-04-01],
        "for E. for specified purposes"
      ),
      cif(
        "UK_wsi_2017_1288",
        "art. 3(a)",
        ["section-8"],
        ~D[2019-04-01],
        "for W. in so far as not already in force"
      ),
      %Effect{
        type: "words substituted",
        affecting: "UK_ukpga_2015_1",
        affected_refs: ["section-8"]
      }
    ]

  test "qualifications: territory and the four purposes" do
    assert Effects.qualification("wholly in force") == {nil, nil}
    assert Effects.qualification("in force in so far as not already in force") == {nil, nil}
    assert Effects.qualification("for specified purposes") == {nil, :for_specified_purposes}

    assert Effects.qualification("for E. for specified purposes") ==
             {"E", :for_specified_purposes}

    assert Effects.qualification("for W. in so far as not already in force") == {"W", nil}
    assert Effects.qualification("for E.W.") == {"E+W", nil}
    assert Effects.qualification("for the insertion of s. 40J") == {nil, :in_relation_to}

    assert Effects.qualification("for the purpose of making regulations") ==
             {nil, :for_making_secondary_legislation}
  end

  test "commencement effects only, one rule per in-force entry, each order its own source" do
    rules = Effects.rules(@act, effects())

    assert Enum.map(rules, &{&1.source.law, &1.scope, &1.territory, &1.purposes}) == [
             {"UK_uksi_2015_773", ["s.8(1)"], nil, :in_relation_to},
             {"UK_uksi_2016_1007", ["s.8(1)"], nil, :for_specified_purposes},
             {"UK_uksi_2018_397", ["s.8"], "E", :for_specified_purposes},
             {"UK_wsi_2017_1288", ["s.8"], "W", nil}
           ]

    assert %Rule{treatment: :feed_commencement, when: {:date, ~D[2015-04-06]}} = hd(rules)
  end

  test "Water Act 2014 s.8(1) on an E+W row: partly from 2015; Wales in 2019 completes it — no full commencement for England is recorded" do
    rules = Effects.rules(@act, effects())

    r =
      Evaluator.evaluate(
        rules,
        Order.ref("section-8-1"),
        Map.put(Order.context(), :extent, "E+W")
      )

    assert %{partial_from: ~D[2015-04-06], full_from: nil} = r
  end

  test "for_row/2: a qualification naming inserted sections reaches only those rows (BSA 2022 Sch. 5 para. 77, Building Act 1984 s.120B)" do
    staged =
      Effects.rules("UK_ukpga_2022_30", [
        %Effect{
          type: "coming into force",
          affecting: "UK_uksi_2022_561",
          affecting_provisions: "reg. 2",
          affected_provisions: "Sch. 5 para. 77",
          affected_refs: ["schedule-5-paragraph-77"],
          in_force: [
            %{
              date: ~D[2022-06-28],
              prospective: false,
              qualification:
                "for the insertion of s. 120A for E. and the insertion of s. 120B for specified purposes",
              applied: true
            }
          ]
        },
        %Effect{
          type: "coming into force",
          affecting: "UK_uksi_2023_362",
          affecting_provisions: "reg. 3",
          affected_provisions: "Sch. 5 para. 77",
          affected_refs: ["schedule-5-paragraph-77"],
          in_force: [
            %{
              date: ~D[2022-12-09],
              prospective: false,
              qualification: "for the insertion of s. 120C",
              applied: true
            }
          ]
        }
      ])

    assert [%Rule{purposes: :for_specified_purposes, territory: nil}] =
             Effects.for_row(staged, "UK_ukpga_1984_55:s.120B(2)")

    assert [%Rule{purposes: nil, territory: "E"}] =
             Effects.for_row(staged, "UK_ukpga_1984_55:s.120A(1)")

    assert [%Rule{purposes: nil, territory: nil}] =
             Effects.for_row(staged, "UK_ukpga_1984_55:s.120C")

    assert Effects.for_row(staged, "UK_ukpga_1984_55:s.121") == []
  end

  test "a Schedule listed with its paragraph is only its place (the feed's affected refs)" do
    [rule] =
      Effects.rules("UK_ukpga_2022_30", [
        %Effect{
          type: "coming into force",
          affecting: "UK_uksi_2022_561",
          affected_refs: ["schedule-5", "schedule-5-paragraph-77"],
          in_force: [
            %{date: ~D[2022-06-28], prospective: false, qualification: nil, applied: true}
          ]
        }
      ])

    assert rule.scope == ["sch.5.para.77"]
  end

  test "Amending.evaluate/4: effects first, the order's text only where no effect reaches the provision" do
    alias SertantaiLegal.Scraper.Commencement.Amending

    effect =
      hd(
        Effects.rules("UK_ukpga_2000_37", [
          %Effect{
            type: "coming into force",
            affecting: "UK_uksi_2004_2173",
            affected_refs: ["section-13-1"],
            in_force: [
              %{date: ~D[2004-09-19], prospective: false, qualification: "for E.", applied: true}
            ]
          }
        ])
      )

    text =
      Rule.new(
        commences: "UK_ukpga_2000_37",
        scope: ["s.13(1)", "s.14"],
        when: {:date, ~D[2004-09-19]},
        source: %{law: "UK_uksi_2004_2173", ref: "art.2", text: "…"},
        treatment: :order_date
      )

    # the effect says England only: never fully on an E+W row from it
    assert %{full_from: nil, partial_from: ~D[2004-09-19]} =
             Amending.evaluate([effect, text], "section-13-1", "UK_ukpga_1957_31:s.1(4)", "E+W")

    # no effect reaches s.14: the order's text
    assert %{full_from: ~D[2004-09-19]} =
             Amending.evaluate([effect, text], "section-14", "UK_ukpga_1957_31:s.2", "E+W")
  end
end

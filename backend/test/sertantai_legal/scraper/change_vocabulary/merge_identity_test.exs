defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeIdentityTest do
  @moduledoc """
  A change's identity in the merge (CV-S07 round 2, `docs/CHANGE-IDENTITY-
  DESIGN.md`): its effect id (the feed's `EffectId`, or the id in its
  `URI`), else its source provision; each source's copies of one event one
  candidate. Each case is a round 1 finding, trimmed.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Merge}

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, law, date \\ ~D[2020-12-31]),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, :words},
        {:law_text, :by, law},
        {:law_text, :date, date}
      ])

  defp feed(key, target, op, law, affecting, extra \\ []),
    do:
      set(
        key,
        target,
        [
          {:feed, :by, law},
          {:feed, :date, ~D[2020-12-31]},
          {:feed, :affecting, affecting}
        ] ++ if(op, do: [{:feed, :operation, op}], else: []) ++ extra
      )

  defp markup(key, target, op, law, extra),
    do: set(key, target, [{:markup, :operation, op}, {:markup, :cited, law}] ++ extra)

  # an effect id (built here: never written whole in the repo)
  defp effect_id(c), do: "key-" <> String.duplicate(c, 32)

  # the change holding `key` among its ids
  defp holding(changes, key), do: Enum.find(changes, &(key in [&1.key | &1.aliases]))

  test "the feed's URI id is the effect's too: the markup carrying it joins (NISR 2004/222 reg.2(1))" do
    {effect, uri} = {effect_id("a"), effect_id("b")}

    changes =
      Merge.merge(
        [
          feed(effect, "reg.2(1)", :substituted, "UK_nisr_2006_205", ["sch.2.pt.2"]),
          markup(uri, "reg.2(1)", :substituted, "UK_nisr_2006_205", [])
        ],
        uris: %{uri => effect}
      )

    assert [%{key: ^effect, aliases: aliases}] = changes
    assert uri in aliases
  end

  test "a markup effect id no feed record holds joins as an id-less record (SI 1977/500 reg.6(1) by SI 2013/1471)" do
    changes =
      Merge.merge([
        feed(effect_id("a"), "reg.6(1)", :substituted, "UK_uksi_2013_1471", ["sch.4"]),
        markup(effect_id("c"), "reg.6(1)", :substituted, "UK_uksi_2013_1471", [
          {:markup, :affecting, ["sch.4"]}
        ])
      ])

    assert [%{key: key, aliases: aliases}] = changes
    assert key == effect_id("a") and effect_id("c") in aliases
  end

  test "markup copies of one note on one provision are one candidate: the law's text joins (HSWA s.28(6), 2009 c.20 Sch.6 para 42)" do
    note = [{:markup, :note, "c20462071"}, {:markup, :affecting, ["sch.6.para.42"]}]

    changes =
      Merge.merge([
        feed(effect_id("a"), "s.28(6)", :inserted, "UK_ukpga_2009_20", ["sch.6.para.42"]),
        markup("d29p3040", "s.28(6)", :inserted, "UK_ukpga_2009_20", note),
        markup("d29p11453", "s.28(6)", :inserted, "UK_ukpga_2009_20", note),
        markup("d29p11784", "s.28(6)", :inserted, "UK_ukpga_2009_20", note),
        text("UK_ukpga_2009_20:schedule-6-paragraph-42", "s.28(6)", :inserted, "UK_ukpga_2009_20")
      ])

    assert [%{aliases: aliases}] = changes

    for k <- ["d29p3040", "d29p11453", "d29p11784", "UK_ukpga_2009_20:schedule-6-paragraph-42"],
        do: assert(k in aliases)
  end

  test "both sides naming the amending provision: they must agree (HSWA s.50(3), SI 2008/960 art.16(4))" do
    changes =
      Merge.merge([
        feed(effect_id("a"), "s.50(3)", :substituted, "UK_uksi_2008_960", ["art.16(4)(a)"]),
        markup("d29p4939", "s.50(3)", :substituted, "UK_uksi_2008_960", [
          {:markup, :affecting, ["art.16(4)(b)"]}
        ]),
        markup("d29p4945", "s.50(3)", :substituted, "UK_uksi_2008_960", [
          {:markup, :affecting, ["art.16(4)(a)"]}
        ])
      ])

    assert "d29p4945" in holding(changes, effect_id("a")).aliases
    refute "d29p4939" in holding(changes, effect_id("a")).aliases
  end

  test "an operation-less feed effect ('amended') joins by its amending provision (HSWA s.52(1), 1997 c.42 s.2)" do
    changes =
      Merge.merge([
        feed(effect_id("a"), "s.52(1)", nil, "UK_ukpga_1997_42", ["s.2"]),
        markup("d29p5247", "s.52(1)(bb)", :inserted, "UK_ukpga_1997_42", [
          {:markup, :affecting, ["s.2"]}
        ]),
        text("UK_ukpga_1997_42:section-2", "s.52(1)(bb)", :inserted, "UK_ukpga_1997_42")
      ])

    assert [%{aliases: aliases}] = changes
    assert "d29p5247" in aliases and "UK_ukpga_1997_42:section-2" in aliases
  end

  test "one effect's stages are one candidate; the law's text joins the stage of its day (HSWA s.47(5), ERRA 2013)" do
    id = effect_id("a")

    changes =
      Merge.merge([
        set(id, "s.47(5)", [
          {:feed, :operation, :repealed},
          {:feed, :by, "UK_ukpga_2013_24"},
          {:feed, :date, ~D[2013-10-01]},
          {:feed, :affecting, ["s.69(6)"]}
        ]),
        set(id <> "@2013-04-25", "s.47(5)", [
          {:feed, :operation, :repealed_in_part},
          {:feed, :by, "UK_ukpga_2013_24"},
          {:feed, :date, ~D[2013-04-25]},
          {:feed, :affecting, ["s.69(6)"]}
        ]),
        text(
          "UK_ukpga_2013_24:section-69-6",
          "s.47(5)",
          :repealed,
          "UK_ukpga_2013_24",
          ~D[2013-10-01]
        )
      ])

    assert "UK_ukpga_2013_24:section-69-6" in holding(changes, id).aliases
  end

  test "one instruction the feed splits into a heading and a body effect: the law's text joins the body (SI 2008/1597 reg.21, SI 2019/696 Sch.12 para 21(a))" do
    changes =
      Merge.merge([
        feed(effect_id("h"), "reg.21", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(a)"], [
          {:feed, :heading, true}
        ]),
        feed(effect_id("b"), "reg.21", :substituted, "UK_uksi_2019_696", ["sch.12.para.21(a)"]),
        text(
          "UK_uksi_2019_696:schedule-12-paragraph-21-a",
          "reg.21",
          :substituted,
          "UK_uksi_2019_696"
        )
      ])

    assert "UK_uksi_2019_696:schedule-12-paragraph-21-a" in holding(changes, effect_id("b")).aliases
  end

  test "several left: the exact operation decides (NISR 2012/255 reg.8(1), NISR 2015/339 reg.34(2)(b))" do
    changes =
      Merge.merge([
        feed(effect_id("a"), "reg.8(1)", :inserted, "UK_nisr_2015_339", ["reg.34(2)(b)"]),
        feed(effect_id("s"), "reg.8(1)", :substituted, "UK_nisr_2015_339", ["reg.34(2)(b)"]),
        text(
          "UK_nisr_2015_339:regulation-34-2-b",
          "reg.8(1)",
          :substituted,
          "UK_nisr_2015_339"
        )
      ])

    assert "UK_nisr_2015_339:regulation-34-2-b" in holding(changes, effect_id("s")).aliases
  end

  test "the same amending provision joins across families: a removal the markup shows as an Addition (HSWA s.84(5), 1992 c.15 Sch.2; Jason 2026-10-28)" do
    changes =
      Merge.merge([
        markup("d29p6848", "s.84(5)", :inserted, "UK_ukpga_1992_15", [
          {:markup, :affecting, ["sch.2"]}
        ]),
        set("UK_ukpga_1992_15:schedule-2", "s.84(5)", [
          {:law_text, :operation, :repealed},
          {:law_text, :level, :provision},
          {:law_text, :by, "UK_ukpga_1992_15"}
        ])
      ])

    assert [%{aliases: aliases}] = changes
    assert "UK_ukpga_1992_15:schedule-2" in aliases
  end

  test "never across families on nearness alone: no provision named on one side" do
    changes =
      Merge.merge([
        markup("d29p6848", "s.84(5)", :inserted, "UK_ukpga_1992_15", []),
        set("UK_ukpga_1992_15:schedule-2", "s.84(5)", [
          {:law_text, :operation, :repealed},
          {:law_text, :by, "UK_ukpga_1992_15"}
        ])
      ])

    assert length(changes) == 2
  end

  test "a note's law read from its words identifies, never fills by (HSWA s.28(5)(b), 'S.I. 2004/ 1822')" do
    changes =
      Merge.merge([
        feed(effect_id("a"), "s.28(5)(b)", :substituted, "UK_uksi_2004_1822", ["sch.para.8(b)(i)"]),
        set("d29p11427", "s.28(5)(b)", [
          {:markup, :operation, :substituted},
          {:markup, :cited_text, "UK_uksi_2004_1822"},
          {:markup, :affecting, ["sch.para.8(b)(i)"]}
        ])
      ])

    assert [%{aliases: aliases}] = changes
    assert "d29p11427" in aliases
  end

  describe "round 2 findings" do
    test "a Schedule's Part is the Schedule's: related (HSWA s.51A(2E)(d), 2006 c.48 Sch.15 Pt 1)" do
      changes =
        Merge.merge([
          feed(effect_id("a"), "s.51A(2E)(d)", :repealed, "UK_ukpga_2006_48", ["sch.15.pt.1"]),
          text("UK_ukpga_2006_48:schedule-15", "s.51A(2E)(d)", :repealed, "UK_ukpga_2006_48")
        ])

      assert [%{aliases: aliases}] = changes
      assert "UK_ukpga_2006_48:schedule-15" in aliases
    end

    test "copies of one note in each version, each with its own note id, are one (HSWA s.28(3)(f), SI 2004/3363 art.5(2))" do
      digest = [{:markup, :note_digest, "d1"}]

      changes =
        Merge.merge([
          feed(effect_id("a"), "s.28(3)(f)", :inserted, "UK_uksi_2004_3363", ["art.5(2)"]),
          markup("d29p2944", "s.28(3)(f)", :inserted, "UK_uksi_2004_3363", [
            {:markup, :note, "c18727421"} | digest
          ]),
          markup("d29p11348", "s.28(3)(f)", :inserted, "UK_uksi_2004_3363", [
            {:markup, :note, "c18727591"} | digest
          ]),
          markup("d29p11694", "s.28(3)(f)", :inserted, "UK_uksi_2004_3363", [
            {:markup, :note, "c18727571"} | digest
          ])
        ])

      assert [%{aliases: aliases}] = changes
      for k <- ["d29p2944", "d29p11348", "d29p11694"], do: assert(k in aliases)
    end

    test "one note's pieces on a provision and below it are one candidate (HSWA s.16, SI 2008/960 art.8)" do
      note = [
        {:markup, :note, "c19946601"},
        {:markup, :note_digest, "d2"},
        {:markup, :affecting, ["art.8"]}
      ]

      changes =
        Merge.merge([
          markup("d29p1426", "s.16", :substituted, "UK_uksi_2008_960", note),
          markup("d29p1449", "s.16(1)", :substituted, "UK_uksi_2008_960", note),
          markup("d29p1502", "s.16(2)", :substituted, "UK_uksi_2008_960", note),
          text("UK_uksi_2008_960:article-8", "s.16", :substituted, "UK_uksi_2008_960")
        ])

      assert "UK_uksi_2008_960:article-8" in holding(changes, "d29p1426").aliases
    end

    test "the family waived for one provision, the same family still preferred; a removal in part is a removal (HSWA s.53(1), 1994 c.19 Sch.9 para 9)" do
      changes =
        Merge.merge([
          feed(effect_id("r"), "s.53(1)", :repealed_in_part, "UK_ukpga_1994_19", ["sch.9.para.9"]),
          feed(effect_id("i"), "s.53(1)", :inserted, "UK_ukpga_1994_19", ["sch.9.para.9"]),
          set("UK_ukpga_1994_19:schedule-9-paragraph-9", "s.53(1)", [
            {:law_text, :operation, :repealed},
            {:law_text, :level, :words},
            {:law_text, :by, "UK_ukpga_1994_19"}
          ])
        ])

      assert "UK_ukpga_1994_19:schedule-9-paragraph-9" in holding(changes, effect_id("r")).aliases
    end

    test "a heading record keeps the heading event (SI 2008/1597 reg.11, SI 2019/696 Sch.12 para 7(a))" do
      changes =
        Merge.merge([
          feed(effect_id("h"), "reg.11", :substituted, "UK_uksi_2019_696", ["sch.12.para.7(a)"], [
            {:feed, :heading, true}
          ]),
          feed(effect_id("b"), "reg.11(1)(b)(i)", :substituted, "UK_uksi_2019_696", [
            "sch.12.para.7(a)"
          ]),
          markup("d1", "reg.11", :substituted, "UK_uksi_2019_696", [
            {:markup, :heading, true},
            {:markup, :affecting, ["sch.12.para.7(a)"]}
          ])
        ])

      assert "d1" in holding(changes, effect_id("h")).aliases
    end

    test "an effect placed here only for want of its finer row ranks below the exact one (REACH art.14(2))" do
      changes =
        Merge.merge([
          feed(effect_id("x"), "art.Article 14(2)", :substituted, "UK_eur_2008_1272", [
            "art.Article 1"
          ]),
          feed(
            effect_id("e"),
            "art.Article 14(2)",
            :substituted,
            "UK_eur_2008_1272",
            ["art.Article 1"],
            [
              {:feed, :finer_unheld, "art.Article 14(2)(e)"}
            ]
          ),
          markup("O031001M011", "art.Article 14(2)", :substituted, "UK_eur_2008_1272", [])
        ])

      assert "O031001M011" in holding(changes, effect_id("x")).aliases
    end

    test "EU markup sharing a generic note is never collapsed (Directive 98/24 art.2(b)(i), (b)(iii))" do
      note = [{:markup, :note, "c000001"}, {:markup, :note_digest, "eu"}]

      changes =
        Merge.merge([
          markup("O002001M001", "art.Article 2", :substituted, "UK_eudr_2014_27", note),
          markup("O002001M003", "art.Article 2", :substituted, "UK_eudr_2014_27", note)
        ])

      assert length(changes) == 2
    end

    test "an Order's article is the feed's 'reg.' (SSI 2010/428 art.2): related; an Addition for a substitution joins (Factories Act s.178(1))" do
      changes =
        Merge.merge([
          feed(effect_id("f"), "s.178(1)", :substituted, "UK_ssi_2010_428", ["reg.2"]),
          markup("68d6df", "s.178(1)", :inserted, "UK_ssi_2010_428", [
            {:markup, :affecting, ["art.1(1)", "art.2"]}
          ])
        ])

      assert [_] = changes
    end
  end
end

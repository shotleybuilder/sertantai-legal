defmodule SertantaiLegal.Scraper.ChangeVocabulary.PlacementTest do
  @moduledoc """
  Every feed effect accounted for (CV-S02, agreed 2026-10-22): placed on
  provisions we hold, or unplaced with a reason from a fixed set; our
  faults told apart from known limits and from what the feed itself says.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Placement

  # what we hold of a law: its LAT rows, the provisions in its CLML
  @held %{
    rows: MapSet.new(["reg.1", "reg.3", "reg.3(1)", "s.23[E+W]", "s.23[S]"]),
    clml: MapSet.new(["reg.1", "reg.3", "reg.3(1)", "reg.4", "s.23", "sch.3", "sch.3.para.1"]),
    schedules?: false
  }

  defp effect(text, refs \\ ["x"]), do: %{affected_provisions: text, affected_refs: refs}

  test "placed: a row we hold, or its territorial versions" do
    assert Placement.classify(effect("reg. 3(1)"), ["reg.3(1)"], @held) == :placed
    assert Placement.classify(effect("s. 23"), ["s.23"], @held) == :placed_versions
  end

  test "whole law" do
    assert Placement.classify(effect("Regulations", []), ["*"], @held) == :whole_law
  end

  test "a schedule we don't parse: the known v0.1 limit" do
    assert Placement.classify(effect("Sch. 3 para. 1"), ["sch.3", "sch.3.para.1"], @held) ==
             {:unplaced, :schedule_not_parsed}
  end

  test "the feed names no provision: not a provision (its own words)" do
    assert Placement.classify(effect("specified amended provision(s)", []), ["?"], @held) ==
             {:unplaced, :not_a_provision}
  end

  test "refs given but not converted: our fault" do
    assert Placement.classify(effect("Annex 17", ["annex-XVII"]), ["?"], @held) ==
             {:unplaced, :refs_not_converted}
  end

  test "a ref naming a part found under several (CLP \"Ch. 2 heading\", chapter-2: Titles II, III, V): ambiguous, the feed's own" do
    held =
      Map.put(@held, :xml_ids, %{
        "title-II-chapter-2" => "pt.II.ch.2",
        "title-III-chapter-2" => "pt.III.ch.2"
      })

    assert Placement.classify(effect("Ch. 2 heading", ["chapter-2"]), ["?"], held) ==
             {:unplaced, :ref_ambiguous}

    refute Placement.fault?(:ref_ambiguous)
  end

  test "gone from the current text; in the text but no row and no held ancestor: the parse's tell-tale (#182)" do
    assert Placement.classify(effect("reg. 5A"), ["reg.5A"], @held) == {:unplaced, :not_in_text}
    assert Placement.classify(effect("reg. 4"), ["reg.4"], @held) == {:unplaced, :row_missing}
  end

  test "deeper than our rows: on the nearest held ancestor (NI SR 1997/248 reg.13(2)(b)(i)(aa))" do
    held = %{
      @held
      | rows: MapSet.put(@held.rows, "reg.13(2)(b)(i)"),
        clml: MapSet.put(@held.clml, "reg.13(2)(b)(i)(aa)")
    }

    assert Placement.classify(effect("reg. 13(2)(b)(i)(aa)"), ["reg.13(2)(b)(i)(aa)"], held) ==
             :placed_ancestor
  end

  test "the feed's ref not in the text, the change marked there: placed by the markup (CLP Art. 2's definitions)" do
    held = Map.put(@held, :marked, MapSet.new(["key-2"]))
    e = %{affected_provisions: "reg. 3(9)", affected_refs: ["regulation-3-9"], effect_id: "key-2"}

    assert Placement.classify(e, ["reg.3(9)"], held) == :placed_by_markup

    assert Placement.classify(%{e | effect_id: "key-3"}, ["reg.3(9)"], held) ==
             {:unplaced, :not_in_text}
  end

  test "marked: change markup in the text only — not an unapplied effect in the metadata, not a note reference (D1)" do
    # effect ids built at runtime: a literal "key-" + 32 hex trips GitHub
    # push protection (read as a Mailgun key)
    id = &("key-" <> String.duplicate(&1, 32))

    xml = """
    <Legislation><ukm:Metadata><ukm:UnappliedEffects>
    <ukm:UnappliedEffect Type="inserted" EffectId="#{id.("7")}" AffectedProvisions="reg. 3A"/>
    </ukm:UnappliedEffects></ukm:Metadata><Body>
    <P1 id="regulation-17"><Pnumber><CommentaryRef Ref="#{id.("1")}"/>17</Pnumber></P1>
    <P4 id="section-3-5-c-ia"><Pnumber><Addition ChangeId="#{id.("a")}-1457517729152" CommentaryRef="#{id.("a")}">ia</Addition></Pnumber></P4>
    </Body></Legislation>
    """

    assert Placement.marked(xml) == MapSet.new([id.("a")])
  end

  test "a finer form not held tells of the parse: a faulty name, items with no ids, or not found" do
    rows = MapSet.new(["art.Article 77(2)", "art.Article 77(2)((e))", "art.Article 57"])

    assert Placement.tell_tale("art.Article 77(2)(e)", rows, false) == :naming
    assert Placement.tell_tale("art.Article 57(a)", rows, true) == :no_ids
    assert Placement.tell_tale("art.Article 54(3)", rows, false) == :not_found
  end

  test "which reasons are faults of ours, which known limits, tell-tales, or the feed's own" do
    assert Placement.fault?(:refs_not_converted)
    refute Placement.fault?(:row_missing)
    refute Placement.fault?(:schedule_not_parsed)
    refute Placement.fault?(:not_in_text)
    refute Placement.fault?(:not_a_provision)
  end

  test "an EU annex is converted, and unparsed like a schedule: the same known limit (REACH Annex XVII)" do
    alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
    assert Ref.from_clml("annex-XVII", "UK_eur_2006_1907") == "annex.XVII"
    assert Ref.from_clml("annex-I-part-2", "UK_eur_2008_1272") == "annex.I"

    assert Placement.classify(
             effect("Annex 17 Table entry 57", ["annex-XVII"]),
             ["annex.XVII"],
             @held
           ) ==
             {:unplaced, :schedule_not_parsed}
  end

  # Jason: "choose the changes that will affect our labels"
  describe "deeper than our rows: retarget/3" do
    alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}

    defp resolved(target, op, level),
      do:
        %Change{
          key: "k",
          target: target,
          claims: [
            %Claim{source: :feed, attribute: :operation, value: op, ref: "k"},
            %Claim{source: :feed, attribute: :level, value: level, ref: "k"}
          ]
        }
        |> Evidence.resolve(nil)

    @rows MapSet.new([
            "reg.13",
            "reg.13(2)",
            "reg.13(2)(b)",
            "reg.13(2)(b)(i)",
            "s.23[E+W]",
            "s.23[S]"
          ])
    @text MapSet.new(["reg.13(2)(b)(i)(aa)", "reg.13(2)(b)(i)"])

    test "moved, its words changed, the feed's target kept" do
      [c] =
        Placement.retarget([resolved("reg.13(2)(b)(i)(aa)", :inserted, :provision)], @rows, @text)

      assert c.target == "reg.13(2)(b)(i)"
      assert c.resolved.level == :words
      assert Change.value(c, :placement, :below_rows) == "reg.13(2)(b)(i)(aa)"
    end

    # a commencement stays on the deep item for the "commenced through its
    # parts" rule; a modification or application changes no label
    test "only text changes move; a commencement and others stay" do
      for {op, level} <- [
            {:repealed, :provision},
            {:inserted, :provision},
            {:substituted, :words},
            {:repealed_in_part, :provision},
            {:renumbered, :provision}
          ] do
        [c] = Placement.retarget([resolved("reg.13(2)(b)(i)(aa)", op, level)], @rows, @text)
        assert c.target == "reg.13(2)(b)(i)" and c.resolved.level == :words
      end

      for op <- [:commenced, :applied, :modified] do
        [c] = Placement.retarget([resolved("reg.13(2)(b)(i)(aa)", op, :provision)], @rows, @text)
        assert c.target == "reg.13(2)(b)(i)(aa)"
      end
    end

    test "not in the text, the event marked there: the markup's change carries it; the feed's record goes" do
      # the feed's "s. 3(5)(ia)" is s.3(5)(c)(ia) in the text (EPA 1989)
      deep = resolved("reg.13(2)(b)(i)(zz)", :substituted, :words)

      marked =
        %Change{
          key: "k",
          target: "reg.13(2)(b)(i)",
          claims: [%Claim{source: :markup, attribute: :operation, value: :substituted, ref: "k"}]
        }
        |> Evidence.resolve(nil)

      assert [%Change{target: "reg.13(2)(b)(i)"} = kept] =
               Placement.retarget([deep, marked], @rows, @text)

      assert Change.values(kept, :markup, :operation) == [:substituted]
      # unmarked, it stays where the feed put it
      assert [%Change{target: "reg.13(2)(b)(i)(zz)"}] = Placement.retarget([deep], @rows, @text)
    end

    test "held, held as versions, gone from the text, or nothing held above: left alone" do
      for t <- ["reg.13(2)", "s.23", "reg.13(2)(b)(i)(cc)", "sch.3"] do
        [c] = Placement.retarget([resolved(t, :substituted, :words)], @rows, @text)
        assert c.target == t
      end
    end
  end
end

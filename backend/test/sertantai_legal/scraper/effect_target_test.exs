defmodule SertantaiLegal.Scraper.EffectTargetTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EffectTarget
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  # 1989/29-like cross-heading block (11C-11H inserted with it; 12A older),
  # 2023/909-like Part 2 with Chapters, a run of sections, a bracket run
  @xml ~s(<Legislation>
    <Part id="part-I">
      <Pblock id="part-I-crossheading-appeal">
        <P1 id="section-11C"/><P1 id="section-11D"/><P1 id="section-11H"/>
        <P1 id="section-12A"><P2 id="section-12A-1"/></P1>
      </Pblock>
    </Part>
    <Part id="part-2">
      <Chapter id="part-2-chapter-1"><P1 id="regulation-5"/></Chapter>
      <Chapter id="part-2-chapter-3"><P1 id="regulation-9"><P2 id="regulation-9-8"/></P1></Chapter>
    </Part>
    <P1 id="section-50"/><P1 id="section-51"/><P1 id="section-55"/><P1 id="section-56"/>
    <P1 id="section-33"><P2 id="section-33-1">
      <P3 id="section-33-1-e"/><P3 id="section-33-1-f"/><P3 id="section-33-1-h"/><P3 id="section-33-1-j"/>
    </P2></P1>
  </Legislation>)

  defp tree, do: @xml |> SweetXml.parse(quiet: true) |> EffectTarget.tree()

  defp fx(text, refs, ranges \\ []),
    do:
      struct!(Effect,
        effect_id: "key-1",
        affecting: "UK_x",
        type: "inserted",
        affected_provisions: text,
        affected_refs: refs,
        affected_ranges: ranges
      )

  defp resolve(text, refs, ranges \\ []), do: EffectTarget.resolve(fx(text, refs, ranges), tree())

  test "provisions named with their cross-heading: those provisions and the heading, not older ones under it (1989/29 s.12A)" do
    assert {:text, ids} = resolve("ss. 11C-11H and cross-heading", ["part-I-crossheading-appeal"])
    assert Enum.sort(ids) == ~w(part-I-crossheading-appeal section-11C section-11D section-11H)
  end

  test "\"s. N cross-heading\": the heading only" do
    assert resolve("s. 11C cross-heading", ["part-I-crossheading-appeal"]) ==
             {:text, ["part-I-crossheading-appeal"]}
  end

  test "\"cross-heading\" alone is the heading, as the text says; a Part or Chapter named alone is its contents" do
    assert resolve("cross-heading", ["part-I-crossheading-appeal"]) ==
             {:text, ["part-I-crossheading-appeal"]}

    assert {:text, ids} = resolve("Pt. 2", ["part-2"])

    assert Enum.sort(ids) ==
             ~w(part-2 part-2-chapter-1 part-2-chapter-3 regulation-5 regulation-9 regulation-9-8)
  end

  test "nested container refs: the text's Chapter, not the whole Part (2023/909 Pt. 2 Ch. 3)" do
    assert {:text, ids} = resolve("Pt. 2 Ch. 3", ["part-2", "part-2-chapter-3"])
    assert Enum.sort(ids) == ~w(part-2-chapter-3 regulation-9 regulation-9-8)
  end

  test "a Part named in Arabic numerals, its id in Roman" do
    assert {:text, ids} = resolve("Pt. 1", ["part-I"])
    assert "section-12A-1" in ids and "part-I" in ids
  end

  test "a range the refs truncate to its first id: the whole range (\"s. 50 - 55\")" do
    assert {:text, ids} = resolve("s. 50 - 55", ["section-50"])
    assert Enum.sort(ids) == ~w(section-50 section-51 section-55)
  end

  test "a bracket range under one parent" do
    assert {:text, ids} = resolve("s. 33(1)(e)-(h)", ["section-33-1-e", "section-33-1-h"])
    assert Enum.sort(ids) == ~w(section-33-1-e section-33-1-f section-33-1-h)
  end

  test "one provision: its own id (sub-provisions are reached through their ancestors, as before)" do
    assert resolve("s. 33", ["section-33"]) == {:text, ["section-33"]}
  end

  test "text and refs sharing nothing: the refs as given, marked :disagree (a gap, never a guess)" do
    assert resolve("s. 56", ["section-50"]) == {:disagree, ["section-50"]}
  end

  test "text it can't read, or a provision the document doesn't hold: the refs as given (no container expansion)" do
    assert resolve("word", ["part-I-crossheading-appeal"]) ==
             {:refs, ["part-I-crossheading-appeal"]}

    assert resolve("s. 99", ["section-50"]) == {:refs, ["section-50"]}
    assert resolve(nil, ["section-50"]) == {:refs, ["section-50"]}
  end

  test "the whole instrument keeps its refs (whole-instrument effects are joined elsewhere)" do
    assert resolve("Act", []) == {:refs, []}
  end

  test "ranges in the refs are kept on the fallback" do
    assert {:refs, ids} = resolve("word", [], [{"section-50", "section-55"}])
    assert Enum.sort(ids) == ~w(section-50 section-51 section-55)
  end

  describe "Gemini review (LR-29)" do
    @lists ~s(<Legislation><P1 id="section-25"><P2 id="section-25-2"><P3 id="section-25-2-4"/></P2><P2 id="section-25-4"/></P1>
      <Part id="part-III"><Chapter id="part-III-chapter-V"><P1 id="section-70"/></Chapter></Part></Legislation>)

    defp tree2, do: @lists |> SweetXml.parse(quiet: true) |> EffectTarget.tree()

    test "brackets that read both as a path and as a list: the reading the refs support (\"s. 25(2)(4)\")" do
      assert EffectTarget.resolve(fx("s. 25(2)(4)", ["section-25-2", "section-25-4"]), tree2()) ==
               {:text, ["section-25-2", "section-25-4"]}

      assert EffectTarget.resolve(fx("s. 25(2)(4)", ["section-25-2-4"]), tree2()) ==
               {:text, ["section-25-2-4"]}
    end

    test "a Chapter named in Arabic numerals, its id in Roman; an en dash range" do
      assert {:text, ids} =
               EffectTarget.resolve(fx("Pt. 3 Ch. 5", ["part-III-chapter-V"]), tree2())

      assert "section-70" in ids

      assert {:text, ids} = resolve("s. 50 – 55", ["section-50"])
      assert Enum.sort(ids) == ~w(section-50 section-51 section-55)
    end

    test "span: an end before its start, or not held, spans nothing" do
      assert EffectTarget.span(tree(), "section-55", "section-50") == []
      assert EffectTarget.span(tree(), "section-50", "section-99") == []
    end

    test "text the grammar declines falls back to the refs (\"Pt. 2 Ch. 3 and 4\", \"Sch. 1 cross-heading\")" do
      assert {:refs, ["part-2"]} = resolve("Pt. 2 Ch. 3 and 4", ["part-2"])

      assert {:refs, ["part-I-crossheading-appeal"]} =
               resolve("Sch. 1 cross-heading", ["part-I-crossheading-appeal"])
    end
  end

  describe "document order (LR-35)" do
    @parts ~s(<Legislation><Part id="part-1"><P1 id="section-1"/><P1 id="section-2"><P2 id="section-2-1"/></P1></Part>
      <Part id="part-2"><P1 id="section-3"/><P1 id="section-4"/></Part></Legislation>)

    defp tree4, do: @parts |> SweetXml.parse(quiet: true) |> EffectTarget.tree()

    test "the tree's order is document order (as EffectIndex's), not xmerl's `//` order" do
      assert tree4().order ==
               ~w(part-1 section-1 section-2 section-2-1 part-2 section-3 section-4)
    end

    test "a range across a Part boundary takes what lies between its ends in the document" do
      assert EffectTarget.span(tree4(), "section-2", "section-3") ==
               ~w(section-2 section-2-1 part-2 section-3)
    end

    test "inside: an element's descendants in document order" do
      assert tree4().inside["part-1"] == ~w(section-1 section-2 section-2-1)
    end
  end

  describe "the 50 disagreements (LR-29)" do
    @mixed ~s(<Legislation><P1 id="section-28"><P2 id="section-28-3"><P3 id="section-28-3-e"/></P2><P3 id="section-28-f"/></P1>
      <P1 id="section-87"><P2 id="section-87-b"/><P2 id="section-87-c"/></P1></Legislation>)

    defp tree3, do: @mixed |> SweetXml.parse(quiet: true) |> EffectTarget.tree()

    test "brackets of different levels are a path, never a list (\"s. 28(3)(f)\" isn't s.28(3) and s.28(f))" do
      assert EffectTarget.resolve(fx("s. 28(3)(f)", ["section-28-3-f"]), tree3()) ==
               {:refs, ["section-28-3-f"]}
    end

    test "refs naming nothing the document holds don't contradict the text (\"s. 87(b)(c)\" → section-87-b-c)" do
      assert EffectTarget.resolve(fx("s. 87(b)(c)", ["section-87-b-c"]), tree3()) ==
               {:text, ["section-87-b", "section-87-c"]}
    end

    test "coverage follows the id hierarchy where the XML doesn't nest (1968/73 s.9(1)(b)(iaa))" do
      flat_xml =
        ~s(<Legislation><P1 id="section-9"><P3 id="section-9-1-b"/><P4 id="section-9-1-b-iaa"/></P1></Legislation>)

      t = flat_xml |> SweetXml.parse(quiet: true) |> EffectTarget.tree()

      assert EffectTarget.resolve(fx("s. 9(1)(b)(iaa)", ["section-9-1-b", "section-9-1-iaa"]), t) ==
               {:text, ["section-9-1-b-iaa"]}
    end
  end
end

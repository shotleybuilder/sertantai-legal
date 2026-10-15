defmodule SertantaiLegal.Scraper.LatParser.EffectsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{EffectIndex, LatTerritory}
  alias SertantaiLegal.Scraper.LatParser.Effects
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  defp effect(id, type, refs, extra \\ []) do
    struct!(
      Effect,
      [effect_id: id, type: type, affecting: "UK_ssi_2025_1", applied: true, affected_refs: refs] ++
        extra
    )
  end

  defp ctx(effects, doc) do
    %{effects: Effects.index(effects, doc, "E+W+S"), provision_changes: [], law_extent: "E+W+S"}
  end

  test "law_extent/2: the document's RestrictExtent, else the type's" do
    assert Effects.law_extent(~s(<Legislation RestrictExtent="E"/>), %{type_code: "ssi"}) == "E"
    assert Effects.law_extent("<Legislation/>", %{type_code: "ssi"}) == "S"
    assert Effects.law_extent("<Legislation/>", %{type_code: "wsi"}) == "E+W"
    assert Effects.law_extent("<Legislation/>", %{type_code: "uksi"}) == nil
  end

  test "index/3: none → empty; an index passes through; a list is indexed" do
    doc = el(~s(<Legislation><P1 id="regulation-3"/></Legislation>))
    assert Effects.index(nil, doc, nil) == EffectIndex.empty()
    index = Effects.index([effect("key-a", "revoked", ["regulation-3"])], doc, "E+W+S")
    assert Effects.index(index, doc, nil) == index
    assert [%Effect{effect_id: "key-a"}] = EffectIndex.on(index, "regulation-3")
  end

  test "with_whole_provision/2: an applied whole-provision effect with no joinable markup" do
    node = el(~s(<P1 id="regulation-3"><Pnumber>3</Pnumber></P1>))
    ctx = ctx([effect("key-a", "revoked", ["regulation-3"], effect_extent: "S")], node)

    assert [%LatTerritory.Change{kind: :keep, effect_id: "key-a", synthetic: true}] =
             Effects.with_whole_provision(ctx, node).provision_changes
  end

  test "with_whole_provision/2: markup joining an effect wins (no synthetic change)" do
    node =
      el(
        ~s(<P1 id="regulation-3"><Pnumber><Repeal ChangeId="key-a-1" RetainText="true">3</Repeal></Pnumber></P1>)
      )

    ctx = ctx([effect("key-a", "revoked", ["regulation-3"])], node)
    assert Effects.with_whole_provision(ctx, node).provision_changes == []
  end

  test "row_effect_ids/4: effects naming the provision, words-level ones excluded" do
    node = el(~s(<P1 id="regulation-3"><Pnumber>3</Pnumber></P1>))

    ctx =
      ctx(
        [
          effect("key-c", "coming into force", ["regulation-3"]),
          effect("key-w", "words substituted", ["regulation-3"])
        ],
        node
      )

    assert Effects.row_effect_ids([], [], ctx, node) == ["key-c"]
  end

  test "row_effect_joins/4: each join with how it reached the row (LR-23)" do
    node = el(~s(<P1 id="regulation-3"><Pnumber>3</Pnumber></P1>))
    ctx = ctx([effect("key-c", "coming into force", ["regulation-3"])], node)

    assert Effects.row_effect_joins([], [], ctx, node) == [{"key-c", :ref}]
    assert Effects.row_effect_ids([], [], ctx, node) == ["key-c"]
  end

  test "excluded/3: the row's exclusion and the segments it was read from" do
    node =
      el(
        ~s(<P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text><Repeal ChangeId="key-a-1" RetainText="true">Words.</Repeal></Text></P1para></P1>)
      )

    ctx = ctx([effect("key-a", "revoked", ["regulation-3"], effect_extent: "S")], node)
    {excluded, segments} = Effects.excluded(node, "E+W+S", ctx)
    assert excluded == "S"
    assert is_list(segments)
  end

  describe "container refs (LR-27; LR-29: the effect lands where its text says)" do
    @doc_xml ~s(<Legislation><Part id="part-2B"><Pblock id="part-2B-crossheading-general"><P1group><P1 id="section-27U"><P2 id="section-27U-1"/></P1></P1group><P1group><P1 id="section-27V"/></P1group></Pblock></Part><P1 id="section-28"/></Legislation>)

    test "provisions inserted with their cross-heading are reached; the ref names only the heading (1996/18 ss. 27U-27Y)" do
      doc = el(@doc_xml)

      index =
        Effects.index(
          [
            effect("key-i", "inserted", ["part-2B-crossheading-general"],
              affected_provisions: "ss. 27U-27V and cross-heading"
            )
          ],
          doc,
          "E+W+S"
        )

      for id <- ~w(part-2B-crossheading-general section-27U section-27U-1 section-27V),
          do: assert([%Effect{effect_id: "key-i"}] = EffectIndex.on(index, id))

      assert EffectIndex.on(index, "section-28") == []
    end

    test "a Part named reaches everything in the Part" do
      index =
        Effects.index(
          [
            effect("key-m", "applied (with modifications)", ["part-2B"],
              affected_provisions: "Pt. 2B"
            )
          ],
          el(@doc_xml),
          nil
        )

      assert [%Effect{}] = EffectIndex.on(index, "section-27V")
    end

    test "a words-level change to a heading stays on the heading" do
      index =
        Effects.index(
          [effect("key-w", "words substituted", ["part-2B-crossheading-general"])],
          el(@doc_xml),
          nil
        )

      assert [%Effect{}] = EffectIndex.on(index, "part-2B-crossheading-general")
      assert EffectIndex.on(index, "section-27U") == []
    end

    test "a provision named with its cross-heading doesn't reach other provisions under the heading (1989/29 s.12A)" do
      index =
        Effects.index(
          [
            effect("key-i", "inserted", ["part-2B-crossheading-general"],
              affected_provisions: "s. 27U and cross-heading"
            )
          ],
          el(@doc_xml),
          nil
        )

      assert [%Effect{}] = EffectIndex.on(index, "section-27U")
      assert EffectIndex.on(index, "section-27V") == []
      assert index.targets["key-i"] == :text
    end
  end
end

defmodule SertantaiLegal.Scraper.CommentaryParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CommentaryParser
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(fields) do
    struct!(Effect, Keyword.merge([type: "inserted", affecting: "UK_x", applied: true], fields))
  end

  @fixtures_path Path.join([__DIR__, "..", "..", "fixtures", "body_xml"])

  defp read_fixture(name) do
    @fixtures_path |> Path.join(name) |> File.read!()
  end

  # ── parse/3 with fixture XML ───────────────────────────────────

  describe "parse/3 with simple_act fixture" do
    setup do
      xml = read_fixture("simple_act.xml")
      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      %{annotations: annotations, xml: xml}
    end

    test "extracts all 3 commentaries", %{annotations: annotations} do
      assert length(annotations) == 3
    end

    test "extracts F-type as amendment", %{annotations: annotations} do
      f = Enum.find(annotations, &(&1.code_type == :amendment))
      assert f != nil
      assert f.code == "F1"
      assert String.contains?(f.text, "Words in s. 3 substituted")
    end

    test "extracts C-type as modification", %{annotations: annotations} do
      c = Enum.find(annotations, &(&1.code_type == :modification))
      assert c != nil
      assert c.code == "C1"
      assert String.contains?(c.text, "S. 3 modified")
    end

    test "extracts I-type as commencement", %{annotations: annotations} do
      i = Enum.find(annotations, &(&1.code_type == :commencement))
      assert i != nil
      # Internal key — not a simple "I1" code
      assert String.contains?(i.code, "key-abc123")
      assert String.contains?(i.text, "in force at 1.1.2025")
    end

    test "assigns sequential IDs per code_type", %{annotations: annotations} do
      ids = Enum.map(annotations, & &1.id)
      assert "UK_ukpga_2024_1:amendment:1" in ids
      assert "UK_ukpga_2024_1:modification:1" in ids
      assert "UK_ukpga_2024_1:commencement:1" in ids
    end

    test "sets source to lat_parser", %{annotations: annotations} do
      for ann <- annotations do
        assert ann.source == "lat_parser"
      end
    end

    test "sets law_name on all annotations", %{annotations: annotations} do
      for ann <- annotations do
        assert ann.law_name == "UK_ukpga_2024_1"
      end
    end
  end

  # ── parse/3 with ref_to_sections mapping ───────────────────────

  describe "parse/3 with ref_to_sections" do
    test "populates affected_sections from ref mapping" do
      xml = """
      <Legislation>
      <Primary><Body>
        <P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><Text><CommentaryRef Ref="F1"/>text</Text></P1para>
        </P1>
      </Body></Primary>
      <Commentaries>
        <Commentary id="F1" Type="F">
          <Para><Text>Words substituted by S.I. 2024/1</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      ref_to_sections = %{
        "F1" => ["UK_ukpga_2024_1:s.1", "UK_ukpga_2024_1:s.2"]
      }

      annotations =
        CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"}, ref_to_sections)

      assert length(annotations) == 1
      ann = hd(annotations)
      assert ann.affected_sections == ["UK_ukpga_2024_1:s.1", "UK_ukpga_2024_1:s.2"]
    end

    test "leaves affected_sections nil when no refs match" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F99" Type="F">
          <Para><Text>Some amendment text</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"}, %{})
      ann = hd(annotations)
      assert ann.affected_sections == nil
    end
  end

  # ── Type mapping ───────────────────────────────────────────────

  describe "Commentary Type mapping" do
    test "maps all 6 XML types correctly" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"><Para><Text>F text</Text></Para></Commentary>
        <Commentary id="C1" Type="C"><Para><Text>C text</Text></Para></Commentary>
        <Commentary id="M1" Type="M"><Para><Text>M text</Text></Para></Commentary>
        <Commentary id="I1" Type="I"><Para><Text>I text</Text></Para></Commentary>
        <Commentary id="E1" Type="E"><Para><Text>E text</Text></Para></Commentary>
        <Commentary id="X1" Type="X"><Para><Text>X text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      types = Enum.map(annotations, & &1.code_type) |> Enum.sort()

      assert :amendment in types
      assert :commencement in types
      assert :modification in types
      assert :extent_editorial in types

      # C is a modification; M (marginal citation) is editorial, not a modification (LH-01)
      mod_count = Enum.count(annotations, &(&1.code_type == :modification))
      assert mod_count == 1

      # E, X and M map to extent_editorial
      ext_count = Enum.count(annotations, &(&1.code_type == :extent_editorial))
      assert ext_count == 3
    end

    test "a marginal citation (Type M) is editorial, not a modification (LH-01)" do
      xml = """
      <Legislation><Commentaries><Commentary id="M1" Type="M"><Para><Text>1906 c. 14.</Text></Para></Commentary></Commentaries></Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.code_type == :extent_editorial
      # keeps its M code, so it never names a changing law (LH-06)
      assert String.starts_with?(ann.code, "M")
    end

    test "skips unknown Type values" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="Z1" Type="Z"><Para><Text>Unknown type</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_ukpga_2024_1"})
      assert annotations == []
    end
  end

  # ── Sequential ID assignment ───────────────────────────────────

  describe "sequential ID assignment" do
    test "assigns per-type sequential IDs" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"><Para><Text>First F</Text></Para></Commentary>
        <Commentary id="F2" Type="F"><Para><Text>Second F</Text></Para></Commentary>
        <Commentary id="F3" Type="F"><Para><Text>Third F</Text></Para></Commentary>
        <Commentary id="C1" Type="C"><Para><Text>First C</Text></Para></Commentary>
        <Commentary id="C2" Type="C"><Para><Text>Second C</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})

      f_ids =
        annotations
        |> Enum.filter(&(&1.code_type == :amendment))
        |> Enum.map(& &1.id)

      assert f_ids == [
               "UK_test_2024_1:amendment:1",
               "UK_test_2024_1:amendment:2",
               "UK_test_2024_1:amendment:3"
             ]

      c_ids =
        annotations
        |> Enum.filter(&(&1.code_type == :modification))
        |> Enum.map(& &1.id)

      assert c_ids == [
               "UK_test_2024_1:modification:1",
               "UK_test_2024_1:modification:2"
             ]
    end
  end

  # ── Text extraction ────────────────────────────────────────────

  describe "text extraction" do
    test "joins multiple Para/Text elements" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F">
          <Para><Text>First paragraph.</Text></Para>
          <Para><Text>Second paragraph.</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.text == "First paragraph. Second paragraph."
    end

    # xmerl's //text() returned direct text before descendants' (the
    # Citations), scrambling notes (LAT parser coverage II).
    test "keeps document order through Citation and CitationSubRef elements" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="key-37f1" Type="F"><Para><Text>Reg. 4(4)  substituted (14.4.1999) by <Citation URI="u" Year="1999" Number="860">The Police (Health and Safety) Regulations 1999 (S.I. 1999/860)</Citation>, <CitationSubRef SectionRef="regulation-1">regs. 1</CitationSubRef>, <CitationSubRef SectionRef="regulation-5-1">5(1)</CitationSubRef></Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_uksi_1998_2306"})

      assert ann.text ==
               "Reg. 4(4) substituted (14.4.1999) by The Police (Health and Safety) Regulations 1999 (S.I. 1999/860), regs. 1, 5(1)"
    end

    test "a note opening with a CitationSubRef keeps it first" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="key-3a88" Type="F"><Para><Text><CitationSubRef SectionRef="regulation-10-1">Reg. 10(1)</CitationSubRef><CitationSubRef SectionRef="regulation-10-2">(2)</CitationSubRef> substituted (17.9.2002) by <Citation Year="2002" Number="2174">The Health and Safety (Miscellaneous Amendments) Regulations 2002 (S.I. 2002/2174)</Citation>, <CitationSubRef>regs. 1</CitationSubRef>, <CitationSubRef>7(a)</CitationSubRef></Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_uksi_1998_2306"})

      assert ann.text ==
               "Reg. 10(1)(2) substituted (17.9.2002) by The Health and Safety (Miscellaneous Amendments) Regulations 2002 (S.I. 2002/2174), regs. 1, 7(a)"
    end

    test "a Text directly under the Commentary (no Para) is read once" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"><Text>S. 2 repealed (1.1.2000) by <Citation>Act 1999 (c. 1)</Citation>, s. 3</Text></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.text == "S. 2 repealed (1.1.2000) by Act 1999 (c. 1), s. 3"
    end

    test "handles empty Commentary gracefully" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F1" Type="F"></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.text == ""
    end
  end

  # ── Edge cases ─────────────────────────────────────────────────

  describe "edge cases" do
    test "empty Commentaries block returns empty list" do
      xml = """
      <Legislation>
      <Commentaries></Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert annotations == []
    end

    test "no Commentaries block returns empty list" do
      xml = """
      <Legislation>
      <Primary><Body>
        <P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><Text>Some text.</Text></P1para>
        </P1>
      </Body></Primary>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert annotations == []
    end

    test "skips Commentary with empty id" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="" Type="F"><Para><Text>No ID</Text></Para></Commentary>
        <Commentary id="F1" Type="F"><Para><Text>Has ID</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      annotations = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert length(annotations) == 1
      assert hd(annotations).code == "F1"
    end
  end

  # ── build_ref_to_sections/1 ────────────────────────────────────

  describe "build_ref_to_sections/1" do
    test "inverts commentary_refs from LAT rows" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: ["F1", "C1"]},
        %{section_id: "law:s.2", commentary_refs: ["F1"]},
        %{section_id: "law:s.3", commentary_refs: []}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)

      assert result["F1"] == ["law:s.1", "law:s.2"]
      assert result["C1"] == ["law:s.1"]
      refute Map.has_key?(result, "")
    end

    test "handles rows with nil commentary_refs" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: nil},
        %{section_id: "law:s.2"}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)
      assert result == %{}
    end

    test "deduplicates section_ids per ref" do
      lat_rows = [
        %{section_id: "law:s.1", commentary_refs: ["F1"]},
        %{section_id: "law:s.1", commentary_refs: ["F1"]}
      ]

      result = CommentaryParser.build_ref_to_sections(lat_rows)
      assert result["F1"] == ["law:s.1"]
    end
  end

  # ── Code derivation ────────────────────────────────────────────

  describe "with_effects/3 (LR-07, LR-19)" do
    test "a note's pointer law is its joined effect's affecting law (the latest dated), else none here (LR-25)" do
      annotations = [%{code: "F:c1", text: "1996 NI 17"}, %{code: "F:c2", text: "b"}]

      rows = [
        %{section_id: "x", note_effects: [{"c1", "key-1"}, {"c1", "key-2"}]},
        %{section_id: "y"}
      ]

      at = fn d -> %{date: d, prospective: false, qualification: nil, applied: true} end

      effects = [
        effect(effect_id: "key-1", affecting: "UK_nisr_2001_1", in_force: [at.(~D[2001-01-01])]),
        effect(effect_id: "key-2", affecting: "UK_nisr_2006_425", in_force: [at.(~D[2006-12-01])])
      ]

      assert CommentaryParser.with_effects(annotations, rows, effects)
             |> Enum.map(&{&1.text, &1[:changed_by]}) == [
               {"1996 NI 17", "UK_nisr_2006_425"},
               {"b", nil}
             ]
    end

    test "from the change markup citing the note, plus its own id when the feed has it" do
      annotations = [
        %{code: "F:key-aa", text: "a"},
        %{code: "F:c123", text: "b"},
        %{code: "I:key-cc", text: "c"},
        %{code: "F:key-dd", text: "d"}
      ]

      rows = [
        %{section_id: "x", note_effects: [{"key-aa", "key-aa"}, {"c123", "key-b1"}]},
        %{section_id: "y", note_effects: [{"c123", "key-b2"}]},
        %{section_id: "z"}
      ]

      known = for id <- ~w(key-aa key-cc key-b1 key-b2), do: effect(effect_id: id)

      assert CommentaryParser.with_effects(annotations, rows, known)
             |> Enum.map(&{&1.text, &1.effect_ids}) == [
               {"a", ["key-aa"]},
               {"b", ["key-b1", "key-b2"]},
               {"c", ["key-cc"]},
               # re-keyed: neither joins
               {"d", []}
             ]
    end

    test "effect_joins: each joined effect with how the note reached it (LR-23)" do
      annotations = [%{code: "F:c123", text: "b"}, %{code: "I:key-cc", text: "c"}]
      rows = [%{section_id: "x", note_effects: [{"c123", "key-b1"}]}]
      known = for id <- ~w(key-cc key-b1), do: effect(effect_id: id)

      assert CommentaryParser.with_effects(annotations, rows, known)
             |> Enum.map(& &1.effect_joins) == [[{"key-b1", :markup}], [{"key-cc", :own}]]
    end

    test "a note no markup joins: the effects on its provision by the law it cites, of its kind, held by no other note (1991/56 s.98(5))" do
      rows = [
        %{section_id: "L:s.98(5)", xml_id: "section-98-5"},
        %{section_id: "L:s.98(5)(a)", xml_id: "section-98-5-a"}
      ]

      ann = fn code, type, text, cited ->
        %{
          code: code,
          code_type: type,
          text: text,
          law_name: "UK_ukpga_1991_56",
          citation_law: cited,
          affected_sections: ["L:s.98(5)"]
        }
      end

      annotations = [
        ann.(
          "F1",
          "amendment",
          "Words in s. 98(5) repealed (28.5.2004) by Water Act 2003 (c. 37), Sch. 9",
          "UK_ukpga_2003_37"
        ),
        # no Citation: the instrument it names after " by " points
        ann.(
          "F2",
          "amendment",
          "Words in s. 98(5) substituted (1.4.2005) by S.I. 2005/9, reg. 2",
          nil
        ),
        # its own effect: it holds key-held
        ann.(
          "F:key-held",
          "amendment",
          "Words in s. 98(5) inserted by Water Act 2003 (c. 37)",
          nil
        ),
        # names no law: no pointer
        ann.("F3", "amendment", "Words in s. 98(5) repealed", nil),
        # only a sub-provision's effect: no join
        ann.("C1", "modification", "S. 98(5) applied by S.I. 2006/1", "UK_uksi_2006_1")
      ]

      on = fn id, by, type, ref ->
        effect(effect_id: id, affecting: by, type: type, affected_refs: [ref])
      end

      effects = [
        on.("key-rep", "UK_ukpga_2003_37", "words repealed", "section-98-5"),
        on.("key-held", "UK_ukpga_2003_37", "words inserted", "section-98-5"),
        # by the cited law, of another kind
        on.("key-cif", "UK_ukpga_2003_37", "coming into force", "section-98-5"),
        on.("key-other", "UK_ukpga_2014_21", "words repealed", "section-98-5"),
        on.("key-si", "UK_uksi_2005_9", "words substituted", "section-98-5"),
        on.("key-sub", "UK_uksi_2006_1", "applied (with modifications)", "section-98-5-a")
      ]

      assert CommentaryParser.with_effects(annotations, rows, effects)
             |> Enum.map(&{&1.code, &1.effect_ids}) == [
               {"F1", ["key-rep"]},
               {"F2", ["key-si"]},
               {"F:key-held", ["key-held"]},
               {"F3", []},
               {"C1", []}
             ]

      assert CommentaryParser.with_effects(annotations, rows, effects)
             |> Enum.map(& &1.effect_joins)
             |> Enum.take(3) == [
               [{"key-rep", :cited, "L:s.98(5)"}],
               [{"key-si", :cited, "L:s.98(5)"}],
               [{"key-held", :own}]
             ]
    end

    test "several effects of its kind by the cited law on its provision: all join" do
      rows = [%{section_id: "L:s.21", xml_id: "section-21"}]

      annotations = [
        %{
          code: "F1",
          code_type: "amendment",
          text:
            "S. 21(2)(3) repealed (S.) (26.3.2003) by Criminal Justice (Scotland) Act 2003 (asp 7)",
          law_name: "UK_ukpga_1981_69",
          citation_law: "UK_asp_2003_7",
          affected_sections: ["L:s.21"]
        }
      ]

      effects =
        for id <- ~w(key-a key-b),
            do:
              effect(
                effect_id: id,
                affecting: "UK_asp_2003_7",
                type: "repealed",
                affected_refs: ["section-21"]
              )

      assert [%{effect_ids: ["key-a", "key-b"]}] =
               CommentaryParser.with_effects(annotations, rows, effects)
    end
  end

  describe "code derivation" do
    test "uses ref_id directly for simple codes like F1, C42" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="F42" Type="F"><Para><Text>Text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.code == "F42"
    end

    test "prefixes internal keys with type letter" do
      xml = """
      <Legislation>
      <Commentaries>
        <Commentary id="key-abc123" Type="F"><Para><Text>Text</Text></Para></Commentary>
      </Commentaries>
      </Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_test_2024_1"})
      assert ann.code == "F:key-abc123"
    end
  end

  # ── renumber/2 (scoped fragments) ──────────────────────────────

  describe "renumber/2" do
    defp note(fragment, seq, code, sections),
      do: %{
        id: "UK_test_2024_1:amendment:#{seq}",
        code_type: :amendment,
        code: code,
        text: "Note #{code}",
        affected_sections: sections,
        fragment: fragment
      }

    test "the same note from two fragments once, its sections combined" do
      [n] =
        CommentaryParser.renumber(
          [note(1, 1, "F:a", ["s.1"]), note(2, 1, "F:a", ["s.2"])],
          "UK_test_2024_1"
        )

      assert n.affected_sections == ["s.1", "s.2"]
      assert n.id == "UK_test_2024_1:amendment:1"
    end

    test "notes numbered alike in different fragments keep fragment order (deterministic)" do
      # every fragment numbers its notes from 1: ties are broken by document
      # order, never by map order (which follows the VM's atom table — LR-04)
      notes = for i <- 1..40, do: note(i, 1, "F:k#{i}", ["s.#{i}"])
      out = CommentaryParser.renumber(notes, "UK_test_2024_1")
      assert Enum.map(out, & &1.code) == Enum.map(notes, & &1.code)
      assert Enum.map(out, & &1.id) == for(i <- 1..40, do: "UK_test_2024_1:amendment:#{i}")
    end

    test "code types come out in name order (never atom-table order)" do
      notes = [
        %{note(1, 1, "F:m", ["s.1"]) | code_type: :modification},
        %{note(1, 1, "F:c", ["s.1"]) | code_type: :commencement},
        note(1, 1, "F:a", ["s.1"])
      ]

      assert notes |> CommentaryParser.renumber("UK_test_2024_1") |> Enum.map(& &1.code_type) ==
               [:amendment, :commencement, :modification]
    end
  end

  describe "citation_law/2 (LR-05)" do
    defp commentary(xml), do: SweetXml.parse(xml, quiet: true)

    test "the first Citation after \" by \": its URI's law, not the text's reading" do
      node =
        commentary(
          ~s|<Commentary id="k1" Type="F"><Para><Text>Words in s. 78A(9) omitted (1.4.2013) by virtue of <Citation URI="http://www.legislation.gov.uk/id/wsi/2013/755" Class="WelshStatutoryInstrument">The Natural Resources Body for Wales (Functions) Order 2013 (S.I. 2013/755)</Citation>, <CitationSubRef URI="http://www.legislation.gov.uk/id/wsi/2013/755/article/1/2">art. 1(2)</CitationSubRef></Text></Para></Commentary>|
        )

      text =
        "Words in s. 78A(9) omitted (1.4.2013) by virtue of The Natural Resources Body for Wales (Functions) Order 2013 (S.I. 2013/755), art. 1(2)"

      assert CommentaryParser.citation_law(node, text) == "UK_wsi_2013_755"
    end

    test "EU Regulations and Directives; a Citation before \" by \" and non-legislation URIs don't count" do
      node =
        commentary(
          ~s|<Commentary id="c2" Type="F"><Para><Text>Art. 2 of <Citation URI="http://www.legislation.gov.uk/id/eudr/1989/391">Directive 89/391/EEC</Citation> substituted by <Citation URI="http://www.legislation.gov.uk/id/eur/2019/1243">Regulation (EU) 2019/1243</Citation> (<Citation URI="https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=OJ">OJ L 198</Citation>)</Text></Para></Commentary>|
        )

      text = "Art. 2 of Directive 89/391/EEC substituted by Regulation (EU) 2019/1243 (OJ L 198)"
      assert CommentaryParser.citation_law(node, text) == "UK_eur_2019_1243"
    end

    test "an instrument named before the first Citation after \" by \": nil, the text stands (nisi 2003/419)" do
      node =
        commentary(
          ~s|<Commentary id="c4" Type="F"><Para><Text>Words omitted by virtue of S.I. 2019/530, reg. 128(ca) (as inserted by <Citation URI="http://www.legislation.gov.uk/id/uksi/2020/1016">S.I. 2020/1016</Citation>)</Text></Para></Commentary>|
        )

      text =
        "Words omitted by virtue of S.I. 2019/530, reg. 128(ca) (as inserted by S.I. 2020/1016)"

      assert CommentaryParser.citation_law(node, text) == nil
    end

    test "no \" by \", or no Citation after it: nil" do
      node =
        commentary(
          ~s|<Commentary id="c3" Type="C"><Para><Text>See <Citation URI="http://www.legislation.gov.uk/id/ukpga/1990/43">1990 c. 43</Citation></Text></Para></Commentary>|
        )

      assert CommentaryParser.citation_law(node, "See 1990 c. 43") == nil
      assert CommentaryParser.citation_law(node, "Applied by s. 5") == nil
    end

    test "parse/3 carries it on each note" do
      xml = """
      <Legislation><Commentaries><Commentary id="key-1" Type="F"><Para><Text>Words substituted by <Citation URI="http://www.legislation.gov.uk/id/eur/2019/1243">Regulation (EU) 2019/1243</Citation></Text></Para></Commentary></Commentaries></Legislation>
      """

      [ann] = CommentaryParser.parse(xml, %{law_name: "UK_eudr_1989_654"})
      assert ann.citation_law == "UK_eur_2019_1243"
    end
  end
end

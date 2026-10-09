defmodule SertantaiLegal.Scraper.LatParserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser

  @fixtures_path Path.join([__DIR__, "..", "..", "fixtures", "body_xml"])

  defp read_fixture(name) do
    @fixtures_path |> Path.join(name) |> File.read!()
  end

  # ── Simple Act ─────────────────────────────────────────────────

  describe "parse/2 with simple Act" do
    setup do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      %{rows: rows}
    end

    test "produces correct number of rows", %{rows: rows} do
      # 2 parts + 3 headings + 3 sections + 3 sub_sections + 2 paragraphs = 13
      assert length(rows) == 13
    end

    test "all section_ids are unique", %{rows: rows} do
      ids = Enum.map(rows, & &1.section_id)
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "first row is Part I with header-only text", %{rows: rows} do
      first = hd(rows)
      assert first.section_type == "part"
      assert first.section_id == "UK_ukpga_2024_1:pt.I"
      assert first.part == "I"
      assert first.position == 1

      # Part row should contain only title text, not child section text
      assert first.text == "General Provisions"
      refute String.contains?(first.text || "", "health and safety")
      refute String.contains?(first.text || "", "employer")
    end

    test "emits heading rows from Pblock", %{rows: rows} do
      headings = Enum.filter(rows, &(&1.section_type == "heading"))
      assert length(headings) == 3
      texts = Enum.map(headings, & &1.text)
      assert "Preliminary" in texts
      assert "General duties" in texts
      assert "Enforcement provisions" in texts
    end

    test "sections use s. prefix", %{rows: rows} do
      sections = Enum.filter(rows, &(&1.section_type == "section"))
      assert length(sections) == 3

      s1 = Enum.at(sections, 0)
      assert s1.section_id == "UK_ukpga_2024_1:s.1"
      assert s1.provision == "1"
    end

    test "sub_sections use s.X(Y) citation", %{rows: rows} do
      subs = Enum.filter(rows, &(&1.section_type == "sub_section"))
      assert length(subs) == 3

      s1_1 = Enum.find(subs, &(&1.section_id == "UK_ukpga_2024_1:s.1(1)"))
      assert s1_1.provision == "1"
      assert s1_1.sub == "1"
    end

    test "paragraphs inside sub_section use s.X(Y)(Z) citation", %{rows: rows} do
      paras = Enum.filter(rows, &(&1.section_type == "paragraph"))
      assert length(paras) == 2

      p_a = Enum.at(paras, 0)
      assert p_a.section_id == "UK_ukpga_2024_1:s.1(1)(a)"
      assert p_a.provision == "1"
      assert p_a.sub == "1"
      assert p_a.paragraph == "a"
    end

    test "Part II section has correct context", %{rows: rows} do
      s3 = Enum.find(rows, &(&1.provision == "3"))
      assert s3.section_type == "section"
      assert s3.part == "II"
      assert s3.section_id == "UK_ukpga_2024_1:s.3"
    end

    test "extent propagates from root", %{rows: rows} do
      for row <- rows do
        assert row.extent_code == "E+W+S+NI"
      end
    end

    test "positions are sequential 1..N", %{rows: rows} do
      positions = Enum.map(rows, & &1.position)
      assert positions == Enum.to_list(1..length(rows))
    end

    test "depth increases with nesting", %{rows: rows} do
      part = Enum.find(rows, &(&1.section_type == "part" and &1.part == "I"))
      heading = Enum.find(rows, &(&1.section_type == "heading" and &1.heading_group == "1"))
      section = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1"))
      sub = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1(1)"))
      para = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1(1)(a)"))

      assert part.depth == 1
      assert heading.depth == 2
      assert section.depth == 3
      assert sub.depth == 4
      assert para.depth == 5
    end

    test "hierarchy_path builds correctly", %{rows: rows} do
      para = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1(1)(a)"))
      assert para.hierarchy_path == "part.I/heading.1/provision.1/sub.1/para.a"
    end
  end

  # ── Simple SI ──────────────────────────────────────────────────

  describe "parse/2 sort_key order" do
    test "rows sort by sort_key in document order: (a)..(i), signed, then schedules" do
      items =
        for l <- ~w(a b c d e f g h i),
            do: "<P3><Pnumber>#{l}</Pnumber><P3para><Text>item #{l}</Text></P3para></P3>"

      xml = """
      <Legislation><Secondary><Body>
      <P1group><P1><Pnumber>6</Pnumber><P1para>
        <P2><Pnumber>4</Pnumber><P2para><Text>Conditions—</Text>#{Enum.join(items)}</P2para></P2>
      </P1para></P1></P1group>
      <SignedSection><Signatory><Para><Text>Signed.</Text></Para></Signatory></SignedSection>
      </Body>
      <Schedules><Schedule><Number>SCHEDULE 1</Number><ScheduleBody>
        <P1group><P1><Pnumber>1</Pnumber><P1para><Text>Particular.</Text></P1para></P1></P1group>
      </ScheduleBody></Schedule></Schedules>
      </Secondary></Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2099_1", type_code: "uksi"})
      by_position = Enum.sort_by(rows, & &1.position)
      by_sort_key = Enum.sort_by(rows, & &1.sort_key)

      assert Enum.map(by_sort_key, & &1.section_id) == Enum.map(by_position, & &1.section_id)
    end
  end

  describe "parse/2 sort_key is monotonic with document order" do
    test "an item after its paragraph has closed (legislation.gov.uk markup) still sorts in place" do
      xml = """
      <Legislation><Secondary><Body>
      <P1group><P1><Pnumber>39</Pnumber><P1para>
        <P2><Pnumber>2</Pnumber><P2para><Text>Lead—</Text>
          <P3><Pnumber>d</Pnumber><P3para><Text>item d</Text></P3para></P3>
        </P2para></P2>
        <P3><Pnumber>e</Pnumber><P3para><Text>item e</Text></P3para></P3>
      </P1para></P1></P1group>
      <P1group><P1><Pnumber>40</Pnumber><P1para><Text>Next.</Text></P1para></P1></P1group>
      </Body></Secondary></Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2099_1", type_code: "uksi"})
      assert Enum.any?(rows, &String.ends_with?(&1.section_id, ":reg.39(e)"))

      keys = rows |> Enum.sort_by(& &1.position) |> Enum.map(& &1.sort_key)
      assert keys == Enum.sort(keys)
    end
  end

  describe "parse/2 with simple SI" do
    setup do
      xml = read_fixture("simple_si.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_100", type_code: "uksi"})
      %{rows: rows}
    end

    test "uses reg. prefix for regulations", %{rows: rows} do
      reg1 = Enum.find(rows, &(&1.provision == "1" and &1.section_type == "article"))
      assert reg1.section_id == "UK_uksi_2024_100:reg.1"
    end

    test "sub_articles use reg.X(Y) citation", %{rows: rows} do
      sub = Enum.find(rows, &(&1.section_type == "sub_article" and &1.sub == "1"))
      assert sub.section_id == "UK_uksi_2024_100:reg.2(1)"
    end

    test "paragraphs use reg.X(Y)(Z) citation", %{rows: rows} do
      paras = Enum.filter(rows, &(&1.section_type == "paragraph"))
      assert length(paras) == 2

      p_a = Enum.find(paras, &(&1.paragraph == "a"))
      assert p_a.section_id == "UK_uksi_2024_100:reg.3(1)(a)"
    end

    test "emits signed section", %{rows: rows} do
      signed = Enum.find(rows, &(&1.section_type == "signed"))
      assert signed != nil
      assert String.contains?(signed.text, "Secretary of State")
    end

    test "uses article/sub_article section_types", %{rows: rows} do
      types = Enum.map(rows, & &1.section_type) |> Enum.uniq() |> Enum.sort()
      assert "article" in types
      assert "sub_article" in types
      refute "section" in types
      refute "sub_section" in types
    end

    test "extent from root is E+W+S", %{rows: rows} do
      for row <- rows do
        assert row.extent_code == "E+W+S"
      end
    end
  end

  # ── Schedules ──────────────────────────────────────────────────

  describe "parse/2 with schedules" do
    setup do
      xml = read_fixture("with_schedules.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_200", type_code: "uksi"})
      %{rows: rows}
    end

    test "emits schedule rows", %{rows: rows} do
      schedules = Enum.filter(rows, &(&1.section_type == "schedule"))
      assert length(schedules) == 2
      assert Enum.at(schedules, 0).section_id == "UK_uksi_2024_200:sch.1"
      assert Enum.at(schedules, 1).section_id == "UK_uksi_2024_200:sch.2"
    end

    test "schedule paragraphs use sch.N.reg.X citation", %{rows: rows} do
      sch1_articles = Enum.filter(rows, &(&1.schedule == "1" and &1.section_type == "article"))
      assert length(sch1_articles) == 2

      first = Enum.at(sch1_articles, 0)
      assert first.section_id == "UK_uksi_2024_200:sch.1.reg.1"
    end

    test "schedule sub_articles have correct citation", %{rows: rows} do
      sub = Enum.find(rows, &(&1.schedule == "1" and &1.section_type == "sub_article"))
      assert sub.section_id == "UK_uksi_2024_200:sch.1.reg.2(1)"
    end

    test "schedule extent overrides root", %{rows: rows} do
      sch2 = Enum.find(rows, &(&1.section_id == "UK_uksi_2024_200:sch.2"))
      assert sch2.extent_code == "E+W"
    end

    test "emits table rows from Tabular", %{rows: rows} do
      tables = Enum.filter(rows, &(&1.section_type == "table"))
      assert length(tables) == 1
      assert tables |> hd() |> Map.get(:schedule) == "1"
    end

    test "body article not scoped to schedule", %{rows: rows} do
      body_reg = Enum.find(rows, &(&1.section_type == "article" and &1.schedule == nil))
      assert body_reg.section_id == "UK_uksi_2024_200:reg.1"
    end
  end

  # ── Parallel Extents ───────────────────────────────────────────

  describe "parse/2 with parallel territorial provisions" do
    setup do
      xml = read_fixture("parallel_extents.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_50", type_code: "ukpga"})
      %{rows: rows}
    end

    test "section 23 appears twice with extent qualifiers", %{rows: rows} do
      s23s = Enum.filter(rows, &(&1.provision == "23" and &1.section_type == "section"))
      assert length(s23s) == 2

      ids = Enum.map(s23s, & &1.section_id) |> Enum.sort()
      assert "UK_ukpga_2024_50:s.23[E+W+S]" in ids
      assert "UK_ukpga_2024_50:s.23[NI]" in ids
    end

    test "sub_sections also get extent qualifiers", %{rows: rows} do
      s23_1s = Enum.filter(rows, &(&1.provision == "23" and &1.sub == "1"))
      assert length(s23_1s) == 2

      ids = Enum.map(s23_1s, & &1.section_id) |> Enum.sort()
      assert "UK_ukpga_2024_50:s.23(1)[E+W+S]" in ids
      assert "UK_ukpga_2024_50:s.23(1)[NI]" in ids
    end

    test "section 24 has no extent qualifier", %{rows: rows} do
      s24 = Enum.find(rows, &(&1.provision == "24" and &1.section_type == "section"))
      assert s24.section_id == "UK_ukpga_2024_50:s.24"
      refute String.contains?(s24.section_id, "[")
    end

    test "sort_key includes extent suffix for parallel provisions", %{rows: rows} do
      s23_ews = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_50:s.23[E+W+S]"))
      s23_ni = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_50:s.23[NI]"))

      assert String.ends_with?(s23_ews.sort_key, "~E+W+S")
      assert String.ends_with?(s23_ni.sort_key, "~NI")
    end

    test "sort_keys produce correct document order for non-parallel provisions" do
      # Use simple_act fixture (no parallel provisions) for clean sort_key == position check
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})

      sorted_by_key = Enum.sort_by(rows, & &1.sort_key)
      sorted_by_pos = Enum.sort_by(rows, & &1.position)

      assert Enum.map(sorted_by_key, & &1.position) == Enum.map(sorted_by_pos, & &1.position),
             "ORDER BY sort_key should match ORDER BY position"
    end
  end

  # ── Extent inheritance ─────────────────────────────────────────

  describe "parse/2 extent inheritance" do
    test "a provision without its own RestrictExtent inherits its nearest ancestor's (WRA 1991 Part III s.82)" do
      xml = """
      <Legislation RestrictExtent="E+W+S">
      <Primary><Body>
        <Part id="part-III" RestrictExtent="E+W"><Number>Part III</Number>
          <P1group>
            <P1 id="section-82"><Pnumber>82</Pnumber>
              <P2 id="section-82-1"><Pnumber>1</Pnumber><P2para><Text>Classification of waters.</Text></P2para></P2>
            </P1>
          </P1group>
        </Part>
        <P1group>
          <P1 id="section-221" RestrictExtent="E+W+S"><Pnumber>221</Pnumber>
            <P1para><Text>Interpretation.</Text></P1para>
          </P1>
        </P1group>
        <P1group>
          <P1 id="section-222"><Pnumber>222</Pnumber><P1para><Text>Crown application.</Text></P1para></P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1991_57", type_code: "ukpga"})

      by_provision =
        rows |> Enum.filter(& &1.provision) |> Enum.group_by(& &1.provision, & &1.extent_code)

      assert by_provision["82"] |> Enum.uniq() == ["E+W"]
      assert by_provision["221"] |> Enum.uniq() == ["E+W+S"]
      # outside Part III: the document's extent
      assert by_provision["222"] |> Enum.uniq() == ["E+W+S"]
    end
  end

  describe "parse/2 status (#167)" do
    test "Status=Prospective is inherited by descendants; dotted text is repealed; the rest in_force" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group RestrictExtent="E+W+S+N.I." Match="false" Status="Prospective">
          <P1 id="section-10"><Pnumber>10</Pnumber>
            <P2 id="section-10-1"><Pnumber>1</Pnumber><P2para><Text>A person must register.</Text></P2para></P2>
          </P1>
        </P1group>
        <P1group>
          <P1 id="section-11"><Pnumber>11</Pnumber><P1para><Text>. . . . . . . . . . . . . . . . . . . .</Text></P1para></P1>
        </P1group>
        <P1group>
          <P1 id="section-12"><Pnumber>12</Pnumber><P1para><Text>The employer must keep records.</Text></P1para></P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2021_30", type_code: "ukpga"})
      by_id = Map.new(rows, &{&1.section_id, &1.status})

      assert by_id["UK_ukpga_2021_30:s.10"] == "prospective"
      assert by_id["UK_ukpga_2021_30:s.10(1)"] == "prospective"
      assert by_id["UK_ukpga_2021_30:s.11"] == "repealed"
      assert by_id["UK_ukpga_2021_30:s.12"] == "in_force"
      assert Enum.all?(rows, &(&1.status in SertantaiLegal.Scraper.LatStatus.statuses()))
    end

    test "to_insert_maps carries status" do
      [row | _] =
        LatParser.parse(
          ~s(<Legislation><Primary><Body><P1group><P1 id="section-1"><Pnumber>1</Pnumber><P1para><Text>Duty.</Text></P1para></P1></P1group></Body></Primary></Legislation>),
          %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"}
        )

      [map] = LatParser.to_insert_maps([row], Ecto.UUID.generate())
      assert map.status == "in_force"
    end
  end

  # ── Skip Elements ──────────────────────────────────────────────

  describe "parse/2 skips amendment blocks" do
    test "BlockAmendment content is not parsed" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>Main section text.</Text>
              <BlockAmendment>
                <P1 id="section-99"><Pnumber>99</Pnumber>
                  <P1para><Text>Amended text from another law.</Text></P1para>
                </P1>
              </BlockAmendment>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      provisions = Enum.map(rows, & &1.provision) |> Enum.reject(&is_nil/1)

      assert "1" in provisions
      refute "99" in provisions
    end

    test "Versions content is not parsed" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para><Text>Main text.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      <Versions>
        <Version id="v001">
          <P1group>
            <P1 id="section-1-v"><Pnumber>1</Pnumber>
              <P1para><Text>Version text.</Text></P1para>
            </P1>
          </P1group>
        </Version>
      </Versions>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      sections = Enum.filter(rows, &(&1.section_type == "section"))
      assert length(sections) == 1
    end
  end

  # ── Commentary Counting & Refs ───────────────────────────────────

  describe "commentary ref counting and collection" do
    test "counts F-prefixed refs as amendments" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1">
            <Pnumber><CommentaryRef Ref="F1"/><CommentaryRef Ref="F2"/>1</Pnumber>
            <P1para>
              <Text><CommentaryRef Ref="F3"/>Some text <CommentaryRef Ref="C1"/>here.</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.amendment_count == 3
      assert section.modification_count == 1
      assert section.commencement_count == nil
      assert section.extent_count == nil
    end

    test "collects raw commentary ref IDs per row" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1">
            <Pnumber>1</Pnumber>
            <P1para>
              <Text><CommentaryRef Ref="F1"/><CommentaryRef Ref="key-abc"/>text</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert "F1" in section.commentary_refs
      assert "key-abc" in section.commentary_refs
      assert length(section.commentary_refs) == 2
    end

    test "rows without CommentaryRef have empty commentary_refs list" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1">
            <Pnumber>1</Pnumber>
            <P1para><Text>No commentary refs here.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.commentary_refs == []
    end
  end

  describe "commentary refs with hash-style IDs and Commentaries block" do
    test "hash-style ref IDs are classified via Commentaries Type attribute" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1">
            <Pnumber><CommentaryRef Ref="c7375871"/><CommentaryRef Ref="key-abc123"/>1</Pnumber>
            <P1para><Text>Some text.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      <Commentaries>
        <Commentary id="c7375871" Type="F">
          <Para><Text>S. 1 repealed by Example Act 2020</Text></Para>
        </Commentary>
        <Commentary id="key-abc123" Type="C">
          <Para><Text>S. 1 modified by SI 2021/100</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1962_58", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      # Hash-style refs classified via Commentaries block
      assert section.amendment_count == 1
      assert section.modification_count == 1
      assert "c7375871" in section.commentary_refs
      assert "key-abc123" in section.commentary_refs
    end

    test "mixed prefix and hash-style refs both classified correctly" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1">
            <Pnumber><CommentaryRef Ref="F1"/><CommentaryRef Ref="key-xyz"/>1</Pnumber>
            <P1para><Text>Some text.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      <Commentaries>
        <Commentary id="F1" Type="F">
          <Para><Text>Amendment note</Text></Para>
        </Commentary>
        <Commentary id="key-xyz" Type="I">
          <Para><Text>Commencement note</Text></Para>
        </Commentary>
      </Commentaries>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.amendment_count == 1
      assert section.commencement_count == 1
    end
  end

  describe "commentary refs in simple_act fixture" do
    setup do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      %{rows: rows}
    end

    test "section 3 has F1 and C1 refs", %{rows: rows} do
      s3 = Enum.find(rows, &(&1.provision == "3" and &1.section_type == "section"))
      assert "F1" in s3.commentary_refs
      assert "C1" in s3.commentary_refs
    end

    test "section 1 has no commentary refs", %{rows: rows} do
      s1 = Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1"))
      assert s1.commentary_refs == []
    end
  end

  # ── to_insert_maps/1 ──────────────────────────────────────────

  describe "to_insert_maps/2" do
    @test_law_id "00000000-0000-0000-0000-000000000001"

    test "produces maps with all required columns" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      insert_maps = LatParser.to_insert_maps(rows, @test_law_id)

      required_keys =
        ~w(section_id law_name law_id section_type part chapter heading_group schedule
           provision paragraph sub_paragraph extent_code sort_key position
           depth hierarchy_path text language amendment_count modification_count
           commencement_count extent_count editorial_count created_at updated_at)a

      for map <- insert_maps do
        for key <- required_keys do
          assert Map.has_key?(map, key), "Missing key: #{key}"
        end
      end
    end

    test "includes law_id in every row" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      insert_maps = LatParser.to_insert_maps(rows, @test_law_id)
      {:ok, expected_binary} = Ecto.UUID.dump(@test_law_id)

      for map <- insert_maps do
        assert map.law_id == expected_binary
      end
    end

    test "includes timestamps" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      [first | _] = LatParser.to_insert_maps(rows, @test_law_id)

      assert %DateTime{} = first.created_at
      assert %DateTime{} = first.updated_at
    end

    test "strips internal fields including commentary_refs" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      [first | _] = LatParser.to_insert_maps(rows, @test_law_id)

      refute Map.has_key?(first, :element)
      refute Map.has_key?(first, :citation)
      refute Map.has_key?(first, :commentary_refs)
    end
  end

  # ── Structural Text Extraction ────────────────────────────────

  describe "structural text extraction" do
    test "Part rows get title-only text, not child section text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <Part id="part-I">
          <Number>Part I</Number>
          <Title>General Provisions</Title>
          <Pblock>
            <Title>Preliminary</Title>
            <P1group>
              <P1 id="section-1"><Pnumber>1</Pnumber>
                <P1para><Text>This is section one text about safety.</Text></P1para>
              </P1>
              <P1 id="section-2"><Pnumber>2</Pnumber>
                <P1para><Text>This is section two text about duties.</Text></P1para>
              </P1>
            </P1group>
          </Pblock>
        </Part>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      part = Enum.find(rows, &(&1.section_type == "part"))

      assert part.text == "General Provisions"
      refute String.contains?(part.text || "", "safety")
      refute String.contains?(part.text || "", "duties")
    end

    test "Chapter rows get title-only text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <Part id="part-I">
          <Number>Part I</Number>
          <Title>Part Title</Title>
          <Chapter id="chapter-1">
            <Number>Chapter 1</Number>
            <Title>Chapter Title</Title>
            <P1group>
              <P1 id="section-1"><Pnumber>1</Pnumber>
                <P1para><Text>Chapter section text.</Text></P1para>
              </P1>
            </P1group>
          </Chapter>
        </Part>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      chapter = Enum.find(rows, &(&1.section_type == "chapter"))

      assert chapter.text == "Chapter Title"
      refute String.contains?(chapter.text || "", "Chapter section text")
    end

    test "Schedule rows get title-only text" do
      xml = """
      <Legislation RestrictExtent="E+W+S">
      <Secondary><Body>
        <P1group>
          <P1 id="reg-1"><Pnumber>1</Pnumber>
            <P1para><Text>Body text.</Text></P1para>
          </P1>
        </P1group>
      </Body></Secondary>
      <Schedules>
        <Schedule id="schedule-1">
          <Number>SCHEDULE 1</Number>
          <Title>Schedule Title</Title>
          <ScheduleBody>
            <P1group>
              <P1 id="sch1-reg-1"><Pnumber>1</Pnumber>
                <P1para><Text>Schedule provision text.</Text></P1para>
              </P1>
            </P1group>
          </ScheduleBody>
        </Schedule>
      </Schedules>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      schedule = Enum.find(rows, &(&1.section_type == "schedule"))

      assert schedule.text == "Schedule Title"
      refute String.contains?(schedule.text || "", "Schedule provision text")
    end

    test "Part with direct introductory Para preserves that text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <Part id="part-I">
          <Number>Part I</Number>
          <Title>General Provisions</Title>
          <Para><Text>This Part applies to England and Wales only.</Text></Para>
          <Pblock>
            <Title>Main duties</Title>
            <P1group>
              <P1 id="section-1"><Pnumber>1</Pnumber>
                <P1para><Text>Section text.</Text></P1para>
              </P1>
            </P1group>
          </Pblock>
        </Part>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      part = Enum.find(rows, &(&1.section_type == "part"))

      assert String.contains?(part.text, "General Provisions")
      assert String.contains?(part.text, "This Part applies to England and Wales only.")
      refute String.contains?(part.text, "Section text")
    end

    test "Part with no child provisions keeps full text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <Part id="part-I">
          <Number>Part I</Number>
          <Title>Interpretation</Title>
          <Para><Text>In this Act, the following definitions apply.</Text></Para>
        </Part>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      part = Enum.find(rows, &(&1.section_type == "part"))

      # No child P1/P2/Pblock — should get full text
      assert String.contains?(part.text, "following definitions apply")
    end

    test "section (P1) with sub_sections only gets direct text, not child text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>This section introduces the main duties.</Text>
              <P2 id="section-1-1"><Pnumber>1</Pnumber>
                <P2para><Text>Every employer shall ensure safety.</Text></P2para>
              </P2>
              <P2 id="section-1-2"><Pnumber>2</Pnumber>
                <P2para><Text>Every employee shall cooperate.</Text></P2para>
              </P2>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))
      subs = Enum.filter(rows, &(&1.section_type == "sub_section"))

      # Section should only have its direct intro text
      assert section.text == "This section introduces the main duties."
      refute String.contains?(section.text || "", "employer")
      refute String.contains?(section.text || "", "employee")

      # Sub_sections should have their own text
      assert length(subs) == 2
      assert Enum.any?(subs, &String.contains?(&1.text, "employer"))
      assert Enum.any?(subs, &String.contains?(&1.text, "employee"))
    end

    test "sub_section (P2) with paragraphs only gets direct text" do
      # P2 numbers (1,2) differ from P1 (2) → not a wrapper, sub_section emitted
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-2"><Pnumber>2</Pnumber>
            <P1para>
              <P2 id="section-2-1"><Pnumber>1</Pnumber>
                <P2para>
                  <Text>The duties include—</Text>
                  <P3 id="section-2-1-a"><Pnumber>a</Pnumber>
                    <P3para><Text>maintaining safe equipment;</Text></P3para>
                  </P3>
                  <P3 id="section-2-1-b"><Pnumber>b</Pnumber>
                    <P3para><Text>providing adequate training.</Text></P3para>
                  </P3>
                </P2para>
              </P2>
              <P2 id="section-2-2"><Pnumber>2</Pnumber>
                <P2para><Text>The employer shall review these duties.</Text></P2para>
              </P2>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      sub = Enum.find(rows, &(&1.section_type == "sub_section"))
      paras = Enum.filter(rows, &(&1.section_type == "paragraph"))

      # Sub_section should only have its intro text
      assert sub.text == "The duties include—"
      refute String.contains?(sub.text || "", "equipment")
      refute String.contains?(sub.text || "", "training")

      # Paragraphs should have their own text
      assert length(paras) == 2
    end

    test "section without sub_sections keeps full text" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para><Text>This Act may be cited as the Example Act 2024.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      # No P2 children — full text preserved
      assert section.text == "This Act may be cited as the Example Act 2024."
    end
  end

  # ── Inline Element Text Order ────────────────────────────────

  # Lists: text in document order, each Text once, separated by spaces.
  # Regression for a bug that went unnoticed in the corpus (2026-10-07): text
  # was built as every Para then every Text, so a chapeau moved to the end,
  # nested list items were repeated, and items ran together ("andany").
  describe "list text order, duplication and spacing" do
    defp text_of(rows, id), do: Enum.find(rows, &(&1.section_id == id)).text

    defp si(body) do
      xml = """
      <Legislation RestrictExtent="E+W+S"><Secondary><Body>
        <P1group><P1 id="regulation-2"><Pnumber>2</Pnumber><P1para>
          <P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para>#{body}</P2para></P2>
        </P1para></P1></P1group>
      </Body></Secondary></Legislation>
      """

      xml
      |> LatParser.parse(%{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      |> text_of("UK_uksi_2024_1:reg.2(1)")
    end

    test "chapeau, then list items in order, each once, space-separated" do
      text =
        si("""
        <Text>Every employer shall—</Text>
        <UnorderedList><ListItem><Para><Text>keep records;</Text></Para></ListItem>
        <ListItem><Para><Text>review them.</Text></Para></ListItem></UnorderedList>
        """)

      assert text == "Every employer shall— keep records; review them."
    end

    test "a nested list appears once, inside its item, in order" do
      text =
        si("""
        <Text>In these Regulations—</Text>
        <UnorderedList Class="Definition">
          <ListItem><Para><Text>“mine” means a mine;</Text></Para></ListItem>
          <ListItem><Para><Text>“workplace” means premises, and includes—</Text>
            <OrderedList><ListItem><Para><Text>any place; and</Text></Para></ListItem>
            <ListItem><Para><Text>any room.</Text></Para></ListItem></OrderedList>
          </Para></ListItem>
        </UnorderedList>
        """)

      assert text ==
               "In these Regulations— “mine” means a mine; “workplace” means premises, and includes— any place; and any room."
    end

    test "text after a list (continuation) follows the list" do
      text =
        si("""
        <Text>Where a person—</Text>
        <OrderedList><ListItem><Para><Text>is employed,</Text></Para></ListItem></OrderedList>
        <Text>that person shall comply.</Text>
        """)

      assert text == "Where a person— is employed, that person shall comply."
    end

    test "real CLML: Workplace Regulations 1992 reg.2(1)" do
      rows =
        "uksi_1992_3004_reg2.xml"
        |> read_fixture()
        |> LatParser.parse(%{law_name: "UK_uksi_1992_3004", type_code: "uksi"})

      text = text_of(rows, "UK_uksi_1992_3004:reg.2(1)")

      assert String.starts_with?(
               text,
               "In these Regulations, unless the context otherwise requires—"
             )

      for phrase <- [
            "any place within the premises to which such person has access while at work; and",
            "any room, lobby, corridor, staircase, road or other place used as a means of access",
            "“workplace” means, subject to paragraph (2)"
          ] do
        assert count(text, phrase) == 1, "#{phrase} should appear exactly once"
      end

      # LH-03: numbered list items keep their numbers
      assert text =~ "while at work; and (b) any room"
      refute text =~ "andany"
      # definitions in document order
      positions =
        Enum.map(
          ["“mine”", "“new workplace”", "“traffic route”", "“workplace” means"],
          &position(text, &1)
        )

      assert positions == Enum.sort(positions)
    end

    test "real CLML: HSWA 1974 s.4(1) — chapeau, then the continuation after the list, marked" do
      rows =
        "ukpga_1974_37_s4.xml"
        |> read_fixture()
        |> LatParser.parse(%{law_name: "UK_ukpga_1974_37", type_code: "ukpga"})

      # (a) and (b) are their own rows; the parent keeps its chapeau and the
      # words after them, with " … " where the child provisions sit
      assert text_of(rows, "UK_ukpga_1974_37:s.4(1)") ==
               "This section has effect for imposing on persons duties in relation to those who— … and applies to premises so made available and other non-domestic premises used in connection with them."

      assert text_of(rows, "UK_ukpga_1974_37:s.4(1)(a)") == "are not their employees; but"
    end

    defp count(text, phrase), do: length(String.split(text, phrase)) - 1

    defp position(text, phrase) do
      {pos, _} = :binary.match(text, phrase)
      pos
    end
  end

  # #174: legislation.gov.uk sometimes places a definition list or closing
  # words as a SIBLING after a subsection (inside the section's P1para), not
  # inside it. Content after a child whose lead-in is open (ends in a dash or
  # colon) belongs to that child; after a closed child it stays the parent's
  # continuation (HSWA s.4(1), above).
  describe "sibling content after an open subsection (#174)" do
    defp rows_of(fixture, law, type) do
      fixture |> read_fixture() |> LatParser.parse(%{law_name: law, type_code: type})
    end

    defp txt(rows, id), do: Enum.find(rows, &(&1.section_id == id)).text

    test "WSI 2005/1806 reg.5: the definitions list belongs to reg.5(1), not reg.5" do
      rows = rows_of("wsi_2005_1806_reg5.xml", "UK_wsi_2005_1806", "wsi")

      assert String.starts_with?(
               txt(rows, "UK_wsi_2005_1806:reg.5(1)"),
               "In these Regulations— “the 1990 Act” (“Deddf 1990”) means the Environmental Protection Act 1990"
             )

      refute (txt(rows, "UK_wsi_2005_1806:reg.5") || "") =~ "the 1990 Act"
    end

    test "CAA 1982 s.44: the closing words after (6) belong to s.44(6), not s.44" do
      rows = rows_of("ukpga_1982_16_s44.xml", "UK_ukpga_1982_16", "ukpga")
      s44_6 = txt(rows, "UK_ukpga_1982_16:s.44(6)")

      assert String.starts_with?(
               s44_6,
               "Where any land is damaged in the exercise of any power of entry conferred by any such order, then— … shall pay such compensation"
             )

      refute (txt(rows, "UK_ukpga_1982_16:s.44") || "") =~ "shall pay such compensation"
      # (a)–(c) stay their own rows
      assert txt(rows, "UK_ukpga_1982_16:s.44(6)(a)") =~ "if the relevant authority"
    end

    test "SI 2010/93 reg.7: each closing text goes to the subsection it follows, (5) and (6)" do
      rows = rows_of("uksi_2010_93_reg7.xml", "UK_uksi_2010_93", "uksi")

      assert txt(rows, "UK_uksi_2010_93:reg.7(5)") =~ "where— … any continuous weeks"
      assert txt(rows, "UK_uksi_2010_93:reg.7(6)") =~ " … for the period that is covered"
      refute (txt(rows, "UK_uksi_2010_93:reg.7") || "") =~ "any continuous weeks"
      refute txt(rows, "UK_uksi_2010_93:reg.7(5)") =~ "for the period that is covered"
    end

    test "the lead-in is the first text: a subsection whose own list follows its open lead-in still takes the sibling (PUWER 1998 reg.2(1))" do
      xml = """
      <Legislation RestrictExtent="E+W+S"><Secondary><Body>
        <P1group><P1 id="regulation-2"><Pnumber>2</Pnumber><P1para>
          <P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para>
            <Text>In these Regulations, unless the context otherwise requires—</Text>
            <UnorderedList><ListItem><Para><Text>“use” means any activity;</Text></Para></ListItem>
            <ListItem><Para><Text>“work equipment” means any machinery.</Text></Para></ListItem></UnorderedList>
          </P2para></P2>
          <Text>and related expressions shall be construed accordingly.</Text>
          <P2 id="regulation-2-2"><Pnumber>2</Pnumber><P2para><Text>Any reference to an employer includes a self-employed person.</Text></P2para></P2>
        </P1para></P1></P1group>
      </Body></Secondary></Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_1998_2306", type_code: "uksi"})

      assert txt(rows, "UK_uksi_1998_2306:reg.2(1)") ==
               "In these Regulations, unless the context otherwise requires— “use” means any activity; “work equipment” means any machinery. and related expressions shall be construed accordingly."

      assert txt(rows, "UK_uksi_1998_2306:reg.2") in [nil, ""]
    end

    test "content after a closed subsection stays on the parent" do
      xml = """
      <Legislation RestrictExtent="E+W+S"><Primary><Body>
        <P1group><P1 id="section-9"><Pnumber>9</Pnumber><P1para>
          <P2 id="section-9-1"><Pnumber>1</Pnumber><P2para><Text>A person must keep records.</Text></P2para></P2>
          <Text>This section applies in England only.</Text>
        </P1para></P1></P1group>
      </Body></Primary></Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_9", type_code: "ukpga"})

      assert txt(rows, "UK_ukpga_2024_9:s.9(1)") == "A person must keep records."
      assert txt(rows, "UK_ukpga_2024_9:s.9") =~ "This section applies in England only."
    end
  end

  describe "inline element text extraction" do
    test "Term element text appears in correct position within quotes" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-4"><Pnumber>4</Pnumber>
            <P1para>
              <P2 id="section-4-3"><Pnumber>3</Pnumber>
                <P2para>
                  <Text>&#x201C;<Term id="term-part-3-service">Part 3 service</Term>&#x201D; means a regulated user-to-user service or a regulated search service.</Text>
                </P2para>
              </P2>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2023_50", type_code: "ukpga"})
      sub = Enum.find(rows, &(&1.section_type == "sub_section"))

      assert sub != nil
      # The defined term should appear between the quotes, not displaced
      assert String.contains?(sub.text, "Part 3 service")
      assert String.contains?(sub.text, "means a regulated")
      # Term should be between the quote marks (allowing for smart quotes)
      refute Regex.match?(~r/["\N{U+201C}]\s*["\N{U+201D}]/u, sub.text),
             "Quotes should not be empty — Term text should be between them"
    end

    test "Addition element text appears in correct position" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>The <Addition>inserted words</Addition> apply to this section.</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert String.contains?(section.text, "inserted words")
      # "inserted words" should appear between "The" and "apply"
      assert Regex.match?(~r/The.*inserted words.*apply/, section.text)
    end

    test "Substitution element text appears in correct position" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>The <Substitution>new text</Substitution> replaces the original.</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert Regex.match?(~r/The.*new text.*replaces/, section.text)
    end

    test "multiple inline elements preserve order" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>&#x201C;<Term id="t1">Part 3</Term>&#x201D; means a <Addition>regulated</Addition> service.</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert String.contains?(section.text, "Part 3")
      assert String.contains?(section.text, "regulated")
      # Verify order: Part 3 before regulated before service
      assert Regex.match?(~r/Part 3.*regulated.*service/, section.text)
    end

    test "Repeal element text preserved in position" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para>
              <Text>Section <Repeal>5 of the 1974 Act</Repeal> is hereby repealed.</Text>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert Regex.match?(~r/Section.*5 of the 1974 Act.*repealed/, section.text)
    end
  end

  # ── EU Regulation ─────────────────────────────────────────────

  describe "parse/2 with EU Regulation (EUTitle + EUChapter)" do
    setup do
      xml = read_fixture("simple_eu_regulation.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_eur_2024_100", type_code: "eur"})
      %{rows: rows}
    end

    test "produces rows from EURetained/EUBody structure", %{rows: rows} do
      assert length(rows) > 0
    end

    test "all section_ids are unique", %{rows: rows} do
      ids = Enum.map(rows, & &1.section_id)
      assert length(ids) == length(Enum.uniq(ids))
    end

    test "EUTitle maps to part in hierarchy", %{rows: rows} do
      parts = Enum.filter(rows, &(&1.section_type == "part"))
      assert length(parts) == 2

      title_i = Enum.find(parts, &(&1.part == "I"))
      assert title_i != nil
      assert title_i.text == "GENERAL ISSUES"

      title_ii = Enum.find(parts, &(&1.part == "II"))
      assert title_ii != nil
      assert title_ii.text == "EVALUATION"
    end

    test "EUChapter maps to chapter in hierarchy", %{rows: rows} do
      chapters = Enum.filter(rows, &(&1.section_type == "chapter"))
      assert length(chapters) == 2

      ch1 = Enum.find(chapters, &(&1.chapter == "1"))
      assert ch1 != nil
      assert ch1.text == "Aim, scope and definitions"
      assert ch1.part == "I"
    end

    test "uses article/sub_article mode (not section)", %{rows: rows} do
      types = Enum.map(rows, & &1.section_type) |> Enum.uniq()
      assert "article" in types
      assert "sub_article" in types
      refute "section" in types
      refute "sub_section" in types
    end

    test "articles use art. prefix in section_id", %{rows: rows} do
      art1 = Enum.find(rows, &(&1.provision == "Article 1" and &1.section_type == "article"))
      assert art1 != nil
      assert String.contains?(art1.section_id, "art.")
    end

    test "sub_articles nest under articles", %{rows: rows} do
      subs = Enum.filter(rows, &(&1.section_type == "sub_article"))
      assert length(subs) >= 2

      sub1 = Enum.find(subs, &(&1.provision == "Article 1" and &1.sub == "1"))
      assert sub1 != nil
      assert String.contains?(sub1.text, "high level of protection")
    end

    test "paragraphs nest under sub_articles", %{rows: rows} do
      paras = Enum.filter(rows, &(&1.section_type == "paragraph"))
      assert length(paras) == 2

      para_a = Enum.find(paras, &(&1.paragraph == "a"))
      assert para_a != nil
      assert String.contains?(para_a.text, "radioactive")
    end

    test "articles in Title II have correct part context", %{rows: rows} do
      art4 = Enum.find(rows, &(&1.provision == "Article 4"))
      assert art4 != nil
      assert art4.part == "II"
      assert String.contains?(art4.text, "evaluate all registrations")
    end

    test "emits signed section", %{rows: rows} do
      signed = Enum.find(rows, &(&1.section_type == "signed"))
      assert signed != nil
      assert String.contains?(signed.text, "Brussels")
    end

    test "positions are sequential", %{rows: rows} do
      positions = Enum.map(rows, & &1.position)
      assert positions == Enum.to_list(1..length(rows))
    end

    test "extent propagates from root", %{rows: rows} do
      for row <- rows do
        assert row.extent_code == "E+W+S+NI"
      end
    end
  end

  # ── EU Directive ─────────────────────────────────────────────

  describe "parse/2 with EU Directive (EUChapter only, no EUTitle)" do
    setup do
      xml = read_fixture("simple_eu_directive.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_eudr_2024_50", type_code: "eudr"})
      %{rows: rows}
    end

    test "produces rows without EUTitle", %{rows: rows} do
      assert length(rows) > 0
    end

    test "chapters have no part context (no EUTitle)", %{rows: rows} do
      chapters = Enum.filter(rows, &(&1.section_type == "chapter"))
      assert length(chapters) == 2

      for ch <- chapters do
        assert ch.part == nil
      end
    end

    test "articles use article/sub_article types", %{rows: rows} do
      types = Enum.map(rows, & &1.section_type) |> Enum.uniq()
      assert "article" in types
      assert "sub_article" in types
    end

    test "article 2 has two sub_articles", %{rows: rows} do
      art2_subs =
        Enum.filter(rows, &(&1.provision == "Article 2" and &1.section_type == "sub_article"))

      assert length(art2_subs) == 2
    end

    test "chapter II article has correct chapter context", %{rows: rows} do
      art3 = Enum.find(rows, &(&1.provision == "Article 3"))
      assert art3 != nil
      assert art3.chapter == "II"
      assert String.contains?(art3.text, "permit")
    end

    test "all section_ids are unique", %{rows: rows} do
      ids = Enum.map(rows, & &1.section_id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  # ── EU provision mode ────────────────────────────────────────

  describe "provision mode for EU type codes" do
    test "eur uses article/sub_article" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <EURetained><EUBody>
        <P1group><P1 id="a-1"><Pnumber>Article 1</Pnumber>
          <P1para><P2 id="a-1-1"><Pnumber>1</Pnumber><P2para><Text>T</Text></P2para></P2></P1para>
        </P1></P1group>
      </EUBody></EURetained>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_eur_2024_1", type_code: "eur"})
      types = Enum.map(rows, & &1.section_type)
      assert "article" in types
      assert "sub_article" in types
    end

    test "eudr uses article/sub_article" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <EURetained><EUBody>
        <P1group><P1 id="a-1"><Pnumber>Article 1</Pnumber>
          <P1para><Text>Directive text.</Text></P1para>
        </P1></P1group>
      </EUBody></EURetained>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_eudr_2024_1", type_code: "eudr"})
      types = Enum.map(rows, & &1.section_type)
      assert "article" in types
      refute "section" in types
    end

    test "eudn uses article/sub_article" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <EURetained><EUBody>
        <P1group><P1 id="a-1"><Pnumber>Article 1</Pnumber>
          <P1para><Text>Decision text.</Text></P1para>
        </P1></P1group>
      </EUBody></EURetained>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_eudn_2024_1", type_code: "eudn"})
      types = Enum.map(rows, & &1.section_type)
      assert "article" in types
      refute "section" in types
    end
  end

  # ── to_insert_maps country derivation ────────────────────────

  describe "to_insert_maps/2 country field" do
    @test_law_id "00000000-0000-0000-0000-000000000001"

    test "UK law gets country 'uk'" do
      xml = read_fixture("simple_si.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_100", type_code: "uksi"})
      [first | _] = LatParser.to_insert_maps(rows, @test_law_id)

      assert first.country == "uk"
    end

    test "EU regulation gets country 'uk' (UK_ prefix)" do
      xml = read_fixture("simple_eu_regulation.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_eur_2024_100", type_code: "eur"})
      [first | _] = LatParser.to_insert_maps(rows, @test_law_id)

      assert first.country == "uk"
    end

    test "AU law gets country 'au'" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group><P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><Text>Test.</Text></P1para>
        </P1></P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "AU_act_2024_1", type_code: "act"})
      [first | _] = LatParser.to_insert_maps(rows, @test_law_id)

      assert first.country == "au"
    end
  end

  # ── Diagnostics ──────────────────────────────────────────────

  describe "Diagnostics.validate/1" do
    alias SertantaiLegal.Scraper.LatParser.Diagnostics

    test "clean parse returns {:ok, []}" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})

      assert {:ok, warnings} = Diagnostics.validate(rows)
      # After the fix, structural rows should have small text — no blob errors
      errors = Enum.filter(warnings, &(&1.severity == :error))
      assert errors == []
    end

    test "detects structural blob when Part has large duplicated text" do
      # Simulate a bad parse: Part row with child section text baked in
      bad_rows = [
        %{
          section_id: "TEST:pt.I",
          section_type: "part",
          text: String.duplicate("This is a very long Part text blob. ", 100),
          part: "I",
          chapter: nil,
          schedule: nil,
          heading_group: nil,
          provision: nil,
          sub: nil,
          paragraph: nil,
          sub_paragraph: nil,
          position: 1
        },
        %{
          section_id: "TEST:s.1",
          section_type: "section",
          text: "Section one text.",
          part: "I",
          chapter: nil,
          schedule: nil,
          heading_group: nil,
          provision: "1",
          sub: nil,
          paragraph: nil,
          sub_paragraph: nil,
          position: 2
        }
      ]

      assert {:error, errors} = Diagnostics.validate(bad_rows)
      assert Enum.any?(errors, &(&1.check == :structural_blob))
    end

    test "detects empty leaf provisions (paragraph/sub_paragraph)" do
      rows = [
        %{
          section_id: "TEST:s.1(a)",
          section_type: "paragraph",
          text: nil,
          part: nil,
          chapter: nil,
          schedule: nil,
          heading_group: nil,
          provision: "1",
          sub: nil,
          paragraph: "a",
          sub_paragraph: nil,
          position: 1
        }
      ]

      assert {:ok, warnings} = Diagnostics.validate(rows)
      assert Enum.any?(warnings, &(&1.check == :empty_section))
    end

    test "does NOT flag empty section (may have children via structural dedup)" do
      rows = [
        %{
          section_id: "TEST:s.1",
          section_type: "section",
          text: nil,
          part: nil,
          chapter: nil,
          schedule: nil,
          heading_group: nil,
          provision: "1",
          sub: nil,
          paragraph: nil,
          sub_paragraph: nil,
          position: 1
        }
      ]

      assert {:ok, warnings} = Diagnostics.validate(rows)
      refute Enum.any?(warnings, &(&1.check == :empty_section))
    end

    test "detects missing provisions (structural only, no sections)" do
      rows = [
        %{
          section_id: "TEST:pt.I",
          section_type: "part",
          text: "Part I Title",
          part: "I",
          chapter: nil,
          schedule: nil,
          heading_group: nil,
          provision: nil,
          sub: nil,
          paragraph: nil,
          sub_paragraph: nil,
          position: 1
        }
      ]

      assert {:error, errors} = Diagnostics.validate(rows)
      assert Enum.any?(errors, &(&1.check == :missing_provisions))
    end
  end

  describe "Diagnostics.summary/1" do
    alias SertantaiLegal.Scraper.LatParser.Diagnostics

    test "returns correct metrics for simple act" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      summary = Diagnostics.summary(rows)

      assert summary.total_rows == 13
      assert summary.structural_rows == 2
      assert summary.section_rows > 0
      # After the fix, structural text % should be very small
      assert summary.structural_text_pct < 10.0
    end
  end

  # ── Provision Mode ─────────────────────────────────────────────

  describe "provision mode" do
    test "ukpga uses section/sub_section" do
      # P2 numbers (1,2) differ from P1 (2) → not a wrapper, sub_section emitted
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group><P1 id="s-2"><Pnumber>2</Pnumber>
          <P1para>
            <P2 id="s-2-1"><Pnumber>1</Pnumber><P2para><Text>T1</Text></P2para></P2>
            <P2 id="s-2-2"><Pnumber>2</Pnumber><P2para><Text>T2</Text></P2para></P2>
          </P1para>
        </P1></P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      types = Enum.map(rows, & &1.section_type)
      assert "section" in types
      assert "sub_section" in types
    end

    test "uksi uses article/sub_article" do
      # P2 numbers (1,2) differ from P1 (2) → not a wrapper, sub_article emitted
      xml = """
      <Legislation RestrictExtent="E+W+S">
      <Secondary><Body>
        <P1group><P1 id="r-2"><Pnumber>2</Pnumber>
          <P1para>
            <P2 id="r-2-1"><Pnumber>1</Pnumber><P2para><Text>T1</Text></P2para></P2>
            <P2 id="r-2-2"><Pnumber>2</Pnumber><P2para><Text>T2</Text></P2para></P2>
          </P1para>
        </P1></P1group>
      </Body></Secondary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      types = Enum.map(rows, & &1.section_type)
      assert "article" in types
      assert "sub_article" in types
    end
  end

  # ── Repealed/Revoked Markers ──────────────────────────────────

  describe "repealed/revoked provision markers" do
    test "empty section with F-code refs gets [Repealed] for Acts" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-2"><Pnumber><CommentaryRef Ref="F1"/>2</Pnumber>
            <P1para><Text/></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1962_58", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.text == "[Repealed]"
    end

    test "empty section with F-code refs gets [Revoked] for SIs" do
      xml = """
      <Legislation RestrictExtent="E+W+S">
      <Secondary><Body>
        <P1group>
          <P1 id="reg-3"><Pnumber><CommentaryRef Ref="F5"/>3</Pnumber>
            <P1para><Text/></P1para>
          </P1>
        </P1group>
      </Body></Secondary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2002_100", type_code: "uksi"})
      article = Enum.find(rows, &(&1.section_type == "article"))

      assert article.text == "[Revoked]"
    end

    test "empty section with hash-style ref IDs gets [Repealed]" do
      # Real-world: legislation.gov.uk uses hash IDs like c7375871, not F-prefix
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-2"><Pnumber><CommentaryRef Ref="c7375871"/>2</Pnumber>
            <P1para><Text/></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1962_58", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.text == "[Repealed]"
    end

    test "dots-only heading gets replaced with marker" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <Pblock>
          <Title>. . . . . . . . . . . . . . . . . . . .</Title>
          <P1group>
            <P1 id="section-3"><Pnumber><CommentaryRef Ref="F2"/>3</Pnumber>
              <P1para><Text/></P1para>
            </P1>
          </P1group>
        </Pblock>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1962_58", type_code: "ukpga"})
      heading = Enum.find(rows, &(&1.section_type == "heading"))

      assert heading.text == "[Repealed]"
    end

    test "section with actual text is NOT marked as repealed" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para><Text>This section is in force.</Text></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      assert section.text == "This section is in force."
      refute section.text == "[Repealed]"
    end

    test "section with sub_sections is NOT marked even with empty text and refs" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-4"><Pnumber><CommentaryRef Ref="c123"/>4</Pnumber>
            <P1para>
              <P2 id="section-4-1"><Pnumber>1</Pnumber>
                <P2para><Text>Active sub-section text.</Text></P2para>
              </P2>
            </P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_1962_58", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      # Section has empty direct text (structural extraction) + commentary refs,
      # but has children → should NOT be marked as repealed
      refute section.text == "[Repealed]"
    end

    test "empty section WITHOUT F-code refs is NOT marked" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group>
          <P1 id="section-1"><Pnumber>1</Pnumber>
            <P1para><Text/></P1para>
          </P1>
        </P1group>
      </Body></Primary>
      </Legislation>
      """

      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})
      section = Enum.find(rows, &(&1.section_type == "section"))

      # No amendment refs — should stay empty, not get a marker
      assert section.text == nil or section.text == ""
    end
  end

  # ── Issue #120: P2 wrapper detection ─────────────────────────────

  describe "parse/2 P2 wrapper detection (Issue #120)" do
    setup do
      xml = read_fixture("p2_wrapper_si.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
      %{rows: rows}
    end

    test "reg.30 with P2 wrapper: section_id omits doubled number", %{rows: rows} do
      # P1 Pnumber=30, single P2 Pnumber=30 → wrapper, should produce reg.30 not reg.30(30)
      reg30 = Enum.find(rows, &(&1.provision == "30" && &1.section_type == "article"))
      assert reg30.section_id == "UK_uksi_2024_1:reg.30"
    end

    test "reg.30 paragraphs: section_id uses (a) not (30)(a)", %{rows: rows} do
      # P3 under the wrapper P2 should produce reg.30(a) not reg.30(30)(a)
      para_a =
        Enum.find(rows, fn r ->
          r.provision == "30" && r.paragraph == "a" && r.section_type == "paragraph"
        end)

      assert para_a.section_id == "UK_uksi_2024_1:reg.30(a)"
    end

    test "reg.3 with multiple P2s: subsections are legitimate", %{rows: rows} do
      # P1 Pnumber=3, P2 Pnumbers=1,2,3 → NOT a wrapper, s.3(1) is legitimate
      sub1 =
        Enum.find(rows, fn r ->
          r.provision == "3" && r.sub == "1" && r.section_type == "sub_article"
        end)

      assert sub1.section_id == "UK_uksi_2024_1:reg.3(1)"
    end

    test "reg.3(3) with multiple P2s: provision==sub is legitimate", %{rows: rows} do
      # reg.3(3) is section 3 subsection 3 — NOT a wrapper because P1 has P2s 1,2,3
      sub3 =
        Enum.find(rows, fn r ->
          r.provision == "3" && r.sub == "3" && r.section_type == "sub_article"
        end)

      assert sub3.section_id == "UK_uksi_2024_1:reg.3(3)"
    end

    test "reg.1 with single P2 wrapper: section_id omits doubled number", %{rows: rows} do
      # P1 Pnumber=1, single P2 Pnumber=1 → wrapper
      reg1 = Enum.find(rows, &(&1.provision == "1" && &1.section_type == "article"))
      assert reg1.section_id == "UK_uksi_2024_1:reg.1"
    end

    test "all section_ids use reg. prefix (not art.)", %{rows: rows} do
      articles =
        Enum.filter(rows, &(&1.section_type in ["article", "sub_article", "paragraph"]))

      for row <- articles do
        assert String.contains?(row.section_id, ":reg.") or
                 not String.contains?(row.section_id, ":art."),
               "Expected reg. prefix, got: #{row.section_id}"
      end
    end
  end

  # ── Provision titles (LAT parser coverage II) ──────────────────

  describe "parse/2 title column" do
    defp parse_body(body, type_code \\ "uksi") do
      LatParser.parse(
        "<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>",
        %{law_name: "UK_#{type_code}_2024_1", type_code: type_code}
      )
    end

    defp row(rows, section_id), do: Enum.find(rows, &(&1.section_id == section_id))

    test "a P1group's Title goes on its P1 row; the row text is unchanged" do
      xml = read_fixture("uksi_1992_3004_reg2.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_1992_3004", type_code: "uksi"})

      reg2 = row(rows, "UK_uksi_1992_3004:reg.2")
      assert reg2.title == "Interpretation"
      refute String.contains?(reg2.text || "", "Interpretation")
      # sub-provisions do not repeat the heading
      assert row(rows, "UK_uksi_1992_3004:reg.2(1)").title == nil
    end

    test "every P1 in a multi-provision P1group takes the group title" do
      rows =
        parse_body("""
        <P1group><Title>Fees</Title>
          <P1><Pnumber>3</Pnumber><P1para><Text>A fee.</Text></P1para></P1>
          <P1><Pnumber>4</Pnumber><P1para><Text>Another fee.</Text></P1para></P1>
        </P1group>
        """)

      assert row(rows, "UK_uksi_2024_1:reg.3").title == "Fees"
      assert row(rows, "UK_uksi_2024_1:reg.4").title == "Fees"
    end

    test "a P1 outside a P1group has no title" do
      rows = parse_body(~s(<P1><Pnumber>1</Pnumber><P1para><Text>Bare.</Text></P1para></P1>))
      assert row(rows, "UK_uksi_2024_1:reg.1").title == nil
    end

    test "inline markup in the title joins without stray spaces" do
      rows =
        parse_body("""
        <P1group><Title>Duties of <Substitution ChangeId="x" CommentaryRef="c-1">employers</Substitution><CommentaryRef Ref="c-2"/> and Re<Emphasis>gulators</Emphasis></Title>
          <P1><Pnumber>5</Pnumber><P1para><Text>Duty.</Text></P1para></P1>
        </P1group>
        """)

      assert row(rows, "UK_uksi_2024_1:reg.5").title == "Duties of employers and Regulators"
    end

    test "a dots-only (repealed) title is nil" do
      rows =
        parse_body("""
        <P1group><Title>. . . . . . .</Title>
          <P1><Pnumber>6</Pnumber><P1para><Text>. . .</Text></P1para></P1>
        </P1group>
        """)

      assert row(rows, "UK_uksi_2024_1:reg.6").title == nil
    end

    test "Part and Pblock rows carry their own Title" do
      xml = read_fixture("simple_act.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"})

      assert row(rows, "UK_ukpga_2024_1:pt.I").title == "General Provisions"

      assert rows |> Enum.filter(&(&1.section_type == "heading")) |> Enum.map(& &1.title) ==
               ["Preliminary", "General duties", "Enforcement provisions"]
    end

    test "a Schedule row's text is its TitleBlock title, like a Part's (#165)" do
      xml = read_fixture("with_schedules.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})

      assert rows |> Enum.filter(&(&1.section_type == "schedule")) |> Enum.map(& &1.text) ==
               ["Particulars to be notified", "Minimum welfare facilities"]
    end

    test "a Schedule row takes its TitleBlock title" do
      xml = read_fixture("with_schedules.xml")
      rows = LatParser.parse(xml, %{law_name: "UK_uksi_2024_1", type_code: "uksi"})

      titles =
        rows |> Enum.filter(&(&1.section_type == "schedule")) |> Enum.map(& &1.title)

      assert titles == ["Particulars to be notified", "Minimum welfare facilities"]
    end

    test "a P2group's / P3group's Title goes on the P2 / P3 row it wraps" do
      rows =
        parse_body("""
        <P1group><Title>Duties</Title><P1><Pnumber>7</Pnumber><P1para>
          <P2group><Title>General duty</Title><P2><Pnumber>1</Pnumber><P2para><Text>An employer shall act.</Text></P2para></P2></P2group>
          <P2><Pnumber>2</Pnumber><P2para><Text>No title.</Text>
            <P3group><Title>Exception</Title><P3><Pnumber>a</Pnumber><P3para><Text>unless exempt.</Text></P3para></P3></P3group>
          </P2para></P2>
        </P1para></P1></P1group>
        """)

      assert row(rows, "UK_uksi_2024_1:reg.7").title == "Duties"
      assert row(rows, "UK_uksi_2024_1:reg.7(1)").title == "General duty"
      assert row(rows, "UK_uksi_2024_1:reg.7(2)").title == nil
      assert row(rows, "UK_uksi_2024_1:reg.7(2)(a)").title == "Exception"
    end

    test "to_insert_maps/2 carries the title" do
      rows =
        parse_body("""
        <P1group><Title>Fees</Title><P1><Pnumber>3</Pnumber><P1para><Text>A fee.</Text></P1para></P1></P1group>
        """)

      [map] = LatParser.to_insert_maps(rows, "00000000-0000-0000-0000-000000000001")
      assert map.title == "Fees"
    end
  end

  # xmerl's //text() returns direct text before descendants' text: headings
  # with inline markup came out scrambled (LAT parser coverage II).
  describe "parse/2 heading text keeps document order" do
    @scrambled ~s(Duties of <Substitution ChangeId="x" CommentaryRef="c-1">employers</Substitution><CommentaryRef Ref="c-2"/> and Re<Emphasis>gulators</Emphasis>)

    defp parse_act(body) do
      LatParser.parse(
        "<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>",
        %{law_name: "UK_ukpga_2024_1", type_code: "ukpga"}
      )
    end

    test "a cross-heading (Pblock) row's text" do
      rows =
        parse_act("""
        <Pblock><Title>#{@scrambled}</Title>
          <P1group><P1><Pnumber>1</Pnumber><P1para><Text>Duty.</Text></P1para></P1></P1group>
        </Pblock>
        """)

      heading = Enum.find(rows, &(&1.section_type == "heading"))
      assert heading.text == "Duties of employers and Regulators"
    end

    test "a Part row's text" do
      rows =
        parse_act("""
        <Part><Number>PART 1</Number><Title>#{@scrambled}</Title>
          <P1group><P1><Pnumber>1</Pnumber><P1para><Text>Duty.</Text></P1para></P1></P1group>
        </Part>
        """)

      part = Enum.find(rows, &(&1.section_type == "part"))
      assert part.text == "Duties of employers and Regulators"
    end

    test "a provision number split by an amendment wrapper" do
      rows =
        parse_act("""
        <P1group><Title>T</Title>
          <P1><Pnumber><Addition ChangeId="x">3</Addition>A</Pnumber><P1para><Text>Inserted.</Text></P1para></P1>
        </P1group>
        """)

      assert Enum.any?(rows, &(&1.section_id == "UK_ukpga_2024_1:s.3A"))
    end

    test "a retained territorial repeal and its replacement stay apart" do
      rows =
        parse_act("""
        <Pblock><Title><Repeal ChangeId="k-1" RetainText="true" SubstitutionRef="k-2" Extent="E+W">Powers of Entry</Repeal><Addition ChangeId="k-2" Extent="E+W">Enforcement</Addition></Title>
          <P1group><Title><CommentaryRef Ref="c-1"/><Repeal ChangeId="k-3" RetainText="true" SubstitutionRef="k-4">Designation of Notified Bodies</Repeal><Addition ChangeId="k-4">Approval</Addition></Title>
            <P1><Pnumber>1</Pnumber><P1para><Text>Duty.</Text></P1para></P1>
          </P1group>
        </Pblock>
        """)

      heading = Enum.find(rows, &(&1.section_type == "heading"))
      assert heading.text == "Powers of Entry Enforcement"
      assert heading.title == "Powers of Entry Enforcement"

      assert Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.1")).title ==
               "Designation of Notified Bodies Approval"
    end

    test "a heading split across several Title elements keeps them all" do
      rows =
        parse_act("""
        <Part><Number>Chapter IV</Number><Title> International Oil Pollution</Title><Title>Compensation Fund</Title>
          <P1group><P1><Pnumber>1</Pnumber><P1para><Text>Duty.</Text></P1para></P1></P1group>
        </Part>
        """)

      part = Enum.find(rows, &(&1.section_type == "part"))
      assert part.text == "International Oil Pollution Compensation Fund"
      assert part.title == "International Oil Pollution Compensation Fund"
    end

    test "consecutive retained repeals that are not substitutions join without a space" do
      rows =
        parse_act("""
        <P1group><Title><Repeal RetainText="true"><Substitution> Advisory committees</Substitution></Repeal><Repeal RetainText="true">.</Repeal></Title>
          <P1><Pnumber>37</Pnumber><P1para><Text>Duty.</Text></P1para></P1>
        </P1group>
        """)

      assert Enum.find(rows, &(&1.section_id == "UK_ukpga_2024_1:s.37")).title ==
               "Advisory committees."
    end
  end

  # Notes referenced only by a CommentaryRef attribute (Addition/Substitution/
  # Repeal) or from a P1group's Title had no affected_sections (LAT parser
  # coverage II): 35,353 + 912 notes unplaced.
  describe "parse/2 commentary refs for note placement" do
    defp refs_of(rows, section_id),
      do: rows |> Enum.find(&(&1.section_id == section_id)) |> Map.fetch!(:commentary_refs)

    setup do
      rows =
        LatParser.parse(
          """
          <Legislation><Secondary><Body>
            <P1group><Title>Duties<CommentaryRef Ref="c-title"/></Title>
              <P1><Pnumber><CommentaryRef Ref="c-num"/>2</Pnumber><P1para>
                <P2><Pnumber>1</Pnumber><P2para><Text>An employer shall <Substitution ChangeId="x" CommentaryRef="c-attr">ensure</Substitution> safety.</Text></P2para></P2>
                <P2><Pnumber>2</Pnumber><P2para><Text><Repeal ChangeId="y" CommentaryRef="c-rep">. . .</Repeal></Text></P2para></P2>
              </P1para></P1>
            </P1group>
          </Body></Secondary>
          <Commentaries>
            <Commentary id="c-title" Type="F"><Para><Text>Title substituted</Text></Para></Commentary>
            <Commentary id="c-num" Type="F"><Para><Text>Reg. 2 amended</Text></Para></Commentary>
            <Commentary id="c-attr" Type="F"><Para><Text>Word substituted</Text></Para></Commentary>
            <Commentary id="c-rep" Type="F"><Para><Text>Reg. 2(2) revoked</Text></Para></Commentary>
          </Commentaries></Legislation>
          """,
          %{law_name: "UK_uksi_2024_1", type_code: "uksi"}
        )

      %{rows: rows}
    end

    test "an attribute-only ref places the note on its provision", %{rows: rows} do
      assert "c-attr" in refs_of(rows, "UK_uksi_2024_1:reg.2(1)")
      assert "c-rep" in refs_of(rows, "UK_uksi_2024_1:reg.2(2)")
    end

    test "a P1group Title's ref goes on the P1 row", %{rows: rows} do
      assert "c-title" in refs_of(rows, "UK_uksi_2024_1:reg.2")
    end

    test "attribute and title refs don't change the per-row counts", %{rows: rows} do
      reg2 = Enum.find(rows, &(&1.section_id == "UK_uksi_2024_1:reg.2"))
      # only the <CommentaryRef> element in the Pnumber, as before
      assert reg2.amendment_count == 1
      assert Enum.find(rows, &(&1.section_id == "UK_uksi_2024_1:reg.2(1)")).amendment_count == nil
    end

    test "the notes get affected_sections", %{rows: rows} do
      refs = SertantaiLegal.Scraper.CommentaryParser.build_ref_to_sections(rows)
      assert List.last(refs["c-attr"]) == "UK_uksi_2024_1:reg.2(1)"
      assert List.last(refs["c-title"]) == "UK_uksi_2024_1:reg.2"
    end
  end

  # Repeal RetainText: text repealed but kept — for other territories, or
  # for specified purposes / savings (LAT parser coverage II, item 5).
  describe "parse/2 retained repeals" do
    defp retained_law(body, commentaries) do
      LatParser.parse(
        """
        <Legislation RestrictExtent="E+W+S"><Secondary><Body>#{body}</Body></Secondary>
        <Commentaries>#{commentaries}</Commentaries></Legislation>
        """,
        %{law_name: "UK_uksi_2024_1", type_code: "uksi"}
      )
    end

    defp by_id(rows, id), do: Enum.find(rows, &(&1.section_id == "UK_uksi_2024_1:" <> id))

    @revoked_s ~s|<Commentary id="k-s" Type="F"><Para><Text>Regulations revoked (S.) (1.11.2025) by The Scotland Regulations 2025 (S.S.I. 2025/165)</Text></Para></Commentary>|

    @tag pending: "LR-03"
    test "a provision repealed in one territory (from the note) keeps its text and status" do
      rows =
        retained_law(
          """
          <P1group><Title>Testing</Title><P1><Pnumber><Repeal CommentaryRef="k-s" RetainText="true">3</Repeal></Pnumber><P1para>
            <P2><Pnumber><Repeal CommentaryRef="k-s" RetainText="true">1</Repeal></Pnumber><P2para><Text><Repeal CommentaryRef="k-s" RetainText="true">The sludge shall be tested.</Repeal></Text></P2para></P2>
            <P2><Pnumber>2</Pnumber><P2para><Text><Repeal CommentaryRef="k-s" RetainText="true">Samples</Repeal> <Repeal CommentaryRef="k-s" RetainText="true">shall be kept.</Repeal></Text></P2para></P2>
          </P1para></P1></P1group>
          """,
          @revoked_s
        )

      for id <- ["reg.3", "reg.3(1)", "reg.3(2)"] do
        row = by_id(rows, id)
        assert row.excluded_extent == "S", id
        assert row.status == "in_force", id
      end

      assert by_id(rows, "reg.3(1)").text == "The sludge shall be tested."
    end

    # Q1 (Jason, 2026-10-09; LAT Parser Refactor): attribute and note both count
    @tag pending: "LR-03"
    test "the Repeal's own Extent and its note's territory together" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>4</Pnumber><P1para><Text><Repeal CommentaryRef="k-s" RetainText="true" Extent="E+W">Old rule.</Repeal></Text></P1para></P1></P1group>|,
          @revoked_s
        )

      assert by_id(rows, "reg.4").excluded_extent == "E+W+S"
    end

    @tag pending: "LR-07"
    test "a retained repeal with no territory (savings / purposes) is repealed_saved everywhere" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>5</Pnumber><P1para><Text><Repeal CommentaryRef="k-sv" RetainText="true">Saved rule.</Repeal></Text></P1para></P1></P1group>|,
          ~s|<Commentary id="k-sv" Type="F"><Para><Text>Reg. 5 revoked (15.4.2018) by The Regulations 2018 (S.I. 2018/374) (subject to savings)</Text></Para></Commentary>|
        )

      row = by_id(rows, "reg.5")
      assert row.status == "repealed_saved"
      assert row.excluded_extent == "E+W+S"
    end

    @tag pending: "LR-03"
    test "a Repeal wrapping whole Text elements counts too" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>6</Pnumber><P1para><Repeal CommentaryRef="k-s" RetainText="true"><Text>First.</Text><Text>Second.</Text></Repeal></P1para></P1></P1group>|,
          @revoked_s
        )

      assert by_id(rows, "reg.6").excluded_extent == "S"
    end

    test "some words repealed is not the provision repealed" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>7</Pnumber><P1para><Text>A duty to <Repeal CommentaryRef="k-s" RetainText="true">consult</Repeal> act.</Text></P1para></P1></P1group>|,
          @revoked_s
        )

      assert by_id(rows, "reg.7").excluded_extent == nil
      assert by_id(rows, "reg.7").status == "in_force"
    end

    test "to_insert_maps/2 carries excluded_extent" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>4</Pnumber><P1para><Text><Repeal RetainText="true" Extent="E+W">Old.</Repeal></Text></P1para></P1></P1group>|,
          ""
        )

      [map] = LatParser.to_insert_maps(rows, "00000000-0000-0000-0000-000000000001")
      assert map.excluded_extent == "E+W"
    end

    test "territorial wording: both versions, bracketed by territory" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>8</Pnumber><P1para><Text>being used for <Repeal CommentaryRef="k-f" Extent="S" RetainText="true" SubstitutionRef="k-f-2">fire brigade</Repeal> <Substitution ChangeId="k-f-2" CommentaryRef="k-f" Extent="S">fire and rescue authority</Substitution> purposes</Text></P1para></P1></P1group>|,
          ""
        )

      row = by_id(rows, "reg.8")

      assert row.text ==
               "being used for [S: fire and rescue authority] [E+W: fire brigade] purposes"

      assert row.excluded_extent == nil
    end

    test "a substitution pair with no territory keeps both versions apart, unbracketed" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>9</Pnumber><P1para><Text>within <Repeal RetainText="true" SubstitutionRef="k-g-2">25(a)</Repeal><Addition ChangeId="k-g-2">25</Addition> days</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.9").text == "within 25(a) 25 days"
    end

    test "words repealed in one territory are bracketed with where they still apply" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>10</Pnumber><P1para><Text>A duty to <Repeal RetainText="true" Extent="S">consult</Repeal> act.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.10").text == "A duty to [E+W: consult] act."
    end

    @tag pending: "LR-03"
    test "the territory can come from the repeal's note" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>13</Pnumber><P1para><Text>A duty to <Repeal CommentaryRef="k-s" RetainText="true">consult and</Repeal> act.</Text></P1para></P1></P1group>|,
          @revoked_s
        )

      assert by_id(rows, "reg.13").text == "A duty to [E+W: consult and] act."
    end

    test "nested retained repeals (Firearms Act 1968 s.51A) render once, plain inside" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>15</Pnumber><P1para><Text>Before <Repeal RetainText="true" Extent="S"><Repeal RetainText="true" Extent="S">in relation to Scotland</Repeal> only</Repeal> after.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.15").text == "Before [E+W: in relation to Scotland only] after."
    end

    test "a retained-repeal lead-in still opens its list (EPA 1990 s.25(2))" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>16</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>First.</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text><Repeal RetainText="true" Extent="S">Where—</Repeal></Text><P3><Pnumber>a</Pnumber><P3para><Text>a thing happens,</Text></P3para></P3></P2para></P2><BlockText><Para><Text>that fact is evidence.</Text></Para></BlockText></P1para></P1></P1group>|,
          ""
        )

      # LH-03: the row's own text is all repealed for S → plain, excluded_extent S
      assert by_id(rows, "reg.16(2)").text == "Where— … that fact is evidence."
      assert by_id(rows, "reg.16(2)").excluded_extent == "S"
    end

    test "words inserted for one territory are bracketed with it" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>17</Pnumber><P1para><Text>A duty to <Addition ChangeId="i1" Extent="E+W">promptly</Addition> act.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.17").text == "A duty to [E+W: promptly] act."
    end

    test "an insertion covering the row's whole extent stays plain" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>18</Pnumber><P1para><Text>A duty to <Addition ChangeId="i2" Extent="E+W+S">promptly</Addition> act.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.18").text == "A duty to promptly act."
    end

    test "adjacent brackets for the same territories merge (EPA 1990 s.156(2))" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>19</Pnumber><P1para><Text>as in <Repeal RetainText="true" Extent="E+W">the 1993 Act</Repeal><Repeal RetainText="true" Extent="E+W">, and</Repeal> <Addition ChangeId="i3" Extent="E+W">the Permitting Regulations</Addition> apply.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.19").text ==
               "as in [S: the 1993 Act, and] [E+W: the Permitting Regulations] apply."
    end

    test "a row inserted wholly for a narrower territory: plain text, excluded_extent the rest" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>20</Pnumber><P1para><Text><Addition ChangeId="i4" Extent="E+W">The Executive shall report.</Addition></Text></P1para></P1></P1group>|,
          ""
        )

      row = by_id(rows, "reg.20")
      assert row.text == "The Executive shall report."
      assert row.excluded_extent == "S"
      assert row.status == "in_force"
    end

    test "dotted extents (\"E.W.\") read as extent codes" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>21</Pnumber><P1para><Text>A duty to <Addition ChangeId="i5" Extent="E.W.">promptly</Addition> act.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.21").text == "A duty to [E+W: promptly] act."
    end

    test "markup nested in bracketed words keeps its spacing (TA 1968 s.20)" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>22</Pnumber><P1para><Text>Then <Addition ChangeId="i6" Extent="E+W">the <Repeal RetainText="true" SubstitutionRef="i7">Board</Repeal><Addition ChangeId="i7">Strategic Rail Authority</Addition> shall pay</Addition> now.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.22").text ==
               "Then [E+W: the Board Strategic Rail Authority shall pay] now."
    end

    test "retained words with no territory (purposes / savings) stay plain" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>14</Pnumber><P1para><Text>A duty to <Repeal RetainText="true">consult</Repeal> act.</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.14").text == "A duty to consult act."
    end

    test "old wording split across Repeals with one SubstitutionRef renders once (TCPA 1990 s.247(1)(a))" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>11</Pnumber><P1para><Text>granted under <Repeal ChangeId="r1" RetainText="true" SubstitutionRef="a1">Part III  </Repeal><Repeal ChangeId="r1" RetainText="true" SubstitutionRef="a1"><Addition ChangeId="d29">or section 293A</Addition></Repeal> <Addition ChangeId="a1">Parts 3 or 13</Addition>, or</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.11").text ==
               "granted under Part III or section 293A Parts 3 or 13, or"
    end

    test "old wording spanning a Term (CROW 2000 s.1(3)(a)) loses nothing" do
      rows =
        retained_law(
          ~s|<P1group><P1><Pnumber>12</Pnumber><P1para><Text>the Commons Registration Act 1965 <Repeal ChangeId="r2" RetainText="true" SubstitutionRef="a2">(in this section referred to as “</Repeal><Term><Repeal ChangeId="r2" RetainText="true" SubstitutionRef="a2">the 1965 Act</Repeal></Term><Repeal ChangeId="r2" RetainText="true" SubstitutionRef="a2">”) </Repeal><Addition ChangeId="a2">(but is not coastal margin)</Addition> or land</Text></P1para></P1></P1group>|,
          ""
        )

      assert by_id(rows, "reg.12").text ==
               "the Commons Registration Act 1965 (in this section referred to as “the 1965 Act”) (but is not coastal margin) or land"
    end
  end

  # Amending provisions: the text they insert into another law, quoted
  # «…» with its numbers (Jason, 2026-10-08: legislation.gov.uk applies
  # amendments late, so the amending text is used to update records).
  describe "parse/2 amending text" do
    defp amending(body) do
      LatParser.parse(
        "<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>",
        %{law_name: "UK_uksi_2024_1", type_code: "uksi"}
      )
    end

    defp amended_text(rows, id),
      do: Enum.find(rows, &(&1.section_id == "UK_uksi_2024_1:" <> id)).text

    test "a BlockAmendment is quoted on its row, numbers kept (uksi 2005/1904 reg.2(4))" do
      rows =
        amending(~s|<P1group><P1><Pnumber>2</Pnumber><P1para>
          <P2><Pnumber>4</Pnumber><P2para><Text>After subsection (4) insert—</Text><BlockAmendment TargetClass="primary"><P2><Pnumber>4A</Pnumber><P2para><Text>A person shall not be liable if he proves that—</Text><P3><Pnumber>a</Pnumber><P3para><Text>the card was damaged;</Text></P3para></P3><P3><Pnumber>b</Pnumber><P3para><Text>it was reported.</Text></P3para></P3></P2para></P2></BlockAmendment></P2para></P2>
          <P2><Pnumber>5</Pnumber><P2para><Text>Subsection (7) is amended.</Text></P2para></P2>
        </P1para></P1></P1group>|)

      assert amended_text(rows, "reg.2(4)") ==
               "After subsection (4) insert— «(4A) A person shall not be liable if he proves that— (a) the card was damaged; (b) it was reported.»"

      # the inserted provisions are not rows of this law
      refute Enum.any?(rows, &String.contains?(&1.section_id, "4A"))
      assert amended_text(rows, "reg.2(5)") == "Subsection (7) is amended."
    end

    test "a BlockAmendment after an open child provision goes with that child" do
      rows =
        amending(
          ~s|<P1group><P1><Pnumber>3</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>In regulation 5—</Text>
          <P3><Pnumber>a</Pnumber><P3para><Text>omit paragraph (2);</Text></P3para></P3>
          <P3><Pnumber>b</Pnumber><P3para><Text>after paragraph (k) insert—</Text></P3para></P3>
          <BlockAmendment><P3><Pnumber>l</Pnumber><P3para><Text>a new duty.</Text></P3para></P3></BlockAmendment>
        </P2para></P2></P1para></P1></P1group>|
        )

      assert amended_text(rows, "reg.3(1)(b)") == "after paragraph (k) insert— «(l) a new duty.»"
    end

    test "a quoted section keeps its number and title" do
      rows =
        amending(
          ~s|<P1group><P1><Pnumber>4</Pnumber><P1para><Text>After section 9 insert—</Text><BlockAmendment><P1group><Title>Fees</Title><P1><Pnumber>9A</Pnumber><P1para><Text>A fee is payable.</Text></P1para></P1></P1group></BlockAmendment></P1para></P1></P1group>|
        )

      assert amended_text(rows, "reg.4") == "After section 9 insert— «Fees 9A. A fee is payable.»"
    end
  end

  describe "parse/2 tables" do
    test "a table row holds its cells; its Title goes on the title column (wsi 2021/77 reg.9(2))" do
      rows =
        LatParser.parse(
          ~s|<Legislation><Secondary><Body><P1group><P1><Pnumber>9</Pnumber><P1para><Text>The percentages are—</Text><Tabular Orientation="portrait"><Title>Available percentage</Title><table xmlns="http://www.w3.org/1999/xhtml" cols="2"><thead><tr><th>Type of livestock manure</th><th>Amount of nitrogen</th></tr></thead><tbody><tr><td>Cattle slurry</td><td>40 %</td></tr><tr><td>Pig <Emphasis>slurry</Emphasis></td><td>50 %</td></tr></tbody></table></Tabular></P1para></P1></P1group></Body></Secondary></Legislation>|,
          %{law_name: "UK_wsi_2021_77", type_code: "wsi"}
        )

      table = Enum.find(rows, &(&1.section_type == "table"))

      assert table.text ==
               "Type of livestock manure | Amount of nitrogen; Cattle slurry | 40 %; Pig slurry | 50 %"

      assert table.title == "Available percentage"

      # the table is its own row, not part of the provision's text
      assert Enum.find(rows, &(&1.section_id == "UK_wsi_2021_77:reg.9")).text ==
               "The percentages are—"
    end
  end

  describe "parse/2 signatures" do
    test "a signature row holds the signee (uksi 2019/156)" do
      rows =
        LatParser.parse(
          ~s|<Legislation><Secondary><Body><P1group><P1><Pnumber>1</Pnumber><P1para><Text>Citation.</Text></P1para></P1></P1group><SignedSection><Signatory><Para><Text>Signed by authority of the Secretary of State</Text></Para><Signee><PersonName>Richard Harrington</PersonName><JobTitle> Parliamentary Under Secretary of State</JobTitle><Address><AddressLine> Department of Business, Energy and Industrial Strategy</AddressLine></Address><DateSigned Date="2019-01-31"><DateText/></DateSigned></Signee></Signatory></SignedSection></Body></Secondary></Legislation>|,
          %{law_name: "UK_uksi_2019_156", type_code: "uksi"}
        )

      signed = Enum.find(rows, &(&1.section_type == "signed"))

      assert signed.text ==
               "Signed by authority of the Secretary of State Richard Harrington, Parliamentary Under Secretary of State, Department of Business, Energy and Industrial Strategy, 2019-01-31"
    end
  end

  describe "parse/2 alternative versions" do
    test "a provision's territorial alternative (Versions, AltVersionRefs) is parsed beside it (uksi 1996/1527 reg.33)" do
      rows =
        LatParser.parse(
          ~s|<Legislation RestrictExtent="E+W+S+N.I."><Secondary><Body>
            <P1group AltVersionRefs="v1" RestrictExtent="E+W+N.I."><Title>Bodies eligible</Title><P1 id="regulation-33"><Pnumber>33</Pnumber><P1para><Text>England version.</Text></P1para></P1></P1group>
            <P1group><P1 id="regulation-34"><Pnumber>34</Pnumber><P1para><Text>Next.</Text></P1para></P1></P1group>
          </Body></Secondary>
          <Versions><Version id="v1" Description="S"><P1group RestrictExtent="S"><Title>Bodies eligible</Title><P1 id="regulation-33"><Pnumber>33</Pnumber><P1para><Text>Scotland version.</Text></P1para></P1></P1group></Version>
          <Version id="v2"><Figure><Image ResourceRef="r1"/></Figure></Version></Versions></Legislation>|,
          %{law_name: "UK_uksi_1996_1527", type_code: "uksi"}
        )

      ids = Enum.map(rows, & &1.section_id)
      assert "UK_uksi_1996_1527:reg.33[E+W+NI]" in ids
      assert "UK_uksi_1996_1527:reg.33[S]" in ids

      scot = Enum.find(rows, &(&1.section_id == "UK_uksi_1996_1527:reg.33[S]"))
      assert scot.text == "Scotland version."
      assert scot.extent_code == "S"

      # beside its counterpart, before reg.34
      assert Enum.find_index(ids, &(&1 == "UK_uksi_1996_1527:reg.33[S]")) <
               Enum.find_index(ids, &(&1 == "UK_uksi_1996_1527:reg.34"))

      refute Enum.any?(rows, &(&1.section_type == "figure"))
    end
  end

  test "a version that repeats the body (same extent and text) adds no rows" do
    rows =
      LatParser.parse(
        ~s|<Legislation><Secondary><Body>
          <P1group AltVersionRefs="v1" RestrictExtent="E"><P1 id="regulation-8"><Pnumber>8</Pnumber><P1para><Text>Identical.</Text></P1para></P1></P1group>
        </Body></Secondary>
        <Versions><Version id="v1"><P1group RestrictExtent="E"><P1 id="regulation-8"><Pnumber>8</Pnumber><P1para><Text>Identical.</Text></P1para></P1></P1group></Version></Versions></Legislation>|,
        %{law_name: "UK_uksi_2010_2214", type_code: "uksi"}
      )

    assert Enum.count(rows, &(&1.text == "Identical.")) == 1
  end

  test "a Welsh version holding a P1 marked E is still the Welsh version (uksi 2010/2214 reg.7)" do
    rows =
      LatParser.parse(
        ~s|<Legislation><Secondary><Body>
          <P1group AltVersionRefs="v1" RestrictExtent="E"><P1 id="regulation-7"><Pnumber>7</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Same words.</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>England only.</Text></P2para></P2></P1para></P1></P1group>
        </Body></Secondary>
        <Versions><Version id="v1" Description="W"><P1group RestrictExtent="W"><P1 id="regulation-7" RestrictExtent="E"><Pnumber>7</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Same words.</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>Wales differs.</Text></P2para></P2></P1para></P1></P1group></Version></Versions></Legislation>|,
        %{law_name: "UK_uksi_2010_2214", type_code: "uksi"}
      )

    # LH-02: the version's own extent (W) governs its P1 marked E, so its rows
    # are the Welsh version — same words, tagged [W]; not a duplicate
    same = rows |> Enum.filter(&(&1.text == "Same words.")) |> Enum.map(& &1.section_id)
    assert same == ["UK_uksi_2010_2214:reg.7(1)[E]", "UK_uksi_2010_2214:reg.7(1)[W]"]
    assert Enum.count(rows, &(&1.text == "Wales differs.")) == 1
  end

  # LH-01: a note is placed on the rows that cite it at their own level, not
  # on ancestors that only contain a citing descendant.
  describe "parse/2 note placement at the citing level" do
    setup do
      rows =
        LatParser.parse(
          """
          <Legislation><Primary><Body><P1group><Title>T</Title><P1><Pnumber><CommentaryRef Ref="c-sec"/>46</Pnumber><P1para>
            <P2><Pnumber>3H</Pnumber><P2para><Text><Addition ChangeId="a" CommentaryRef="c-range">First.</Addition></Text></P2para></P2>
            <P2><Pnumber>3I</Pnumber><P2para><Text><Addition ChangeId="b" CommentaryRef="c-range">Second.</Addition></Text></P2para></P2>
            <P2><Pnumber>4</Pnumber><P2para><Text>Plain.</Text></P2para></P2>
          </P1para></P1></P1group></Body></Primary>
          <Commentaries>
            <Commentary id="c-sec" Type="F"><Para><Text>S. 46 inserted (1.1.2020) by x</Text></Para></Commentary>
            <Commentary id="c-range" Type="F"><Para><Text>S. 46(3H)(3I) inserted (18.2.2014) by y</Text></Para></Commentary>
          </Commentaries></Legislation>
          """,
          %{law_name: "UK_ukpga_2008_32", type_code: "ukpga"}
        )

      %{refs: SertantaiLegal.Scraper.CommentaryParser.build_ref_to_sections(rows), rows: rows}
    end

    test "a note cited by sibling provisions is placed on each of them, not their parent", %{
      refs: refs
    } do
      assert refs["c-range"] == ["UK_ukpga_2008_32:s.46(3H)", "UK_ukpga_2008_32:s.46(3I)"]
    end

    test "a note cited on the section's own number is placed on the section only", %{refs: refs} do
      assert refs["c-sec"] == ["UK_ukpga_2008_32:s.46"]
    end

    test "per-row counts still cover the subtree (struct_hash unchanged)", %{rows: rows} do
      s46 = Enum.find(rows, &(&1.section_id == "UK_ukpga_2008_32:s.46"))
      assert s46.amendment_count == 1
    end
  end

  describe "parse/2 identity (LH-02)" do
    test "Acts of Senedd Cymru (asc) and Welsh Measures (mwa) are Acts: s. ids" do
      for type <- ~w(asc mwa) do
        rows =
          LatParser.parse(
            ~s|<Legislation><Primary><Body><P1group><P1 id="section-119"><Pnumber>119</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>A duty.</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>Another.</Text></P2para></P2></P1para></P1></P1group></Body></Primary></Legislation>|,
            %{law_name: "UK_#{type}_2023_3", type_code: type}
          )

        assert Enum.any?(rows, &(&1.section_id == "UK_#{type}_2023_3:s.119(1)")), type

        assert Enum.find(rows, &(&1.section_id == "UK_#{type}_2023_3:s.119(1)")).section_type ==
                 "sub_section"
      end
    end

    test "a child with a narrower extent doesn't qualify its provision (uksi 2017/1047 reg.3)" do
      rows =
        LatParser.parse(
          ~s|<Legislation RestrictExtent="E+W"><Secondary><Body><P1group><P1 id="regulation-3" RestrictExtent="E+W"><Pnumber>3</Pnumber><P1para>
            <P2><Pnumber>2</Pnumber><P2para><Text>Applies to both.</Text></P2para></P2>
            <P2 RestrictExtent="E"><Pnumber>3</Pnumber><P2para><Text>England only.</Text></P2para></P2>
          </P1para></P1></P1group></Body></Secondary></Legislation>|,
          %{law_name: "UK_uksi_2017_1047", type_code: "uksi"}
        )

      ids = Enum.map(rows, & &1.section_id)
      assert "UK_uksi_2017_1047:reg.3(2)" in ids
      assert "UK_uksi_2017_1047:reg.3(3)" in ids
      refute Enum.any?(ids, &String.contains?(&1, "["))
    end

    test "a sub-provision with territorial versions qualifies only that sub-provision" do
      rows =
        LatParser.parse(
          ~s|<Legislation RestrictExtent="E+W+S"><Primary><Body><P1group><P1 id="section-10"><Pnumber>10</Pnumber><P1para>
            <P2 id="section-10-1"><Pnumber>1</Pnumber><P2para><Text>Common.</Text></P2para></P2>
            <P2 id="section-10-2" RestrictExtent="E+W"><Pnumber>2</Pnumber><P2para><Text>E+W wording.</Text></P2para></P2>
            <P2 id="section-10-2" RestrictExtent="S"><Pnumber>2</Pnumber><P2para><Text>S wording.</Text></P2para></P2>
          </P1para></P1></P1group></Body></Primary></Legislation>|,
          %{law_name: "UK_ukpga_2000_1", type_code: "ukpga"}
        )

      ids = Enum.map(rows, & &1.section_id)
      assert "UK_ukpga_2000_1:s.10" in ids
      assert "UK_ukpga_2000_1:s.10(1)" in ids
      assert "UK_ukpga_2000_1:s.10(2)[E+W]" in ids
      assert "UK_ukpga_2000_1:s.10(2)[S]" in ids
    end

    test "a version's own extent governs rows an inner extent contradicts (uksi 2010/2214 reg.36)" do
      rows =
        LatParser.parse(
          ~s|<Legislation><Secondary><Body>
            <P1group AltVersionRefs="v6" RestrictExtent="E"><P1 id="regulation-36"><Pnumber>36</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>England text.</Text></P2para></P2></P1para></P1></P1group>
          </Body></Secondary>
          <Versions><Version id="v6" Description="W"><P1group RestrictExtent="W"><P1 id="regulation-36" RestrictExtent="E"><Pnumber>36</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Wales text.</Text></P2para></P2></P1para></P1></P1group></Version></Versions></Legislation>|,
          %{law_name: "UK_uksi_2010_2214", type_code: "uksi"}
        )

      wales = Enum.find(rows, &(&1.text == "Wales text."))
      assert wales.extent_code == "W"
      assert wales.section_id == "UK_uksi_2010_2214:reg.36(1)[W]"

      assert Enum.find(rows, &(&1.text == "England text.")).section_id ==
               "UK_uksi_2010_2214:reg.36(1)[E]"
    end
  end

  describe "parse/2 rendering (LH-03)" do
    defp lh3(body, extent \\ "E+W+S") do
      LatParser.parse(
        ~s|<Legislation RestrictExtent="#{extent}"><Primary><Body>#{body}</Body></Primary></Legislation>|,
        %{law_name: "UK_ukpga_2000_9", type_code: "ukpga"}
      )
    end

    defp lh3_row(rows, id), do: Enum.find(rows, &(&1.section_id == "UK_ukpga_2000_9:" <> id))

    test "prefixed XHTML tables (xhtml:tr / xhtml:td) keep their cells (ukpga 1991/22 s.106)" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>106</Pnumber><P1para><Text>Defined—</Text></P1para><Tabular><xhtml:table xmlns:xhtml="http://www.w3.org/1999/xhtml"><xhtml:tbody><xhtml:tr><xhtml:td>apparatus</xhtml:td><xhtml:td>sections 89(3) and 105(1)</xhtml:td></xhtml:tr><xhtml:tr><xhtml:td>bridge</xhtml:td><xhtml:td>section 88(1)(a)</xhtml:td></xhtml:tr></xhtml:tbody></xhtml:table></Tabular></P1></P1group>|
        )

      table = Enum.find(rows, &(&1.section_type == "table"))
      assert table.text == "apparatus | sections 89(3) and 105(1); bridge | section 88(1)(a)"
      assert table.status == "in_force"
    end

    test "list items keep their numbers (NumberOverride), in text and table cells" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>6</Pnumber><P1para><Text>A test may be required where—</Text><OrderedList Type="alpha" Decoration="parens"><ListItem NumberOverride="a"><Para><Text>a constable suspects,</Text></Para></ListItem><ListItem NumberOverride="b"><Para><Text>an accident occurs.</Text></Para></ListItem></OrderedList></P1para></P1></P1group>|
        )

      assert lh3_row(rows, "s.6").text ==
               "A test may be required where— (a) a constable suspects, (b) an accident occurs."
    end

    test "an ordered list without overrides is numbered from its Type and Decoration" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>7</Pnumber><P1para><Text>Either—</Text><OrderedList Type="roman" Decoration="parens"><ListItem><Para><Text>this,</Text></Para></ListItem><ListItem><Para><Text>that.</Text></Para></ListItem></OrderedList></P1para></P1></P1group>|
        )

      assert lh3_row(rows, "s.7").text == "Either— (i) this, (ii) that."
    end

    test "«…» keeps Schedule / Part numbers and references (ukpga 2024/13 s.327(2))" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>327</Pnumber><P1para><Text>After Schedule 4 insert—</Text><BlockAmendment><Schedule><Number>Schedule 4A</Number><TitleBlock><Title>Functions</Title></TitleBlock><Reference>Section 25</Reference><ScheduleBody><Part><Number>Part 1</Number><Title>Introduction</Title><P1><Pnumber>1</Pnumber><P1para><Text>The functions.</Text></P1para></P1></Part></ScheduleBody></Schedule></BlockAmendment></P1para></P1></P1group>|
        )

      assert lh3_row(rows, "s.327").text ==
               "After Schedule 4 insert— «Schedule 4A Functions Section 25 Part 1 Introduction 1. The functions.»"
    end

    test "a table inside «…» keeps its cells" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>173</Pnumber><P1para><Text>Insert—</Text><BlockAmendment><P1><Pnumber>2</Pnumber><P1para><Text>Persons are—</Text><Tabular><table xmlns="http://www.w3.org/1999/xhtml"><tr><td>Newspaper</td><td>Editor</td></tr></table></Tabular></P1para></P1></BlockAmendment></P1para></P1></P1group>|
        )

      assert lh3_row(rows, "s.173").text == "Insert— «2. Persons are— Newspaper | Editor»"
    end

    test "AppendText after a quoted block closes the quote (ukpga 2019/17 s.55(3))" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>55</Pnumber><P1para><Text>For paragraph (b) substitute—</Text><BlockAmendment><P3><Pnumber>b</Pnumber><P3para><Text>it increases the rate of fire; and”</Text></P3para></P3></BlockAmendment><AppendText>.</AppendText></P1para></P1></P1group>|
        )

      assert lh3_row(rows, "s.55").text ==
               "For paragraph (b) substitute— «(b) it increases the rate of fire; and”.»"
    end

    test "excluded_extent from the row's own text when its children differ (ukpga 1989/14 s.3(5))" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>3</Pnumber><P1para><P2><Pnumber>5</Pnumber><P2para><Text><Repeal RetainText="true" Extent="S">In relation to an applicant, if—</Repeal></Text><P3><Pnumber>a</Pnumber><P3para><Text>a condition is met.</Text></P3para></P3></P2para></P2></P1para></P1></P1group>|
        )

      s35 = lh3_row(rows, "s.3(5)")
      assert s35.text == "In relation to an applicant, if—"
      assert s35.excluded_extent == "S"
    end

    test "no bracket when the territory covers the row's whole extent" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>66</Pnumber><P1para><Text>Paid by <Repeal RetainText="true" SubstitutionRef="n1" Extent="E+W">the council</Repeal> <Addition ChangeId="n1" Extent="E+W">the authority</Addition> now.</Text></P1para></P1></P1group>|,
          "E+W"
        )

      assert lh3_row(rows, "s.66").text == "Paid by the authority now."
    end

    test "no bracket for words repealed in a territory the row doesn't extend to" do
      rows =
        lh3(
          ~s|<P1group><P1><Pnumber>5</Pnumber><P1para><Text>A duty to <Repeal RetainText="true" Extent="S">consult</Repeal> act.</Text></P1para></P1></P1group>|,
          "E+W"
        )

      assert lh3_row(rows, "s.5").text == "A duty to consult act."
    end
  end

  test "a signature joins its parts without doubled punctuation" do
    rows =
      LatParser.parse(
        ~s|<Legislation><Secondary><Body><P1group><P1><Pnumber>1</Pnumber><P1para><Text>Citation.</Text></P1para></P1></P1group><SignedSection><Signatory><Signee><PersonName>Alan Howarth</PersonName><JobTitle>Parliamentary Under Secretary of State,</JobTitle><Department>Department of Employment</Department></Signee></Signatory></SignedSection></Body></Secondary></Legislation>|,
        %{law_name: "UK_uksi_1990_1", type_code: "uksi"}
      )

    assert Enum.find(rows, &(&1.section_type == "signed")).text ==
             "Alan Howarth, Parliamentary Under Secretary of State, Department of Employment"
  end

  describe "parse/2 own-level note refs (LH-06)" do
    defp refs_for(body, commentaries) do
      rows =
        LatParser.parse(
          ~s|<Legislation><Primary><Body>#{body}</Body></Primary><Commentaries>#{commentaries}</Commentaries></Legislation>|,
          %{law_name: "UK_ukpga_2004_20", type_code: "ukpga"}
        )

      SertantaiLegal.Scraper.CommentaryParser.build_ref_to_sections(rows)
    end

    test "a subsection substituted whole cites the note itself and in its children: all are placed (2004/20 s.84(4))" do
      refs =
        refs_for(
          ~s|<P1group><P1><Pnumber>84</Pnumber><P1para><P2><Pnumber><Substitution CommentaryRef="c-sub">4</Substitution></Pnumber><P2para><Text><Substitution CommentaryRef="c-sub">The Secretary of State may—</Substitution></Text><P3><Pnumber><Substitution CommentaryRef="c-sub">a</Substitution></Pnumber><P3para><Text><Substitution CommentaryRef="c-sub">make rules;</Substitution></Text></P3para></P3></P2para></P2></P1para></P1></P1group>|,
          ~s|<Commentary id="c-sub" Type="F"><Para><Text>S. 84(4) substituted (31.3.2014) by x</Text></Para></Commentary>|
        )

      assert refs["c-sub"] == ["UK_ukpga_2004_20:s.84(4)", "UK_ukpga_2004_20:s.84(4)(a)"]
    end

    test "a section inserted whole: the section row carries its insertion note (1990/8 s.225A)" do
      refs =
        refs_for(
          ~s|<P1group><Title><Addition CommentaryRef="c-ins">Notices</Addition></Title><P1><Pnumber><Addition CommentaryRef="c-ins">225A</Addition></Pnumber><P1para><P2><Pnumber><Addition CommentaryRef="c-ins">1</Addition></Pnumber><P2para><Text><Addition CommentaryRef="c-ins">A duty.</Addition></Text></P2para></P2></P1para></P1></P1group>|,
          ~s|<Commentary id="c-ins" Type="F"><Para><Text>Ss. 225A-225E inserted (6.4.2012) by x</Text></Para></Commentary>|
        )

      assert "UK_ukpga_2004_20:s.225A" in refs["c-ins"]
    end

    test "a note cited only inside a child is not placed on the parent" do
      refs =
        refs_for(
          ~s|<P1group><P1><Pnumber>5</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>Words <Addition CommentaryRef="c-w">added</Addition>.</Text></P2para></P2><P2><Pnumber>2</Pnumber><P2para><Text>Plain.</Text></P2para></P2></P1para></P1></P1group>|,
          ~s|<Commentary id="c-w" Type="F"><Para><Text>Word in s. 5(1) inserted (1.1.2020) by x</Text></Para></Commentary>|
        )

      assert refs["c-w"] == ["UK_ukpga_2004_20:s.5(1)"]
    end

    test "refs inside a quoted block belong to the amending row" do
      refs =
        refs_for(
          ~s|<P1group><P1><Pnumber>9</Pnumber><P1para><Text>Insert—</Text><BlockAmendment><P1><Pnumber>9A</Pnumber><P1para><Text>New <CommentaryRef Ref="c-q"/>text.</Text></P1para></P1></BlockAmendment></P1para></P1></P1group>|,
          ~s|<Commentary id="c-q" Type="F"><Para><Text>S. 9 in force (1.1.2020) by x</Text></Para></Commentary>|
        )

      assert refs["c-q"] == ["UK_ukpga_2004_20:s.9"]
    end

    test "a section's P1group Title note is not placed on the cross-heading or Part above (QA 3: 1956/52 s.15, 1968/73 pt.VI)" do
      refs =
        refs_for(
          ~s|<Part><Number>Part VI</Number><Title>Misc</Title><Pblock><Title>Smoke control areas</Title><P1group><Title>Exclusion<CommentaryRef Ref="c-ex"/></Title><P1><Pnumber>15</Pnumber><P1para><Text>A duty.</Text></P1para></P1></P1group></Pblock></Part>|,
          ~s|<Commentary id="c-ex" Type="C"><Para><Text>S. 15 excluded by x</Text></Para></Commentary>|
        )

      assert refs["c-ex"] == ["UK_ukpga_2004_20:s.15"]
    end
  end

  test "dotted RestrictExtent normalises on rows; an insertion covering it stays plain (LH-06: uksi 2017/1012 reg.16A)" do
    rows =
      LatParser.parse(
        ~s|<Legislation RestrictExtent="E.W.S."><Secondary><Body><P1group RestrictExtent="E.W."><P1><Pnumber>16A</Pnumber><P1para><Text><Addition Extent="E.W.">the natural range, and</Addition></Text></P1para></P1></P1group></Body></Secondary></Legislation>|,
        %{law_name: "UK_uksi_2017_1012", type_code: "uksi"}
      )

    row = Enum.find(rows, &(&1.section_id == "UK_uksi_2017_1012:reg.16A"))
    assert row.extent_code == "E+W"
    assert row.text == "the natural range, and"
  end

  describe "parse/2 edge spacing around territorial text (LH-06)" do
    defp spacing(body, extent) do
      [row | _] =
        ~s|<Legislation RestrictExtent="#{extent}"><Primary><Body><P1group><P1><Pnumber>60</Pnumber><P1para><Text>#{body}</Text></P1para></P1></P1group></Body></Primary></Legislation>|
        |> LatParser.parse(%{law_name: "UK_ukpga_1990_9", type_code: "ukpga"})
        |> Enum.filter(&(&1.section_id == "UK_ukpga_1990_9:s.60"))

      row.text
    end

    test "a pair resolved to its new words keeps the spaces around it (1990/9 s.60(3))" do
      assert spacing(
               ~s|the Council under <Repeal RetainText="true" SubstitutionRef="n1" Extent="E+W">section 2 of the 1991 Measure</Repeal><Addition ChangeId="n1" Extent="E+W">section 38 of the 2018 Measure</Addition> or is otherwise|,
               "E+W"
             ) == "the Council under section 38 of the 2018 Measure or is otherwise"
    end

    test "bracketed words keep the spaces around them (2004/20 s.10(2)(b))" do
      assert spacing(
               ~s|within the meaning of <Addition Extent="E+W">the Environmental Permitting Regulations </Addition>and others|,
               "E+W+S"
             ) ==
               "within the meaning of [E+W: the Environmental Permitting Regulations] and others"
    end

    test "an insertion for a territory outside the row's extent stays plain (2010/2214 reg.2(6) Welsh version)" do
      assert spacing(~s|panels <Addition Extent="E">with metal layers</Addition> only|, "W") ==
               "panels with metal layers only"
    end
  end

  test "a Part heading held in its Number (LH-06: ukpga 1875/17, wsi 2012/1903)" do
    rows =
      LatParser.parse(
        ~s|<Legislation><Primary><Body>
          <Part><Number>Part III.—Administration of Law</Number><P1group><P1><Pnumber>20</Pnumber><P1para><Text>A duty.</Text></P1para></P1></P1group></Part>
          <Part><Number>PART 4 —</Number><Title>Enforcement</Title><P1group><P1><Pnumber>30</Pnumber><P1para><Text>Another.</Text></P1para></P1></P1group></Part>
        </Body></Primary></Legislation>|,
        %{law_name: "UK_ukpga_1875_17", type_code: "ukpga"}
      )

    p3 = Enum.find(rows, &(&1.section_id == "UK_ukpga_1875_17:pt.III"))
    assert p3.title == "Administration of Law"
    assert p3.text == "Administration of Law"
    assert Enum.find(rows, &(&1.section_id == "UK_ukpga_1875_17:pt.4")).title == "Enforcement"
  end

  test "a sub-provision number written \"6.\" gives (6), not (6.) (EU 2008/1272 Art. 37(6)(c))" do
    rows =
      LatParser.parse(
        ~s|<Legislation><EURetained><EUBody><P1group><P1><Pnumber>Article 37</Pnumber><P1para><P2><Pnumber>6.</Pnumber><P2para><Text>Proposals—</Text><P3><Pnumber>c</Pnumber><P3para><Text>a manufacturer must submit a proposal.</Text></P3para></P3></P2para></P2></P1para></P1></P1group></EUBody></EURetained></Legislation>|,
        %{law_name: "UK_eur_2008_1272", type_code: "eur"}
      )

    ids = Enum.map(rows, & &1.section_id)
    assert "UK_eur_2008_1272:art.Article 37(6)(c)" in ids
    refute Enum.any?(ids, &String.contains?(&1, "6.)"))
  end
end

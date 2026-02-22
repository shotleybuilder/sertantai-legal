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

    test "first row is Part I", %{rows: rows} do
      first = hd(rows)
      assert first.section_type == "part"
      assert first.section_id == "UK_ukpga_2024_1:pt.I"
      assert first.part == "I"
      assert first.position == 1
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

  # ── Provision Mode ─────────────────────────────────────────────

  describe "provision mode" do
    test "ukpga uses section/sub_section" do
      xml = """
      <Legislation RestrictExtent="E+W+S+N.I.">
      <Primary><Body>
        <P1group><P1 id="s-1"><Pnumber>1</Pnumber>
          <P1para><P2 id="s-1-1"><Pnumber>1</Pnumber><P2para><Text>T</Text></P2para></P2></P1para>
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
      xml = """
      <Legislation RestrictExtent="E+W+S">
      <Secondary><Body>
        <P1group><P1 id="r-1"><Pnumber>1</Pnumber>
          <P1para><P2 id="r-1-1"><Pnumber>1</Pnumber><P2para><Text>T</Text></P2para></P2></P1para>
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
end

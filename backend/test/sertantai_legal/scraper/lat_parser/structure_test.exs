defmodule SertantaiLegal.Scraper.LatParser.StructureTest do
  @moduledoc """
  CV-S02a (#183): legislation.gov.uk structure faults, sensed — an id that
  contradicts its nesting, a level skipped — and one repair: a loose
  element whose number continues the sibling just before it belongs in it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LatParser.Structure

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  defp p3(n, id \\ nil, body \\ ""),
    do:
      ~s|<P3#{id && ~s( id="#{id}")}><Pnumber>#{n}</Pnumber><P3para><Text>#{n} text</Text></P3para>#{body}</P3>|

  defp p4(n), do: ~s|<P4><Pnumber>#{n}</Pnumber><P4para><Text>#{n} text</Text></P4para></P4>|

  # HSWA 1974 s.28: (3) closes after (e); (f) sits loose under the section
  defp s28,
    do: """
    <P1 id="section-28"><Pnumber>28</Pnumber><P1para>
      <P2 id="section-28-2"><Pnumber>2</Pnumber><P2para><Text>Two.</Text></P2para></P2>
      <P2 id="section-28-3"><Pnumber>3</Pnumber><P2para><Text>Three—</Text>
        #{for n <- ~w(a b c d e), do: p3(n, "section-28-3-" <> n)}
      </P2para></P2>
      #{p3("f", "section-28-f", p4("i") <> p4("ii"))}
      <P2 id="section-28-4"><Pnumber>4</Pnumber><P2para><Text>Four.</Text></P2para></P2>
    </P1para></P1>
    """

  # HSWA 1974 s.50: (1AA) has no paragraphs; (a)–(c) after it are the section's
  defp s50,
    do: """
    <P1 id="section-50"><Pnumber>50</Pnumber><P1para>
      <P2 id="section-50-1AA"><Pnumber>1AA</Pnumber><P2para><Text>Where—</Text></P2para></P2>
      #{for n <- ~w(a b c), do: p3(n, "section-50-" <> n)}
    </P1para></P1>
    """

  defp act(body) do
    xml = "<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"
    LatParser.parse(xml, %{law_name: "UK_ukpga_2099_1", type_code: "ukpga"})
  end

  defp ids(rows),
    do: Enum.map(rows, &(&1.section_id |> String.split(":", parts: 2) |> List.last()))

  describe "faults/1" do
    test "an id that contradicts its nesting (CLP: article-50-2-a inside Art. 52(1))" do
      doc =
        el(
          ~s|<Legislation><EUBody><P1 id="article-52"><Pnumber>Article 52</Pnumber><P2 id="article-52-1"><Pnumber>1</Pnumber><P2para>#{p3("a", "article-50-2-a")}#{p3("b", "article-52-1-b")}</P2para></P2></P1></EUBody></Legislation>|
        )

      assert [
               %{
                 kind: :id_contradicts_nesting,
                 xml_id: "article-50-2-a",
                 parent_id: "article-52-1"
               }
             ] =
               Structure.faults(doc)
    end

    test "version marks (n1, n2) don't contradict" do
      doc =
        el(
          ~s|<Legislation><Body><P1 id="section-28n1"><Pnumber>28</Pnumber><P2 id="section-28n1-3"><Pnumber>3</Pnumber><P2para>#{p3("a", "section-28-3-an1")}</P2para></P2></P1></Body></Legislation>|
        )

      assert Structure.faults(doc) == []
    end

    test "a level skipped: adopted when it continues the sibling before it, else sensed only" do
      faults = Structure.faults(el("<Legislation><Body>#{s28()}#{s50()}</Body></Legislation>"))
      skipped = for %{kind: :level_skipped} = f <- faults, do: {f.xml_id, f.adopted}

      assert skipped == [
               {"section-28-f", true},
               {"section-50-a", false},
               {"section-50-b", false},
               {"section-50-c", false}
             ]
    end

    test "amending text quoting other laws is not sensed" do
      doc =
        el(
          ~s|<Legislation><Body><P1 id="section-1"><Pnumber>1</Pnumber><P1para><BlockAmendment><P1 id="section-9"><P2 id="section-7-1"><Pnumber>1</Pnumber></P2></P1></BlockAmendment></P1para></P1></Body></Legislation>|
        )

      assert Structure.faults(doc) == []
    end
  end

  describe "adoptions/1" do
    test "a loose P3 continuing the P2 before it: that P2's number" do
      assert s28() |> el() |> Structure.adoptions() |> Map.values() == [{:sub, "3"}]
      assert s50() |> el() |> Structure.adoptions() == %{}
    end

    test "a run of loose items continues one another" do
      node =
        el(
          ~s|<P1 id="section-9"><Pnumber>9</Pnumber><P2 id="section-9-1"><Pnumber>1</Pnumber><P2para>#{p3("a")}</P2para></P2>#{p3("b")}#{p3("c")}</P1>|
        )

      assert node |> Structure.adoptions() |> Map.values() == [{:sub, "1"}, {:sub, "1"}]
    end

    test "a loose P4 continuing the P3 before it, under a P2: that P3's number" do
      node =
        el(
          ~s|<P2 id="regulation-3-1"><Pnumber>1</Pnumber><P2para>#{p3("a", nil, p4("i") <> p4("ii"))}#{p4("iii")}</P2para></P2>|
        )

      assert node |> Structure.adoptions() |> Map.values() == [{:paragraph, "a"}]
    end
  end

  test "Diagnostics.structure_faults/1: each fault as a warning" do
    xml = "<Legislation><Primary><Body>#{s28()}</Body></Primary></Legislation>"

    assert [%{check: :level_skipped, severity: :warning, message: message}] =
             SertantaiLegal.Scraper.LatParser.Diagnostics.structure_faults(xml)

    assert message =~ "section-28-f skips a level in section-28"
    assert message =~ "adopted"
  end

  describe "parse/2" do
    test "HSWA s.28(f) is s.28(3)(f), its (i) and (ii) under it" do
      rows = act(s28())
      assert "s.28(3)(f)" in ids(rows)
      assert "s.28(3)(f)(i)" in ids(rows)
      assert "s.28(3)(f)(ii)" in ids(rows)
      refute Enum.any?(ids(rows), &String.starts_with?(&1, "s.28(f)"))

      keys = Enum.map(rows, & &1.sort_key)
      assert keys == Enum.sort(keys)
    end

    test "s.50(a)–(c) stay the section's" do
      assert ids(act(s50())) == ["s.50", "s.50(1AA)", "s.50(a)", "s.50(b)", "s.50(c)"]
    end
  end
end

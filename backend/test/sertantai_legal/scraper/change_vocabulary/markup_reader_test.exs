defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupReaderTest do
  @moduledoc """
  CV-S03: the markup reader's placement and facts, one rule a test — the
  markup catalogue's findings A–E (2026-10-23).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  # an effect id built at run time (a literal one trips push protection)
  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp read(body, xml_ids \\ %{}) do
    "<Legislation><Body>#{body}</Body></Legislation>"
    |> String.replace("KEY", effect_id(1))
    |> Markup.read("UK_ukpga_2016_2", xml_ids)
    |> Enum.map(fn {key, target, claims} ->
      {key, target, Map.new(claims, &{&1.attribute, &1.value})}
    end)
    |> Enum.sort()
  end

  defp section(n, inner),
    do:
      ~s(<P1 id="section-#{n}"><Pnumber>#{n}</Pnumber><P1para><Text>#{inner}</Text></P1para></P1>)

  describe "A: a change in a group (Part, Chapter, cross-heading)" do
    @inserted """
    <Pblock id="part-4-crossheading-qualified"><Title><Addition ChangeId="KEY-1">Qualified</Addition></Title>
    <P1 id="section-85B"><Pnumber><Addition ChangeId="KEY-2">85B</Addition></Pnumber><P1para><Text><Addition ChangeId="KEY-2">First text.</Addition></Text></P1para></P1>
    <P1 id="section-85C"><Pnumber><Addition ChangeId="KEY-2">85C</Addition></Pnumber><P1para><Text><Addition ChangeId="KEY-2">Second text.</Addition></Text></P1para></P1>
    </Pblock>
    """

    test "across the group's provisions: one change on each provision" do
      sets = read(@inserted)

      assert {key, "s.85B", %{operation: :inserted, level: :provision}} =
               Enum.find(sets, &(elem(&1, 1) == "s.85B"))

      assert {_, "s.85C", %{operation: :inserted, level: :provision}} =
               Enum.find(sets, &(elem(&1, 1) == "s.85C"))

      assert key == effect_id(1)
    end

    test "the group's own heading: a change to the group's row, named as the parse names it" do
      sets = read(@inserted, %{"part-4-crossheading-qualified" => "pt.4.h.2"})

      assert {_, "pt.4.h.2", %{operation: :inserted, level: :words}} =
               Enum.find(sets, &(elem(&1, 1) == "pt.4.h.2"))
    end

    test "a group the rows don't name: its heading change is unplaced, its provisions still placed" do
      targets = @inserted |> read() |> Enum.map(&elem(&1, 1))
      assert targets == ["s.85B", "s.85C"]
    end
  end

  test "B: a defined term's id inside a provision is not its place" do
    body =
      section(
        3,
        ~s(In this Act <Term id="term-car">"car" <Substitution ChangeId="KEY-1">means a vehicle</Substitution></Term>.)
      )

    assert [{_, "s.3", %{operation: :substituted, level: :words}}] = read(body)
  end

  test "C: a provision id led by its group's is named by the provision" do
    body =
      ~s(<P2 id="part-V-section-36-2A"><Pnumber>2A</Pnumber><P2para><Text>Some <Addition ChangeId="d29p2480">words</Addition>.</Text></P2para></P2>)

    assert [{"d29p2480", "s.36(2A)", _}] = read(body)
  end

  test "D: a retained substitution (old words kept, new words added) is one substitution" do
    body =
      section(
        65,
        ~s(carry out their <Repeal ChangeId="KEY-1" RetainText="true" SubstitutionRef="KEY-2">special functions</Repeal> <Addition ChangeId="KEY-2">learning functions</Addition> here)
      )

    assert [{key, "s.65", claims}] = read(body)
    assert key == effect_id(1)
    assert claims.operation == :substituted
    assert claims.retained == true
    assert claims.level == :words
  end

  test "E: a ChangeId's suffix after the effect id (-N, -N/2) is not part of its key" do
    body =
      section(
        63,
        ~s(the <Substitution ChangeId="KEY-1790691857434">Commission</Substitution> and the <Substitution ChangeId="KEY-1790691857434/2">Commission</Substitution>)
      )

    assert [{key, "s.63", %{operation: :substituted}}, {key, "s.63", _}] = read(body)
    assert key == effect_id(1)
    assert Markup.key(effect_id(1) <> "-1790691857434/2") == effect_id(1)
    assert Markup.key("d29p1234") == "d29p1234"
  end

  describe "G: the note's amending provisions, from its structured pointers" do
    defp note(text) do
      ~s|<Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>|
    end

    defp affecting(note) do
      ("<Legislation><Body>" <>
         section(
           1,
           ~s|Some <Substitution ChangeId="d1p1" CommentaryRef="c1">words</Substitution>|
         ) <>
         "</Body>" <> note <> "</Legislation>")
      |> Markup.read("UK_ukpga_2016_2")
      |> Enum.flat_map(fn {_, _, claims} ->
        for c <- claims, c.attribute == :affecting, do: c.value
      end)
    end

    @cite ~s|<Citation id="x1" URI="http://www.legislation.gov.uk/id/uksi/2010/1">S.I. 2010/1</Citation>|

    test "the operative pointers of the cited law: not its (with …) ones, not another law's" do
      text =
        ~s|Words substituted by #{@cite}, <CitationSubRef CitationRef="x1" SectionRef="regulation-1">reg. 1</CitationSubRef>, | <>
          ~s|<CitationSubRef CitationRef="x1" SectionRef="regulation-34-2-b" Operative="true">34(2)(b)</CitationSubRef> | <>
          ~s|(with <CitationSubRef CitationRef="x1" SectionRef="regulation-3">reg. 3</CitationSubRef>; and as amended by | <>
          ~s|<Citation id="x2" URI="http://www.legislation.gov.uk/id/uksi/2011/2">S.I. 2011/2</Citation>, | <>
          ~s|<CitationSubRef CitationRef="x2" SectionRef="regulation-9" Operative="true">reg. 9</CitationSubRef>)|

      assert affecting(note(text)) == [["reg.34(2)(b)"]]
    end

    test "one pointer stays one: Sch. 2 para. 15(a)(i)(aa)" do
      text =
        ~s|Words substituted by #{@cite}, <CitationSubRef CitationRef="x1" SectionRef="schedule-2-paragraph-15-a-i-aa" Operative="true">Sch. 2 para. 15(a)(i)(aa)</CitationSubRef>|

      assert affecting(note(text)) == [["sch.2.para.15(a)(i)(aa)"]]
    end

    test "a Schedule's paragraph named as the feed names it: Part left out; unnumbered Schedule" do
      text =
        ~s|Words substituted by #{@cite}, <CitationSubRef CitationRef="x1" SectionRef="schedule-10-part-5-paragraph-9" Operative="true">Sch. 10 Pt. 5 para. 9</CitationSubRef>, | <>
          ~s|<CitationSubRef CitationRef="x1" SectionRef="schedule-paragraph-3-3" Operative="true">Sch. para. 3(3)</CitationSubRef>|

      assert affecting(note(text)) == [["sch.10.para.9", "sch.para.3(3)"]]
    end

    test "none marked operative: every pointer of the cited law" do
      text =
        ~s|Words substituted by #{@cite}, <CitationSubRef CitationRef="x1" SectionRef="regulation-1">reg. 1</CitationSubRef>, | <>
          ~s|<CitationSubRef CitationRef="x1" SectionRef="regulation-3">reg. 3</CitationSubRef>|

      assert affecting(note(text)) == [["reg.1", "reg.3"]]
    end
  end

  test "H: whole subsections inserted under one id land on each, not as words on the parent" do
    body = """
    <P1 id="section-18"><Pnumber>18</Pnumber><P1para><Text>Text.</Text>
    <P2 id="section-18-1A"><Pnumber><Addition ChangeId="KEY-1">1A</Addition></Pnumber><P2para><Text><Addition ChangeId="KEY-1">First.</Addition></Text></P2para></P2>
    <P2 id="section-18-1B"><Pnumber><Addition ChangeId="KEY-1">1B</Addition></Pnumber><P2para><Text><Addition ChangeId="KEY-1">Second.</Addition></Text></P2para></P2>
    </P1para></P1>
    """

    assert [{_, "s.18(1A)", a}, {_, "s.18(1B)", b}] = read(body)
    assert a.operation == :inserted and a.level == :provision
    assert b.operation == :inserted and b.level == :provision
  end

  test "H: a change touching the provision's own number stays one change on it" do
    body = """
    <P1 id="section-5"><Pnumber><Addition ChangeId="KEY-1">5</Addition></Pnumber><P1para>
    <P2 id="section-5-1"><Pnumber><Addition ChangeId="KEY-1">1</Addition></Pnumber><P2para><Text><Addition ChangeId="KEY-1">First.</Addition></Text></P2para></P2>
    </P1para></P1>
    """

    assert [{_, "s.5", %{operation: :inserted, level: :provision}}] = read(body)
  end

  test "I: a repeated id (K3) is named by the element's own number" do
    body = """
    <P1 id="article-38"><Pnumber>38</Pnumber><P1para>
    <P2 id="article-38-1"><Pnumber>A1</Pnumber><P2para><Text>First.</Text></P2para></P2>
    <P2 id="article-38-1"><Pnumber>1</Pnumber><P2para><Text>Second.</Text></P2para></P2>
    <P2 id="article-38-1"><Pnumber><Addition ChangeId="KEY-1">3</Addition></Pnumber><P2para><Text><Addition ChangeId="KEY-1">Third.</Addition></Text></P2para></P2>
    </P1para></P1>
    """

    assert [{_, "reg.38(3)", %{operation: :inserted}}] = read(body)
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupTerritoryCitationsTest do
  @moduledoc """
  A note pairing territories with instruments ("repealed (E.W.) … by A …;
  and … repealed (S.) … by B …"): a change whose markup states one of
  those territories (its Extent) cites that territory's instrument, with
  its own amending provisions, never the note's first (Waste, Water and
  Climate: Markup reader, `note-two-laws-one-cited`). A change stating no
  Extent, or one the note pairs with no single instrument, keeps the first.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.TerritoryCitations

  # effect ids are built at run time, never written
  @note "key-" <> String.duplicate("c", 32)

  defp cite(id, type, year, number, words),
    do:
      ~s|<Citation URI="http://www.legislation.gov.uk/id/#{type}/#{year}/#{number}" id="#{id}">#{words}</Citation>|

  defp piece(citation, section_ref, words, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="#{citation}" SectionRef="#{section_ref}"#{mark}>#{words}</CitationSubRef>|
  end

  # the Wildlife and Countryside Act 1981 s.22(3)'s note
  defp marine_note do
    "S. 22(3) repealed (E.W.) (12.1.2010) by " <>
      cite("c1", "ukpga", 2009, 23, "Marine and Coastal Access Act 2009 (c. 23)") <>
      ", " <>
      piece("c1", "section-324-3", "s. 324(3)") <>
      ", " <>
      piece("c1", "schedule-22-part-5-A", "Sch. 22 Pt. 5(A)", true) <>
      "; " <>
      cite("c2", "uksi", 2009, 3345, "S.I. 2009/3345") <>
      ", " <>
      piece("c2", "article-2", "art. 2") <>
      "; and s. 22(3) repealed (S.) (24.2.2011) by " <>
      cite("c3", "asp", 2010, 5, "Marine (Scotland) Act 2010 (asp 5)") <>
      ", " <>
      piece("c3", "section-168-1", "s. 168(1)") <>
      ", " <>
      piece("c3", "schedule-4-paragraph-11-2-b", "Sch. 4 para. 11(2)(b)", true) <>
      " (with " <>
      piece("c3", "section-162", "s. 162") <>
      "); " <>
      cite("c4", "ssi", 2011, 58, "S.S.I. 2011/58") <> ", " <> piece("c4", "article-2", "art. 2")
  end

  defp law(note, change) do
    """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para>
    <P2 id="section-22-3"><Pnumber>3</Pnumber><P2para><Text>#{change}</Text></P2para></P2>
    </P1para></P1>
    </Body><Commentaries>
    <Commentary id="#{@note}" Type="F"><Para><Text>#{note}</Text></Para></Commentary>
    </Commentaries></Legislation>
    """
  end

  defp repeal(extent) do
    extent = if extent, do: ~s| Extent="#{extent}"|, else: ""

    ~s|<Repeal ChangeId="#{@note}-1" CommentaryRef="#{@note}" RetainText="true"#{extent}>| <>
      "The Secretary of State may by order vary the close season" <> "</Repeal>"
  end

  defp pointers(note, change) do
    [{_key, _target, claims}] = note |> law(change) |> Markup.read("UK_ukpga_1981_29")
    for c <- claims, c.attribute in [:cited, :affecting, :territory], do: {c.attribute, c.value}
  end

  test "a change stating S. cites the instrument the note pairs with (S.)" do
    assert pointers(marine_note(), repeal("S")) == [
             territory: "S",
             cited: "UK_asp_2010_5",
             affecting: ["sch.4.para.11(2)(b)"]
           ]
  end

  test "a change stating E+W cites the instrument the note pairs with (E.W.)" do
    assert [territory: "E+W", cited: "UK_ukpga_2009_23", affecting: _] =
             pointers(marine_note(), repeal("E+W"))
  end

  # EPA 1990 s.6(6A), `d29p866`: one element for both insertions
  test "a change stating no Extent keeps the note's first instrument" do
    assert [cited: "UK_ukpga_2009_23", affecting: _] = pointers(marine_note(), repeal(nil))
  end

  test "an Extent the note pairs with no single instrument keeps the first" do
    assert [territory: "E+W+S", cited: "UK_ukpga_2009_23", affecting: _] =
             pointers(marine_note(), repeal("E+W+S"))
  end

  # one change in two rows, stating its territory in only one of them
  test "a change only some of whose elements state the territory keeps the first" do
    one =
      ~s|<Substitution ChangeId="#{@note}-1" CommentaryRef="#{@note}">new words</Substitution>|

    two =
      ~s|<Substitution ChangeId="#{@note}-1" CommentaryRef="#{@note}" Extent="S">words</Substitution>|

    xml = """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para>
    <P2 id="section-22-3"><Pnumber>3</Pnumber><P2para><Text>kept #{one}</Text></P2para></P2>
    <P2 id="section-22-4"><Pnumber>4</Pnumber><P2para><Text>kept #{two}</Text></P2para></P2>
    </P1para></P1>
    </Body><Commentaries>
    <Commentary id="#{@note}" Type="F"><Para><Text>#{marine_note()}</Text></Para></Commentary>
    </Commentaries></Legislation>
    """

    cited =
      for {_key, target, claims} <- Markup.read(xml, "UK_ukpga_1981_29"),
          c <- claims,
          c.attribute == :cited,
          do: {target, c.value}

    assert Enum.sort(cited) == [{"s.22(3)", "UK_ukpga_2009_23"}, {"s.22(4)", "UK_ukpga_2009_23"}]
  end

  defp pairs(note) do
    {doc, _} = :xmerl_scan.string(String.to_charlist("<Commentary>#{note}</Commentary>"))
    for {territory, el} <- TerritoryCitations.pairs(doc), do: {territory, uri(el)}
  end

  defp uri({:xmlElement, _, _, _, _, _, _, attrs, _, _, _, _}) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, :URI, _, _, _, _, _, _, value, _} ->
        value |> to_string() |> String.replace("http://www.legislation.gov.uk/id/", "")

      _ ->
        nil
    end)
  end

  test "each territory's instrument is the first cited after its \"by\", not its commencement order" do
    assert pairs(marine_note()) == [{"E+W", "ukpga/2009/23"}, {"S", "asp/2010/5"}]
  end

  # EPA 1990 s.119: "Words in s. 119 inserted: (E.) … by …; (S.) … by …; (W.) … by virtue of …"
  test "three territories, undated and \"by virtue of\" pieces" do
    note =
      "Words in s. 119 inserted: (E.) (17.10.2002) by " <>
        cite("a", "uksi", 2002, 2443, "S.I. 2002/2443") <>
        ", regs. 1(2)(3), 30; (S.) by " <>
        cite("b", "ssi", 2002, 541, "S.S.I. 2002/541") <>
        ", reg. 30; (W.) (31.12.2002) by virtue of " <>
        cite("c", "uksi", 2002, 3188, "S.I. 2002/3188") <> ", reg. 31"

    assert pairs(note) == [
             {"E", "uksi/2002/2443"},
             {"S", "ssi/2002/541"},
             {"W", "uksi/2002/3188"}
           ]
  end

  test "a note for one territory, or one instrument, pairs nothing" do
    one =
      "Words in s. 101(1) substituted (W.) (1.4.2011) by " <>
        cite("a", "mwa", 2010, 1, "the Measure") <>
        ", s. 75(3); " <> cite("b", "wsi", 2011, 1, "S.I. 2011/1") <> ", art. 2"

    assert pairs(one) == []
    assert pairs("S. 1 repealed by " <> cite("a", "ukpga", 2000, 1, "an Act")) == []
  end

  test "a territory the note pairs with two instruments is left out" do
    note =
      "Words inserted (E.) (1.1.2001) by " <>
        cite("a", "uksi", 2001, 1, "S.I. 2001/1") <>
        " and (E.) (1.1.2002) by " <>
        cite("b", "uksi", 2002, 2, "S.I. 2002/2") <>
        " and (W.) (1.1.2003) by " <> cite("c", "uksi", 2003, 3, "S.I. 2003/3")

    assert pairs(note) == []
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupCopiedNotePiecesTest do
  @moduledoc """
  A copied note's pieces (Waste, Water and Climate: Markup reader,
  `copied-note-pieces-unmatched`): legislation.gov.uk's copy of a note adds
  "n1" to the Citation's id but leaves its pieces' CitationRef, so the
  pieces are matched by the id before the copy. Their Operative marks are
  read as any note's; a SectionRef its own words contradict gives way to
  the words.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.CopiedNotePieces

  defp cite(id, path, text),
    do: ~s|<Citation id="#{id}" URI="http://www.legislation.gov.uk/id/#{path}">#{text}</Citation>|

  defp sub(citation, section_ref, text, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="#{citation}" SectionRef="#{section_ref}"#{mark}>#{text}</CitationSubRef>|
  end

  defp read(text) do
    """
    <Legislation><Body>
    <P1 id="section-8"><Pnumber>8</Pnumber><P1para><Text>Some <Addition ChangeId="d30p100" CommentaryRef="c1">words</Addition></Text></P1para></P1>
    </Body><Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>
    </Legislation>
    """
    |> Markup.read("UK_ukpga_1967_10")
  end

  defp claims(text, attribute) do
    for {_, _, claims} <- read(text), c <- claims, c.attribute == attribute, do: c.value
  end

  defp pieces(text) do
    doc = SweetXml.parse("<Commentary id=\"c1\"><Para><Text>#{text}</Text></Para></Commentary>")

    for s <-
          SweetXml.xpath(CopiedNotePieces.mend(doc), SweetXml.sigil_x(".//CitationSubRef", ~c"l")) do
      {SweetXml.xpath(s, SweetXml.sigil_x("./@CitationRef", ~c"s")),
       SweetXml.xpath(s, SweetXml.sigil_x("./@SectionRef", ~c"s"))}
    end
  end

  describe "the pieces are matched by the Citation's id before the copy" do
    # the Forestry Act 1967 s.8(2)(3): "… Regulatory Reform (Forestry) Order
    # 2006 (S.I. 2006/780), arts. 1(1), 3(3)", article 3(3) marked operative
    test "the marked piece alone, not the commencement piece (1967 c.10)" do
      text =
        "S. 8(2)(3) inserted (16.3.2006) by " <>
          cite("c4i2-00008n1", "uksi/2006/780", "Regulatory Reform (Forestry) Order 2006") <>
          " (S.I. 2006/780), " <>
          sub("c4i2-00008", "article-1-1", "arts. 1(1)") <>
          ", " <> sub("c4i2-00008", "article-3-3", "3(3)", true)

      assert claims(text, :affecting) == [["reg.3(3)"]]
      assert claims(text, :cited) == ["UK_uksi_2006_780"]
    end

    test "a second copy's id (n2) is matched the same way" do
      text =
        "Words substituted by " <>
          cite("d4n2", "ukpga/2008/17", "2008 c. 17") <>
          ", " <>
          sub("d4", "section-325-1", "s. 325(1)") <>
          ", " <> sub("d4", "schedule-8-paragraph-2", "Sch. 8 para. 2", true)

      assert claims(text, :affecting) == [["sch.8.para.2"]]
    end

    # a copied note goes through `FirstProvisionList` as any note does
    test "a mark on the instrument's first provision stands for the pieces listed with it" do
      text =
        "Words substituted by " <>
          cite("d4n1", "uksi/1988/1729", "S.I. 1988/1729") <>
          ", " <>
          sub("d4", "regulation-1-1", "regs. 1(1)", true) <>
          ", " <> sub("d4", "regulation-12-1-a", "12(1)(a)")

      assert claims(text, :affecting) == [["reg.12(1)(a)"]]
    end

    test "a Citation whose pieces name its own id is left as it is" do
      text =
        "Words substituted by " <>
          cite("d4n1", "ukpga/2008/17", "2008 c. 17") <>
          ", " <> sub("d4n1", "schedule-8-paragraph-18-3-a", "Sch. 8 para. 18(3)(b)(i)")

      assert pieces(text) == [{"d4n1", "schedule-8-paragraph-18-3-a"}]
    end

    test "pieces of a Citation in the note that still holds the id are not taken" do
      text =
        "Words substituted by " <>
          cite("d4n1", "ukpga/2008/17", "2008 c. 17") <>
          " (as amended by " <>
          cite("d4", "ukpga/2010/1", "2010 c. 1") <>
          ", " <> sub("d4", "section-2", "s. 2") <> ")"

      assert pieces(text) == [{"d4", "section-2"}]
    end
  end

  describe "a copied piece's SectionRef its words contradict gives way to the words" do
    # the Local Government Act 1974 s.26(7)(ba): the copy's words name
    # para. 18(3)(b)(i), its SectionRef still the copied note's 18(3)(a)
    test "Sch. 8 para. 18(3)(b)(i) under SectionRef …18-3-a (1974 c.7)" do
      text =
        "Words in s. 26(7)(ba) substituted (1.12.2008) by " <>
          cite("d13e4n1", "ukpga/2008/17", "Housing and Regeneration Act 2008 (c. 17)") <>
          ", " <>
          sub("d13e4", "section-325-1", "s. 325(1)") <>
          ", " <>
          sub("d13e4", "schedule-8-paragraph-18-3-a", "Sch. 8 para. 18(3)(b)(i)", true)

      assert claims(text, :affecting) == [["sch.8.para.18(3)(b)(i)"]]

      assert pieces(text) == [
               {"d13e4n1", "section-325-1"},
               {"d13e4n1", "schedule-8-paragraph-18-3-b-i"}
             ]
    end

    test "bare words continue the piece before: 3(2)(b) after regs. 1(2); (2)(f) after a paragraph" do
      text =
        cite("d4n1", "uksi/2017/1", "S.I. 2017/1") <>
          ", " <>
          sub("d4", "regulation-1-2", "regs. 1(2)") <>
          ", " <>
          sub("d4", "regulation-3-2-a", "3(2)(b)", true) <>
          ", " <>
          sub("d4", "schedule-17-paragraph-57-1", "Sch. 17 para. 57(1)") <>
          ", " <> sub("d4", "schedule-17-paragraph-57-2-d", "(2)(f)", true)

      assert pieces(text) |> Enum.map(&elem(&1, 1)) == [
               "regulation-1-2",
               "regulation-3-2-b",
               "schedule-17-paragraph-57-1",
               "schedule-17-paragraph-57-2-f"
             ]
    end

    # the Education Act 2002 s.76(1): "Sch. 12 para. 32(4)" in two pieces,
    # their SectionRefs the copied note's 32(2) and 32(3)
    test "words that say less than the SectionRef are still the words" do
      text =
        cite("d4n1", "ukpga/2009/22", "2009 c. 22") <>
          ", " <>
          sub("d4", "section-269-4", "s. 269(4)") <>
          ", " <>
          sub("d4", "schedule-12-paragraph-32-2", "Sch. 12 para. 32") <>
          sub("d4", "schedule-12-paragraph-32-3", "(4)")

      assert pieces(text) |> Enum.map(&elem(&1, 1)) == [
               "section-269-4",
               "schedule-12-paragraph-32",
               "schedule-12-paragraph-32-4"
             ]
    end

    test "words naming several provisions, or none, keep the SectionRef" do
      text =
        cite("d4n1", "ukpga/1984/60", "1984 c. 60") <>
          ", " <>
          sub("d4", "section-183-1", "s. 183(1)(5)(e)") <>
          ", " <> sub("d4", "section-90", "the said Act")

      assert pieces(text) |> Enum.map(&elem(&1, 1)) == ["section-183-1", "section-90"]
    end

    test "a note not copied keeps its SectionRefs, words or no" do
      text =
        cite("d4", "ukpga/2008/17", "2008 c. 17") <>
          ", " <> sub("d4", "schedule-8-paragraph-18-3-a", "Sch. 8 para. 18(3)(b)(i)")

      assert claims(text, :affecting) == [["sch.8.para.18(3)(a)"]]
    end
  end
end

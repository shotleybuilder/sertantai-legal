defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPluralListTest do
  @moduledoc """
  A note's plural citation whose only operative mark sits on the
  instrument's first provision (its citation and commencement): the pieces
  listed with it are the amending provisions (Waste, Water and Climate:
  Markup reader, the parked `note-citation-bracketed-list-read-short`).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  @cite ~s|<Citation id="x1" URI="http://www.legislation.gov.uk/id/uksi/1988/1729">S.I. 1988/1729</Citation>|

  defp sub(section_ref, text, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="x1" SectionRef="#{section_ref}"#{mark}>#{text}</CitationSubRef>|
  end

  defp affecting(text) do
    """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para><Text>Some <Addition ChangeId="d30p100" CommentaryRef="c1">words</Addition></Text></P1para></P1>
    </Body><Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>
    </Legislation>
    """
    |> Markup.read("UK_ukpga_1954_70")
    |> Enum.flat_map(fn {_, _, claims} ->
      for c <- claims, c.attribute == :affecting, do: c.value
    end)
  end

  # Mines and Quarries Act 1954 ss.22-25, 33-35 (c650684): the mark is on
  # reg.1(1), the commencement; reg.12(1)(a) repeals
  test "regs. 1(1), 12(1)(a): the piece listed with the first provision is the amending one" do
    text =
      "Ss. 22–25, 33–35 repealed (1.4.1989, in part, and 1.4.1994, fully) by #{@cite}, " <>
        sub("regulation-1-1", "regs. 1(1)", true) <> ", " <> sub("regulation-12-1-a", "12(1)(a)")

    assert affecting(text) == [["reg.12(1)(a)"]]
  end

  # EPA 1990 s.153(1)(ee) by SI 1996/1431: the same form with no brackets
  test "arts. 1, 2: an Order's article 1 the same" do
    text =
      "inserted by #{@cite}, " <>
        sub("article-1", "arts. 1", true) <> ", " <> sub("article-2", "2")

    assert affecting(text) == [["reg.2"]]
  end

  # the Commissioners for Revenue and Customs: "regs. 1(2), 2(1)(2)"
  test "every piece of the list, joined by commas, \"and\" or nothing" do
    text =
      "by #{@cite}, " <>
        sub("regulation-1-2", "regs. 1(2)", true) <>
        ", " <>
        sub("regulation-2-1", "2(1)") <>
        sub("regulation-2-2", "(2)") <> " and " <> sub("regulation-5", "5")

    assert affecting(text) == [["reg.2(1)", "reg.2(2)", "reg.5"]]
  end

  test "the list ends at its first other words: a (with …) piece is not in it" do
    text =
      "by #{@cite}, " <>
        sub("regulation-1-2", "regs. 1(2)", true) <>
        ", " <>
        sub("regulation-65-1", "65(1)") <>
        " (subject to savings in " <> sub("regulation-63", "reg. 63") <> ")"

    assert affecting(text) == [["reg.65(1)"]]
  end

  test "nothing listed with it but (with …): the mark stands" do
    text =
      "by #{@cite}, " <>
        sub("regulation-1", "reg. 1", true) <> " (with " <> sub("regulation-7", "reg. 7") <> ")"

    assert affecting(text) == [["reg.1"]]
  end

  # S. 157 excluded by "regs. 1(1)(a)(b)": pieces of the first provision only
  test "only the first provision's own pieces listed: the mark stands" do
    text =
      "by #{@cite}, " <>
        sub("regulation-1-1-a", "regs. 1(1)(a)", true) <> sub("regulation-1-1-b", "(b)")

    assert affecting(text) == [["reg.1(1)(a)"]]
  end

  # Environment Act 2021 "ss. 57(4), 147(3)": an Act's marked section is
  # the amending one and the other its commencement (the known limit's
  # usual case): read as marked
  test "a mark on any other provision is read as given" do
    text =
      "by #{@cite}, " <>
        sub("section-57-4", "ss. 57(4)", true) <> ", " <> sub("section-147-3", "147(3)")

    assert affecting(text) == [["s.57(4)"]]

    text =
      "by #{@cite}, " <>
        sub("regulation-4", "regs. 4", true) <> ", " <> sub("regulation-12", "12")

    assert affecting(text) == [["reg.4"]]

    # an Act's section 1 can amend
    text = "by #{@cite}, " <> sub("section-1", "ss. 1", true) <> ", " <> sub("section-9", "9")
    assert affecting(text) == [["s.1"]]
  end

  test "a second mark beside the first provision's: read as marked" do
    text =
      "by #{@cite}, " <>
        sub("regulation-1", "regs. 1", true) <>
        ", " <> sub("regulation-3", "3", true) <> ", " <> sub("regulation-8", "8")

    assert affecting(text) == [["reg.1", "reg.3"]]
  end

  describe "a piece written as words, not marked up (note-piece-in-braces)" do
    # the Fire (Scotland) Act 2005 s.24A, by SSI 2006/367: the feed's
    # affecting provision is art. 8
    test "arts. 1(1) {8}: the piece in braces is the amending one" do
      text =
        "S. 24A inserted (23.6.2006) by #{@cite}, " <>
          sub("article-1-1", "arts. 1(1)", true) <> " {8}"

      assert affecting(text) == [["reg.8"]]
    end

    # the Telecommunications Act 1984 s.89: the feed's is Sch. 1 Pt. 5 Group 19
    test "art. 1(1), {Sch. 1 Pt. 5 Group 19}: a Schedule's Part in braces" do
      text =
        "S. 89 repealed (22.7.2004) by #{@cite}, " <>
          sub("article-1-1", "art. 1(1)", true) <> ", {Sch. 1 Pt. 5 Group 19}"

      assert affecting(text) == [["sch.1.pt.5"]]
    end

    # the Taxes Management Act 1970 s.113(1B), by SI 1993/415: no braces
    test "regs. 1(1), 6: a bare number continues the mark's kind" do
      text = "by #{@cite}, " <> sub("regulation-1-1", "regs. 1(1)", true) <> ", 6"

      assert affecting(text) == [["reg.6"]]
    end

    # the Medical Act 1983 s.19, by SI 2002/3135
    test "the written list ends at its first other words" do
      text =
        "by #{@cite}, " <>
          sub("article-1-2", "arts. 1(2)", true) <>
          "((d), {6(2)} (with transitional provisions in Sch. 2)"

      assert affecting(text) == [["reg.6(2)"]]

      text =
        "by #{@cite}, " <>
          sub("regulation-1", "regs. 1", true) <> ", 6 as amended by S.I. 2000/1, reg. 4"

      assert affecting(text) == [["reg.6"]]
    end

    test "written and marked-up pieces in one list, in order" do
      text =
        "by #{@cite}, " <>
          sub("regulation-1", "regs. 1", true) <>
          ", 4(2), " <> sub("regulation-7", "7") <> " and 9 (with reg. 12)"

      assert affecting(text) == [["reg.4(2)", "reg.7", "reg.9"]]
    end

    test "words that name only the first provision's own pieces: the mark stands" do
      text = "by #{@cite}, " <> sub("regulation-1-4-a", "reg. 1(4)(a)", true) <> "(5)"
      assert affecting(text) == [["reg.1(4)(a)"]]

      text = "by #{@cite}, " <> sub("regulation-1-3", "reg. 1(3)", true) <> "-(9)"
      assert affecting(text) == [["reg.1(3)"]]

      text =
        "by #{@cite}, " <>
          sub("regulation-1-1", "reg. 1(1)", true) <> " (as amended by S.R. 2011/232, reg. 3(2))"

      assert affecting(text) == [["reg.1(1)"]]
    end

    test "a written piece beside a mark on any other provision is not read" do
      text = "by #{@cite}, " <> sub("regulation-4", "regs. 4", true) <> " {8}"
      assert affecting(text) == [["reg.4"]]

      text = "by #{@cite}, " <> sub("section-1", "ss. 1", true) <> ", 9"
      assert affecting(text) == [["s.1"]]
    end
  end
end

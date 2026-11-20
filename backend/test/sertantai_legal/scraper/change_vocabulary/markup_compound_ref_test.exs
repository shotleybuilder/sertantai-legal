defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupCompoundRefTest do
  @moduledoc """
  A note piece's SectionRef that joins sibling provisions in one id
  (Waste, Water and Climate: Markup reader, `compound-sectionref-not-split`):
  "ss. 86(2)(c)(5)(8)" under `section-86-2-c-5-8` names s.86(2)(c), s.86(5)
  and s.86(8), never the one ref s.86(2)(c)(5)(8). Where the parts' forms
  do not settle the split, the piece is carried as given, the joined ref.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.JoinedSectionRef

  defp cite(id, path, text),
    do: ~s|<Citation id="#{id}" URI="http://www.legislation.gov.uk/id/#{path}">#{text}</Citation>|

  defp sub(citation, section_ref, text, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="#{citation}" SectionRef="#{section_ref}"#{mark}>#{text}</CitationSubRef>|
  end

  defp affecting(text) do
    """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para><Text>Some <Addition ChangeId="d30p100" CommentaryRef="c1">words</Addition></Text></P1para></P1>
    </Body><Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>
    </Legislation>
    """
    |> Markup.read("UK_ukpga_2003_1")
    |> Enum.flat_map(fn {_, _, claims} ->
      for c <- claims, c.attribute == :affecting, do: c.value
    end)
  end

  describe "a number climbs back to the number before it" do
    # the Income Tax (Earnings and Pensions) Act 2003 s.446R(4)
    test "ss. 86(2)(c)(5)(8)" do
      assert JoinedSectionRef.pieces("section-86-2-c-5-8") ==
               ["section-86-2-c", "section-86-5", "section-86-8"]
    end

    # the Income Tax (Trading and Other Income) Act 2005 s.628
    test "Sch. 13 para. 33(1)(5)" do
      assert JoinedSectionRef.pieces("schedule-13-paragraph-33-1-5") ==
               ["schedule-13-paragraph-33-1", "schedule-13-paragraph-33-5"]
    end

    test "s. 58(2)(b)(4)(b): each number with its own paragraph" do
      assert JoinedSectionRef.pieces("section-58-2-b-4-b") == ["section-58-2-b", "section-58-4-b"]
    end

    test "Sch. 1 Pt. II paras. 10(2)(a)(5)(a)(6)(7)" do
      assert JoinedSectionRef.pieces("schedule-1-part-II-paragraph-10-2-a-5-a-6-7") == [
               "schedule-1-part-II-paragraph-10-2-a",
               "schedule-1-part-II-paragraph-10-5-a",
               "schedule-1-part-II-paragraph-10-6",
               "schedule-1-part-II-paragraph-10-7"
             ]
    end

    test "S. 63(A1)(1): a lettered number is a number" do
      assert JoinedSectionRef.pieces("section-63-A1-1") == ["section-63-A1", "section-63-1"]

      assert JoinedSectionRef.pieces("article-48-4-5-5A") ==
               ~w(article-48-4 article-48-5 article-48-5A)
    end
  end

  describe "a part beside a part of its own form" do
    test "art. 2(c)(d): two letters" do
      assert JoinedSectionRef.pieces("article-2-c-d") == ["article-2-c", "article-2-d"]
    end

    test "s. 44(1)(b)(c)" do
      assert JoinedSectionRef.pieces("section-44-1-b-c") == ["section-44-1-b", "section-44-1-c"]
    end

    test "art. 3(ddd)(jjj): doubled letters; (y)(z14): an inserted letter" do
      assert JoinedSectionRef.pieces("article-3-ddd-jjj") == ["article-3-ddd", "article-3-jjj"]

      assert JoinedSectionRef.pieces("regulation-2-y-z14") == [
               "regulation-2-y",
               "regulation-2-z14"
             ]
    end

    test "art. 2(b)(iii)(iv): two roman numerals" do
      assert JoinedSectionRef.pieces("article-2-b-iii-iv") == [
               "article-2-b-iii",
               "article-2-b-iv"
             ]
    end
  end

  describe "a nesting is one provision" do
    test "the forms that go down a level" do
      for whole <- ~w(section-86-2-c regulation-8-4-a-ii schedule-2-paragraph-15-a-i-aa
                      regulation-315-c-i section-38-2-ca section-35-A1 regulation-2-z60
                      article-4-1-ee-iii regulation-6-11-aa-i article-2-1-i regulation-9-2-b-B) do
        assert JoinedSectionRef.pieces(whole) == [whole]
      end
    end

    # SI 2019/277 reg. 6(14)(i)(i): paragraph (i), its sub-paragraph (i)
    test "(i)(i): the letter and the numeral under it" do
      assert JoinedSectionRef.pieces("regulation-6-14-i-i") == ["regulation-6-14-i-i"]
    end

    test "an id with no parts, or of another kind" do
      for whole <- ~w(section-86 schedule-2 schedule-2-part-1 part-2-chapter-2
                      schedule-1-rule-3-2 regulation-10-section-36) ++ [""] do
        assert JoinedSectionRef.pieces(whole) == [whole]
      end
    end
  end

  describe "a Schedule joined after a provision" do
    test "s. 22(3) Sch. 9 para. 3(1)" do
      assert JoinedSectionRef.pieces("section-22-3-schedule-9-paragraph-3-1") ==
               ["section-22-3", "schedule-9-paragraph-3-1"]
    end

    test "s. 179 Sch. 19; s. 156(1)(3) Sch. 9 para. 74(3)" do
      assert JoinedSectionRef.pieces("section-179-schedule-19") == ["section-179", "schedule-19"]

      assert JoinedSectionRef.pieces("section-156-1-3-schedule-9-paragraph-74-3") ==
               ["section-156-1", "section-156-3", "schedule-9-paragraph-74-3"]
    end
  end

  describe "a split the forms do not settle is carried as given" do
    test "a letter then a doubled letter: beside (art. 3(y)(aa)) or under (31(14)(g)(bb))" do
      assert JoinedSectionRef.pieces("regulation-5-a-aa") == ["regulation-5-a-aa"]
    end

    test "(i) then a letter: art. 4(i)(j), art. 2(2)(d)(i)(l), reg. 24(3)(a)(i)(b)(ii)" do
      assert JoinedSectionRef.pieces("article-4-i-j") == ["article-4-i-j"]
      assert JoinedSectionRef.pieces("article-2-2-d-i-l") == ["article-2-2-d-i-l"]
      assert JoinedSectionRef.pieces("regulation-24-3-a-i-b-ii") == ["regulation-24-3-a-i-b-ii"]
    end

    test "a roman numeral then a letter: art. 2(g)(ii)(a), S. 166(2)(b)(iii)(c)" do
      assert JoinedSectionRef.pieces("article-2-g-ii-a") == ["article-2-g-ii-a"]
      assert JoinedSectionRef.pieces("section-166-2-b-iii-c") == ["section-166-2-b-iii-c"]
    end

    test "(i)(v), (i)(ii), (gg)(ii), the same part again" do
      for joined <- ~w(article-3-i-v section-12-i-ii article-5-gg-ii article-11-c-c) do
        assert JoinedSectionRef.pieces(joined) == [joined]
      end
    end

    # SI 2008/2504 art. 2: (a) and (i)(viii); SI 2020/1540 reg. 14(6)(b): (i) and (ii)
    test "(a)(i) then a roman numeral: art. 2(a)(i)(viii)" do
      assert JoinedSectionRef.pieces("article-2-a-i-viii") == ["article-2-a-i-viii"]
      assert JoinedSectionRef.pieces("regulation-14-6-b-i-ii") == ["regulation-14-6-b-i-ii"]
      assert JoinedSectionRef.pieces("section-37-4-i-iii") == ["section-37-4-i-iii"]
      assert JoinedSectionRef.pieces("article-2-f-i-i") == ["article-2-f-i-i"]
    end

    test "a number with no number before it: s. 171(b)(2)" do
      assert JoinedSectionRef.pieces("section-171-b-2") == ["section-171-b-2"]
    end
  end

  describe "the reader's pointers" do
    # the Income Tax (Earnings and Pensions) Act 2003 s.446R(4): a copied
    # note (`CopiedNotePieces`), its marked piece three provisions
    test "ss. 86(2)(c)(5)(8) is three amending provisions" do
      text =
        "Words in s. 446R(4) substituted (retrospective to 7.5.2004) by " <>
          cite("d35e5n1", "ukpga/2004/12", "Finance Act 2004 (c. 12)") <>
          ", " <>
          sub("d35e5", "section-86-2-c-5-8", "ss. 86(2)(c)(5)(8)", true) <>
          ", " <> sub("d35e5", "section-86-1", "86(1)")

      assert affecting(text) == [["s.86(2)(c)", "s.86(5)", "s.86(8)"]]
    end

    # the Income Tax (Trading and Other Income) Act 2005 s.628
    test "Sch. 13 para. 33(1)(5) is two" do
      text =
        "Words in s. 628 substituted (retrospective to 6.4.2006) by " <>
          cite("d12e5n1", "ukpga/2006/25", "Finance Act 2006 (c. 25)") <>
          ", " <> sub("d12e5", "schedule-13-paragraph-33-1-5", "Sch. 13 para. 33(1)(5)", true)

      assert affecting(text) == [["sch.13.para.33(1)", "sch.13.para.33(5)"]]
    end

    test "a piece named once: s. 86(1)(2), s. 86(2)" do
      text =
        "Words in s. 22 substituted by " <>
          cite("x1", "ukpga/2004/12", "Finance Act 2004 (c. 12)") <>
          ", " <>
          sub("x1", "section-86-1-2", "s. 86(1)(2)", true) <>
          ", " <> sub("x1", "section-86-2", "s. 86(2)", true)

      assert affecting(text) == [["s.86(1)", "s.86(2)"]]
    end

    test "an unsettled piece is carried as given, beside the note's other pieces" do
      text =
        "Words in s. 22 substituted by " <>
          cite("x1", "uksi/2015/3", "S.I. 2015/3") <>
          ", " <>
          sub("x1", "regulation-5-a-aa", "regs. 5(a)(aa)", true) <>
          ", " <> sub("x1", "regulation-7-2", "7(2)", true)

      assert affecting(text) == [["reg.5(a)(aa)", "reg.7(2)"]]
    end

    test "a nesting is carried whole" do
      text =
        "Words in s. 22 substituted by " <>
          cite("x1", "uksi/2015/3", "S.I. 2015/3") <>
          ", " <> sub("x1", "regulation-8-4-a-ii", "reg. 8(4)(a)(ii)", true)

      assert affecting(text) == [["reg.8(4)(a)(ii)"]]
    end
  end
end

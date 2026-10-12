defmodule SertantaiLegal.Scraper.LatParser.IdsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.Ids

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  test "pnumber/1: through change markup, EU trailing dot dropped" do
    assert Ids.pnumber(el("<P1><Pnumber>1<Addition>A</Addition></Pnumber></P1>")) == "1A"
    assert Ids.pnumber(el("<P1><Pnumber>6.</Pnumber></P1>")) == "6"
    assert Ids.pnumber(el("<P1><Text>x</Text></P1>")) == nil
  end

  test "pnumber/1: a Pnumber with no number (\"...\", empty) takes the element id's (LR-13)" do
    # 1875/17: an N.I. version of s.5 numbered "...", and s.65 with an empty Pnumber
    assert Ids.pnumber(el(~s(<P1 id="section-5"><Pnumber>...</Pnumber></P1>))) == "5"
    assert Ids.pnumber(el(~s(<P1 id="section-65"><Pnumber/></P1>))) == "65"
    assert Ids.pnumber(el(~s(<P3 id="regulation-7-1-dn1"><Pnumber> </Pnumber></P3>))) == "d"
    # a generated id or an empty last segment is no number
    assert Ids.pnumber(el(~s(<P2 id="c7yjk6in3-00031"><Pnumber>...</Pnumber></P2>))) == nil
    assert Ids.pnumber(el(~s(<P2 id="article-14-"><Pnumber/></P2>))) == nil
  end

  test "number/2 strips the prefix word and any dashed heading" do
    assert Ids.number(
             el("<Part><Number>Part III.— Administration of Law</Number></Part>"),
             "Part"
           ) ==
             "III"

    assert Ids.number(el("<Schedule><Number>SCHEDULE 1</Number></Schedule>"), "Schedule") == "1"
    assert Ids.number(el("<Part><Number>PART 3 —</Number></Part>"), "Part") == "3"
    # a spaced hyphen joins a heading too (2010/2214 "PART 2B - WALES"; LR-05)
    assert Ids.number(el("<Part><Number>PART 2B - WALES</Number></Part>"), "Part") == "2B"
    # a heading in the Number element: the number from the id (1965/57; LR-05)
    named = el(~s(<Part id="part-2"><Number>Nuclear site licences</Number></Part>))
    assert Ids.number(named, "Part") == "2"

    assert Ids.number_titled(%{title: nil, text: ""}, named, "Part") ==
             %{title: "Nuclear site licences", text: "Nuclear site licences"}

    assert Ids.number(
             el(~s(<Chapter id="part-1-chapter-3"><Number>General duties</Number></Chapter>)),
             "Chapter"
           ) == "3"

    # an unspaced one is part of the number
    assert Ids.number(el("<Part><Number>Part 2-3</Number></Part>"), "Part") == "2-3"
  end

  test "number_titled/3: an untitled row takes its Number's heading" do
    node = el("<Part><Number>Part III — Administration</Number></Part>")
    row = %{title: nil, text: ""}

    assert Ids.number_titled(row, node, "Part") == %{
             title: "Administration",
             text: "Administration"
           }

    assert Ids.number_titled(%{title: "T", text: "x"}, node, "Part") == %{title: "T", text: "x"}

    wales = el("<Part><Number>PART 2B - WALES</Number></Part>")

    assert Ids.number_titled(%{title: nil, text: ""}, wales, "Part") == %{
             title: "WALES",
             text: "WALES"
           }
  end

  test "title/1 and heading_title/1: Title, else a Schedule's TitleBlock; dots-only is nil" do
    assert Ids.title(el("<Pblock><Title>Re<Emphasis>gulators</Emphasis></Title></Pblock>")) ==
             "Regulators"

    sched = el("<Schedule><TitleBlock><Title>Fees</Title></TitleBlock></Schedule>")
    assert Ids.title(sched) == "Fees"
    assert Ids.heading_title(sched) == "Fees"
    assert Ids.heading_title(el("<Part><Title>. . . .</Title></Part>")) == nil
    assert Ids.title(el("<Part/>")) == nil
    # zero-width characters are not words (LR-05)
    assert Ids.title(el("<Pblock><Title>Fees\u200D and charges</Title></Pblock>")) ==
             "Fees and charges"
  end

  test "first_p1_number/1" do
    assert Ids.first_p1_number(
             el("<Pblock><P1group><P1><Pnumber>4</Pnumber></P1></P1group></Pblock>")
           ) ==
             "4"

    assert Ids.first_p1_number(el("<Pblock/>")) == nil
  end

  test "p2_wrapper?/2: one P2 numbered as its P1" do
    wrap = el("<P1><Pnumber>30</Pnumber><P2><Pnumber>30</Pnumber></P2></P1>")
    assert Ids.p2_wrapper?(wrap, "30")

    two =
      el(
        "<P1><Pnumber>3</Pnumber><P2><Pnumber>1</Pnumber></P2><P2><Pnumber>2</Pnumber></P2></P1>"
      )

    refute Ids.p2_wrapper?(two, "3")
  end
end

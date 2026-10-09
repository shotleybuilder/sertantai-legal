defmodule SertantaiLegal.Scraper.LatParser.IdsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.Ids

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  test "pnumber/1: through change markup, EU trailing dot dropped" do
    assert Ids.pnumber(el("<P1><Pnumber>1<Addition>A</Addition></Pnumber></P1>")) == "1A"
    assert Ids.pnumber(el("<P1><Pnumber>6.</Pnumber></P1>")) == "6"
    assert Ids.pnumber(el("<P1><Text>x</Text></P1>")) == nil
  end

  test "number/2 strips the prefix word and any dashed heading" do
    assert Ids.number(
             el("<Part><Number>Part III.— Administration of Law</Number></Part>"),
             "Part"
           ) ==
             "III"

    assert Ids.number(el("<Schedule><Number>SCHEDULE 1</Number></Schedule>"), "Schedule") == "1"
    assert Ids.number(el("<Part><Number>PART 3 —</Number></Part>"), "Part") == "3"
  end

  test "number_titled/3: an untitled row takes its Number's heading" do
    node = el("<Part><Number>Part III — Administration</Number></Part>")
    row = %{title: nil, text: ""}

    assert Ids.number_titled(row, node, "Part") == %{
             title: "Administration",
             text: "Administration"
           }

    assert Ids.number_titled(%{title: "T", text: "x"}, node, "Part") == %{title: "T", text: "x"}
  end

  test "title/1 and heading_title/1: Title, else a Schedule's TitleBlock; dots-only is nil" do
    assert Ids.title(el("<Pblock><Title>Re<Emphasis>gulators</Emphasis></Title></Pblock>")) ==
             "Regulators"

    sched = el("<Schedule><TitleBlock><Title>Fees</Title></TitleBlock></Schedule>")
    assert Ids.title(sched) == "Fees"
    assert Ids.heading_title(sched) == "Fees"
    assert Ids.heading_title(el("<Part><Title>. . . .</Title></Part>")) == nil
    assert Ids.title(el("<Part/>")) == nil
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

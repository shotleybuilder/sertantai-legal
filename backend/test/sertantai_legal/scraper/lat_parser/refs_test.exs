defmodule SertantaiLegal.Scraper.LatParser.RefsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.Refs

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  test "type_lookup/1: Commentary id → type letter" do
    doc =
      el("""
      <Legislation><Commentaries><Commentary id="key-1" Type="F"/><Commentary id="c2" Type="c"/></Commentaries></Legislation>
      """)

    assert Refs.type_lookup(doc) == %{"key-1" => "F", "c2" => "C"}
  end

  test "collect/2: subtree counts by type; own-level refs only (child rows excluded)" do
    node =
      el("""
      <P1><Pnumber>1</Pnumber><P1para><Text>a<CommentaryRef Ref="key-1"/>
      <Addition CommentaryRef="F2">b</Addition></Text></P1para>
      <P2><Pnumber>1</Pnumber><P2para><Text>c<CommentaryRef Ref="C3"/></Text></P2para></P2>
      <P2><Pnumber>2</Pnumber><P2para><Text>d</Text></P2para></P2></P1>
      """)

    {counts, refs} = Refs.collect(node, %{"key-1" => "F"})
    assert counts == %{f: 1, c: 1, i: nil, e: nil}
    assert refs == ["key-1", "F2"]
  end

  test "collect/2: a wrapper P2's refs are the P1's; quoted provisions' refs stay" do
    node =
      el("""
      <P1><Pnumber>4</Pnumber><P2><Pnumber>4</Pnumber><P2para><Text>x<CommentaryRef Ref="F1"/>
      <BlockAmendment><P1><Pnumber>9</Pnumber><P1para><Text>y<CommentaryRef Ref="F2"/></Text></P1para></P1></BlockAmendment>
      </Text></P2para></P2></P1>
      """)

    {_counts, refs} = Refs.collect(node, %{})
    assert refs == ["F1", "F2"]
  end

  test "placement/2: element and attribute refs under a path" do
    node =
      el(
        ~s(<P1group><Title>T<CommentaryRef Ref="F1"/><Addition CommentaryRef="F2">x</Addition></Title></P1group>)
      )

    assert Refs.placement(node, "./Title") == ["F1", "F2"]
  end
end

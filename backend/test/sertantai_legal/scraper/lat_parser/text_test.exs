defmodule SertantaiLegal.Scraper.LatParser.TextTest do
  use ExUnit.Case, async: true

  import SweetXml, only: [sigil_x: 2]

  alias SertantaiLegal.Scraper.LatSegments
  alias SertantaiLegal.Scraper.LatParser.Text

  defp el(xml), do: SweetXml.parse(xml, quiet: true)
  defp plain(segments), do: LatSegments.plain(segments)

  test "leaf/1: Text blocks in order, lists numbered from Type and Decoration" do
    node =
      el("""
      <P2><Pnumber>1</Pnumber><P2para><Text>In these Regulations—</Text>
      <OrderedList Type="alpha" Decoration="parens"><ListItem><Para><Text>first</Text></Para></ListItem>
      <ListItem><Para><Text>second</Text></Para></ListItem></OrderedList>
      <Text>and closing words.</Text></P2para></P2>
      """)

    assert plain(Text.leaf(node)) ==
             "In these Regulations— (a) first (b) second and closing words."
  end

  test "leaf/1: a table's cells joined with | and rows with ;" do
    node =
      el("""
      <P1><P1para><Text>Table:</Text><Tabular><table xmlns="http://www.w3.org/1999/xhtml"><tbody>
      <tr><td>A</td><td>1</td></tr><tr><td>B</td><td>2</td></tr></tbody></table></Tabular></P1para></P1>
      """)

    # tables are rows of their own in leaf mode
    assert plain(Text.leaf(node)) == "Table:"
  end

  test "a table cell's provisions keep their numbers (2020/1265 table.111; LR-05)" do
    node =
      el("""
      <P1><P1para><Tabular><table xmlns="http://www.w3.org/1999/xhtml"><tbody>
      <tr><td><P><BlockText><Para><Text>Installation in—</Text></Para></BlockText></P>
      <P3 id="x-a"><Pnumber>a</Pnumber><P3para><Text>England;</Text></P3para></P3>
      <P3 id="x-b"><Pnumber>b</Pnumber><P3para><Text>the territorial sea</Text></P3para></P3></td>
      <td>Environment Agency</td></tr></tbody></table></Tabular></P1para></P1>
      """)

    [table] = SweetXml.xpath(node, ~x"//Tabular"l)
    rows = Text.leaf(table)

    assert plain(rows) ==
             "Installation in— (a) England; (b) the territorial sea | Environment Agency"
  end

  test "a cell provision whose text already starts with its number isn't numbered twice (2000/17 sch.6 table.940)" do
    node =
      el("""
      <Tabular><table xmlns="http://www.w3.org/1999/xhtml"><tbody><tr><td>
      <P1 id="p-1"><Pnumber>1</Pnumber><P1para><Text>1. Part A installations.</Text></P1para></P1>
      </td></tr></tbody></table></Tabular>
      """)

    assert plain(Text.leaf(node)) == "1. Part A installations."
  end

  test "leaf/1: amending text is one «…» block with its numbers" do
    node =
      el("""
      <P2><P2para><Text>For section 2 substitute—</Text>
      <BlockAmendment><P1><Pnumber>2</Pnumber><P1para><Text>New text.</Text></P1para></P1></BlockAmendment>
      </P2para></P2>
      """)

    assert plain(Text.leaf(node)) == "For section 2 substitute— «2. New text.»"
  end

  test "structural/1: own text, a gap where child provisions sit" do
    node =
      el("""
      <P1><Pnumber>3</Pnumber><Title>Duties</Title>
      <P2><Pnumber>1</Pnumber><P2para><Text>child</Text></P2para></P2>
      </P1>
      """)

    assert plain(Text.structural(node)) == "Duties"
  end

  test "text_blocks/2 :structural marks child rows as :gap" do
    node =
      el("""
      <P1para><Text>Lead</Text><P2><Pnumber>1</Pnumber><P2para><Text>c</Text></P2para></P2>
      <Text>tail</Text></P1para>
      """)

    assert [lead, :gap, tail] = Text.text_blocks(node, :structural)
    assert plain(lead) == "Lead"
    assert plain(tail) == "tail"
    assert plain(Text.join_blocks([lead, :gap, tail])) == "Lead … tail"
  end

  test "open_lead_in?/1: a lead-in ending in a dash or colon" do
    assert Text.open_lead_in?(el("<P2><P2para><Text>otherwise requires—</Text></P2para></P2>"))
    refute Text.open_lead_in?(el("<P2><P2para><Text>A sentence.</Text></P2para></P2>"))
  end

  test "with_trailing/3: sibling content appended (#174)" do
    node = el("<P2><P2para><Text>means—</Text></P2para></P2>")
    trailing = [el("<Text>closing words.</Text>")]
    segments = LatSegments.text("means—")
    assert plain(Text.with_trailing(segments, trailing, node)) == "means— closing words."
    assert Text.with_trailing(segments, [], node) == segments
  end
end

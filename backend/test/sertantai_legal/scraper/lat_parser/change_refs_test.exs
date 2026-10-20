defmodule SertantaiLegal.Scraper.LatParser.ChangeRefsTest do
  @moduledoc """
  AR-10: older change markup carries its note as a CommentaryRef element
  beside the Addition, not as its attribute (RTA 1988 s.92(10):
  `<Pnumber><CommentaryRef Ref="c13981151"/><Addition ChangeId="d29p11612">`).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser

  @xml ~s(<Legislation><Primary><Body>
    <P1group><Title>Physical fitness</Title><P1 id="section-92"><Pnumber>92</Pnumber>
      <P2 id="section-92-9"><Pnumber>9</Pnumber><P2para><Text><Addition ChangeId="d1" CommentaryRef="c1">Own ref.</Addition></Text></P2para></P2>
      <P2 id="section-92-10"><Pnumber><CommentaryRef Ref="c13981151"/><Addition ChangeId="d29p11612">10</Addition></Pnumber><P2para><Text><Addition ChangeId="d29p11612">A person who holds a licence.</Addition></Text></P2para></P2>
      <P2 id="section-92-11"><Pnumber>11</Pnumber><P2para><Text><Addition ChangeId="d3">No ref anywhere.</Addition></Text></P2para></P2>
    </P1></P1group></Body></Primary></Legislation>)

  defp unjoined(sid) do
    @xml
    |> LatParser.parse(%{law_name: "UK_ukpga_1988_52", type_code: "ukpga", effects: []})
    |> Enum.find(&String.ends_with?(&1.section_id, sid))
    |> Map.get(:unjoined_changes)
  end

  test "a change with no CommentaryRef attribute takes the CommentaryRef just before it, for all its occurrences" do
    assert unjoined(":s.92(10)") == [{"d29p11612", "c13981151", "inserted"}]
  end

  test "a change's own attribute stands; none anywhere stays nil" do
    assert unjoined(":s.92(9)") == [{"d1", "c1", "inserted"}]
    assert unjoined(":s.92(11)") == [{"d3", nil, "inserted"}]
  end
end

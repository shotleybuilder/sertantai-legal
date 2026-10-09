defmodule SertantaiLegal.Scraper.LatParser.WalkerTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EffectIndex
  alias SertantaiLegal.Scraper.LatParser.Walker
  alias SertantaiLegal.Scraper.LatParser.Walker.Ctx

  @xml """
  <Legislation RestrictExtent="E+W"><Secondary><Body>
  <Part><Number>Part 1</Number><Title>General</Title>
  <P1group><Title>Citation</Title><P1 id="regulation-1"><Pnumber>1</Pnumber><P1para><Text>These Regulations may be cited.<CommentaryRef Ref="F1"/></Text></P1para></P1></P1group>
  <P1group><Title>Duties</Title><P1 id="regulation-2"><Pnumber>2</Pnumber>
    <P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para><Text>An employer shall—</Text>
      <P3><Pnumber>a</Pnumber><P3para><Text>assess;</Text></P3para></P3></P2para></P2></P1></P1group>
  </Part></Body></Secondary>
  <Commentaries><Commentary id="F1" Type="F"/></Commentaries></Legislation>
  """

  defp doc, do: SweetXml.parse(@xml, quiet: true)

  test "Ctx.new/3: the law's extent, note types, no effects" do
    ctx = Ctx.new(doc(), %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
    assert %Ctx{default_extent: "E+W", law_extent: "E+W", provision_changes: []} = ctx
    assert ctx.ref_type_lookup == %{"F1" => "F"}
    assert ctx.effects == EffectIndex.empty()
    assert ctx.versions == %{}
  end

  test "walk/2: one raw row per row element, in document order, with its place" do
    ctx = Ctx.new(doc(), %{law_name: "UK_uksi_2024_1", type_code: "uksi"})
    rows = Walker.walk(doc(), ctx)

    assert Enum.map(rows, &{&1.element, &1.part, &1.provision, &1.sub, &1.paragraph}) == [
             {"Part", "1", nil, nil, nil},
             {"P1", "1", "1", nil, nil},
             {"P1", "1", "2", nil, nil},
             {"P2", "1", "2", "1", nil},
             {"P3", "1", "2", "1", "a"}
           ]

    [part, reg1, reg2 | _] = rows
    assert part.title == "General"
    assert reg1.title == "Citation"

    assert Enum.map(rows, & &1.text) == [
             "General",
             "These Regulations may be cited.",
             nil,
             "An employer shall—",
             "assess;"
           ]

    assert reg1.amendment_count == 1
    assert reg1.commentary_refs == ["F1"]
    assert reg2.title == "Duties"
    assert Enum.all?(rows, &(&1.extent_code == "E+W" and &1.from_version == false))
  end
end

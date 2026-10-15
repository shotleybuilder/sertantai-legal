defmodule SertantaiLegal.Scraper.LatParser.HeadingEffectsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @xml ~s(<Legislation><Primary><Body><Part id="part-1"><Number>Part 1</Number>
    <Pblock id="part-1-crossheading-penalties"><Title>Financial penalties</Title>
      <P1group><Title>Penalties</Title><P1 id="section-22A"><Pnumber>22A</Pnumber><P1para><Text>A penalty may be imposed.</Text></P1para></P1></P1group>
    </Pblock></Part></Body></Primary></Legislation>)

  defp parse(effects),
    do:
      LatParser.parse(@xml, %{law_name: "UK_ukpga_1991_56", type_code: "ukpga", effects: effects})

  test "an effect whose text names the cross-heading joins the heading row, as it joins the provisions (LR-29)" do
    e =
      struct!(Effect,
        effect_id: "key-h",
        type: "inserted",
        affecting: "UK_ukpga_2003_37",
        applied: true,
        affected_provisions: "s. 22A and cross-heading",
        affected_refs: ["part-1-crossheading-penalties"]
      )

    rows = parse([e])
    heading = Enum.find(rows, &(&1.section_type == "heading"))
    section = Enum.find(rows, &String.ends_with?(&1.section_id, ":s.22A"))

    assert {"key-h", :ref} in heading.effect_joins
    assert {"key-h", :ref} in section.effect_joins
  end

  test "a heading row joins nothing an effect doesn't name" do
    e =
      struct!(Effect,
        effect_id: "key-o",
        type: "inserted",
        affecting: "UK_x",
        applied: true,
        affected_provisions: "s. 22A",
        affected_refs: ["section-22A"]
      )

    heading = parse([e]) |> Enum.find(&(&1.section_type == "heading"))
    assert heading.effect_joins == []
  end

  test "a change to a provision under the heading doesn't join the heading (asp 2005/5 h.48: ss. 44-46 repealed)" do
    xml =
      ~s(<Legislation><Primary><Body><Part id="part-1"><Number>Part 1</Number>
        <Pblock id="part-1-crossheading-training"><Title>Training</Title>
          <P1group><Title>Training</Title><P1 id="section-44"><Pnumber>44</Pnumber><P1para><Text><Repeal ChangeId="key-r-1" RetainText="true">Training shall be given.</Repeal></Text></P1para></P1></P1group>
        </Pblock></Part></Body></Primary></Legislation>)

    e =
      struct!(Effect,
        effect_id: "key-r",
        type: "repealed",
        affecting: "UK_asp_2012_8",
        applied: true,
        affected_provisions: "s. 44",
        affected_refs: ["section-44"],
        effect_extent: "S"
      )

    rows = LatParser.parse(xml, %{law_name: "UK_asp_2005_5", type_code: "asp", effects: [e]})
    heading = Enum.find(rows, &(&1.section_type == "heading"))
    section = Enum.find(rows, &String.ends_with?(&1.section_id, ":s.44"))

    assert Enum.any?(section.effect_joins, &(elem(&1, 0) == "key-r"))
    assert heading.effect_joins == []
  end
end

defmodule SertantaiLegal.Scraper.LatParser.InlineTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{LatSegments, LatTerritory}
  alias SertantaiLegal.Scraper.LatParser.Inline

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  test "text/1: inline markup joined without extra spaces" do
    segments = Inline.text(el(~s(<Text>The <Term>employer</Term> shall</Text>)))
    assert LatSegments.plain(segments) == "The employer shall"
  end

  test "text/1: an Addition is a change of kind :ins carrying its note ref" do
    [_, {:words, change, inner}] =
      Inline.text(el(~s(<Text>a <Addition ChangeId="c1" CommentaryRef="F1">b</Addition></Text>)))

    assert %LatTerritory.Change{kind: :ins, ref: "F1", change_id: "c1"} = change
    assert LatSegments.plain(inner) == "b"
  end

  test "text/1: a retained Repeal with no partner is :keep" do
    [{:words, change, _}] =
      Inline.text(
        el(~s(<Text><Repeal RetainText="true" Extent="S" CommentaryRef="F2">x</Repeal></Text>))
      )

    assert %LatTerritory.Change{kind: :keep, attribute: "S", ref: "F2"} = change
  end

  test "text/1: a sibling territorial substitution is one :pair" do
    xml =
      ~s(<Text><Repeal RetainText="true" SubstitutionRef="c9" CommentaryRef="F3">old</Repeal><Substitution ChangeId="c9">new</Substitution></Text>)

    [{:pair, change, new, old}] = Inline.text(el(xml))
    assert change.kind == :pair
    assert LatSegments.plain(new) == "new"
    assert LatSegments.plain(old) == "old"
  end

  test "text/1: an InlineAmendment's quotes hold its words, not the source's line breaks (anaw 2016/3 s.5(3)(a))" do
    xml = """
    <Text>after “Body's” insert <InlineAmendment>“
                            general purpose
                          ”</InlineAmendment>;</Text>
    """

    assert LatSegments.plain(Inline.text(el(xml))) == "after “Body's” insert “general purpose”;"
  end

  test "text/1: an InlineAmendment opening a quote it doesn't close loses its trailing break too (2012/3119 reg.20(b))" do
    xml = """
    <Text>substitute <InlineAmendment>“
                regulation 27
              </InlineAmendment>”;</Text>
    """

    assert LatSegments.plain(Inline.text(el(xml))) == "substitute “regulation 27”;"
  end

  test "text/1: a note reference before the closing quote doesn't keep the break (2018/1370 reg.5(2)(a))" do
    xml = """
    <Text>substitute <InlineAmendment>“
                regulation 8 <CommentaryRef Ref="c1"/>
              ”</InlineAmendment>;</Text>
    """

    assert LatSegments.plain(Inline.text(el(xml))) == "substitute “regulation 8”;"
  end

  test "text/1: zero-width characters dropped" do
    assert LatSegments.plain(Inline.text(el("<Text>paragraph\u200D 24ZA</Text>"))) ==
             "paragraph 24ZA"
  end

  test "plain/1: words as one trimmed string" do
    assert Inline.plain(el("<Pnumber>  12A </Pnumber>")) == "12A"
  end

  test "block_change/1 and changed_block/2" do
    keep = Inline.block_change(el(~s(<Repeal RetainText="true"><Text>x</Text></Repeal>)))
    assert keep.kind == :keep
    assert Inline.block_change(el(~s(<Repeal><Text>x</Text></Repeal>))) == nil
    assert Inline.block_change(el(~s(<Substitution ChangeId="c"/>))).kind == :ins

    seg = LatSegments.text("x")
    assert Inline.changed_block(seg, keep) == [{:words, keep, seg}]
    assert Inline.changed_block({:append, seg}, keep) == {:append, [{:words, keep, seg}]}
    assert Inline.changed_block(:gap, keep) == :gap
  end
end

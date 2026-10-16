defmodule SertantaiLegal.Scraper.LatParser.OrphanLocationTest do
  @moduledoc """
  LR-37: an orphan change's locations are structural elements — inline
  elements carrying ids (Citation, CitationSubRef, Term, links) are not
  provisions an effect could land on (eur 2006/1013 Art. 2A-2C).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EffectIndex
  alias SertantaiLegal.Scraper.LatParser.Effects
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  # one insertion of Arts 2A-2B marked by a ChangeId the feed doesn't hold;
  # its heading's markup sits in an id-less P1group under the Title, with an
  # inline Citation carrying an id
  @xml ~s(<Legislation><EUTitle id="title-I">
    <P1group><Title><Addition ChangeId="key-orphan-1" CommentaryRef="key-orphan">Meaning of </Addition><Citation id="c00026"><Addition ChangeId="key-orphan-1" CommentaryRef="key-orphan">Directive 2008/98</Addition></Citation></Title>
      <P1 id="article-2A"><P2 id="article-2A-1"><Text><Addition ChangeId="key-orphan-1" CommentaryRef="key-orphan">text</Addition></Text></P2></P1></P1group>
    <P1group><P1 id="article-2B"><Text><Addition ChangeId="key-orphan-1" CommentaryRef="key-orphan">more</Addition></Text></P1></P1group>
    </EUTitle></Legislation>)

  test "inline ids aren't locations: the orphan takes the one insertion over its provisions" do
    effect =
      struct!(Effect,
        effect_id: "key-range",
        type: "inserted",
        affecting: "UK_uksi_2019_590",
        applied: true,
        affected_provisions: "Art. 2A-2B",
        affected_refs: ["article-2A", "article-2B"],
        affected_ranges: [{"article-2A", "article-2B"}]
      )

    index = Effects.index([effect], SweetXml.parse(@xml, quiet: true), nil)
    assert %Effect{effect_id: "key-range"} = EffectIndex.orphan(index, "key-orphan-1", :ins)
  end
end

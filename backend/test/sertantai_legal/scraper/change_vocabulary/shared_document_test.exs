defmodule SertantaiLegal.Scraper.ChangeVocabulary.SharedDocumentTest do
  @moduledoc """
  The build parses a law's body once and every reader reads that document
  (`readers-reparse-body`): each reader gives the same from the document
  as from the XML it was parsed from.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Application, Expiry, Markup}

  @law "UK_ukpga_2020_7"

  @xml ~S"""
  <Legislation xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata" RestrictExtent="E+W+S+N.I."><ukm:Metadata><ukm:PrimaryMetadata><ukm:EnactmentDate Date="2020-03-25"/></ukm:PrimaryMetadata></ukm:Metadata><Primary><Body>
  <Part id="part-1"><P1 id="section-1"><P1para><Text>This section applies in relation to England only.</Text></P1para></P1>
  <P1 id="section-2" Status="Prospective"><P1para><Text>A duty <Substitution ChangeId="c1" CommentaryRef="c00001">substituted words</Substitution> here.</Text></P1para></P1>
  <P1 id="section-3"><P1para><Text><Repeal ChangeId="c2" CommentaryRef="c00002">. . .</Repeal></Text></P1para></P1></Part>
  <Part id="part-2"><P1 id="section-89"><P1para>
  <P2 id="section-89-1"><P2para><Text>This Act expires at the end of the period of 2 years beginning with the day on which it is passed, subject to subsection (2).</Text></P2para></P2>
  <P2 id="section-89-2"><P2para><Text>Subsection (1) does not apply to section 1.</Text></P2para></P2>
  </P1para></P1></Part>
  </Body></Primary>
  <Commentaries><Commentary id="c00001" Type="F"><Para><Text>Words substituted (1.1.2021) by Some Act 2020 (c. 1), s. 1</Text></Para></Commentary>
  <Commentary id="c00002" Type="F"><Para><Text>S. 3 repealed (1.1.2021) by Some Act 2020 (c. 1), s. 2</Text></Para></Commentary></Commentaries>
  </Legislation>
  """

  setup do
    %{doc: SweetXml.parse(@xml, quiet: true, namespace_conformant: false)}
  end

  test "markup facts, order and claims", %{doc: doc} do
    assert Markup.provisions(doc, @law) == Markup.provisions(@xml, @law)
    assert Markup.order(doc) == Markup.order(@xml)
    assert Markup.read(doc, @law, %{}) == Markup.read(@xml, @law, %{})
    assert Markup.order(doc) != []
    assert Markup.read(doc, @law, %{}) != []
  end

  test "application", %{doc: doc} do
    assert Application.read(doc, @law) == Application.read(@xml, @law)
  end

  test "expiry", %{doc: doc} do
    read = &Expiry.read(&1, @law, nil, "Coronavirus Act 2020", [])
    assert read.(doc) == read.(@xml)
    assert read.(doc) != []
  end
end

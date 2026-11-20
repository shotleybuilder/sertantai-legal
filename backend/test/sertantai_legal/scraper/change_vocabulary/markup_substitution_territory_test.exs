defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupSubstitutionTerritoryTest do
  @moduledoc """
  A substitution made for one territory with the old words kept for
  another: the retained Repeal states where the old words stay, its new
  words (the Addition its SubstitutionRef names, under the same note) where
  the change applies. The change's territory is the new words' (Waste,
  Water and Climate: Markup reader, Decision 3).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  # effect ids are built at run time, never written
  @note "key-" <> String.duplicate("a", 32)
  @other "key-" <> String.duplicate("b", 32)

  defp law(text) do
    """
    <Legislation><Body>
    <P1 id="section-101"><Pnumber>101</Pnumber><P1para>
    <P2 id="section-101-1"><Pnumber>1</Pnumber><P2para><Text>#{text}</Text></P2para></P2>
    </P1para></P1>
    </Body><Commentaries>
    <Commentary id="#{@note}" Type="F"><Para><Text>Words in s. 101(1) substituted (W.) (1.4.2011) by Children and Families (Wales) Measure 2010 (nawm 1), s. 75(3), Sch. 1 para. 24(a)</Text></Para></Commentary>
    <Commentary id="#{@other}" Type="F"><Para><Text>Words in s. 101(1) substituted (E.W.) (16.7.2005) by S.I. 2005/894, Sch. 11 para. 2</Text></Para></Commentary>
    </Commentaries></Legislation>
    """
  end

  defp repeal(id, note, to, extent, text) do
    ~s|<Repeal ChangeId="#{note}-#{id}" CommentaryRef="#{note}" RetainText="true" | <>
      ~s|SubstitutionRef="#{to}" Extent="#{extent}">#{text}</Repeal>|
  end

  defp addition(id, note, extent, text) do
    extent = if extent, do: ~s| Extent="#{extent}"|, else: ""
    ~s|<Addition ChangeId="#{note}-#{id}" CommentaryRef="#{note}"#{extent}>#{text}</Addition>|
  end

  defp territories(text) do
    for {key, _target, claims} <- text |> law() |> Markup.read("UK_ukpga_2006_21"),
        c <- claims,
        c.attribute == :territory,
        do: {key, c.value}
  end

  # Childcare Act 2006 s.101(1)(a): "Words in s. 101(1)(a) substituted (W.)"
  test "old words kept for E., new words for W.: the change applies in W." do
    text =
      "registered under " <>
        repeal(637, @note, "#{@note}-638", "E", "Part 10A of the Children Act 1989") <>
        addition(638, @note, "W", "Part 2 of the Measure") <> " to provide day care"

    assert territories(text) == [{@note, "W"}]
  end

  # the common form (SI 1995/723 and some 500 more): both state the change's
  test "the old and the new words stating one territory: unchanged" do
    text =
      repeal(1, @note, "#{@note}-2", "E+W", "old words") <>
        addition(2, @note, "E+W", "new words")

    assert territories(text) == [{@note, "E+W"}]
  end

  test "new words stating no territory: the retained Repeal's stands" do
    text =
      repeal(1, @note, "#{@note}-2", "S", "old words") <> addition(2, @note, nil, "new words")

    assert territories(text) == [{@note, "S"}]
  end

  # Waste and Emissions Trading Act 2003 s.25(2): the E.W. change's Repeal
  # names the Wales change's new words (a mis-pointed SubstitutionRef). New
  # words under another note are not this change's
  test "new words under another change's note do not give the territory" do
    text =
      repeal(139, @other, "#{@note}-728", "E+W", "for the purpose of the Directive") <>
        repeal(727, @note, "#{@note}-728", "W", addition(728, @note, "W", "within reg. 6"))

    assert {@other, "E+W"} in territories(text)
  end
end

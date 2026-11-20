defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupSubstitutionPairsTest do
  @moduledoc """
  A retained Repeal whose SubstitutionRef names another change's new words
  (a mis-pointed SubstitutionRef) is paired with the new words under its
  own note: each change is one substitution with its own new words (Waste,
  Water and Climate: Markup reader, Decision 3).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  # effect ids are built at run time, never written
  @wales "key-" <> String.duplicate("a", 32)
  @both "key-" <> String.duplicate("b", 32)
  @earlier "key-" <> String.duplicate("c", 32)

  defp law(text) do
    """
    <Legislation><Body>
    <P1 id="section-25"><Pnumber>25</Pnumber><P1para>
    <P2 id="section-25-2"><Pnumber>2</Pnumber><P2para><Text>#{text}</Text></P2para></P2>
    </P1para></P1>
    </Body><Commentaries>
    <Commentary id="#{@wales}" Type="F"><Para><Text>Words in s. 25(2) substituted (W.) (16.7.2005) by The Hazardous Waste (Wales) Regulations 2005 (S.I. 2005/1806), reg. 1(2)(ii), Sch. 11 para. 4</Text></Para></Commentary>
    <Commentary id="#{@both}" Type="F"><Para><Text>Words in s. 25(2) substituted (E.W.) (16.7.2005) by Hazardous Waste (England and Wales) Regulations 2005 (S.I. 2005/894), reg. 1(1)(b), Sch. 11 para. 2</Text></Para></Commentary>
    <Commentary id="#{@earlier}" Type="F"><Para><Text>Words in s. 25(2) inserted (1.4.2004) by S.I. 2004/100, reg. 2</Text></Para></Commentary>
    </Commentaries></Legislation>
    """
  end

  defp doc(text), do: text |> law() |> SweetXml.parse(quiet: true, namespace_conformant: false)

  defp repeal(id, note, to, extent, text) do
    ~s|<Repeal ChangeId="#{note}-#{id}" CommentaryRef="#{note}" RetainText="true" | <>
      ~s|SubstitutionRef="#{to}" Extent="#{extent}">#{text}</Repeal>|
  end

  defp addition(id, note, extent, text),
    do:
      ~s|<Addition ChangeId="#{note}-#{id}" CommentaryRef="#{note}" Extent="#{extent}">#{text}</Addition>|

  defp read(text) do
    for {key, target, claims} <- text |> doc() |> Markup.read("UK_ukpga_2003_33") do
      facts = Map.new(claims, &{&1.attribute, &1.value})
      {key, target, facts.operation, facts[:territory]}
    end
  end

  # Waste and Emissions Trading Act 2003 s.25(2): the Wales change's Repeal
  # is marked round the England and Wales change's, and both name the Wales
  # change's new words
  defp section_25_2 do
    outer = &repeal(727, @wales, "#{@wales}-728", "W", &1)
    inner = &repeal(139, @both, "#{@wales}-728", "E+W", &1)

    "sludge is not hazardous waste " <>
      outer.(inner.("for the purpose of Council Directive 91/689/EEC")) <>
      outer.(inner.(addition(140, @both, "E+W", "within the England and Wales Regulations"))) <>
      outer.(addition(728, @wales, "W", "within the Wales Regulations")) <> "."
  end

  test "a Repeal naming another change's new words is paired with its own" do
    assert Markup.substitutions(doc(section_25_2())) == %{
             "#{@wales}-728" => "#{@wales}-727",
             "#{@both}-140" => "#{@both}-139"
           }
  end

  test "each change is one substitution with its own new words and territory" do
    assert Enum.sort(read(section_25_2())) == [
             {@wales, "s.25(2)", :substituted, "W"},
             {@both, "s.25(2)", :substituted, "E+W"}
           ]
  end

  # Limited Partnerships Act 1907 s.6(3D): a later substitution inside an
  # earlier insertion names the insertion's Addition; the insertion stays
  # its own change
  test "an earlier change's Addition a later Repeal names stays its own change" do
    text =
      addition(
        836,
        @earlier,
        "E+W",
        "inserted words " <>
          repeal(117, @both, "#{@earlier}-836", "E+W", "old words") <>
          addition(118, @both, "E+W", "new words")
      )

    assert Markup.substitutions(doc(text)) == %{"#{@both}-118" => "#{@both}-117"}

    assert Enum.sort(read(text)) == [
             {@both, "s.25(2)", :substituted, "E+W"},
             {@earlier, "s.25(2)", :inserted, "E+W"}
           ]
  end

  # SI 2007/1711 reg.16: the Repeal and its new words under two note ids,
  # and no new words under the Repeal's own: the pair stands as written
  test "new words under another note, none under the Repeal's own: the pair stands" do
    text =
      repeal(1, @both, "#{@wales}-2", "E+W", "old words") <>
        addition(2, @wales, "E+W", "new words")

    assert Markup.substitutions(doc(text)) == %{"#{@wales}-2" => "#{@both}-1"}
  end

  # the Repeal's own new words already named by another Repeal of the note
  # (EPA 1990 s.6(6B)): nothing is left to pair with, the pair stands
  test "the note's own new words named by another Repeal: the pair stands" do
    text =
      repeal(1, @both, "#{@both}-2", "S", "old words") <>
        addition(2, @both, "S", "new words") <>
        repeal(3, @both, "#{@earlier}-9", "S", "more old words") <>
        addition(9, @earlier, "S", "earlier words")

    assert Markup.substitutions(doc(text)) == %{
             "#{@both}-2" => "#{@both}-1",
             "#{@earlier}-9" => "#{@both}-3"
           }
  end

  test "the common form: one note, the pair as written" do
    text =
      repeal(1, @both, "#{@both}-2", "E+W", "old") <> addition(2, @both, "E+W", "new")

    assert Markup.substitutions(doc(text)) == %{"#{@both}-2" => "#{@both}-1"}
  end
end

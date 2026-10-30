defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupLevelTest do
  @moduledoc """
  The markup's level and how sure it is (CV-S08 round 3): a change round
  the number is the whole provision; one covering all of the words, the
  number outside, ranks below the feed; legacy markup's Addition claims no
  operation; a heading's own record beside its provision's whole one claims
  no level; an empty id segment names no level.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.Level

  defp claims(xml, target) do
    xml
    |> Markup.read("UK_uksi_2000_1")
    |> Enum.filter(fn {_, t, _} -> t == target end)
    |> Enum.flat_map(&elem(&1, 2))
    |> Map.new(&{&1.attribute, &1.value})
  end

  test "new words round all of a provision, its number outside, are whole only below the feed" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text><Substitution ChangeId="d29p1">The Control of Noise at Work Regulations 2005</Substitution></Text></P1para></P1></Legislation>)

    c = claims(xml, "reg.3")
    assert c[:level_covering] == :provision
    refute Map.has_key?(c, :level)
  end

  test "a number wrapped but a child left with its own number and text: not the whole provision (NISR 2004/241 reg.3)" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber><Substitution ChangeId="key-a">3</Substitution></Pnumber><P1para><P2 id="regulation-3-1"><Pnumber><Substitution ChangeId="key-a">1</Substitution></Pnumber><P2para><Text><Substitution ChangeId="key-a">New text.</Substitution></Text></P2para></P2><P2 id="regulation-3-2"><Pnumber>2</Pnumber><P2para><Text>Old text.</Text></P2para></P2></P1para></P1></Legislation>)

    # the event's one markup place is its top; the feed places it on reg.3(1)
    assert claims(xml, "reg.3")[:level] == :words
  end

  test "a child inserted later, its number wrapped by its own change, never undoes a whole substitution" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber><Substitution ChangeId="key-a">3</Substitution></Pnumber><P1para><P2 id="regulation-3-1"><Pnumber><Substitution ChangeId="key-a">1</Substitution></Pnumber><P2para><Text><Substitution ChangeId="key-a">New text.</Substitution></Text></P2para></P2><P2 id="regulation-3-1A"><Pnumber><Addition ChangeId="key-b">1A</Addition></Pnumber><P2para><Text><Addition ChangeId="key-b">Later text.</Addition></Text></P2para></P2></P1para></P1></Legislation>)

    assert claims(xml, "reg.3")[:level] == :provision
  end

  test "a legacy Addition inside the text places the change but claims no operation" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text>None of <Addition ChangeId="d29p2">the provisions</Addition> shall apply.</Text></P1para></P1></Legislation>)

    refute Map.has_key?(claims(xml, "reg.3"), :operation)
  end

  test "a legacy Addition round the number is a whole provision inserted (Forestry Act 1967 s.1(4)(a))" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber><Addition ChangeId="d29p2">3</Addition></Pnumber><P1para><Text><Addition ChangeId="d29p2">None of the provisions shall apply.</Addition></Text></P1para></P1></Legislation>)

    c = claims(xml, "reg.3")
    assert {c[:operation], c[:level]} == {:inserted, :provision}
  end

  test "a heading's own record beside its provision's whole record claims no level" do
    sets = [
      {"key-x", "reg.20", Claim.new(:markup, :level, :provision, "a")},
      {"key-x", "reg.20",
       Claim.new(:markup, :level, :words, "b") ++ Claim.new(:markup, :heading, true, "b")}
    ]

    assert [_, {_, _, heading}] = Level.heading_wrappers(sets)
    refute Enum.any?(heading, &(&1.attribute == :level))
  end

  test "an empty id segment names no level (REACH article-2-6--d)" do
    assert Ref.from_clml("article-2-6--d-i", "UK_eur_2006_1907") == "art.Article 2(6)(d)(i)"
  end

  test "EU consolidation markup round the number covers, below the feed (REACH Art 77(2)(e) first sentence)" do
    xml =
      ~s(<Legislation><P3 id="article-77-2-e"><Pnumber><Substitution ChangeId="O003001M009">e</Substitution></Pnumber><P3para><Text><Substitution ChangeId="O003001M009">first sentence replaced;</Substitution> second sentence kept.</Text></P3para></P3></Legislation>)

    c =
      xml
      |> Markup.read("UK_eur_2006_1907")
      |> Enum.flat_map(&elem(&1, 2))
      |> Map.new(&{&1.attribute, &1.value})

    assert c[:level_covering] == :provision
    refute Map.has_key?(c, :level)
  end

  test "an EU list point numbered \"A1.\" is its own row: an addition inside it is placed there, not on the Article (REACH Art 3)" do
    xml =
      ~s(<Legislation><P1 id="article-3"><Pnumber>3</Pnumber><P1para><Text>For the purposes of this Regulation:</Text><OrderedList><ListItem NumberOverride="A1."><Para><Text><Addition ChangeId="key-x">the appropriate authority means the Secretary of State;</Addition></Text></Para></ListItem><ListItem NumberOverride="1."><Para><Text>substance means a chemical element;</Text></Para></ListItem></OrderedList></P1para></P1></Legislation>)

    targets = xml |> Markup.read("UK_eur_2006_1907") |> Enum.map(&elem(&1, 1))
    assert "art.Article 3(A1)" in targets
    refute "art.Article 3" in targets
  end

  test "the version whose own text carries a change, though the versions share an id (SI 2008/1597 reg.14(1))" do
    xml =
      ~s(<Legislation><P1 id="regulation-14"><Pnumber>14</Pnumber><P1para><P2 DocumentURI="http://www.legislation.gov.uk/uksi/2008/1597/regulation/14/1/england+wales+scotland" id="regulation-14-1"><Pnumber>1</Pnumber><P2para><Text>A <Substitution ChangeId="key-gb">GB words</Substitution>.</Text></P2para></P2><P2 DocumentURI="http://www.legislation.gov.uk/uksi/2008/1597/regulation/14/1/ni" id="regulation-14-1"><Pnumber>1</Pnumber><P2para><Text>A <Substitution ChangeId="key-ni">NI words</Substitution>.</Text></P2para></P2></P1para></P1></Legislation>)

    by_key =
      xml
      |> Markup.read("UK_uksi_2008_1597")
      |> Map.new(fn {k, _t, cl} ->
        {k, Enum.find_value(cl, &(&1.attribute == :in_versions && &1.value))}
      end)

    assert by_key["key-gb"] == ["E+W+S"]
    assert by_key["key-ni"] == ["NI"]
  end
end

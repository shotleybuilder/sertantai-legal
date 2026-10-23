defmodule SertantaiLegal.Scraper.LatParser.ItemsTest do
  @moduledoc """
  CV-S02a (#184): a numbered list item with no id of its own, directly
  under a provision, is a row — named as legislation.gov.uk's address for
  it converts (article-57-a → art.Article 57(a)). Items inside a definition
  (an unnumbered item) and items with no level left stay text.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LatParser.Items

  defp el(xml), do: SweetXml.parse(xml, quiet: true)

  defp eu(body) do
    xml = "<Legislation><EURetained><EUBody>#{body}</EUBody></EURetained></Legislation>"
    LatParser.parse(xml, %{law_name: "UK_eur_2099_1", type_code: "eur"})
  end

  defp si(body) do
    xml = "<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>"
    LatParser.parse(xml, %{law_name: "UK_uksi_2099_1", type_code: "uksi"})
  end

  defp ids(rows),
    do: Enum.map(rows, &(&1.section_id |> String.split(":", parts: 2) |> List.last()))

  defp row(rows, id), do: Enum.find(rows, &String.ends_with?(&1.section_id, ":" <> id))
  defp text(row), do: String.replace(row.text, ~r/\s+/, " ")

  @points """
  <P1 id="article-57"><Pnumber>Article 57</Pnumber><P1para>
    <Text>The following substances may be included—</Text>
    <OrderedList Type="alpha" Decoration="parens">
      <ListItem><Para><Text>substances meeting the criteria for carcinogenic;</Text></Para></ListItem>
      <ListItem><Para><Text>substances that are mutagenic:</Text>
        <OrderedList Type="roman" Decoration="parens">
          <ListItem><Para><Text>category 1A;</Text></Para></ListItem>
          <ListItem><Para><Text>category 1B.</Text></Para></ListItem>
        </OrderedList></Para></ListItem>
    </OrderedList>
    <Text>in accordance with Article 58.</Text>
  </P1para></P1>
  """

  describe "Items.rows/2" do
    test "numbered items under a provision, nested numbered items too" do
      rows = @points |> el() |> Items.rows(3)
      assert rows |> Map.values() |> Enum.map(& &1.number) |> Enum.sort() == ~w(a b i ii)
    end

    test "as many levels as are free: none at P4, one under P3" do
      assert @points |> el() |> Items.rows(0) == %{}

      assert @points
             |> el()
             |> Items.rows(1)
             |> Map.values()
             |> Enum.map(& &1.number)
             |> Enum.sort() == ~w(a b)
    end

    test "a NumberOverride is the number, without its decoration (CLP Art. 2 \"15.\")" do
      node =
        el(~s|<P1 id="article-2"><Pnumber>Article 2</Pnumber><P1para><Text>Definitions:</Text>
          <UnorderedList><ListItem NumberOverride="15."><Para><Text>‘substance’ means x;</Text></Para></ListItem>
          <ListItem NumberOverride="(16)"><Para><Text>‘mixture’ means y;</Text></Para></ListItem></UnorderedList>
        </P1para></P1>|)

      assert node |> Items.rows(3) |> Map.values() |> Enum.map(& &1.number) |> Enum.sort() ==
               ~w(15 16)
    end

    test "items inside an unnumbered item (a definition's \"means— (a) (b)\") stay text" do
      node =
        el(
          ~s|<P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para><Text>In these Regulations—</Text>
          <UnorderedList Class="Definition"><ListItem><Para><Text>“workplace” means—</Text>
            <OrderedList Type="alpha"><ListItem><Para><Text>premises;</Text></Para></ListItem>
            <ListItem><Para><Text>land;</Text></Para></ListItem></OrderedList></Para></ListItem>
          </UnorderedList></P2para></P2>|
        )

      assert Items.rows(node, 2) == %{}
    end

    test "an item that already is a provision's content row stops the search (P3 inside)" do
      node =
        el(~s|<P2><Pnumber>1</Pnumber><P2para><Text>An employer shall—</Text>
          <P3><Pnumber>a</Pnumber><P3para><OrderedList Type="roman"><ListItem><Text>x</Text></ListItem></OrderedList></P3para></P3>
          </P2para></P2>|)

      assert Items.rows(node, 2) == %{}
    end
  end

  describe "parse/2: item rows" do
    test "an EU article's points are rows, named as the feed's ids convert" do
      rows = eu(@points)

      assert ids(rows) == [
               "art.Article 57",
               "art.Article 57(a)",
               "art.Article 57(b)",
               "art.Article 57(b)(i)",
               "art.Article 57(b)(ii)"
             ]

      for {xml_id, id} <- [
            {"article-57-a", "art.Article 57(a)"},
            {"article-57-b-ii", "art.Article 57(b)(ii)"}
          ] do
        assert Ref.from_clml(xml_id, "UK_eur_2099_1") == id
        assert row(rows, id)
      end

      # the CLML has no id for them
      assert row(rows, "art.Article 57(a)").xml_id == nil
    end

    test "the parent's text stops where its item rows begin; each item holds its own (no number, as P rows)" do
      rows = eu(@points)

      assert text(row(rows, "art.Article 57")) ==
               "The following substances may be included— … in accordance with Article 58."

      assert text(row(rows, "art.Article 57(a)")) ==
               "substances meeting the criteria for carcinogenic;"

      assert text(row(rows, "art.Article 57(b)")) == "substances that are mutagenic:"
      assert text(row(rows, "art.Article 57(b)(ii)")) == "category 1B."
    end

    test "CLP Art. 2's numbered definitions: art.Article 2(15)" do
      rows =
        eu(~s|<P1 id="article-2"><Pnumber>Article 2</Pnumber><P1para><Text>Definitions:</Text>
          <UnorderedList><ListItem NumberOverride="15."><Para><Text>‘substance’ means x;</Text></Para></ListItem></UnorderedList>
        </P1para></P1>|)

      assert ids(rows) == ["art.Article 2", "art.Article 2(15)"]
      assert Ref.from_clml("article-2-15", "UK_eur_2099_1") == "art.Article 2(15)"
    end

    test "a UK definition's (a), (b) stay in the paragraph's text" do
      rows =
        si(
          ~s|<P1 id="regulation-2"><Pnumber>2</Pnumber>
          <P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para><Text>In these Regulations—</Text>
          <UnorderedList Class="Definition"><ListItem><Para><Text>“workplace” means—</Text>
            <OrderedList Type="alpha"><ListItem><Para><Text>premises;</Text></Para></ListItem></OrderedList></Para></ListItem>
          </UnorderedList></P2para></P2>
          <P2 id="regulation-2-2"><Pnumber>2</Pnumber><P2para><Text>More.</Text></P2para></P2></P1>|
        )

      assert ids(rows) == ["reg.2", "reg.2(1)", "reg.2(2)"]
      assert text(row(rows, "reg.2(1)")) =~ "(a) premises;"
    end

    test "UK points under a paragraph take the next level: reg.4(1)(a)" do
      rows =
        si(
          ~s|<P1 id="regulation-4"><Pnumber>4</Pnumber>
          <P2 id="regulation-4-1"><Pnumber>1</Pnumber><P2para><Text>An employer shall—</Text>
          <OrderedList Type="alpha"><ListItem><Para><Text>assess;</Text></Para></ListItem>
          <ListItem><Para><Text>record.</Text></Para></ListItem></OrderedList></P2para></P2></P1>|
        )

      assert ids(rows) == ["reg.4", "reg.4(1)", "reg.4(1)(a)", "reg.4(1)(b)"]
      keys = Enum.map(rows, & &1.sort_key)
      assert keys == Enum.sort(keys)
    end
  end
end

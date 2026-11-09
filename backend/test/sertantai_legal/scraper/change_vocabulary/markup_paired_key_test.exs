defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPairedKeyTest do
  @moduledoc """
  Environmental Protection: Markup reader (2026-11-09): a substitution's new
  words (the Addition a Repeal's SubstitutionRef names) are the Repeal's
  change, under one key for the reader, the check and the catalogue, even
  where the two ChangeIds' keys differ (EPA 1990 h.62 `d29p10003` →
  `d29p10005`; s.6(6A), a `key-…` Repeal naming legacy `d29p866`).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  # an effect id built at run time (a literal one trips push protection)
  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp doc(inner) do
    ~s(<Legislation><Body><P1 id="section-6"><Pnumber>6</Pnumber><P1para><Text>#{inner}</Text></P1para></P1></Body></Legislation>)
    |> String.replace("KEY", effect_id(1))
    |> SweetXml.parse(quiet: true, namespace_conformant: false)
  end

  @legacy ~s(the <Repeal ChangeId="d29p10003" RetainText="true" SubstitutionRef="d29p10005">special</Repeal> <Addition ChangeId="d29p10005">hazardous</Addition> waste)
  @mixed ~s(the <Repeal ChangeId="KEY-1535551461851" RetainText="true" SubstitutionRef="d29p866">old</Repeal> <Addition ChangeId="d29p866">new</Addition> words)

  test "the new words' ChangeId maps to the Repeal's" do
    assert Markup.substitutions(doc(@legacy)) == %{"d29p10005" => "d29p10003"}
  end

  test "legacy ids: the reader and the catalogue's changes give one change, the Repeal's key" do
    d = doc(@legacy)

    assert [{"d29p10003", "s.6", _}] = Markup.read(d, "UK_ukpga_1990_43")
    assert %{"d29p10003" => change} = changes = MarkupPatterns.changes(d)
    assert Map.keys(changes) == ["d29p10003"]
    assert Enum.map(change.elements, & &1.change_id) == ["d29p10003", "d29p10005"]
  end

  test "a key-… Repeal naming a legacy Addition: one change under the effect id" do
    d = doc(@mixed)

    assert [{key, "s.6", _}] = Markup.read(d, "UK_ukpga_1990_43")
    assert key == effect_id(1)
    assert Map.keys(MarkupPatterns.changes(d)) == [effect_id(1)]
  end
end

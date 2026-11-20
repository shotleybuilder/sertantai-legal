defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupCopiedChangeIdTest do
  @moduledoc """
  Waste, Water and Climate: Markup reader, Decision 3. A ChangeId copied
  from the change beside it with a letter added, under another effect's
  note, is that note's change (SI 2014/2384 art.2(1): the words inserted
  "6.1 and" under one effect, then "environmental statement" substituted
  under a second, its ChangeId the first's with a "w").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.CopiedChangeIds

  @law "UK_uksi_2014_2384"

  # effect ids are built at run time, never written whole
  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp xml(text) do
    (~s(<Legislation><Body><P1 id="article-2"><Pnumber>2</Pnumber>) <>
       ~s(<P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>#{text}</Text></P2para></P2></P1></Body>) <>
       ~s(<Commentaries><Commentary id="KEY1" Type="F"><Para><Text>Words in art. 2\(1\) inserted \(17.3.2015\) by S.I. 2015/723, art. 1, Sch. Table 2</Text></Para></Commentary>) <>
       ~s(<Commentary id="KEY2" Type="F"><Para><Text>Words in art. 2\(1\) substituted \(17.3.2015\) by S.I. 2015/723, art. 1, Sch. Table 2</Text></Para></Commentary></Commentaries></Legislation>))
    |> String.replace("KEY1", effect_id(1))
    |> String.replace("KEY2", effect_id(2))
  end

  defp read(text) do
    text
    |> xml()
    |> Markup.read(@law, %{})
    |> Enum.map(fn {key, target, claims} ->
      {key, target, Map.new(claims, &{&1.attribute, &1.value})}
    end)
    |> Enum.sort()
  end

  defp keys(text), do: text |> read() |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

  defp doc(text), do: text |> xml() |> SweetXml.parse(quiet: true)

  @inserted ~s(reference <Addition ChangeId="KEY1-1788518391375" CommentaryRef="KEY1">6.1 and</Addition> 6.2)
  @copied ~s( to that <Substitution ChangeId="KEY1-1788518391375w" CommentaryRef="KEY2">environmental statement</Substitution> with)

  test "a ChangeId copied with a letter added is keyed by its own note's effect" do
    assert [{inserted, "reg.2(1)", first}, {substituted, "reg.2(1)", second}] =
             read(@inserted <> @copied)

    assert inserted == effect_id(1)
    assert first.note == effect_id(1)
    assert first.operation == :inserted

    assert substituted == effect_id(2)
    assert second.note == effect_id(2)
    assert second.operation == :substituted
  end

  test "the catalogue lists it under the same key" do
    keys = (@inserted <> @copied) |> doc() |> MarkupPatterns.changes() |> Map.keys()
    assert Enum.sort(keys) == [effect_id(1), effect_id(2)]
  end

  test "the copied id alone maps to its note's effect" do
    assert CopiedChangeIds.keys([
             {effect_id(1) <> "-1788518391375", effect_id(1)},
             {effect_id(1) <> "-1788518391375w", effect_id(2)}
           ]) == %{(effect_id(1) <> "-1788518391375w") => effect_id(2)}
  end

  test "a lettered ChangeId under its own effect's note keeps its key" do
    text =
      @inserted <>
        ~s( and <Addition ChangeId="KEY1-1788518391375w" CommentaryRef="KEY1">more</Addition>)

    assert keys(text) == [effect_id(1)]
  end

  test "a lettered ChangeId with no change of the unlettered id keeps its key" do
    assert [{key, "reg.2(1)", claims}] = read(@copied)
    assert key == effect_id(1)
    assert claims.note == effect_id(2)
  end

  test "an unlettered ChangeId under another effect's note keeps its key" do
    # common and not this form: 623 elements in 40 stored laws
    text =
      ~s(<Repeal ChangeId="KEY1-1631629180954" CommentaryRef="KEY2">74</Repeal> and ) <>
        ~s(<Repeal ChangeId="KEY1-1631629180955" CommentaryRef="KEY2">75</Repeal>)

    assert keys(text) == [effect_id(1)]
  end

  test "a copied id with no note keeps its key" do
    text =
      @inserted <> ~s( to <Substitution ChangeId="KEY1-1788518391375w">that</Substitution>)

    assert keys(text) == [effect_id(1)]
  end
end

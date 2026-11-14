defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupNoteKeyTest do
  @moduledoc """
  Fire and OH&S: Markup reader, Decision 1 (a), #188. A legacy change
  whose note is an effect id takes that id as its key, where safe: the
  note is that one change's and no change element's own key. Its
  operation is still read as legacy.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup

  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp xml(body),
    do:
      "<Legislation><Body>#{body}</Body></Legislation>"
      |> String.replace("KEY1", effect_id(1))
      |> String.replace("KEY2", effect_id(2))

  defp read(body) do
    body
    |> xml()
    |> Markup.read("UK_uksi_2008_1597", %{})
    |> Enum.map(fn {key, target, claims} ->
      {key, target, Map.new(claims, &{&1.attribute, &1.value})}
    end)
  end

  @one ~s(<P1 id="regulation-14"><Pnumber>14</Pnumber><P1para><Text>Some <Addition ChangeId="M_F_1" CommentaryRef="KEY1">words</Addition>.</Text></P1para></P1>)

  test "a legacy change with its own effect-id note is keyed by the note" do
    assert [{key, "reg.14", claims}] = read(@one)
    assert key == effect_id(1)
    # still legacy markup: an Addition in the text says nothing of its operation
    refute Map.has_key?(claims, :operation)
  end

  test "the catalogue lists it under the same key" do
    doc = SweetXml.parse(xml(@one), quiet: true)
    assert Map.keys(MarkupPatterns.changes(doc)) == [effect_id(1)]
  end

  test "a note shared by two legacy changes keys neither" do
    body =
      ~s(<P1 id="regulation-14"><Pnumber>14</Pnumber><P1para><Text><Addition ChangeId="M_F_1" CommentaryRef="KEY1">a</Addition> <Addition ChangeId="M_F_2" CommentaryRef="KEY1">b</Addition></Text></P1para></P1>)

    keys = body |> read() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert keys == ["M_F_1", "M_F_2"]
  end

  test "a note that is another element's own key keys nothing" do
    body =
      ~s(<P1 id="regulation-14"><Pnumber>14</Pnumber><P1para><Text><Addition ChangeId="M_F_1" CommentaryRef="KEY2">a</Addition></Text></P1para></P1>) <>
        ~s(<P1 id="regulation-15"><Pnumber>15</Pnumber><P1para><Text><Addition ChangeId="KEY2-9" CommentaryRef="KEY2">b</Addition></Text></P1para></P1>)

    keys = body |> read() |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    assert keys == ["M_F_1", effect_id(2)]
  end
end

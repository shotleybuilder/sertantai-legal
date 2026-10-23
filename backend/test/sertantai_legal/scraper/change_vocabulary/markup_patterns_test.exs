defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatternsTest do
  @moduledoc """
  CV-S03: the markup reader against the change markup's pattern catalogue
  (`test/fixtures/markup_patterns/`, written by `mix lat.markup_patterns`).
  Every example — a real change, as the XML around it — must read as
  `expected.json` holds. A pattern with no status hasn't been reviewed and
  fails. A known limit is `pending: <why>`, its examples holding the
  correct outcome: `mix test --only pending` lists those still failing.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns

  @dir Path.expand("../../../fixtures/markup_patterns", __DIR__)
  @files Map.new(~w(patterns examples expected), &{&1, Path.join(@dir, &1 <> ".json")})
  for {_, path} <- @files, do: @external_resource(path)

  defp load(name) do
    case File.read(@files[name]) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  # compile time: which examples exist, and which belong to a pending pattern
  catalogue = fn name ->
    case File.read(Path.join(@dir, name <> ".json")) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  statuses = Map.get(catalogue.("expected"), "patterns", %{})

  pending =
    for {p, %{"examples" => ids}} <- Map.get(catalogue.("patterns"), "patterns", %{}),
        String.starts_with?(Map.get(statuses, p, ""), "pending"),
        id <- ids,
        into: MapSet.new(),
        do: id

  setup_all do
    %{patterns: load("patterns"), examples: load("examples"), expected: load("expected")}
  end

  describe "the catalogue" do
    test "every pattern is reviewed: accepted, or pending with why", ctx do
      statuses = ctx.expected["patterns"] || %{}
      patterns = ctx.patterns["patterns"] || %{}

      unreviewed = for {p, _} <- patterns, not Map.has_key?(statuses, p), do: p

      assert unreviewed == [],
             "#{length(unreviewed)} patterns not reviewed (mix lat.markup_patterns --accept, then review the diff):\n  " <>
               Enum.join(Enum.sort(unreviewed), "\n  ")
    end

    test "every change classed", ctx do
      assert ctx.patterns["totals"]["unclassified"] in [0, nil]
    end
  end

  describe "examples" do
    for id <- catalogue.("examples") |> Map.keys() |> Enum.sort() do
      if MapSet.member?(pending, id), do: @tag(:pending)

      test id, fixtures do
        %{"law" => law, "key" => key, "xml" => xml} = example = fixtures.examples[unquote(id)]
        expected = fixtures.expected["examples"][unquote(id)]

        assert expected, "#{unquote(id)}: no expected outcome (mix lat.markup_patterns --accept)"

        assert xml
               |> MarkupPatterns.read(key, law, example["xml_ids"] || %{})
               |> MarkupPatterns.outcome() ==
                 expected
      end
    end
  end

  # an effect id built at run time (a literal one trips push protection)
  defp effect_id(n), do: "key-" <> String.duplicate(Integer.to_string(n), 32)

  defp doc(xml), do: SweetXml.parse(xml, quiet: true, namespace_conformant: false)

  describe "shapes" do
    test "id_shape/1: effect ids, uuids and numbers generalised" do
      assert MarkupPatterns.id_shape(effect_id(1) <> "-1473449269178") == "key-HEX-N"
      assert MarkupPatterns.id_shape(effect_id(1) <> "-1790691857434/2") == "key-HEX-N/N"
      assert MarkupPatterns.id_shape("d29p1234") == "dNpN"

      assert MarkupPatterns.id_shape("M_F_5a114256-2b90-4867-a947-1c901326dce3-1623860210593") ==
               "M_F_U-H"

      assert MarkupPatterns.id_shape("V_W_8db1f8e3-48e2-4b5e-a5c0-fd4e2b9e4fd9-f2d3e5c7ab1") ==
               "V_W_U-H"
    end
  end

  describe "changes/1 and example/4" do
    @xml """
    <Legislation><Body>
    <P1 id="section-1"><Pnumber>1</Pnumber><P1para><Text>Some words
      <Substitution ChangeId="KEY-1" CommentaryRef="KEY">new words</Substitution>
      and <Addition ChangeId="OTHER-1" CommentaryRef="OTHER">more</Addition>.</Text></P1para></P1>
    <P1 id="section-2"><Pnumber>2</Pnumber><P1para><Text>Text<CommentaryRef Ref="KEY"/></Text></P1para></P1>
    </Body>
    <Commentaries><Commentary id="KEY" Type="F"><Para><Text>Words substituted by
      <Citation URI="http://www.legislation.gov.uk/id/uksi/2020/1">S.I. 2020/1</Citation></Text></Para></Commentary></Commentaries>
    </Legislation>
    """

    defp xml,
      do: @xml |> String.replace("KEY", effect_id(1)) |> String.replace("OTHER", effect_id(2))

    test "a change is its key's elements and note refs" do
      changes = xml() |> doc() |> MarkupPatterns.changes()
      change = changes[effect_id(1)]

      assert length(change.elements) == 1
      assert length(change.refs) == 1
      assert Map.has_key?(changes, effect_id(2))
    end

    test "an example holds no effect id: its own key-E, others key-E2…" do
      d = doc(xml())
      change = MarkupPatterns.changes(d)[effect_id(1)]
      {example, key} = MarkupPatterns.example(change, d)

      assert key == "key-E"
      refute example =~ ~r/key-[0-9a-f]{32}/
      assert example =~ ~s(ChangeId="key-E-1")
      assert example =~ ~s(ChangeId="key-E2-1")
    end

    test "an example reads as the whole law does" do
      d = doc(xml())
      change = MarkupPatterns.changes(d)[effect_id(1)]
      {example, key} = MarkupPatterns.example(change, d)

      whole =
        d
        |> MarkupPatterns.read(effect_id(1), "UK_ukpga_2000_1")
        |> MarkupPatterns.outcome()
        |> MarkupPatterns.rekey(effect_id(1), key)

      assert example |> MarkupPatterns.read(key, "UK_ukpga_2000_1") |> MarkupPatterns.outcome() ==
               whole
    end

    test "a large example is pruned to the provisions the change touches" do
      d = doc(xml())
      change = MarkupPatterns.changes(d)[effect_id(1)]
      {example, _} = MarkupPatterns.example(change, d, 10, 30_000)

      assert example =~ ~s(id="section-1")
      # section 2 holds only a note ref: kept to the ref, its text cut
      assert example =~ ~s(id="section-2")
      refute example =~ "Text<"
    end
  end
end

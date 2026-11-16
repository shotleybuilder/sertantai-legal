defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelWholeLawTest do
  @moduledoc """
  A law revoked provision by provision is revoked whole (`Label.WholeLaw`;
  Fire and OH&S: Label fold, Decision 3 a): SI 2009/716 revoked SI
  2008/2337 as reg.1 to reg.7, one feed effect each, no level stated. The
  rows under them go with them only when the set is every top-level
  provision of the law, by one law on one day.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence, Fold, Label}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.WholeLaw

  @ids ~w|reg.1 reg.1(1) reg.1(2) reg.2 reg.2(a) reg.3 reg.3(2) reg.3(2)(a)|
  @day ~D[2009-04-06]
  @unstated %{operation: :feed, level: nil}

  defp repeal(target, opts \\ []) do
    %Change{
      key: "k-#{target}",
      target: target,
      claims: [],
      resolved: %Evidence.Resolved{
        operation: :repealed,
        level: :provision,
        territory: nil,
        date: Keyword.get(opts, :date, @day),
        by: Keyword.get(opts, :by, "UK_uksi_2009_716"),
        commenced_by: nil,
        retained: false,
        partial: false,
        saved: false,
        sources: Keyword.get(opts, :sources, @unstated)
      }
    }
  end

  defp status(id, changes, ids \\ @ids) do
    id
    |> Label.fold(
      %{law: "UK_uksi_2008_2337", extent: "E+W+S", start: ~D[2008-10-01]},
      WholeLaw.state(changes, ids)
    )
    |> List.last()
    |> Map.fetch!(:status)
  end

  test "every top-level provision repealed by one law on one day: the rows under them go too" do
    changes = Enum.map(~w(reg.1 reg.2 reg.3), &repeal/1)

    for id <- @ids, do: assert(status(id, changes) == :repealed, id)
  end

  test "one top-level provision missing from the set: the rows under the others stay" do
    changes = Enum.map(~w(reg.1 reg.3), &repeal/1)

    assert WholeLaw.state(changes, @ids) == changes
    assert status("reg.1", changes) == :repealed

    for id <- ~w|reg.1(1) reg.1(2) reg.2 reg.2(a) reg.3(2)(a)|,
        do: assert(status(id, changes) == :in_force, id)
  end

  test "the set made up over two days, or by two laws, is no whole revocation" do
    later = [repeal("reg.1"), repeal("reg.2"), repeal("reg.3", date: ~D[2010-01-01])]
    other = [repeal("reg.1"), repeal("reg.2"), repeal("reg.3", by: "UK_uksi_2010_1")]

    assert WholeLaw.state(later, @ids) == later
    assert WholeLaw.state(other, @ids) == other
    assert status("reg.1(1)", later) == :in_force
    assert status("reg.3(2)", other) == :in_force
  end

  test "a words repeal, or one with no date, repeals no top-level provision" do
    words = repeal("reg.3")
    words = %{words | resolved: %{words.resolved | level: :words}}
    undated = [repeal("reg.1"), repeal("reg.2"), repeal("reg.3", date: nil)]

    assert WholeLaw.whole_days([repeal("reg.1"), repeal("reg.2"), words], @ids) == []
    assert WholeLaw.whole_days(undated, @ids) == []
  end

  test "a Part or Chapter row is no top-level provision; a version's tag is read past" do
    ids = ["pt.1", "pt.1.ch.2", "reg.1", "reg.1(1)", "reg.2[E+W]", "reg.2[S]", "reg.2(a)[S]"]
    changes = [repeal("reg.1"), repeal("reg.2")]

    assert WholeLaw.tops(ids) == ~w(reg.1 reg.2)
    assert WholeLaw.whole_days(changes, ids) == [{"UK_uksi_2009_716", @day}]
    assert status("reg.1(1)", changes, ids) == :repealed
    assert status("reg.2(a)", changes, ids) == :repealed
  end

  test "the repeal's own row is read as before: its level is still unstated" do
    changes = Enum.map(~w(reg.1 reg.2 reg.3), &repeal/1)

    for {before, stated} <- Enum.zip(changes, WholeLaw.state(changes, @ids)) do
      assert stated.resolved.sources.level == nil
      assert stated.resolved.sources.reach == :whole_law
      assert %{stated | resolved: %{stated.resolved | sources: @unstated}} == before
    end
  end

  test "a repeal whose level a source states is left as it is" do
    stated =
      Enum.map(
        ~w(reg.1 reg.2 reg.3),
        &repeal(&1, sources: %{operation: :law_text, level: :law_text})
      )

    assert WholeLaw.state(stated, @ids) == stated
  end

  @xml ~S"""
  <Legislation RestrictExtent="E+W+S"><Secondary><Body>
  <P1 id="regulation-1"><P1para><P2 id="regulation-1-1"><P2para><Text>These Regulations may be cited.</Text></P2para></P2></P1para></P1>
  <P1 id="regulation-2"><P1para><Text>They come into force.</Text></P1para></P1>
  </Body></Secondary><Commentaries/></Legislation>
  """

  describe "the fold's entry (`Fold.labels/5`)" do
    defp last_status(provisions, opts) do
      changes = Enum.map(~w(reg.1 reg.2), &repeal/1)

      "UK_uksi_2008_2337"
      |> Fold.labels(@xml, provisions, changes, opts)
      |> Map.new(fn {id, periods} -> {id, List.last(periods).status} end)
    end

    defp row, do: %{extent: "E+W+S", start: ~D[2008-10-01]}

    test "every row of the law given: the rule is asked" do
      provisions = Map.new(~w|reg.1 reg.1(1) reg.2|, &{&1, row()})

      assert %{"reg.1" => :repealed, "reg.1(1)" => :repealed} =
               last_status(provisions, all_rows: true)
    end

    test "a few rows given (golden's): never asked, they are not the whole law" do
      assert last_status(%{"reg.1(1)" => row()}, []) == %{"reg.1(1)" => :in_force}
    end
  end
end

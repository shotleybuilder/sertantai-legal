defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedTextStagesTest do
  @moduledoc """
  A text change commenced in stages is one change, from its first stage;
  its `stages` claim lists every dated stage as read, in feed order: the
  date, the commencing order, the territory its qualification names or
  excepts, its classes and whether it is partial (Decisions 2 and 3, Fire
  and OH&S: Feed reader). `commenced_by` keeps the first order.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store.Codec
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @id "key-" <> String.duplicate("c", 4)

  defp entry(date, qualification, order),
    do: %{date: date, qualification: qualification, prospective: false, commencing: order}

  defp effect(type, in_force),
    do: %Effect{
      effect_id: @id,
      type: type,
      affected_provisions: "art. 9(6)",
      affected_refs: ["article-9-6"],
      affecting: "UK_ukpga_2022_30",
      in_force: in_force,
      in_force_date: in_force |> Enum.find_value(& &1.date)
    }

  defp read(e), do: Feed.read([e], "UK_uksi_2005_1541")

  defp facts(e) do
    [{@id, _target, claims}] = read(e)
    Map.new(claims, &{&1.attribute, &1.value})
  end

  # the Fire Safety Order 2005 art. 9(6), words substituted by the Building
  # Safety Act 2022 s.156(3)(a): its feed record's in-force entries
  defp fire_safety do
    effect("words substituted", [
      %{date: nil, qualification: nil, prospective: true, commencing: nil},
      entry(~D[2023-10-01], "except in relation to W.", "UK_uksi_2023_362"),
      entry(~D[2023-10-01], "for W.", "UK_wsi_2023_914")
    ])
  end

  test "words substituted on one day by two orders: one change, both orders in its stages" do
    facts = facts(fire_safety())

    assert facts[:stages] == [
             %{
               date: ~D[2023-10-01],
               commenced_by: "UK_uksi_2023_362",
               in_force_for: nil,
               in_force_except: "W",
               qualification: "territory + except",
               partial: true
             },
             %{
               date: ~D[2023-10-01],
               commenced_by: "UK_wsi_2023_914",
               in_force_for: "W",
               in_force_except: nil,
               qualification: "territory",
               partial: true
             }
           ]

    # the one change's own facts are its first stage's, as before
    assert {facts[:operation], facts[:level]} == {:substituted, :words}
    assert facts[:commenced_by] == "UK_uksi_2023_362"
    assert {facts[:date_first], facts[:partial], facts[:date_full]} == {~D[2023-10-01], true, nil}
  end

  test "words substituted for E., then for W.: each stage its date, order and territory" do
    e =
      effect("words substituted", [
        entry(~D[2003-11-18], "for E.", "UK_uksi_2003_2938"),
        entry(~D[2003-11-27], "for W.", "UK_wsi_2003_3034")
      ])

    assert for(s <- facts(e)[:stages], do: {s.date, s.commenced_by, s.in_force_for}) == [
             {~D[2003-11-18], "UK_uksi_2003_2938", "E"},
             {~D[2003-11-27], "UK_wsi_2003_3034", "W"}
           ]
  end

  test "for specified purposes, then fully: the full stage names no territory, not partial" do
    e =
      effect("words repealed", [
        entry(~D[2013-04-25], "for specified purposes", nil),
        entry(~D[2013-10-01], "in so far as not already in force", "UK_uksi_2013_2227")
      ])

    facts = facts(e)

    assert for(s <- facts[:stages], do: {s.date, s.qualification, s.partial}) == [
             {~D[2013-04-25], "purposes", true},
             {~D[2013-10-01], "complete", false}
           ]

    assert facts[:date_full] == ~D[2013-10-01]
  end

  test "an entry the feed repeats without its order is one stage" do
    e =
      effect("words substituted", [
        entry(~D[2003-11-18], "for E.", nil),
        entry(~D[2003-11-18], "for E.", "UK_uksi_2003_2938"),
        entry(~D[2003-11-27], "for W.", "UK_wsi_2003_3034")
      ])

    assert length(facts(e)[:stages]) == 2
  end

  test "a text change with one dated stage carries no stages claim" do
    e = effect("words substituted", [entry(~D[2023-10-01], "for W.", "UK_wsi_2023_914")])
    refute Map.has_key?(facts(e), :stages)
  end

  test "a whole insertion or removal in stages keeps its per-stage records, no stages claim" do
    for type <- ["inserted", "omitted", "coming into force"],
        {_key, _target, claims} <- read(%{fire_safety() | type: type}) do
      refute Enum.any?(claims, &(&1.attribute == :stages))
    end
  end

  test "the stages claim stores and reads back as written, and the catalogue holds it as JSON" do
    [{_, _, claims}] = sets = read(fire_safety())
    stages = Enum.find(claims, &(&1.attribute == :stages)).value

    assert stages |> Codec.encode() |> Jason.encode!() |> Jason.decode!() |> Codec.decode() ==
             stages

    [%{"claims" => held}] = FeedPatterns.outcome(sets)

    assert held |> Jason.encode!() |> Jason.decode!() == held

    assert hd(held["feed.stages"]) == %{
             "date" => "2023-10-01",
             "commenced_by" => "UK_uksi_2023_362",
             "in_force_for" => nil,
             "in_force_except" => "W",
             "qualification" => "territory + except",
             "partial" => true
           }
  end
end

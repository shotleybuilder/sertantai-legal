defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSameDateStagesTest do
  @moduledoc """
  Two in-force entries of one effect on the same date, by different
  commencing orders (one for England, one for Wales), are two stages: each
  its own key, its own order and its own territory (`each-stage-its-own-order`;
  the Fire Safety Order 2005 by the Building Safety Act 2022, 2023-10-01:
  SI 2023/362 except in relation to Wales, WSI 2023/914 for Wales).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @id "key-" <> String.duplicate("a", 4)
  @day ~D[2023-10-01]

  defp england(date \\ @day),
    do: %{
      date: date,
      qualification: "except in relation to W.",
      prospective: false,
      commencing: "UK_uksi_2023_362"
    }

  defp wales(date \\ @day),
    do: %{date: date, qualification: "for W.", prospective: false, commencing: "UK_wsi_2023_914"}

  defp effect(type, in_force),
    do: %Effect{
      effect_id: @id,
      type: type,
      affected_provisions: "art. 9A",
      affected_refs: ["article-9A"],
      affecting: "UK_ukpga_2022_30",
      in_force: in_force,
      in_force_date: hd(in_force).date
    }

  # key → the stage's facts
  defp read(e) do
    for {key, _target, claims} <- Feed.read([e], "UK_uksi_2005_1541"), into: %{} do
      facts = Map.new(claims, &{&1.attribute, &1.value})

      {key,
       {facts[:operation], facts[:commenced_by], facts[:in_force_for], facts[:in_force_except]}}
    end
  end

  test "a commencement: each same-date entry its own stage, order and territory" do
    assert read(effect("coming into force", [england(), wales()])) == %{
             "#{@id}@2023-10-01" => {:commenced, "UK_uksi_2023_362", nil, "W"},
             "#{@id}@2023-10-01~2" => {:commenced, "UK_wsi_2023_914", "W", nil}
           }
  end

  test "a whole insertion: the same-date later stage names its own order (art. 9A)" do
    assert read(effect("inserted", [england(), wales()])) == %{
             @id => {:inserted, "UK_uksi_2023_362", nil, "W"},
             "#{@id}@2023-10-01" => {:commenced, "UK_wsi_2023_914", "W", nil}
           }
  end

  test "a whole removal with no full stage: the second same-date stage names its own order" do
    assert read(effect("omitted", [england(), wales()])) == %{
             @id => {:repealed_in_part, "UK_uksi_2023_362", nil, "W"},
             "#{@id}@2023-10-01" => {:repealed_in_part, "UK_wsi_2023_914", "W", nil}
           }
  end

  test "a whole removal: two same-date partial stages before the full one are two keys" do
    full = %{
      date: ~D[2024-04-06],
      qualification: "in so far as not already in force",
      prospective: false,
      commencing: "UK_uksi_2024_100"
    }

    assert read(effect("omitted", [england(), wales(), full])) == %{
             @id => {:repealed, "UK_uksi_2024_100", nil, nil},
             "#{@id}@2023-10-01" => {:repealed_in_part, "UK_uksi_2023_362", nil, "W"},
             "#{@id}@2023-10-01~2" => {:repealed_in_part, "UK_wsi_2023_914", "W", nil}
           }
  end

  test "same-date entries alike in qualification and order stay one stage" do
    entry = %{date: @day, qualification: "wholly in force", prospective: false, commencing: nil}

    assert Map.keys(read(effect("coming into force", [entry, entry]))) == ["#{@id}@2023-10-01"]
  end

  test "an entry repeated without its order is the same stage (PWA 1991 Sch. 4 para. 104)" do
    entry = %{date: @day, qualification: "wholly in force", prospective: false, commencing: nil}
    ordered = %{entry | commencing: "UK_uksi_2023_362"}

    assert read(effect("coming into force", [entry, ordered])) == %{
             "#{@id}@2023-10-01" => {:commenced, "UK_uksi_2023_362", nil, nil}
           }

    assert read(effect("repealed", [entry, ordered])) == %{
             @id => {:repealed, "UK_uksi_2023_362", nil, nil}
           }
  end

  test "entries repeated without their orders take their twins' (PWA 1991 s. 43)" do
    bare = &%{&1 | commencing: nil}

    assert read(
             effect("coming into force", [bare.(england()), bare.(wales()), england(), wales()])
           ) ==
             read(effect("coming into force", [england(), wales()]))
  end

  test "one entry per date keeps its key" do
    keys = read(effect("coming into force", [england(), wales(~D[2023-11-01])])) |> Map.keys()

    assert Enum.sort(keys) == ["#{@id}@2023-10-01", "#{@id}@2023-11-01"]
  end
end

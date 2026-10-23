defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedFactsTest do
  @moduledoc """
  The feed's facts carried faithfully (CV-S02, the 50-effect check): the
  feed's other words for the verbs (EU types, older abbreviations,
  misspellings), a change within a provision's text at words level, and a
  change in stages kept stage by stage.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.EffectFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(type, in_force \\ []),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: "s. 47(5)",
      affected_refs: ["section-47-5"],
      affecting: "UK_uksi_2013_1667",
      in_force: in_force,
      in_force_date: (List.first(in_force) || %{date: nil}).date
    }

  # {key, operation, level, date, partial} per change the reader makes
  defp read(e) do
    for {key, _target, claims} <- Feed.read([e], "UK_ukpga_1974_37") do
      v = fn a ->
        Enum.find_value(claims, &(&1.attribute == a and {:ok, &1.value})) |> elem_or_nil()
      end

      {key, v.(:operation), v.(:level), v.(:date_first) || v.(:date), v.(:partial)}
    end
  end

  defp elem_or_nil({:ok, v}), do: v
  defp elem_or_nil(_), do: nil

  test "the feed's other words for the verbs" do
    for {type, op} <- [
          {"replacement", :substituted},
          {"addition", :inserted},
          {"completion", :inserted},
          {"deletion", :repealed},
          {"words deleted", :repealed},
          {"word replaced", :substituted},
          {"rev", :repealed},
          {"rev in pt", :repealed_in_part},
          {"rev. in pt.", :repealed_in_part},
          {"rev.in pt. (E)", :repealed_in_part},
          {"partial repeal", :repealed_in_part},
          {"subst (W)", :substituted},
          {"substititued", :substituted},
          {"words subsitituted", :substituted},
          {"omittted", :repealed}
        ] do
      assert [{_, ^op, _, _, _}] = read(effect(type)), type
    end
  end

  test "the parse's own reading is unchanged (EffectKind counts toward ParserVersion)" do
    assert EffectFacts.type("words deleted") == "words omitted"
    assert SertantaiLegal.Scraper.EffectKind.kind("replacement", nil) == "other"
  end

  test "a change within the provision's text is at words level" do
    for type <- [
          "sum substituted",
          "words deleted",
          "entry inserted",
          "comma omitted",
          "figure substituted"
        ],
        do: assert([{_, _, :words, _, _}] = read(effect(type)), type)

    assert [{_, _, :provision, _, _}] = read(effect("substituted"))
  end

  test "a whole removal in stages: in part for specified purposes, then the removal (HSWA 1974 s.47(5), (6))" do
    e =
      effect("omitted", [
        %{date: ~D[2013-04-25], qualification: "for specified purposes", prospective: false},
        %{
          date: ~D[2013-10-01],
          qualification: "in so far as not already in force",
          prospective: false
        }
      ])

    assert Enum.sort(read(e)) == [
             {"key-1", :repealed, :provision, ~D[2013-10-01], nil},
             {"key-1@2013-04-25", :repealed_in_part, :provision, ~D[2013-04-25], nil}
           ]
  end

  test "words substituted in stages: from the first stage, partly, complete at the full one — no commencement" do
    e =
      effect("words substituted", [
        %{date: ~D[2006-04-06], qualification: "for specified purposes", prospective: false},
        %{date: ~D[2008-04-06], qualification: "wholly in force", prospective: false}
      ])

    assert [{"key-1", :substituted, :words, ~D[2006-04-06], true}] = read(e)

    [{_, _, claims}] = Feed.read([e], "UK_ukpga_1974_37")
    assert Enum.find(claims, &(&1.attribute == :date_full)).value == ~D[2008-04-06]
  end

  test "a whole insertion in stages: each later stage commences it (TCPA 1990 s.78(4BA))" do
    e =
      effect("inserted", [
        %{date: ~D[2015-09-06], qualification: "for specified purposes", prospective: false},
        %{date: ~D[2017-03-01], qualification: "wholly in force", prospective: false}
      ])

    assert Enum.sort(read(e)) == [
             {"key-1", :inserted, :provision, ~D[2015-09-06], true},
             {"key-1@2017-03-01", :commenced, :provision, ~D[2017-03-01], false}
           ]
  end

  test "a staged modification is one change (no commencement of the text)" do
    e =
      effect("applied (with modifications)", [
        %{date: ~D[2006-04-06], qualification: "for specified purposes", prospective: false},
        %{date: ~D[2008-04-06], qualification: "wholly in force", prospective: false}
      ])

    assert [{"key-1", nil, _, _, _}] = read(e)
  end

  describe "a commencement carries what the feed says, as read (D5)" do
    defp commenced(qualification, extent \\ "N.I.") do
      e = %{
        effect("coming into force", [
          %{date: ~D[2010-05-19], qualification: qualification, prospective: false}
        ])
        | effect_extent: extent,
          savings: ["s. 3"]
      }

      [{_, _, claims}] = Feed.read([e], "UK_nisr_2010_160")
      Map.new(claims, &{&1.attribute, &1.value})
    end

    test "its effects extent and savings (NISR 2010/160 reg. 30)" do
      c = commenced("wholly in force")
      assert c.effect_extent == "NI"
      assert c.savings == ["s. 3"]
      refute Map.has_key?(c, :in_force_for)
    end

    test "the territory its qualification names, as a fact for the label fold" do
      assert commenced("for E.W.S.").in_force_for == "E+W+S"
      assert commenced("for N.I.").in_force_for == "NI"
      assert commenced("for specified purposes for E.").in_force_for == "E"
      assert commenced("in relation to Wales").in_force_for == "W"
      assert commenced("in relation to England and Wales").in_force_for == "E+W"
      refute Map.has_key?(commenced("for specified purposes"), :in_force_for)
    end
  end
end

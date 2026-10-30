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

    # the partial stage says so: partly in force, its text kept (CV-S09 round 2)
    assert Enum.sort(read(e)) == [
             {"key-1", :repealed, :provision, ~D[2013-10-01], nil},
             {"key-1@2013-04-25", :repealed_in_part, :provision, ~D[2013-04-25], true}
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

    test "a territory excepted is never the territory it comes into force for (review A)" do
      c = commenced("in so far as not already in force except in relation to W.")
      refute Map.has_key?(c, :in_force_for)
      assert c.in_force_except == "W"
      assert c.partial == false

      c = commenced("for specified purposes except in relation to W.")
      assert c.in_force_except == "W"
      assert c.partial == true
      assert commenced("for W. for specified purposes").in_force_for == "W"
    end

    test "a qualification that limits no scope is not partial, its class carried (review E)" do
      for {q, class} <- [
            {"at the end of the day", "time of day"},
            {"at 11.00 p.m.", "time of day"},
            {"with effect in accordance with", "in accordance with"},
            {"retrospective", "retrospective"},
            {"other(no date)", "other"}
          ] do
        c = commenced(q)
        assert c.partial == false, q
        assert c.qualification == class, q
      end

      for q <- [
            "for specified purposes",
            "for W.",
            "with effect in relation to financial years beginning on or after 1.4.2021",
            "for the repeal of s. 3"
          ],
          do: assert(commenced(q).partial == true, q)

      assert commenced("wholly in force").qualification == "complete"
    end
  end

  test "a commencement not yet dated is a change with no date, prospective (review F)" do
    e = %{
      effect("coming into force", [%{date: nil, qualification: nil, prospective: true}])
      | prospective: true
    }

    assert [{"key-1", _target, claims}] = Feed.read([e], "UK_anaw_2016_3")
    c = Map.new(claims, &{&1.attribute, &1.value})
    assert c.operation == :commenced
    assert c.prospective == true
    refute Map.has_key?(c, :date)
  end

  describe "a verb counts only when it says what this effect did to the provision (review B)" do
    test "a verb describing another provision or law is no operation" do
      for type <- [
            "fees confirmed by S.I. 2010/441, Sch. (as substituted)",
            "savings for effects of SSI 2016/141 art. 5(2) by SSI 2016/141 art. 16 (as inserted)",
            "transitional provisions for effects of 2000 c. 38, s. 123J(2) (as inserted by 2017 c. 21, s. 4)",
            "referred to by SI 2001/369 reg. 2C(4) (as inserted)",
            "amendment to earlier commencing S.I. 2007/2194 Sch. 3 para. 23A (as inserted by S.I. 2007/3495 Sch. 5 para. 2(5))",
            "Appointed days (transitional provns added)",
            "repeal of affecting provision 2020 c. 7, Sch. 24",
            "saving (mods) re repeal of certain provns of 1973 c. 65)"
          ] do
        assert [{_, nil, _, _, _}] = read(effect(type)), type
      end
    end

    test "a verb of its own still counts beside one in brackets" do
      assert [{_, :substituted, :words, _, _}] =
               read(effect("words substituted (as amended by S.I. 2001/3)"))

      assert [{_, :substituted, _, _, _}] = read(effect("fees substituted and confirmed"))
    end
  end

  test "the feed's other words for removal, coming into force, renumbering, return (reviews C, D, G)" do
    for {type, op} <- [
          {"words cease to have effect", :repealed},
          {"definition ceases to have effect", :repealed},
          {"words removed", :repealed},
          {"words left out", :repealed},
          {"word omiited", :repealed},
          {"rep in pt", :repealed_in_part},
          {"rep in part (prosp.)", :repealed_in_part},
          {"lapsed by virtue of the omission of enabling provision 2008 c. 29, s. 42", :repealed},
          {"reg. 23 becomes reg. 23(1)", :renumbered},
          {"definition moved", :renumbered},
          {"restored", :inserted},
          {"revived", :inserted}
        ] do
      assert [{_, ^op, _, _, _}] = read(effect(type)), type
    end

    assert [{"key-1@1978-10-01", :commenced, _, _, _}] =
             read(
               effect("coming into operation", [
                 %{date: ~D[1978-10-01], qualification: "wholly in force", prospective: false}
               ])
             )
  end

  describe "one dated stage with a qualification carries what it says (review J)" do
    defp one_stage(type, qualification) do
      e =
        effect(type, [%{date: ~D[2007-04-02], qualification: qualification, prospective: false}])

      [{"key-1", _, claims}] = Feed.read([e], "UK_nisr_2007_31")
      Map.new(claims, &{&1.attribute, &1.value})
    end

    test "a whole removal for specified purposes removes in part (NISR 2007/31)" do
      c = one_stage("revoked", "for specified purposes")
      assert c.operation == :repealed_in_part
      assert c.partial == true
      assert c.qualification == "purposes"
      assert c.date == ~D[2007-04-02]
    end

    test "for S.: the territory carried (asp 2012/8)" do
      c = one_stage("repealed", "for S.")
      assert c.operation == :repealed_in_part
      assert c.in_force_for == "S"
    end

    test "words changed for specified purposes stay a words change, partly" do
      c = one_stage("words substituted", "for specified purposes")
      assert {c.operation, c.level, c.partial} == {:substituted, :words, true}
    end

    test "a qualification that limits nothing: the change whole, its class carried" do
      c = one_stage("repealed", "at 5.00 a.m.")
      assert {c.operation, c.partial, c.qualification} == {:repealed, false, "time of day"}
      assert one_stage("omitted", "wholly in force").operation == :repealed
    end
  end
end

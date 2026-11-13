defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedMadeRecordTest do
  @moduledoc """
  The feed's record of an effect's earlier maker (`key#made`, beside an
  effect whose Type names it: "words inserted by S.I. 2019/696, Sch. 12
  para. 6(b)(ii) (as substituted)", the effect by SI 2020/1460) is the
  maker's: it names the maker's own amending provision, the one the Type
  writes, and none of the later law's facts about itself (its amending
  provision, its territory, its extent clause). So the maker's own text
  joins it in the merge (Fire and OH&S: Feed reader;
  `made-record-carries-later-affecting`). The date stays the effect's: the
  day the words as amended took effect.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @id "key-" <> String.duplicate("b", 32)
  @made @id <> "#made"
  @exit_day ~D[2020-12-31]

  # SI 2008/1597 (Supply of Machinery (Safety) Regulations) reg. 7(2)(f),
  # as its feed records it: the effect by SI 2020/1460 Sch. 3 para. 7(4)(a)
  defp reg_7(type \\ "words inserted by S.I. 2019/696, Sch. 12 para. 6(b)(ii) (as substituted)"),
    do: %Effect{
      effect_id: @id,
      type: type,
      affected_provisions: "reg. 7(2)(f)",
      affected_refs: ["regulation-7-2-f"],
      affecting: "UK_uksi_2020_1460",
      affecting_provisions: "Sch. 3 para. 7(4)(a)",
      affecting_territory: "E+W+S",
      in_force_date: @exit_day,
      in_force: [%{date: @exit_day, qualification: nil, prospective: false}]
    }

  # key → {target → the record's facts}
  defp read(e, order \\ [], extents \\ %{}) do
    for {key, target, claims} <- Feed.read([e], "UK_uksi_2008_1597", order, %{}, extents),
        reduce: %{} do
      acc ->
        facts = Enum.group_by(claims, &{&1.source, &1.attribute}, & &1.value)
        Map.update(acc, key, %{target => facts}, &Map.put(&1, target, facts))
    end
  end

  defp made(e, order \\ [], extents \\ %{}), do: e |> read(order, extents) |> Map.fetch!(@made)

  describe "the made record's amending provision" do
    test "is the maker's own, as the Type writes it — never the later law's" do
      %{"reg.7(2)(f)" => facts} = made(reg_7())

      assert facts[{:feed, :by}] == ["UK_uksi_2019_696"]
      assert facts[{:feed, :affecting}] == [["sch.12.para.6(b)(ii)"]]
    end

    test "the effect's own record keeps the later law and its provision" do
      %{"reg.7(2)(f)" => facts} = reg_7() |> read() |> Map.fetch!(@id)

      assert facts[{:feed, :by}] == ["UK_uksi_2020_1460"]
      assert facts[{:feed, :affecting}] == [["sch.3.para.7(4)(a)"]]
      assert facts[{:law, :territory}] == ["E+W+S"]
    end

    # CLP Art 4(5), by SI 2020/1567 Sch. 2 para. 5
    test "a Schedule paragraph (CLP Art 4(5): S.I. 2019/720, Sch. 2 para. 15(b))" do
      e = %{
        reg_7("words inserted by S.I. 2019/720, Sch. 2 para. 15(b) (as substituted)")
        | affecting: "UK_uksi_2020_1567",
          affecting_provisions: "Sch. 2 para. 5"
      }

      %{"reg.7(2)(f)" => facts} = made(e)
      assert facts[{:feed, :by}] == ["UK_uksi_2019_720"]
      assert facts[{:feed, :affecting}] == [["sch.2.para.15(b)"]]
    end

    # REACH Title 15A, by SI 2020/1577 reg. 6
    test "a whole Schedule (REACH Title 15A: S.I. 2019/758, Sch. 2A (as inserted))" do
      %{"reg.7(2)(f)" => facts} = made(reg_7("inserted by S.I. 2019/758, Sch. 2A (as inserted)"))

      assert facts[{:feed, :by}] == ["UK_uksi_2019_758"]
      assert facts[{:feed, :affecting}] == [["sch.2A"]]
    end

    # the Enterprise Act 2002 Sch. 13 para. 18A-18C, by SI 2020/1347
    test "a Type naming no provision the reader can name gives none" do
      %{"reg.7(2)(f)" => facts} = made(reg_7("inserted by S.I. 2019/203, Sch. (as amended)"))

      assert facts[{:feed, :by}] == ["UK_uksi_2019_203"]
      refute Map.has_key?(facts, {:feed, :affecting})
    end
  end

  describe "the later law's facts about itself" do
    test "its territory and competence are not the maker's" do
      %{"reg.7(2)(f)" => facts} = made(reg_7())

      refute Map.has_key?(facts, {:law, :territory})
      refute Map.has_key?(facts, {:law, :competence})
    end

    test "its extent clause bounds its own record only; the maker's is read at the maker's provision" do
      extents = %{
        "UK_uksi_2020_1460" => %Extent{default: "E+W"},
        "UK_uksi_2019_696" => %Extent{default: "E+W+S+NI"}
      }

      %{@id => %{"reg.7(2)(f)" => own}, @made => %{"reg.7(2)(f)" => made}} =
        read(reg_7(), [], extents)

      assert own[{:law_text, :extent}] == ["E+W"]
      assert made[{:law_text, :extent}] == ["E+W+S+NI"]
    end

    test "the effect's facts stay: its operation, level and the day the words took effect" do
      %{"reg.7(2)(f)" => facts} = made(reg_7())

      assert facts[{:feed, :operation}] == [:inserted]
      assert facts[{:feed, :level}] == [:words]
      assert facts[{:feed, :date}] == [@exit_day]
    end
  end

  describe "every target the effect reaches" do
    # SI 2016/1107 reg. 41(2)-(5): "word substituted by S.I. 2019/696, Sch.
    # 25 para. 26(ac) (as inserted)", by SI 2020/1460 Sch. 3 para. 17(4)(b)
    test "a range the document spans: a made record on each provision" do
      order = ~w(regulation-41 regulation-41-1 regulation-41-2 regulation-41-3
                 regulation-41-4 regulation-41-5 regulation-41-6)

      e = %{
        reg_7("word substituted by S.I. 2019/696, Sch. 25 para. 26(ac) (as inserted)")
        | affected_provisions: "reg. 41(2)-(5)",
          affected_refs: ["regulation-41-2", "regulation-41-5"],
          affected_ranges: [{"regulation-41-2", "regulation-41-5"}],
          affecting_provisions: "Sch. 3 para. 17(4)(b)"
      }

      records = read(e, order)
      targets = ["reg.41(2)", "reg.41(3)", "reg.41(4)", "reg.41(5)"]

      assert records[@id] |> Map.keys() |> Enum.sort() == targets
      assert records[@made] |> Map.keys() |> Enum.sort() == targets

      for {_target, facts} <- records[@made] do
        assert facts[{:feed, :affecting}] == [["sch.25.para.26(ac)"]]
        assert facts[{:feed, :ranged}] == [true]
      end
    end
  end

  describe "no made record" do
    test "a Type naming no earlier maker" do
      assert reg_7("words inserted") |> read() |> Map.keys() == [@id]
    end

    # REACH, SI 2020/1577 on its own earlier provision
    test "a Type naming the affecting law itself" do
      e = %{reg_7("inserted by S.I. 2020/1460, Sch. 3 para. 7 (as inserted)") | type: nil}
      assert e |> read() |> Map.keys() == [@id]

      same = reg_7("words inserted by S.I. 2020/1460, Sch. 3 para. 7(3) (as substituted)")
      assert same |> read() |> Map.keys() == [@id]
    end
  end

  describe "the feed's own effect by the maker" do
    # SI 2014/1638 reg. 2(1): SI 2019/696 Sch. 16 para. 2(2)(m)'s own effect
    # (never applied), beside SI 2020/676 reg. 4(5)(a)'s "words substituted
    # by S.I. 2019/696, Sch. 16 para. 2(2)(m) (as substituted)"
    defp own_effect(provisions, type \\ "words substituted"),
      do: %Effect{
        effect_id: "key-" <> String.duplicate("c", 32),
        type: type,
        affected_provisions: "reg. 2(1)",
        affected_refs: ["regulation-2-1"],
        affecting: "UK_uksi_2019_696",
        affecting_provisions: provisions,
        in_force_date: @exit_day,
        in_force: [%{date: @exit_day, qualification: nil, prospective: false}]
      }

    defp later(type),
      do: %{
        reg_7(type)
        | affected_provisions: "reg. 2(1)",
          affected_refs: ["regulation-2-1"],
          affecting: "UK_uksi_2020_676",
          affecting_provisions: "reg. 4(5)(a)"
      }

    defp keys(effects),
      do:
        effects
        |> Feed.read("UK_uksi_2014_1638")
        |> Enum.map(&elem(&1, 0))
        |> Enum.filter(&String.ends_with?(&1, "#made"))

    @as_substituted "words substituted by S.I. 2019/696, Sch. 16 para. 2(2)(m) (as substituted)"

    test "is the maker's record: no second one for the same instruction" do
      assert keys([own_effect("Sch. 16 para. 2(2)(m)"), later(@as_substituted)]) == []
    end

    # SI 2014/1638 reg. 68(2): the maker's effect names para. 27(c), the
    # Type para. 27(c)(ii)
    test "naming a provision holding the Type's" do
      assert keys([own_effect("Sch. 16 para. 2(2)"), later(@as_substituted)]) == []
    end

    test "another instruction of the maker's leaves the made record" do
      assert keys([own_effect("Sch. 16 para. 2(2)(o)"), later(@as_substituted)]) == [@made]
    end

    # SI 2008/1597 reg. 7(2)(f): the maker's own effect substitutes (para.
    # 6(b)); the insertion (para. 6(b)(ii)) has no effect of its own
    test "another operation leaves the made record" do
      inserted = "words inserted by S.I. 2019/696, Sch. 16 para. 2(2)(m) (as substituted)"
      assert keys([own_effect("Sch. 16 para. 2(2)"), later(inserted)]) == [@made]
    end

    # CLP Art 2(10): SI 2019/720 Sch. 2 para. 14(a)'s own effect substitutes
    # words; SI 2020/1567's "substituted by S.I. 2019/720, Sch. 2 para.
    # 14(a) (as substituted)" is the whole of Art 2(10), reaching (a) and (b)
    test "a words change is never the record of a whole-provision change" do
      whole = "substituted by S.I. 2019/696, Sch. 16 para. 2(2)(m) (as substituted)"
      assert keys([own_effect("Sch. 16 para. 2(2)(m)"), later(whole)]) == [@made]
      assert keys([own_effect("Sch. 16 para. 2(2)(m)", "substituted"), later(whole)]) == []
    end

    test "a word and words are one level" do
      word = "word substituted by S.I. 2019/696, Sch. 16 para. 2(2)(m) (as substituted)"
      assert keys([own_effect("Sch. 16 para. 2(2)(m)"), later(word)]) == []
    end

    test "on another provision, or another day, leaves the made record" do
      elsewhere = %{own_effect("Sch. 16 para. 2(2)(m)") | affected_refs: ["regulation-3"]}
      earlier = %{own_effect("Sch. 16 para. 2(2)(m)") | in_force_date: ~D[2019-04-01]}

      assert keys([elsewhere, later(@as_substituted)]) == [@made]
      assert keys([earlier, later(@as_substituted)]) == [@made]
    end
  end

  describe "in the merge" do
    defp law_text(key, target, operation, law),
      do:
        {key, target,
         for(
           {s, a, v} <- [
             {:law_text, :operation, operation},
             {:law_text, :level, :words},
             {:law_text, :by, law},
             {:commencement, :date, @exit_day}
           ],
           do: %Claim{source: s, attribute: a, value: v, ref: key}
         )}

    test "the maker's own text joins its made record, not left apart (SI 2019/696 Sch. 12 para. 6(b)(ii))" do
      text = "UK_uksi_2019_696:schedule-12-paragraph-6-b-ii"

      changes =
        Merge.merge(
          Feed.read([reg_7()], "UK_uksi_2008_1597") ++
            [law_text(text, "reg.7(2)(f)", :inserted, "UK_uksi_2019_696")]
        )

      assert [made] = Enum.filter(changes, &(&1.key == @made))
      assert text in made.aliases
      assert Change.value(made, :law_text, :by) == "UK_uksi_2019_696"
      refute Enum.any?(changes, &(&1.key == text))
    end

    test "the later law's own text still joins the effect's own record" do
      text = "UK_uksi_2020_1460:schedule-3-paragraph-7-4-a"

      changes =
        Merge.merge(
          Feed.read([reg_7()], "UK_uksi_2008_1597") ++
            [law_text(text, "reg.7(2)(f)", :inserted, "UK_uksi_2020_1460")]
        )

      assert [own] = Enum.filter(changes, &(&1.key == @id))
      assert text in own.aliases
    end
  end
end

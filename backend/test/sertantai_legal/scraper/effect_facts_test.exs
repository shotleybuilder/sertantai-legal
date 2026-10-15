defmodule SertantaiLegal.Scraper.EffectFactsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EffectFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @today ~D[2026-10-09]

  defp fx(fields),
    do:
      struct!(
        Effect,
        Keyword.merge([type: "inserted", affecting: "UK_x", applied: true], fields)
      )

  defp at(date, q \\ nil),
    do: %{date: date, prospective: false, qualification: q, applied: true}

  describe "kind/2" do
    test "the note's code_type decides commencement and modification; else the type's first verb" do
      assert EffectFacts.kind("coming into force", "commencement") == "commenced"
      assert EffectFacts.kind("applied (with modifications)", "modification") == "modified"
      assert EffectFacts.kind("words substituted", "amendment") == "substituted"
      assert EffectFacts.kind("Words added", "amendment") == "inserted"
      assert EffectFacts.kind("word omitted", "amendment") == "repealed"
      assert EffectFacts.kind("coming into force", nil) == "commenced"
      assert EffectFacts.kind("expires", "amendment") == "other"
    end

    test "a change to an earlier amending or affecting provision changes another law's provision, not this text (LR-24)" do
      assert EffectFacts.kind(
               "amendment to earlier affecting provision SI 1995/3128 reg. 10(2) (as substituted)",
               nil
             ) == "other"

      assert EffectFacts.kind(
               "omitted in earlier amending provision 2023 c. 55, Sch. 8 para. 39(3)(a)",
               nil
             ) == "other"

      assert EffectFacts.kind(
               "Art. 5(1)-(3) renumbered as Art. 5(2)-(2B) in earlier amending provision S.I. 2019/720",
               nil
             ) == "other"

      assert EffectFacts.kind("words substituted", nil) == "substituted"
    end

    test "a modification's own verb wins over a trailing '(as inserted)' (LR-24)" do
      assert EffectFacts.kind("applied in part by S.I. 2023/1 reg. 4 (as inserted)", nil) ==
               "other"

      assert EffectFacts.kind("modified by S.I. 2003/281", nil) == "other"
      assert EffectFacts.kind("excluded (as substituted)", nil) == "other"
      assert EffectFacts.kind("functions transferred (as amended)", nil) == "other"
      assert EffectFacts.kind("power to amend conferred", nil) == "other"
      assert EffectFacts.kind("extended (with modifications)", nil) == "other"
      assert EffectFacts.kind("words inserted (with savings)", nil) == "inserted"
    end
  end

  test "effect_fact/1: an effect's facts, keyed by its effect id" do
    e =
      fx(
        effect_id: "effect-1",
        type: "coming into force",
        affecting: "UK_uksi_2010_1",
        in_force: [at(~D[2010-10-01])]
      )

    assert %{
             effect: "commenced",
             effective_from: ~D[2010-10-01],
             changed_by: "UK_uksi_2010_1",
             change_id: "effect-1",
             source: :effect
           } = EffectFacts.effect_fact(e)
  end

  describe "partial?/3" do
    test "for specified purposes, nothing completing it: partial" do
      e = fx(type: "coming into force", in_force: [at(~D[2015-01-01], "for specified purposes")])
      assert EffectFacts.partial?([e], "E+W", @today)
    end

    test "completed by a later entry or a separate commencement effect" do
      staged =
        fx(
          in_force: [
            at(~D[2015-01-01], "for specified purposes"),
            at(~D[2016-01-01], "in force in so far as not already in force")
          ]
        )

      refute EffectFacts.partial?([staged], "E+W", @today)

      first =
        fx(type: "coming into force", in_force: [at(~D[2015-01-01], "for specified purposes")])

      rest = fx(type: "coming into force", in_force: [at(~D[2016-01-01], "wholly in force")])
      refute EffectFacts.partial?([first, rest], "E+W", @today)

      unqualified = fx(type: "coming into force", in_force: [at(~D[2016-01-01])])
      refute EffectFacts.partial?([first, unqualified], "E+W", @today)
    end

    test "a completing step after today hasn't happened yet" do
      e =
        fx(
          in_force: [
            at(~D[2026-01-01], "for specified purposes"),
            at(~D[2027-04-01], "in force in so far as not already in force")
          ]
        )

      assert EffectFacts.partial?([e], "E+W", @today)
    end

    test "territorial commencement is partial while another territory's entry is still to come (Building Safety Act; Jason 2026-10-09)" do
      w_pending = %{date: nil, prospective: true, qualification: "for W.", applied: false}
      e_only = fx(in_force: [at(~D[2022-06-28], "for E."), w_pending])
      assert EffectFacts.partial?([e_only], "E+W", @today)

      both = fx(in_force: [at(~D[2022-06-28], "for E."), at(~D[2023-09-05], "for W.")])
      refute EffectFacts.partial?([both], "E+W", @today)

      # W dated after today: still to come
      w_later = fx(in_force: [at(~D[2022-06-28], "for E."), at(~D[2027-01-01], "for W.")])
      assert EffectFacts.partial?([w_later], "E+W", @today)

      # "for E. in so far as not already in force" completes E only
      e_rest =
        fx(in_force: [at(~D[2022-06-28], "for E. in so far as not already in force"), w_pending])

      assert EffectFacts.partial?([e_rest], "E+W", @today)
      refute EffectFacts.partial?([e_rest], "E", @today)
    end

    test "a territory the effect doesn't mention is a gap in the feed, not \"not in force\" (1995/21 s.136A: only \"1.4.2015 for S.\" listed)" do
      s_only =
        fx(
          in_force: [
            %{date: nil, prospective: true, qualification: nil, applied: true},
            at(~D[2015-04-01], "for S.")
          ]
        )

      refute EffectFacts.partial?([s_only], "E+W+S+NI", @today)
    end

    test "\"except in relation to W.\" is the rest of the extent (1984/55 s.30A: E 6.4.2023, W in stages to 1.7.2026)" do
      e =
        fx(
          in_force: [
            at(~D[2023-04-06], "except in relation to W."),
            at(~D[2023-09-05], "for W. for specified purposes"),
            at(~D[2026-07-01], "for W. in so far as not already in force")
          ]
        )

      refute EffectFacts.partial?([e], "E+W", @today)
      assert EffectFacts.partial?([e], "E+W", ~D[2025-01-01])
    end

    test "each amendment is judged alone: one in force everywhere doesn't complete another (1984/55 s.91A(5))" do
      ins = fx(type: "inserted", in_force: [at(~D[2006-02-01], "for specified purposes")])

      words =
        fx(
          type: "words substituted",
          in_force: [at(~D[2022-06-28], "for E."), at(~D[2023-09-05], "for W.")]
        )

      assert EffectFacts.partial?([ins, words], "E+W", @today)
    end

    test "modifications and repeals don't commence anything; unreadable qualifiers count neither way" do
      applied =
        fx(
          type: "applied (with modifications)",
          in_force: [at(~D[2015-01-01], "for specified purposes")]
        )

      refute EffectFacts.partial?([applied], "E+W", @today)

      repeal = fx(type: "repealed", in_force: [at(~D[2015-01-01], "for specified purposes")])
      refute EffectFacts.partial?([repeal], "E+W", @today)

      pilot = fx(in_force: [at(~D[2015-01-01], "for E. in relation to the pilot areas")])
      refute EffectFacts.partial?([pilot], "E+W", @today)
    end
  end
end

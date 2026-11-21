defmodule SertantaiLegal.Scraper.Commencement.AmendingDatingFormsTest do
  @moduledoc """
  When an amending provision came into force, from the amending law's own
  words (LAT Change Pipeline, step Commencement reader; the Waste, Water
  and Climate round, amending-law dating):

  - a purpose-limited day is a first stage, never the whole start, though
    the register holds that day as the law's coming into force (the
    Merchant Shipping (Oil Pollution) (Bunkers Convention) Regulations
    2006, SI 2006/1244 reg.1(2), (4));
  - a provision the law deems to have come into force before it was
    passed is not the law's first start (the Merchant Shipping and
    Maritime Security Act 1997 s.28(5)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmenderStart, AmendingCommencement}
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}

  @bunkers_2006 [
    %{section_id: "UK_x:reg.1", text: "", part: nil, chapter: nil},
    %{
      section_id: "UK_x:reg.1(1)",
      text:
        "These Regulations may be cited as the Merchant Shipping (Oil Pollution) (Bunkers Convention) Regulations 2006.",
      part: nil,
      chapter: nil
    },
    %{
      section_id: "UK_x:reg.1(2)",
      text:
        "Subject to paragraph (4), these Regulations shall come into force on the day on which the International Convention on Civil Liability for Bunker Oil Pollution Damage 2001 comes into force in respect of the United Kingdom.",
      part: nil,
      chapter: nil
    },
    %{
      section_id: "UK_x:reg.1(3)",
      text:
        "The date on which these Regulations are to come into force shall be notified by the Secretary of State in the London, Edinburgh and Belfast Gazettes.",
      part: nil,
      chapter: nil
    },
    %{
      section_id: "UK_x:reg.1(4)",
      text:
        "These Regulations shall come into force on 15th July 2006 so far as may be necessary for the purpose of enabling certificates under section 164(1A) of the Merchant Shipping Act 1995 (as inserted by regulation 18) to be issued before the date mentioned in paragraph (2).",
      part: nil,
      chapter: nil
    },
    %{section_id: "UK_x:reg.18", text: "", part: nil, chapter: nil},
    %{section_id: "UK_x:reg.19", text: "", part: nil, chapter: nil}
  ]

  describe "SI 2006/1244 reg.1: the register's day is the purpose-limited stage's" do
    setup do
      input = %{
        type_code: "uksi",
        rows: @bunkers_2006,
        made: ~D[2006-05-02],
        lrt_date: ~D[2006-07-15]
      }

      %{rules: OwnClause.rules("UK_x", input)}
    end

    test "no rule brings the Regulations fully into force on 15th July 2006", %{rules: rules} do
      refute Enum.any?(rules, &(&1.when == {:date, ~D[2006-07-15]} and &1.purposes == nil))
    end

    test "reg.1(2)'s day, the Convention's, is the whole start: undated", %{rules: rules} do
      assert [general] = Enum.filter(rules, &(&1.scope == :all))
      assert {:appointed, _} = general.when
      assert general.source.ref == "reg.1(2)"
    end

    test "regulation 19 is partly in force from 15th July 2006, never fully", %{rules: rules} do
      result = AmendingCommencement.commencement(rules, "reg.19(7)")
      assert result.full_from == nil
      assert result.partial_from == ~D[2006-07-15]
    end
  end

  describe "the register's day stays the start where no stage shares it" do
    test "a general clause tied to another event, with no purpose-limited stage on the day" do
      rows = Enum.reject(@bunkers_2006, &(&1.section_id == "UK_x:reg.1(4)"))
      input = %{type_code: "uksi", rows: rows, made: ~D[2006-05-02], lrt_date: ~D[2008-11-21]}

      assert [general] = "UK_x" |> OwnClause.rules(input) |> Enum.filter(&(&1.scope == :all))
      assert general.when == {:date, ~D[2008-11-21]}
      assert general.treatment == :lrt_metadata
    end
  end

  describe "1997 c.28 s.28(5): a provision deemed in force before the Act was passed" do
    @deemed "Subsection (4) shall be taken to have come into force on 15th September 1996."
    @passed "Sections 5, 8, 11, 12, 13, 16, 24, 28 and 30, this section and Schedule 2 and paragraph 16 of Schedule 6 shall come into force on the day on which this Act is passed."

    defp rule(scope, date, ref, text),
      do:
        Rule.new(
          commences: "UK_x",
          scope: scope,
          when: {:date, date},
          source: %{law: "UK_x", ref: ref, text: text},
          treatment: :provision_dated
        )

    test "the Act's first start is the day it was passed, not the deemed day" do
      rules = [
        rule(["s.28(4)"], ~D[1996-09-15], "s.28(5)", @deemed),
        rule(["s.5", "s.8", "s.28"], ~D[1997-03-19], "s.31(4)", @passed)
      ]

      assert AmenderStart.first_start(rules) == ~D[1997-03-19]
    end

    test "\"is treated as having come into force on\" (2023 c.30 s.348(4)) is deemed too" do
      rules = [
        rule(
          ["s.348(2)"],
          ~D[2022-06-06],
          "s.348(4)",
          "The amendment made by subsection (2) is treated as having come into force on 6 June 2022."
        ),
        rule(:all, ~D[2023-07-11], nil, nil)
      ]

      assert AmenderStart.first_start(rules) == ~D[2023-07-11]
    end

    test "the feed's record of the deemed provision on the deemed day is not the first start" do
      feed = %{
        rule(["s.348(2)"], ~D[2022-06-06], "s.348(2)", nil)
        | treatment: :feed_commencement
      }

      rules = [
        rule(
          ["s.348(2)"],
          ~D[2022-06-06],
          "s.348(4)",
          "The amendment made by subsection (2) is treated as having come into force on 6 June 2022."
        ),
        feed,
        rule(:all, ~D[2023-07-11], nil, nil)
      ]

      assert AmenderStart.first_start(rules) == ~D[2023-07-11]
    end

    test "a law whose only dated rule is a deemed day has no first start" do
      assert AmenderStart.first_start([rule(["s.28(4)"], ~D[1996-09-15], "s.28(5)", @deemed)]) ==
               nil
    end
  end
end

defmodule SertantaiLegal.Scraper.LawStart.InputTest do
  @moduledoc """
  What `LawStart` decides a law's start from, read once for both paths: the
  old register's commencement collector and the change vocabulary's build
  (Maritime Safety: Switch-over, the start-from-old-register bug).
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Scraper.{ChangeCollector, LawStart}

  test "a law the store doesn't hold: the type, the rows as given, no dates" do
    rows = [
      %{
        section_id: "UK_uksi_2099_9:reg.1",
        text: "These Regulations come into force on 1st May 2099."
      }
    ]

    assert %{type_code: "uksi", lrt_date: nil, made: nil, clml_head: nil, rows: [row]} =
             LawStart.Input.of("UK_uksi_2099_9", rows)

    assert row.section_id == "UK_uksi_2099_9:reg.1"
    assert row.text =~ "1st May 2099"
  end

  test "the old collector's input is the same reader's" do
    rows = [%{section_id: "UK_uksi_2099_9:reg.1", text: "x"}]

    assert ChangeCollector.law_start_input("UK_uksi_2099_9", rows) ==
             LawStart.Input.of("UK_uksi_2099_9", rows)
  end

  test "a law's rows in document order, from its LAT rows" do
    assert LawStart.Input.rows("UK_uksi_2099_9") == []
  end

  test "the build resolves the start from the same input (ChangeVocabulary.Build.start/1)" do
    input = LawStart.Input.of("UK_uksi_2099_9", LawStart.Input.rows("UK_uksi_2099_9"))

    assert SertantaiLegal.Scraper.ChangeVocabulary.Build.start("UK_uksi_2099_9") ==
             LawStart.resolve(input)
  end

  describe "named_date/2: another law's provision dated by a rule naming it" do
    alias SertantaiLegal.Scraper.Commencement.Rule

    defp rule(scope, date, treatment),
      do:
        Rule.new(
          commences: "UK_ukpga_1996_56",
          scope: scope,
          when: {:date, date},
          source: %{law: "UK_ukpga_1996_56", ref: "s.583(2)", text: "x"},
          treatment: treatment
        )

    test "a rule naming the provision dates it (Water Act 2003 s.7(3), SI 2006/641)" do
      rules = [rule(["s.7(3)"], ~D[2018-01-01], :order_article)]
      assert LawStart.Input.named_date(rules, "s.7(3)") == ~D[2018-01-01]
    end

    # a provision inserted later is no part of the law's own start
    # (Education Act 1996 s.562J, WSI 2016/413 reg.2(3))
    test "the law's whole-law start never dates a provision" do
      rules = [rule(:all, ~D[1996-11-01], :clause_date)]
      assert LawStart.Input.named_date(rules, "s.562J") == nil
    end
  end
end

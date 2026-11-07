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
end

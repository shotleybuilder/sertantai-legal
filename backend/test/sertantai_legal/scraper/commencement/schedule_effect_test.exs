defmodule SertantaiLegal.Scraper.Commencement.ScheduleEffectTest do
  @moduledoc """
  A Schedule comes into force with the provision that gives it effect
  (CV-S08 round 2): Energy Act 2013 Sch.12 with s.116(1) in Part 3, which SI
  2014/251 commences; NISR 2003/152 Sch.7 Pt II with reg.15(2).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw
  alias SertantaiLegal.Scraper.Commencement.{Rule, ScheduleEffect}

  @act "UK_ukpga_2013_32"

  test "\"Schedule N … has effect\" and \"amended in accordance with that Part\" are read" do
    rows = [
      %{
        section_id: "#{@act}:s.116(1)",
        text: "Schedule 12 (minor and consequential amendments related to Part 3) has effect.",
        part: "3",
        chapter: nil
      },
      %{
        section_id: "UK_nisr_2003_152:reg.15(2)",
        text:
          "The statutory provisions referred to in Part II of Schedule 7 shall be amended in accordance with that Part.",
        part: nil,
        chapter: nil
      }
    ]

    assert [a, b] = ScheduleEffect.rules(@act, rows)

    assert {a.scope, a.when, a.treatment} ==
             {["sch.12"], {:with, "s.116(1) pt.3"}, :schedule_effect}

    assert {b.scope, b.when} == {["sch.7.pt.2"], {:with, "reg.15(2)"}}
  end

  test "a Schedule's paragraph nothing else dates comes in with its introducing provision" do
    rules =
      ScheduleEffect.rules(@act, [
        %{
          section_id: "#{@act}:s.116(1)",
          text: "Schedule 12 has effect.",
          part: "3",
          chapter: nil
        }
      ]) ++
        [
          Rule.new(
            commences: @act,
            scope: ["pt.3"],
            when: {:date, ~D[2014-04-01]},
            source: %{law: "UK_uksi_2014_251", ref: "art.4(1)", text: nil},
            treatment: :order_date
          ),
          Rule.new(
            commences: @act,
            scope: :all,
            when: {:date, ~D[2013-12-18]},
            source: %{law: @act, ref: nil, text: nil},
            treatment: :act_enactment
          )
        ]

    result = AmendingLaw.commencement(rules, "schedule-12-paragraph-93")
    assert result.full_from == ~D[2014-04-01]
    assert AmendingLaw.commenced_by(result) == "UK_uksi_2014_251"

    # a provision of the Act outside Part 3: Royal Assent still
    assert AmendingLaw.commencement(rules, "section-150").full_from == ~D[2013-12-18]
  end
end

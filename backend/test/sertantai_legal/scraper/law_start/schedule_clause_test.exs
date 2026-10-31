defmodule SertantaiLegal.Scraper.LawStart.ScheduleClauseTest do
  @moduledoc "A commencement clause handing over to a Schedule (CV-06 round 1, R3: SI 1989/2169)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.ScheduleClause

  @clause "These Regulations may be cited as the Pressure Systems and Transportable Gas Containers Regulations 1989 and shall come into force in accordance with the provisions of Part I of Schedule 1."

  @xml ~S"""
  <Legislation><Secondary><Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>COMING INTO FORCE OF THE REGULATIONS AND TRANSITIONAL PROVISIONS</Title></TitleBlock><ScheduleBody>
  <Part><Number>PART I</Number><Title>coming into force of the regulations</Title>
  <P1><Pnumber>1</Pnumber><P1para><Text>Regulations 1 to 3 and 27 shall come into force on 1st July 1990.</Text></P1para></P1>
  <P1><Pnumber>2</Pnumber><P1para><Text>Regulation 26 (in so far as it revokes the instruments marked with an asterisk in Schedule 6) shall come into force on 1st January 1991.</Text></P1para></P1>
  <P1><Pnumber>3</Pnumber><P1para><Text>All the other provisions of these Regulations shall come into force on 1st July 1994.</Text></P1para></P1>
  </Part><Part><Number>PART II</Number><Title>transitional provisions</Title><P1><Pnumber>1</Pnumber><P1para><Text>This Part shall apply until regulations 8 to 10 come into force.</Text></P1para></P1></Part>
  </ScheduleBody></Schedule></Schedules></Secondary></Legislation>
  """

  test "the Schedule and Part a clause hands over to" do
    assert ScheduleClause.redirect(@clause) == {"1", "I"}

    assert ScheduleClause.redirect(
             "This Order shall come into force in accordance with Schedule 3."
           ) ==
             {"3", nil}

    assert ScheduleClause.redirect("These Regulations shall come into force on 1st July 1990.") ==
             nil
  end

  test "the clause then the Part's sentences, its heading and paragraph numbers dropped; no other Part" do
    text = ScheduleClause.inline(@clause, @xml)
    assert text =~ "Schedule 1. Regulations 1 to 3 and 27 shall come into force on 1st July 1990."
    assert text =~ "1st January 1991. All the other provisions"
    refute text =~ "transitional"
    refute text =~ "PART I"
  end

  test "a clause handing over to nothing held stays as it is" do
    assert ScheduleClause.inline(@clause, nil) == @clause

    assert ScheduleClause.inline(
             "These Regulations shall come into force on 1st July 1990.",
             @xml
           ) ==
             "These Regulations shall come into force on 1st July 1990."
  end
end

defmodule SertantaiLegal.Scraper.LawStartScheduleTableTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeCollector
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.ScheduleTable

  @clause "Each provision of these Regulations mentioned in the second column of the Table in Schedule 1 shall come into force on the date mentioned in the first column of that Table, for the purpose mentioned in the third column."

  @xml ~S"""
  <Legislation><Secondary><Schedules><Schedule id="schedule-1"><ScheduleBody><Tabular><table><tbody>
  <tr><th>Coming into force date</th><th>Provision</th><th>Purpose for which the provision comes into force</th></tr>
  <tr><td>9th January 2013</td><td>Regulations 1, 2 and 3</td><td>All purposes</td></tr>
  <tr><td>9th January 2013</td><td>Regulations 6, 11(a) (in so far as it inserts paragraphs (3B), (3C) and (3D) into regulation 20) and (b), 12</td><td>All purposes</td></tr>
  <tr><td>9th January 2013</td><td>Regulation 15</td><td>In respect of buildings occupied by public authorities</td></tr>
  <tr><td>9th January 2013</td><td>Regulation 17 (for the purpose of new regulation 25A)</td><td>In respect of new buildings occupied by public authorities</td></tr>
  <tr><td><leg:Substitution xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation">6th April 2013</leg:Substitution></td><td><leg:Substitution xmlns:leg="http://www.legislation.gov.uk/namespaces/legislation">Regulation 4, 5 and Schedule 2</leg:Substitution></td><td>All purposes</td></tr>
  <tr><td>9th July 2013</td><td>Regulation 15</td><td>In respect of all buildings</td></tr>
  <tr><td>1st October 2013</td><td>Regulation 13(a) (so far as not otherwise commenced)</td><td>All purposes</td></tr>
  </tbody></table></Tabular></ScheduleBody></Schedule></Schedules></Secondary></Legislation>
  """

  defp input do
    rows =
      for {sid, text} <- [
            {"reg.1", @clause},
            {"reg.2", ""},
            {"reg.3", ""},
            {"reg.4", ""},
            {"reg.5", ""},
            {"reg.6", ""},
            {"reg.11", ""},
            {"reg.11(a)", ""},
            {"reg.11(b)", ""},
            {"reg.12", ""},
            {"reg.13", ""},
            {"reg.13(a)", ""},
            {"reg.15", ""},
            {"reg.17", ""}
          ],
          do: %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}

    %{type_code: "uksi", rows: rows, schedule_tables: ScheduleTable.parse(@xml)}
  end

  test "the Schedule's table read: date, provisions, purpose per row (header skipped)" do
    assert [
             %{
               date: ~D[2013-01-09],
               provisions: "Regulations 1, 2 and 3",
               purpose: "All purposes"
             }
             | _
           ] = ScheduleTable.rows(@clause, ScheduleTable.parse(@xml))
  end

  test "V1-02: a law commenced by its Schedule's table starts on the table's earliest date (SI 2012/3119)" do
    assert %{treatment: :clause_staged, date: ~D[2013-01-09]} = LawStart.resolve(input())
  end

  test "V1-02: each row dates its provisions; a purpose short of all, or a provision's own qualifier, is partial" do
    recs =
      "UK_x"
      |> ChangeCollector.Commencement.records(input())
      |> Enum.filter(
        &(&1.section_id != nil and String.starts_with?(&1.effect_type, "provision_"))
      )

    by = fn sid ->
      for r <- recs, r.section_id == "UK_x:" <> sid, do: {r.effect_type, r.effective_from}
    end

    assert {"provision_dated", ~D[2013-01-09]} in by.("reg.2")
    assert {"provision_dated", ~D[2013-04-06]} in by.("reg.4")
    # one item's qualifier is that item's: 6, 11(b) and 12 fully, 11(a) partly
    assert {"provision_dated", ~D[2013-01-09]} in by.("reg.6")
    assert {"provision_dated", ~D[2013-01-09]} in by.("reg.12")
    assert {"provision_dated", ~D[2013-01-09]} in by.("reg.11(b)")
    refute Enum.any?(by.("reg.11(a)"), &match?({"provision_dated", _}, &1))
    # "In respect of buildings occupied by public authorities" (partly, 9 Jan),
    # then "all buildings" (fully, 9 Jul): the partial start kept as an entry
    assert [%{effective_from: ~D[2013-07-09], in_force: entries}] =
             Enum.filter(recs, &(&1.section_id == "UK_x:reg.15"))

    assert Enum.any?(entries, &(&1["date"] == "2013-01-09"))
    # "(for the purpose of new regulation 25A)": partial
    refute Enum.any?(by.("reg.17"), &match?({"provision_dated", _}, &1))
    # "(so far as not otherwise commenced)": full
    assert {"provision_dated", ~D[2013-10-01]} in by.("reg.13(a)")
  end
end

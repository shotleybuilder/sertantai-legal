defmodule SertantaiLegal.Scraper.LabelsTodayTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelProjection, LabelsToday}

  defp period(sid, from, to, status, opts \\ []) do
    Repo.query!(
      """
      INSERT INTO lat_label_timeline (law_name, section_id, valid_from, valid_to, status, in_force_from, changed_by, code_version)
      VALUES ('L', $1, $2, $3, $4, $5, $6, 'test')
      """,
      [sid, from, to, status, opts[:in_force_from], opts[:changed_by]]
    )
  end

  test "lat_labels_today: the period in force on the UK date, computed in Postgres" do
    today = LabelProjection.uk_today()
    period("L:s.1", Date.add(today, -100), Date.add(today, -10), "prospective")

    period("L:s.1", Date.add(today, -10), Date.add(today, 30), "in_force",
      in_force_from: Date.add(today, -10),
      changed_by: "UK_uksi_2001_1"
    )

    period("L:s.1", Date.add(today, 30), nil, "repealed")
    period("L:s.2", Date.add(today, 1), nil, "in_force")

    %{rows: [[db_today]]} = Repo.query!("SELECT (now() AT TIME ZONE 'Europe/London')::date")
    assert db_today == today

    assert LabelsToday.for_law("L") == %{
             "L:s.1" => %{
               status: "in_force",
               effective_from: Date.add(today, -10),
               changed_by: "UK_uksi_2001_1"
             }
           }
  end

  test "put/2: each row gets today's labels; a row with no period gets nils (unknown)" do
    labels = %{"L:s.1" => %{status: "repealed", effective_from: ~D[2001-01-01], changed_by: "X"}}

    assert LabelsToday.put(
             [%{section_id: "L:s.1", text: "a"}, %{section_id: "L:s.2", text: "b"}],
             labels
           ) ==
             [
               %{
                 section_id: "L:s.1",
                 text: "a",
                 status: "repealed",
                 effective_from: ~D[2001-01-01],
                 changed_by: "X"
               },
               %{
                 section_id: "L:s.2",
                 text: "b",
                 status: nil,
                 effective_from: nil,
                 changed_by: nil
               }
             ]
  end
end

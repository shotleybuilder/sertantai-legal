defmodule SertantaiLegal.Scraper.LawStart.Provisions.SubjectsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Subjects

  @rows [
    %{section_id: "UK_x:reg.1", text: ""},
    %{section_id: "UK_x:reg.2", text: ""},
    %{section_id: "UK_x:reg.5", text: ""}
  ]

  defp group(sentence),
    do: %{
      kind: :named,
      refs: [],
      excluded: [],
      treatment: :provision_dated,
      date: ~D[2015-05-31],
      qualified_date: nil,
      appointed: false,
      evidence: "UK_x:reg.1",
      text: sentence
    }

  test "a subject naming its provisions in full" do
    s = "Regulations 2 and 5 come into force on 31st May 2015"

    assert Enum.any?(
             Subjects.subject_groups(
               group(s),
               s,
               "Regulations 2 and 5",
               "on 31st May 2015",
               @rows,
               "UK_x:reg.1"
             ),
             &(&1.treatment == :provision_dated and
                 &1.refs == [{"UK_x:reg.2", 10}, {"UK_x:reg.5", 10}])
           )
  end
end

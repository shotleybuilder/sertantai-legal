defmodule SertantaiLegal.Scraper.Commencement.OwnReadTest do
  @moduledoc "A law's own rules as `--read` writes them: its clause and its Schedules' effect, in one reading."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnRead

  @law "UK_uksi_2099_1"

  defp row(id, text), do: %{section_id: "#{@law}:#{id}", text: text, part: nil, chapter: nil}

  test "read/3 holds the clause's rules and the Schedule's effect" do
    rows = [
      row("reg.1", "These Regulations come into force on 6th April 2020."),
      row("reg.9", "Schedule 2 (consequential amendments) has effect.")
    ]

    input = %{
      type_code: "uksi",
      lrt_date: nil,
      made: ~D[2020-03-01],
      clml_head: nil,
      schedule_tables: [],
      tied_date: nil,
      rows: rows
    }

    rules = OwnRead.read(@law, input, nil)

    assert Enum.any?(rules, &(&1.when == {:date, ~D[2020-04-06]}))
    assert [effect] = Enum.filter(rules, &(&1.treatment == :schedule_effect))
    assert effect.scope == ["sch.2"]
    assert effect.source.ref == "reg.9"
  end
end

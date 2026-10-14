defmodule SertantaiLegal.Architecture.NoteReadTest do
  @moduledoc """
  Notes are pointers, never facts (lat-refactor LR-20 rule; LR-25 D4): no
  module reads a fact (effect, date, status, territory) out of a note's
  text. Note text may be read only to point where to look, by the modules
  allow-listed here, each with its reason. A new reader fails this test
  until it is put to Jason and added.
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)

  # functions that turn note text into a fact
  @fact_calls [
    "AmendmentNote.parse(",
    "AmendmentNote.row_effective(",
    "AmendmentNote.resolve_law(",
    "LatStatus.resolve(",
    "NoteTerritory."
  ]

  # Fact readers still to be deleted in LR-25 step 7 (a ratchet: the list
  # may only shrink, and must be empty when LR-25 closes).
  @to_delete [
    {"sertantai_legal/scraper/change_facts.ex", "AmendmentNote.parse("},
    {"sertantai_legal/scraper/change_facts.ex", "AmendmentNote.row_effective("},
    {"sertantai_legal/scraper/change_facts.ex", "AmendmentNote.resolve_law("},
    {"sertantai_legal/scraper/change_facts.ex", "LatStatus.resolve("},
    {"sertantai_legal/scraper/commentary_parser.ex", "AmendmentNote.parse("},
    {"sertantai_legal/scraper/lat_cause/apply.ex", "AmendmentNote.parse("},
    {"sertantai_legal/scraper/lat_status/apply.ex", "AmendmentNote.parse("},
    {"sertantai_legal/scraper/lat_territory_check.ex", "NoteTerritory."}
  ]

  # SQL that reads amendment_annotations.text, by file → why it may
  @text_readers %{
    # J5: a note saying "inserted" withholds the law's default start; it
    # supplies no value (LR-24)
    "sertantai_legal/scraper/label_timeline.ex" => :pointer,
    # the amending law's pointer (law, provisions, commencing SI) in the
    # note's citation tail (LR-08 AmendingLaw.Pointer)
    "sertantai_legal/scraper/change_collector.ex" => :pointer,
    # shown to QA agents as the note, beside the row
    "mix/tasks/lat.qa_sample.ex" => :display,
    # exported as the note itself (AI sync)
    "sertantai_legal_web/controllers/ai_sync_controller.ex" => :display,
    # the admin LAT page lists a law's notes
    "sertantai_legal_web/controllers/lat_admin_controller.ex" => :display,
    # LR-25 step 7 deletes it
    "sertantai_legal/scraper/lat_status/apply.ex" => :to_delete
  }

  defp files,
    do:
      Path.wildcard(Path.join(@lib, "**/*.ex"))
      |> Enum.map(&{Path.relative_to(&1, @lib), File.read!(&1)})

  test "no module calls a function that reads a fact from note text" do
    offenders =
      for {path, src} <- files(),
          call <- @fact_calls,
          not String.starts_with?(path, "sertantai_legal/scraper/amendment_note"),
          String.contains?(src, call),
          do: {path, call}

    assert offenders -- @to_delete == []
    assert @to_delete -- offenders == [], "remove deleted readers from @to_delete"
  end

  test "only allow-listed modules read note text in SQL" do
    readers =
      for {path, src} <- files(),
          sql <- Regex.scan(~r/"""(.*?)"""/s, src, capture: :all_but_first) |> List.flatten(),
          sql =~ ~r/\bamendment_annotations\b/,
          sql =~ ~r/(?<!::)\btext\b\s*(~|!~|ILIKE|LIKE|,|\n\s*FROM|\s+FROM)/i,
          uniq: true,
          do: path

    assert readers -- Map.keys(@text_readers) == []
  end
end

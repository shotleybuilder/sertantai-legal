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

  # SQL that reads amendment_annotations.text, by file → why it may
  @text_readers %{
    # J5: a note saying "inserted" withholds the law's default start; it
    # supplies no value (LR-24)
    "sertantai_legal/scraper/label_timeline.ex" => :pointer,
    # the amending law's pointer (law, provisions, commencing SI) in the
    # note's citation tail (LR-08 AmendingLaw.Pointer)
    "sertantai_legal/scraper/change_collector.ex" => :pointer,
    # the same pointer: which commencing orders a note cites, so their text
    # is read for rules (commencement-rules CR-04 --read-orders; CR-06)
    "mix/tasks/lat.commencement.ex" => :pointer,
    # the same pointer: which amending provisions a note points to, read
    # once into amendment rules (amendment-rules AR-03 read pass)
    "mix/tasks/lat.amending.ex" => :pointer,
    # shown to QA agents as the note, beside the row
    "mix/tasks/lat.qa_sample.ex" => :display,
    # exported as the note itself (AI sync)
    "sertantai_legal_web/controllers/ai_sync_controller.ex" => :display,
    # the admin LAT page lists a law's notes
    "sertantai_legal_web/controllers/lat_admin_controller.ex" => :display,
    # our copy's change log (LatParseLog): a "renumbered as" note pairs a
    # removed and an inserted row as a rename; the note's change id is the
    # evidence. Not a label.
    "sertantai_legal/scraper/lat_cause/apply.ex" => :pointer
  }

  # heredoc SQL and one-line "…" strings
  defp sql_strings(src) do
    heredocs = Regex.scan(~r/"""(.*?)"""/s, src, capture: :all_but_first)
    lines = Regex.scan(~r/"((?:[^"\\\n]|\\.)*)"/, src, capture: :all_but_first)
    List.flatten(heredocs ++ lines)
  end

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

    assert offenders == []
  end

  test "only allow-listed modules read note text in SQL" do
    readers =
      for {path, src} <- files(),
          sql <- sql_strings(src),
          sql =~ ~r/\bamendment_annotations\b/,
          sql =~ ~r/(?<!::)\btext\b\s*(~|!~|ILIKE|LIKE|,|\n\s*FROM|\s+FROM)/i,
          uniq: true,
          do: path

    assert readers -- Map.keys(@text_readers) == []
  end
end

defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleParts do
  @moduledoc """
  A Schedule's Part in a commencement order's item, where it is not the
  whole Part brought in: some of it (its entries, a lettered division: SI
  2007/709 art.3) or only the place its paragraphs are (NISR 2020/58).
  Pure text.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Asides

  @of_schedule ~S"of\s+Schedule\s+(\d+[A-Z]*)\b(?!\s+to\s+th(?:is|ese)\s)"
  @part_entries ~r/^\W*in\s+Part\s+([IVXL]+|\d+)[A-Z]?\s*(?:\([A-Z]\)\s*)?#{@of_schedule}\s*(?:to\s+the\s+Act\s*)?,?\s*the\s+(?:repeals?|entr(?:y|ies))\b/iu
  @lettered_part ~r/^\W*Part\s+([IVXL]+|\d+)[A-Z]?\s*\([A-Z]\)\s*#{@of_schedule}/u

  # "paragraphs 3 … and 19 in Part 2 of Schedule 11" (NISR 2020/58)
  @paragraphs_in_part ~r/(\bparagraphs?\b[^;]*?)\s+in\s+Part\s+(?:[IVXL]+|\d+)[A-Z]?\s+(?=of\s+Schedule\s+\d)/i
  # "In Part 1 of Schedule 7, paragraphs 1, 2 …" (SI 2026/323)
  @in_part_paragraphs ~r/\bin\s+Part\s+(?:[IVXL]+|\d+)[A-Z]?\s+of\s+(Schedule\s+\d+[A-Z]*\s*,\s*paragraphs?\b)/i

  # "Schedule 13, Part 2, paragraph 2." (SI 2005/2812 Sch.1)
  @schedule_part_paragraphs ~r/\b(Schedule\s+\d+[A-Z]*)\s*,\s*Part\s+(?:[IVXL]+|\d+)[A-Z]?\s*,\s*(?=paragraphs?\b)/i

  @doc """
  The Part ("sch.15.pt.2") `line` brings in partly: its entries ("in Part 2
  of Schedule 15 (repeals: powers of police etc) the entries relating to—")
  or a lettered division the Part's own text has no provision for ("Part
  1(A) (national policing improvement agency) of Schedule 15"). Nil for any
  other line.
  """
  @spec partial_ref(String.t()) :: String.t() | nil
  def partial_ref(line) do
    text = Asides.strip(line)

    case Regex.run(@part_entries, text) || Regex.run(@lettered_part, text) do
      [_, part, schedule] -> "sch.#{schedule}.pt.#{part}"
      nil -> nil
    end
  end

  @doc """
  `text` without a Part that only says where its paragraphs are, never an
  item: "paragraphs 3 and 19 in Part 2 of Schedule 11" → "paragraphs 3 and
  19 of Schedule 11"; "Schedule 13, Part 2, paragraph 2" → "Schedule 13,
  paragraph 2".
  """
  @spec as_place(String.t()) :: String.t()
  def as_place(text) do
    text
    |> String.replace(@paragraphs_in_part, "\\1 ")
    |> String.replace(@in_part_paragraphs, "in \\1")
    |> String.replace(@schedule_part_paragraphs, "\\1, ")
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedPart do
  @moduledoc """
  A part of a provision that the feed names after it and that is no
  provision of its own: its Table, Form, proviso, Note, footnote or Figure
  ("reg. 6(2) Table 1", "s. 15(2) Proviso", "Sch. 5 Note 2", "Annex 4
  FOOTNOTE 3", "sch. 1 Form A1", "Sch. 2 Figure 1").

  The feed links the provision and writes the part in words. A change to
  the part is a change within the provision: SI 2023/331 reg. 9(a), "in
  paragraph (2), for the table entitled … substitute the table …", is
  recorded "reg. 6(2) Table 1 substituted". Pure.
  """

  # the part's name, and what the feed writes after it
  @part ~r/(?<![\w-])(?<!explanatory\s)(tables?|forms?|proviso|notes?|footnotes?|figures?)\b(.*)$/is

  # a provision named after the part ("Table para. 17", "Table Pt.I") is
  # the feed's target, or a piece of the part we do not read
  @provision ~r/(?<![\w-])(?:(?:ss?|regs?|arts?|rr?|pts?|chs?|schs?)\.|(?:paras?|rules?|annex|appendix|groups?|sections?|articles?|class(?:es)?)\b)/i

  # what may follow the part's name: its own number or letter ("A1",
  # "(2A)", "6(2)(b)", "2.1.3", "(1)-(3)") …
  @designator ~r/^\(?[0-9a-z]{1,4}(?:\.[0-9]+)*\)?(?:\([0-9a-z]+\))*(?:-\(?[0-9a-z]{1,4}\)?)?$/i

  # … and a piece of it or a part beside it ("Table B and notes", "Table
  # note 1", "Table entry 3", "first note")
  @words ~w(and to of the entry entries item items text heading first second third last
            table tables form forms proviso note notes footnote footnotes figure figures)

  # a Form with an id of its own in the text ("schedule-1-form-6A")
  @linked ~r/-form(?:-|$)/

  # the Table itself, not a note, an entry or an item of it
  @table ~r/(?<![\w-])tables?(?:\s+\(?(?:[a-z]{1,2}\d*|\d[0-9a-z.]*)\)?)?(?:\s+and\s+notes)?\s*$/i

  @doc """
  Whether the affected provisions end in a part of the provision they
  name: "reg. 8 Table note 1" does, "Sch. 1 Pt. 1 Table para. 17" (a
  paragraph, linked) does not, nor a Form the feed links itself (`refs`).
  """
  @spec named?(String.t() | nil, [String.t()] | nil) :: boolean()
  def named?(nil, _refs), do: false

  def named?(text, refs) do
    case Regex.run(@part, text, capture: :all_but_first) do
      [_part, tail] -> not linked?(refs) and not String.match?(tail, @provision) and tail?(tail)
      nil -> false
    end
  end

  @doc ~S|Whether the part named is the Table itself ("reg. 4 Table 1", "sch. 1 Table B and notes").|
  @spec table?(String.t() | nil) :: boolean()
  def table?(nil), do: false
  def table?(text), do: String.match?(text, @table)

  @doc """
  Whether the provision holds a Table as a row of its own, on it or under
  it ("reg.4" holds "reg.4.table.1"; "reg.6" holds "reg.6(2).table.1").
  """
  @spec holds_table?(String.t(), Enumerable.t()) :: boolean()
  def holds_table?(target, rows) do
    Enum.any?(rows, fn row ->
      String.contains?(row, ".table.") and
        (String.starts_with?(row, target <> ".") or String.starts_with?(row, target <> "("))
    end)
  end

  defp linked?(refs), do: Enum.any?(List.wrap(refs), &String.match?(&1 || "", @linked))

  defp tail?(tail) do
    tail
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.all?(&(String.downcase(&1) in @words or String.match?(&1, @designator)))
  end
end

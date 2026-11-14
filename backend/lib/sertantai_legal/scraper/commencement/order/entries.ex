defmodule SertantaiLegal.Scraper.Commencement.Order.Entries do
  @moduledoc """
  A repeals Schedule's entries as a commencement order's list names them:
  the head that says which Schedule (or Part) they are in, and the lines
  that each describe one entry by the other law's provisions it repeals
  (SI 2005/1909 Sch.: "The following entries in Part 1 of Schedule 13:",
  "The entries relating to Schedule 2, Schedule 3 and Schedule 6 of the
  Railways Act 1993."). Pure text.
  """

  @head ~r/^\W*the\s+following\s+(?:repeals|entries)\s+in\s+(?:Part\s+([IVXL]+|\d+)[A-Z]?\s+of\s+)?Schedule\s+(\d+[A-Z]*)\b(?!\s+to\s+th(?:is|ese)\s)/iu
  @entry ~r/^\W*the\s+entr(?:y|ies)\s+(?:relating\s+to|in\s+respect\s+of)\b/iu

  @doc """
  The Schedule or Part ("sch.13.pt.1") whose entries `line` heads: brought
  in partly, by the entries listed under it. Nil for any other line.
  """
  @spec head_ref(String.t()) :: String.t() | nil
  def head_ref(line) do
    case Regex.run(@head, line) do
      [_, "", schedule] -> "sch.#{schedule}"
      [_, part, schedule] -> "sch.#{schedule}.pt.#{part}"
      nil -> nil
    end
  end

  @doc """
  True when `line` describes an entry ("The entry relating to section 104
  of the Railways and Transport Safety Act 2003."): the provisions it names
  are the repealed law's, never the Act's own.
  """
  @spec entry?(String.t()) :: boolean()
  def entry?(line), do: Regex.match?(@entry, line)
end

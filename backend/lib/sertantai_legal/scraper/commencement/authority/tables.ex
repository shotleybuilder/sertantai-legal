defmodule SertantaiLegal.Scraper.Commencement.Authority.Tables do
  @moduledoc """
  An Act's authority table held in a Schedule, which the LAT rows leave out
  (Schedules unparsed): Water Act 2014 s.94(6) points to Schedule 12,
  "Commencement orders: appropriate authority" (Decision 11, Jason
  2026-11-22). Each table of a Schedule titled for commencement becomes one
  row in the LAT's table form, "<cell> | <cell>; <cell> | <cell>", for
  `Commencement.Authority.read/1`; a row of one cell (the left cell spans
  it) is a further authority for the row above it. Pure: the Act's CLML
  documents come in.
  """

  import SweetXml

  @doc "The rows (`{\"sch.N.table.K\", text}`) of the Act's commencement Schedules' tables."
  @spec rows([String.t()]) :: [{String.t(), String.t()}]
  def rows(xmls) do
    for xml <- xmls,
        schedule <- xpath(xml, ~x"//*[local-name()='Schedule']"l),
        commencement?(schedule),
        n = number(schedule),
        {table, k} <- schedule |> xpath(~x".//*[local-name()='table']"l) |> Enum.with_index(1),
        do: {"sch.#{n}.table.#{k}", text(table)}
  end

  defp commencement?(schedule),
    do:
      schedule |> xpath(~x"./*[local-name()='TitleBlock']//text()"ls) |> Enum.join() =~
        ~r/commencement/i

  defp number(schedule) do
    case Regex.run(~r/schedule-(\w+)$/, xpath(schedule, ~x"./@id"s)) do
      [_, n] -> n
      nil -> "?"
    end
  end

  defp text(table) do
    table
    |> xpath(~x".//*[local-name()='tr']"l)
    |> Enum.map(fn tr ->
      tr |> xpath(~x"./*[local-name()='td' or local-name()='th']"l) |> Enum.map(&cell/1)
    end)
    |> Enum.reduce([], &row/2)
    |> Enum.reverse()
    |> Enum.map_join("; ", fn {left, right} -> "#{left} | #{right}" end)
  end

  # a row of one cell continues the row above's authority
  defp row([only], [{left, right} | rows]), do: [{left, "#{right}; #{only}"} | rows]
  defp row([left, right | _], rows), do: [{left, right} | rows]
  defp row(_cells, rows), do: rows

  defp cell(el),
    do:
      el
      |> xpath(~x".//text()"ls)
      |> Enum.join(" ")
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
end

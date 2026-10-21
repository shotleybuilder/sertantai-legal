defmodule SertantaiLegal.Scraper.LawStart.ScheduleTable do
  @moduledoc """
  A law commenced by a table in its own Schedule (V1-02): "Each provision of
  these Regulations mentioned in the second column of the Table in Schedule 1
  shall come into force on the date mentioned in the first column of that
  Table, for the purpose mentioned in the third column" (SI 2012/3119, wsi
  2013/747). LAT holds no Schedules, so the table comes from the stored
  CLML (`parse/1`, read by `ChangeCollector.law_start_input/2` only for a law
  whose text cites such a table).

  - `clause?/1`: the clause cites a table in its Schedule
  - `parse/1`: each Schedule's table rows as cell texts
  - `rows/2`: the table the clause cites as `%{date, provisions, purpose}`,
    columns as the clause numbers them; rows with no date (headers) skipped
  - `start/2`: the earliest date (the law's start, `:clause_staged`)

  Which rows each table row reaches is `LawStart.Provisions.table_groups/3`.
  Pure.
  """

  import SweetXml

  # cell text by walking the nodes: a cell's text can sit in a prefixed
  # element (`<leg:Substitution xmlns:leg=…>`, SI 2012/3119) that
  # `string(.)` drops
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.LawStart.Clause

  @clause ~r/\bmentioned\s+in\s+the\s+(\w+)\s+column\s+of\s+the\s+Table\s+in\s+(?:the\s+)?Schedule(?:\s+(\d+[A-Z]?))?\b.*?\bdate\s+mentioned\s+in\s+the\s+(\w+)\s+column(?:.*?\bpurpose\s+mentioned\s+in\s+the\s+(\w+)\s+column)?/is

  @ordinals %{"first" => 0, "second" => 1, "third" => 2, "fourth" => 3}

  @type row :: %{date: Date.t(), provisions: String.t(), purpose: String.t() | nil}

  @doc "Whether the text cites a commencement table in the law's Schedule."
  @spec clause?(String.t() | nil) :: boolean()
  def clause?(nil), do: false
  def clause?(text), do: Regex.match?(@clause, text)

  @doc "Each Schedule's table rows (by Schedule id) as cell texts."
  @spec parse(String.t()) :: %{String.t() => [[String.t()]]}
  def parse(xml) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    for schedule <- xpath(doc, ~x"//*[local-name()='Schedule'][@id]"l),
        id = schedule |> xpath(~x"./@id"s) |> to_string(),
        into: %{} do
      # every row of the Schedule's tables, in order (a table may be split)
      rows =
        for tr <- xpath(schedule, ~x".//*[local-name()='table']//*[local-name()='tr']"l) do
          for cell <- xpath(tr, ~x"./*[local-name()='td' or local-name()='th']"l),
              do: cell |> Doc.text() |> squash()
        end

      {id, rows}
    end
  end

  @doc "The cited table's rows with a date, as `%{date, provisions, purpose}`."
  @spec rows(String.t() | nil, %{String.t() => [[String.t()]]} | nil) :: [row()]
  def rows(clause, tables) when is_binary(clause) and is_map(tables) do
    case Regex.run(@clause, clause) do
      [_, prov, sch, date | rest] ->
        id = if sch in [nil, ""], do: "schedule", else: "schedule-#{sch}"
        purpose = List.first(rest)
        [p, d] = Enum.map([prov, date], &Map.get(@ordinals, String.downcase(&1)))
        u = purpose && Map.get(@ordinals, String.downcase(purpose))

        for cells <- table(tables, id),
            %Date{} = date <- [Clause.date_at_start(Enum.at(cells, d) || "")],
            do: %{
              date: date,
              provisions: Enum.at(cells, p) || "",
              purpose: u && Enum.at(cells, u)
            }

      _ ->
        []
    end
  end

  def rows(_clause, _tables), do: []

  @doc "The law's start: the cited table's earliest date; nil with none."
  @spec start(String.t() | nil, map() | nil) :: Date.t() | nil
  def start(clause, tables) do
    case rows(clause, tables) do
      [] -> nil
      rs -> rs |> Enum.map(& &1.date) |> Enum.min(Date)
    end
  end

  # "schedule" (a law with one Schedule, wsi 2013/747) may be stored as
  # "schedule-1" and the other way round
  defp table(tables, id) do
    Map.get(tables, id) ||
      Map.get(tables, if(id == "schedule", do: "schedule-1", else: "schedule")) || []
  end

  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()
end

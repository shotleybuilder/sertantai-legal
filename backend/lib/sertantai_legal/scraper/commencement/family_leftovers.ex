defmodule SertantaiLegal.Scraper.Commencement.FamilyLeftovers do
  @moduledoc """
  The commencement leftovers that reach a family (Decision 1 (c), Jason
  2026-11-05: the family gate): every commencement statement of its laws'
  own clauses, of the commencement orders held for them, and of the held
  amending laws its undated changes point to — read as the catalogues read
  them (`Leftovers.sentences/2`, `Leftovers.order_units/2`) — each leftover
  with its group's reviewed status (`leftovers.json`). The gate itself is
  `Leftovers.gate/1`. IO: the DB, the CLML store, the cached order lists
  (never a search).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ChangeCollector
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Order, OwnClause}
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @sentences "test/fixtures/commencement_patterns/leftovers.json"
  @orders "test/fixtures/order_patterns/leftovers.json"

  @doc """
  The leftovers reaching `laws` (the family's LAT laws) and `amenders`
  (`%{amending law => its undated changes on the family}`), as
  `Leftovers.item()`s.
  """
  @spec for_family([String.t()], %{String.t() => integer()}) :: [Leftovers.item()]
  def for_family(laws, amenders) do
    sentences = reviewed(@sentences)
    orders = reviewed(@orders)

    Enum.flat_map(laws, &own(&1, sentences)) ++
      Enum.flat_map(laws, &orders(&1, orders)) ++
      (amenders
       |> Enum.reject(fn {law, _} -> order?(law) end)
       |> Enum.flat_map(fn {law, n} -> amending(law, n, sentences) end))
  end

  # a commencement order is read as an order (its Schedule's table), never
  # as an amending law's own clause (SI 1997/1082 "The provisions specified
  # in the Schedule shall come into force …")
  defp order?(law) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT (SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1),
               EXISTS (SELECT 1 FROM commencement_rules WHERE source_law = $1
                       AND treatment IN ('order_date', 'order_schedule'))
        """,
        [law]
      )

    case rows do
      [[title, stored?]] ->
        stored? or (is_binary(title) and title =~ ~r/\((?:Commencement|Appointed Day)/i)

      _ ->
        false
    end
  end

  defp own(law, reviewed) do
    rows = lat_rows(law)
    read = OwnClause.read(law, ChangeCollector.law_start_input(law, rows))
    statements(:own, law, rows, read, length(rows), reviewed)
  end

  defp amending(law, reach, reviewed) do
    case ClmlStore.law_docs(law) do
      [_ | _] = xmls ->
        rows = law |> Doc.new(xmls) |> OwnClause.doc_rows()
        read = OwnClause.read(law, ChangeCollector.law_start_input(law, rows))
        statements(:amending, law, rows, read, reach, reviewed)

      _ ->
        []
    end
  end

  defp statements(source, law, rows, read, reach, reviewed) do
    for %{row: row, pattern: pattern, leftovers: [_ | _] = left} <-
          Leftovers.sentences(rows, read) do
      shape = Leftovers.shape(pattern, left)

      Leftovers.item(source, law, row, shape, left, reach, Leftovers.status(shape, reviewed, row))
    end
  end

  # the orders held for a law: its cached list and those its rules came from
  defp orders(law, reviewed) do
    act = %{law: law, title: title(law), year: law |> String.split("_") |> Enum.at(2)}
    reach = length(lat_rows(law))

    # (an order legislation.gov.uk lists for the law but which commences
    # another Act is read for that one: SI 1995/965, the 1970 Act's, listed
    # for the 1995 Act)
    for order <- order_names(law),
        # (a law is never its own order: NISR 2012/286)
        order != law,
        xmls = ClmlStore.law_docs(order),
        xmls != [],
        doc = Doc.new(order, xmls),
        Order.commences?(doc, act),
        %{unit: unit, pattern: pattern, leftovers: [_ | _] = left} <-
          Leftovers.order_units(doc, Order.rules(doc, act)) do
      shape = Leftovers.shape(pattern, left)

      Leftovers.item(
        :order,
        order,
        unit.id,
        shape,
        left,
        reach,
        Leftovers.status(shape, reviewed, "#{order}:#{unit.id}")
      )
    end
  end

  defp order_names(law) do
    listed =
      case File.read("data/cache/commencement-orders/#{law}.json") do
        {:ok, json} -> Jason.decode!(json)
        _ -> []
      end

    stored =
      Repo.query!(
        """
        SELECT DISTINCT source_law FROM commencement_rules
        WHERE commences = $1 AND source_law <> $1 AND treatment IN ('order_date', 'order_schedule')
        """,
        [law]
      ).rows
      |> List.flatten()

    Enum.uniq(listed ++ stored)
  end

  defp lat_rows(law) do
    for [s, t, p, c] <-
          Repo.query!(
            "SELECT section_id, text, part, chapter FROM legal_articles WHERE law_name = $1 ORDER BY position",
            [law]
          ).rows,
        do: %{section_id: s, text: t, part: p, chapter: c}
  end

  # as `mix lat.commencement` names the Act an order commences
  defp title(law) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
      %{rows: [[t]]} when is_binary(t) ->
        t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

      _ ->
        nil
    end
  end

  defp reviewed(path) do
    case File.read(path) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end
end

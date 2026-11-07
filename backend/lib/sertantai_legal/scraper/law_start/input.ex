defmodule SertantaiLegal.Scraper.LawStart.Input do
  @moduledoc """
  What `LawStart` decides a law's start from (LR-33), read once for both
  label paths: the old register's commencement collector
  (`ChangeCollector.law_start_input/2`) and the change vocabulary's build
  (`ChangeVocabulary.Build.start/1`), which stores the start with the
  law's changes (Maritime Safety: Switch-over, 2026-11-07: the new path no
  longer reads the start from the old register).

  Reads the register, the law's LAT rows and the local CLML store; writes
  nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc """
  What `LawStart` decides a law's start from (LR-33): the register's coming
  into force and made date (`uk_lrt`), the stored CLML's metadata, and the
  law's rows (`section_id`, `text`, `part`, `chapter`, in document order).
  """
  @spec of(String.t(), [map()]) :: SertantaiLegal.Scraper.LawStart.input()
  def of(law_name, rows) do
    {lrt_date, made} =
      case Repo.query!(
             "SELECT md_coming_into_force_date, md_made_date FROM uk_lrt WHERE name = $1 LIMIT 1",
             [law_name]
           ) do
        %{rows: [[cif, made]]} -> {date(cif), date(made)}
        _ -> {nil, nil}
      end

    head = clml_head(law_name)

    %{
      type_code: law_name |> String.split("_", parts: 3) |> Enum.at(1),
      lrt_date: lrt_date,
      made: made || clml_made(head),
      clml_head: head,
      # V1-02: a commencement table in the law's own Schedule (LAT holds no
      # Schedules), read only when the text cites one
      schedule_tables: schedule_tables(law_name, rows),
      tied_date: tied_date(rows, made || clml_made(head)),
      rows:
        Enum.map(
          rows,
          &%{
            section_id: &1.section_id,
            # a clause handing over to a Schedule reads its sentences (CV-06 R3)
            text: schedule_clause(law_name, Map.get(&1, :text)),
            part: Map.get(&1, :part),
            chapter: Map.get(&1, :chapter)
          }
        )
    }
  end

  defp schedule_clause(law_name, text) do
    with {_, _} <- SertantaiLegal.Scraper.LawStart.ScheduleClause.redirect(text),
         [_, type, year, number] <- String.split(law_name, "_", parts: 4),
         {:ok, gz} <- File.read("data/cache/clml/#{type}/#{year}/#{number}/schedules/data.xml.gz") do
      SertantaiLegal.Scraper.LawStart.ScheduleClause.inline(text, :zlib.gunzip(gz))
    else
      _ -> text
    end
  end

  defp schedule_tables(law_name, rows) do
    with true <-
           Enum.any?(
             rows,
             &SertantaiLegal.Scraper.LawStart.ScheduleTable.clause?(Map.get(&1, :text))
           ),
         [_, type, year, number] <- String.split(law_name, "_", parts: 4),
         {:ok, gz} <- File.read("data/cache/clml/#{type}/#{year}/#{number}/schedules/data.xml.gz") do
      gz |> :zlib.gunzip() |> SertantaiLegal.Scraper.LawStart.ScheduleTable.parse()
    else
      _ -> %{}
    end
  end

  # V1-02: a law tied to another law's provision ("at the same time as
  # section 83 of the 2022 Act comes into force") starts when that provision
  # came into force — fully, else first — by the other law's own feed (the
  # store; one hop)
  defp tied_date(rows, made) do
    alias SertantaiLegal.Scraper.Commencement.{Effects, Evaluator}
    alias SertantaiLegal.Scraper.LawStart.Clause
    alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

    rows = Enum.map(rows, &%{section_id: &1.section_id, text: Map.get(&1, :text)})

    with %{treatment: :tied_to_other_law, text: text} <- Clause.read(rows, made),
         {title, ref} <- Clause.tied_ref(text, rows),
         other when is_binary(other) <- law_by_title(title),
         [_, t, y, n] <- String.split(other, "_", parts: 4),
         {:ok, effects} <- ChangesFeed.fetch(t, y, n, store: :only) do
      result = Evaluator.evaluate(Effects.rules(other, effects), ref)

      result.full_from ||
        result |> Evaluator.in_force() |> Enum.map(& &1.date) |> Enum.min(Date, fn -> nil end)
    else
      _ -> nil
    end
  end

  # "Building Safety Act 2022" → its register name (title and year, a
  # primary type first)
  defp law_by_title(title) do
    with [_, name, year] <- Regex.run(~r/^(.+?)\s+(\d{4})$/, title),
         %{rows: [[law] | _]} <-
           Repo.query!(
             """
             SELECT name FROM uk_lrt WHERE lower(title_en) = lower($1) AND name LIKE $2
             ORDER BY (split_part(name, '_', 2) IN ('ukpga', 'asp', 'anaw', 'asc', 'nia', 'mwa')) DESC LIMIT 1
             """,
             [name, "%\\_#{year}\\_%"]
           ) do
      law
    else
      _ -> nil
    end
  end

  defp date(%Date{} = d), do: d
  defp date(_other), do: nil

  # the stored CLML's metadata (up to its close: EU metadata runs long)
  defp clml_head(law_name) do
    with [path | _] <- ClmlStore.law_files(law_name),
         {:ok, gz} <- File.read(path) do
      xml = :zlib.gunzip(gz)

      case :binary.match(xml, "</ukm:Metadata>") do
        {pos, len} -> binary_part(xml, 0, pos + len)
        :nomatch -> binary_part(xml, 0, min(byte_size(xml), 80_000))
      end
    else
      _ -> nil
    end
  end

  defp clml_made(nil), do: nil

  # an SI's made date; an Act's passing (Royal Assent)
  defp clml_made(head) do
    with [_, d] <- Regex.run(~r/<ukm:(?:Made|EnactmentDate) Date="(\d{4}-\d{2}-\d{2})"/, head),
         {:ok, date} <- Date.from_iso8601(d) do
      date
    else
      _ -> nil
    end
  end

  @doc "The law's LAT rows in document order, as `of/2` reads them."
  @spec rows(String.t()) :: [map()]
  def rows(law_name) do
    Repo.query!(
      "SELECT section_id, text, part, chapter, extent_code FROM legal_articles " <>
        "WHERE law_name = $1 AND section_id IS NOT NULL ORDER BY position",
      [law_name]
    ).rows
    |> Enum.map(fn [sid, text, part, chapter, extent] ->
      %{section_id: sid, text: text, part: part, chapter: chapter, extent_code: extent}
    end)
  end
end

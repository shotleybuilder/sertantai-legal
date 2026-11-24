defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleDate do
  @moduledoc """
  When a commencement order's Schedule comes in: the date its own title gives,
  or the article that brings it in.

  Pure; part of the order reader (`Commencement.Order`).
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Dates,
    Words
  }

  @doc "The date a Schedule (or its Part) comes in: its title's, its Reference article's, or the articles bringing it in."
  @spec schedule_date(Doc.t(), term()) :: Date.t() | nil
  def schedule_date(order, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    case Dates.parse_dates(title) do
      [d] -> d
      _ -> article_date(order, el) || intro_date(order, el)
    end
  end

  # a Schedule with no date and no Reference: the one date of the articles
  # bringing it in ("The provisions … specified in column 1 of the Schedule
  # to this order … shall come into force on 14th June 1976": SI 1976/731)
  defp intro_date(order, el) do
    case order |> intro_words(el) |> Enum.flat_map(&Dates.parse_dates/1) |> Enum.uniq() do
      [d] -> d
      _ -> nil
    end
  end

  # the words of the articles that bring the Schedule (or its Part) in
  @doc "The words of the articles that bring the Schedule (or its Part) in."
  @spec intro_words(Doc.t(), term()) :: [String.t()]
  def intro_words(order, el) do
    id = xpath(el, ~x"./@id"s)
    names = if String.contains?(id, "-part-"), do: part_named(id), else: schedule_named(id)

    order.ids
    |> Enum.filter(&String.match?(&1, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/))
    |> Enum.map(&Text.words_of(order, &1))
    |> Enum.filter(&(Regex.match?(Words.cif(), &1) and Regex.match?(names, &1)))
  end

  # the words of the article the Schedule's Reference names ("Article 2")
  @doc "The words of the article the Schedule's Reference names."
  @spec reference_words(Doc.t(), term()) :: String.t()
  def reference_words(order, el) do
    with ref when ref != nil <- xpath(el, ~x"./Reference"),
         [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)) do
      Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}")
    else
      _ -> ""
    end
  end

  @doc "How an article names this order's Schedule, never the Act's."
  @spec schedule_named(String.t()) :: Regex.t()
  def schedule_named("schedule"),
    do:
      ~r/\bthe\s+Schedule\b(?!\s+\d)(?:\s+(?:to\s+th(?:is|e)\s+(?:Order|order|Regulations)|hereto))?(?!\s+to\s+the\s+(?:\d{4}\s+|said\s+|principal\s+)?Act)/

  def schedule_named("schedule-" <> n),
    do:
      ~r/\bSchedule\s+#{Regex.escape(n)}\b(?!\s+to\s+the\s+(?:\d{4}\s+|said\s+|principal\s+)?Act)/

  def schedule_named(_id), do: ~r/(?!)/

  # "Part 1 of the Schedule hereto" (SI 2002/1014), "Part I of Schedule 2"
  @doc "How an article names a Part of this order's Schedule."
  @spec part_named(String.t()) :: Regex.t()
  def part_named("schedule-part-" <> p),
    do: ~r/\bPart\s+#{Regex.escape(p)}\s+of\s+the\s+Schedule\b(?!\s+\d)/

  def part_named("schedule-" <> rest) do
    case String.split(rest, "-part-") do
      [n, p] -> ~r/\bPart\s+#{Regex.escape(p)}\s+of\s+Schedule\s+#{Regex.escape(n)}\b/
      _ -> nil
    end
  end

  defp article_date(order, el) do
    with ref when ref != nil <- xpath(el, ~x"./Reference"),
         [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)),
         words =
           Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}") do
      case Dates.parse_dates(words) do
        [d] -> d
        [] -> paragraphs_date(order, n)
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  # the one date in the article's paragraphs bringing in the provisions the
  # Schedule lists, where its own words hold none ("3.—(1) Subject to
  # paragraph (2), 10th June 2013 is the day appointed for the coming into
  # force of the provisions of the Act specified in column 1 …": SSI
  # 2013/163) — never a paragraph commencing the article ("Paragraphs (1)
  # and (2) shall come into force on 1st April 2005": SI 2005/968 art.4(3))
  @lists_provisions ~r/\b(?:column|provisions\s+of\s+the\s+Act)\b/i

  defp paragraphs_date(order, n) do
    dates =
      for id <- order.ids,
          String.match?(id, ~r/^(?:article|regulation)-#{n}-\d+[A-Z]*$/),
          words = Text.words_of(order, id),
          words =~ @lists_provisions,
          d <- Dates.parse_dates(words),
          uniq: true,
          do: d

    case dates do
      [d] -> d
      _ -> nil
    end
  end
end

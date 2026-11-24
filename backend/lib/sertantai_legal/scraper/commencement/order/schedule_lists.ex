defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleLists do
  @moduledoc """
  A commencement order's Schedule that lists provisions: its items, its
  territory and its limit.

  Pure; part of the order reader (`Commencement.Order`).
  """

  import SweetXml

  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Items,
    ScheduleDate,
    ScheduleTables,
    Territory,
    Words
  }

  # a Schedule (or each of its Parts) listing the provisions as items, not a
  # table: "SCHEDULE 1 PROVISIONS COMING INTO FORCE ON 8TH JUNE 2005 Article
  # 2(1) — Section 1(2). Section 1(3), except paragraph (e). …" (SI
  # 2005/1444), dated as a table is (its title, its Reference, the article
  # bringing it in); a Schedule with Parts is read by its Parts
  @doc "The rules of an order's Schedules that list provisions."
  @spec schedule_lists(Doc.t(), [String.t()]) :: [Rule.t()]
  def schedule_lists(order, aliases) do
    for id <- order.ids,
        String.match?(id, ~r/^schedule(-\d+[A-Z]*)?(?:-part-[IVXL\d]+[A-Z]?)?$/),
        not has_parts?(order, id),
        el = Doc.element(order, id),
        ScheduleTables.table_rows(el) == [],
        date = ScheduleDate.schedule_date(order, el),
        date != nil,
        head = "Schedule list #{id}",
        {place, limit} = {schedule_territory(order, el), schedule_limit(order, el)},
        rule <- Items.item_rules(list_lines(el), aliases, date, order.law_name, id, head),
        do: %{
          rule
          | treatment: :order_schedule,
            territory: rule.territory || place,
            purposes: rule.purposes || limit
        }
  end

  # the one place the articles bringing a Schedule in name: "The provisions
  # … specified in the Schedule to this Order … shall come into force in
  # England and Wales … on 6th June 1988" (SI 1988/818 art.2) reaches each
  # row that names none; nil where they name none, or more than one
  @doc "The one territory the articles bringing a Schedule in give; nil for none or several."
  @spec schedule_territory(Doc.t(), term()) :: String.t() | nil
  def schedule_territory(order, el) do
    Territory.only([
      ScheduleDate.reference_words(order, el) | ScheduleDate.intro_words(order, el)
    ])
  end

  # the articles bringing a Schedule (or its Schedule, for a Part) in, where
  # they bring it in "Except in relation to" some cases: partly in force
  # ("Except in relation to the premises to which Article 2 of this Order
  # applies, the provisions … specified in … each of the Parts of Schedule 1
  # …": SI 1964/191 art.1, covered markets); nil where none so limits it
  @except_cases ~r/^\W*(?:\d+\s+)?(?:\(\d+\)\s*)?(?:Except|Save)\s+(?:in\s+relation\s+to|as\s+respects)\b/i

  @doc "`:in_relation_to` when the articles bringing a Schedule in limit it (\"Except in relation to …\")."
  @spec schedule_limit(Doc.t(), term()) :: :in_relation_to | nil
  def schedule_limit(order, el) do
    id = xpath(el, ~x"./@id"s)
    schedule = String.replace(id, ~r/-part-[IVXL\d]+[A-Z]?$/, "")

    words =
      [ScheduleDate.reference_words(order, el) | ScheduleDate.intro_words(order, el)] ++
        whole_words(order, schedule, id)

    if Enum.any?(words, &Regex.match?(@except_cases, &1)), do: :in_relation_to
  end

  # (a Part's Schedule, as its articles name it: "each of the Parts of
  # Schedule 1")
  defp whole_words(_order, id, id), do: []

  defp whole_words(order, schedule, _id) do
    case Doc.element(order, schedule) do
      nil -> []
      whole -> ScheduleDate.intro_words(order, whole)
    end
  end

  defp has_parts?(order, id),
    do: Enum.any?(order.ids, &String.match?(&1, ~r/^#{Regex.escape(id)}-part-[IVXL\d]+[A-Z]?$/))

  # the items, never the Schedule's number, title or Reference
  defp list_lines(el) do
    el
    |> xpath(
      ~x"./*[not(local-name()='Number' or local-name()='Title' or local-name()='TitleBlock' or local-name()='Reference')]"l
    )
    |> Enum.flat_map(&Doc.lines/1)
    |> Items.join_open()
    |> Enum.map(&Words.clean_line/1)
    |> Enum.reject(&(&1 == ""))
  end
end

defmodule SertantaiLegal.Scraper.LawStart.Clause.Tail do
  @moduledoc """
  The date a clause's tail gives, and its treatment ("on 17th April 1995", a named day, a day made- or laid-relative, "X or, if later, Y"). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.OwnDays
  alias SertantaiLegal.Scraper.LawStart.Clause.{NamedDays, RelativeDays, WrittenDates}

  # a tail counting from a day of the law's own that is not held
  @unknown [:made_unknown, :laid_unknown]

  @doc "The tail results that count from a day not held."
  @spec unknown() :: [:made_unknown | :laid_unknown]
  def unknown, do: @unknown

  # "X or, if later, Y": the later day, read as its own form reads; a day
  # not read leaves the whole unread, never the other day alone (SI
  # 2018/797 reg.1(2)(b): the 21st day after making or, if later, 1st
  # October 2018)
  @if_later ~r/\s+or,?\s+if\s+later,?\s+(?:on\s+)?(?:the\s+(?=\d))?/i

  @doc """
  A tail's date and its treatment: `{treatment, date}`; `:made_unknown`
  (`:laid_unknown`) when it counts from a made (laid) day we don't have;
  nil when it states none. `days`: the law's made and laid days
  (`OwnDays`), or its made day alone.
  """
  @spec tail_date(String.t(), OwnDays.days()) ::
          {LawStart.treatment(), Date.t()} | :made_unknown | :laid_unknown | nil
  def tail_date(tail, days) do
    case Regex.split(@if_later, tail, parts: 2) do
      [first, second] -> later(one_date(first, days), one_date(second, days))
      [_one] -> one_date(tail, days)
    end
  end

  defp later({_, %Date{} = a} = first, {_, %Date{} = b} = second),
    do: if(Date.compare(b, a) == :gt, do: second, else: first)

  defp later(unknown, _second) when unknown in @unknown, do: unknown

  defp later(_first, unknown) when unknown in @unknown, do: unknown

  defp later(_first, _second), do: nil

  defp one_date(tail, days) do
    made = OwnDays.made(days)

    cond do
      d = named_day(tail, made) ->
        {:clause_named_day, d}

      d =
          WrittenDates.date_at_start(
            String.replace(tail, ~r/^(?:at [^,]{1,30}? )?(?:on|from|until)\s+/i, "")
          ) ->
        {:clause_date, d}

      d = by_territory(tail) ->
        {:clause_staged, d}

      d = end_of_day(tail) ->
        {:clause_date, d}

      true ->
        RelativeDays.made_relative(tail, made) ||
          RelativeDays.laid_relative(tail, OwnDays.laid(days))
    end
  end

  # "at the end of 31st December 2024" (SI 2024/1366 art.2(2)(a)): in force
  # from the next day
  defp end_of_day(tail) do
    with [_, rest] <- Regex.run(~r/^at\s+the\s+end\s+of\s+(?:the\s+)?(\d.*)$/is, tail),
         %Date{} = d <- WrittenDates.date_at_start(rest) do
      Date.add(d, 1)
    else
      _ -> nil
    end
  end

  # "in England on 1st July 2007 and in Wales on 2nd April 2007": the earliest
  defp by_territory(tail) do
    if tail =~ ~r/^in (?:England|Wales|Scotland|Northern Ireland|Great Britain)\b/i do
      ~r/\bon\s+(\d{1,2}\s*(?:st|nd|rd|th)?\s*[A-Za-z]+,?\s+\d{4})/
      |> Regex.scan(tail, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&WrittenDates.date_at_start/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.min(Date, fn -> nil end)
    end
  end

  # "on the day before that on which exit day falls" (SI 2019/544
  # reg.1(2)): the named day less one
  @day_before ~r/^(?:on\s+)?the\s+day\s+before\s+(?:that\s+on\s+which\s+|the\s+day\s+on\s+which\s+)?((?:IP|implementation period) completion day|exit day)(?:\s+falls)?\b/i

  defp named_day(tail, made) do
    case Regex.run(@day_before, tail) do
      [_, day] -> day |> named_day(made) |> Date.add(-1)
      nil -> NamedDays.named_day_on(tail, made)
    end
  end
end

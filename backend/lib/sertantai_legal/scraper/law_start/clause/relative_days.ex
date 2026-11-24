defmodule SertantaiLegal.Scraper.LawStart.Clause.RelativeDays do
  @moduledoc """
  A day counted from the day a law is made or laid (Interpretation Act conventions: a period "from" or "after" a day excludes it; "beginning with" includes it). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.Clause.WrittenDates

  @numbers WrittenDates.numbers()

  @made ~S"(?:(?:(?:the\s+)?(?:day|date)\s+(?:(?:on\s+which|of)\s+)?)?(?:it\s+is|they\s+are|they\s+were|(?:(?:this|these)\s+[A-Za-z ]+?|the\s+(?:Order|Regulations|Rules|Act|Scheme|Measure|Instrument))\s+(?:is|are|was|were))\s+(?:made|passed|approved\s+by\s+Her\s+Majesty\s+in\s+Council)|(?:the\s+)?(?:making|passing)\s+(?:of\s+(?:this|these)\s+[A-Za-z ]+|thereof)|its\s+(?:making|passing)|(?:the\s+day\s+(?:on\s+which\s+)?)?(?:(?:this\s+Act|it)\s+receives\s+)?Royal\s+Assent|receiving\s+Royal\s+Assent|the\s+(?:day|date)\s+of\s+Royal\s+Assent|the\s+Bill\s+for\s+this\s+Act\s+receives\s+Royal\s+Assent|that\s+on\s+which\s+(?:it|this\s+Act)\s+is\s+passed|the\s+(?:day|date)\s+of\s+(?:the\s+)?(?:passing|making)\s+(?:thereof|of\s+(?:this|these)\s+[A-Za-z ]+)|the\s+(?:day|date)\s+of\s+(?:this|these)\s+(?:Order|Regulations|Rules|Scheme)\b(?!\s+(?:is|are|was|were)\b))"

  # (the last: "on the date of this Order", the day it is made and sealed:
  # NISR 2007/282 art.2(1))

  # the day the law is laid: "the day on which these Regulations are laid",
  # "… they are laid before Parliament" (the House, the Senedd: whatever
  # follows is where, not when)
  @laid ~S"(?:(?:the\s+)?(?:day|date)\s+(?:on\s+which\s+)?)?(?:it\s+is|they\s+are|they\s+were|it\s+was|(?:(?:this|these)\s+[A-Za-z ]+?|the\s+(?:Order|Regulations|Rules|Scheme|Instrument))\s+(?:is|are|was|were))\s+laid\b"

  @number ~S"(\d+(?:st|nd|rd|th)?|[a-z]+(?:[- ][a-z]+)?)"

  @doc "A tail counted from the day the law is made: its date, `:made_unknown` without a made day, nil when it doesn't count from it."
  @spec made_relative(String.t(), Date.t() | nil) ::
          {:clause_made_relative, Date.t()} | :made_unknown | nil
  def made_relative(tail, made) do
    case relative_shift(tail, @made) do
      nil -> nil
      _shift when is_nil(made) -> :made_unknown
      shift -> {:clause_made_relative, shift.(made)}
    end
  end

  # the same counts from the day the law is laid ("on the 22nd day after
  # the day on which these Regulations are laid": SI 2018/1221 reg.2(a))
  @doc "A tail counted from the day the law is laid: its date, `:laid_unknown` without a laid day, nil when it doesn't count from it."
  @spec laid_relative(String.t(), Date.t() | nil) ::
          {:clause_laid_relative, Date.t()} | :laid_unknown | nil
  def laid_relative(tail, laid) do
    case relative_shift(tail, @laid) do
      nil -> nil
      _shift when is_nil(laid) -> :laid_unknown
      shift -> {:clause_laid_relative, shift.(laid)}
    end
  end

  # the tail's count from the law's own day `from` words (the made day's,
  # the laid day's), as a function of that day; nil when the tail doesn't
  # count from it
  defp relative_shift(tail, from) do
    t = String.replace(tail, ~r/\s+/, " ")
    near_shift(t, from) || counted_shift(t, from)
  end

  # the day itself, or the day after it
  defp near_shift(t, from) do
    cond do
      Regex.match?(
        ~r/^on (?:the (?:day|date) (?:(?:on which|of) )?|Royal Assent|the (?:passing|making) of)/i,
        t
      ) and
          starts_from?(t, ~r/^on /i, from) ->
        & &1

      # "when they are made" (SI 2022/500, CV-S04)
      Regex.match?(~r/^when\s+(?:they\s+are|it\s+is|this\s+\w+\s+is)\s+(?:made|passed)\b/i, t) ->
        & &1

      Regex.match?(~r/^(?:on )?the day (?:after|following) /i, t) and
          starts_from?(t, ~r/^(?:on )?the day (?:after|following) /i, from) ->
        &Date.add(&1, 1)

      true ->
        nil
    end
  end

  # a count of days, weeks or months from the day
  @nth_day_after ~r/^(?:on )?the #{@number} day (?:after|following) (.*)$/i

  @first_of_month_after ~r/^(?:on )?the first day of the (?:#{@number} )?(?:calendar )?month (?:following|after) (?:that|the month) in which (.*)$/i

  @end_of_period ~r/^(?:on |at |with )?(?:the )?(?:expiration|expiry|end) of (?:a |the )?(?:period of )?#{@number} (days?|weeks?|months?|years?) (from|after|beginning with|beginning on|starting with) (.*)$/i

  # ("six months after …"; "the day which is 21 days after …": SI 2023/1394)
  @n_after ~r/^(?:on )?(?:the (?:day|date) (?:which|that) is )?#{@number} (days?|weeks?|months?) after (.*)$/i

  defp counted_shift(t, from) do
    cond do
      m = Regex.run(@nth_day_after, t) ->
        [_, n, rest] = m
        with_from(rest, from, n, fn day, k -> Date.add(day, k) end)

      m =
          Regex.run(
            @first_of_month_after,
            t
          ) ->
        first_of_month(m, from)

      m =
          Regex.run(
            @end_of_period,
            t
          ) ->
        [_, n, unit, rel, rest] = m
        extra = if String.downcase(rel) in ["from", "after"], do: 1, else: 0
        with_from(rest, from, n, fn day, k -> day |> shift(unit, k) |> Date.add(extra) end)

      m = Regex.run(@n_after, t) ->
        [_, n, unit, rest] = m
        with_from(rest, from, n, fn day, k -> shift(day, unit, k) end)

      true ->
        nil
    end
  end

  defp starts_from?(t, lead, from),
    do:
      Regex.match?(
        ~r/^#{from}/i,
        t
        |> String.replace(lead, "")
        |> String.replace(~r/^the day (?:on which|of) /i, "the day on which ")
      )

  # a period "beginning with the day after the day on which these
  # Regulations are laid" (SI 2025/287 reg.1(2)) counts from the next day
  defp with_from(rest, from, n, fun) do
    {rest, next} =
      case Regex.run(~r/^the day (?:after|following) (.*)$/i, rest) do
        [_, after_] -> {after_, 1}
        nil -> {rest, 0}
      end

    with true <- Regex.match?(~r/^#{from}/i, rest),
         k when is_integer(k) <- number(n) do
      &fun.(Date.add(&1, next), k)
    else
      _ -> nil
    end
  end

  defp first_of_month([_, n, rest], from) do
    k = if n in [nil, ""], do: 1, else: number(n)

    if is_integer(k) and Regex.match?(~r/^#{from}/i, rest),
      do: fn day -> day |> Date.beginning_of_month() |> Date.shift(month: k) end
  end

  defp first_of_month([_, rest], from), do: first_of_month([nil, "", rest], from)

  defp shift(date, unit, k) do
    case String.downcase(unit) do
      "day" <> _ -> Date.add(date, k)
      "week" <> _ -> Date.add(date, 7 * k)
      "month" <> _ -> Date.shift(date, month: k)
      "year" <> _ -> Date.shift(date, year: k)
    end
  end

  defp number(n) do
    n = String.downcase(n)

    case Integer.parse(n) do
      # (a numeric ordinal: "the 22nd day after …", SI 2022/1342)
      {i, suffix} when suffix in ["", "st", "nd", "rd", "th"] ->
        i

      _ ->
        n |> String.split(~r/[- ]/) |> words_number()
    end
  end

  # "twenty-one", "twenty one", "six"
  defp words_number([a, b]) do
    with x when is_integer(x) <- @numbers[a],
         y when is_integer(y) <- @numbers[b],
         do: x + y
  end

  defp words_number([a]), do: @numbers[a]
end

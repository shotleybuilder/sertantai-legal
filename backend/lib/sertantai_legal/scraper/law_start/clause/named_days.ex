defmodule SertantaiLegal.Scraper.LawStart.Clause.NamedDays do
  @moduledoc """
  Named days a clause comes into force on: IP completion day, exit day, and the Scotland Act 1998's principal appointed day. Pure.
  """

  @ip_completion_day ~D[2020-12-31]

  @exit_day ~D[2020-01-31]

  @doc "The named day a tail opens with (IP completion day, exit day, the principal appointed day); nil when none."
  @spec named_day_on(String.t(), Date.t() | nil) :: Date.t() | nil
  def named_day_on(tail, made) do
    case Regex.run(
           ~r/^(?:on\s+|at\s+|immediately\s+(?:before|after)\s+)?(IP completion day|implementation period completion day|exit day)\b/i,
           tail
         ) do
      [_, day] ->
        if day =~ ~r/^(?:IP|implementation)/i, do: @ip_completion_day, else: exit_day(tail, made)

      nil ->
        principal_appointed_day(tail, made)
    end
  end

  # "on [immediately before] the principal appointed day" in an instrument
  # made under the Scotland Act 1998 before that day: 1st July 1999, the
  # day SI 1998/3178 art.3 names (SI 1999/1750, SI 1999/1756). Another
  # Act's principal appointed day (Wales Act 2017 s.71) is made outside
  # that span and is not read; nor one with no made date.
  @scotland_act_passed ~D[1998-11-19]

  @principal_appointed_day ~D[1999-07-01]

  defp principal_appointed_day(tail, %Date{} = made) do
    named? =
      tail =~
        ~r/^(?:on\s+|immediately\s+(?:before|after)\s+)?the\s+principal\s+appointed\s+day\b/i

    if named? and Date.compare(made, @scotland_act_passed) != :lt and
         Date.compare(made, @principal_appointed_day) != :gt,
       do: @principal_appointed_day
  end

  defp principal_appointed_day(_tail, _made), do: nil

  # EU(WA)A 2020 Sch. 5 para. 1(1) (CR-09, Jason 2026-10-19): subordinate
  # legislation made before exit day that comes into force by reference to
  # exit day is read as coming into force by reference to IP completion day —
  # unless it expressly disapplies that (para. 1(2)); regulations varying it
  # (para. 1(3)) aren't read (a known limit). Made date unknown: as written.
  defp exit_day(tail, %Date{} = made) do
    disapplied? = tail =~ ~r/Schedule 5 to the European Union \(Withdrawal Agreement\) Act 2020/i

    if Date.compare(made, @exit_day) == :lt and not disapplied?,
      do: @ip_completion_day,
      else: @exit_day
  end

  defp exit_day(_tail, _made), do: @exit_day
end

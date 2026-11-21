defmodule SertantaiLegal.Scraper.Commencement.LeftoversExpiryTest do
  @moduledoc """
  A date on which a law ceases to have effect or expires is its end, not a
  commencement: never a commencement leftover (SI 2001/1623 reg.1(1); the
  end is a repeal fact, the feed's "expires").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Rule}

  defp rule(date),
    do:
      Rule.new(
        commences: "UK_x",
        scope: :all,
        when: {:date, date},
        source: %{law: "UK_x", ref: "reg.1(1)", text: ""},
        treatment: :clause_date
      )

  defp none(_text), do: []

  test "\"shall cease to have effect on\" (SI 2001/1623 reg.1(1))" do
    s =
      "These Regulations may be cited as the Pollution Prevention and Control (Foot-and-Mouth Disease) (Air Curtain Incinerators) (England and Wales) Regulations 2001 and shall come into force on 1st May 2001 and shall cease to have effect on 31st October 2001."

    assert Leftovers.of(s, [rule(~D[2001-05-01])], &none/1) == []
  end

  test "ceases to have effect at the end of, and expires on" do
    assert Leftovers.of(
             "This Order comes into force on 23rd December 2003 and ceases to have effect at the end of 1st April 2004.",
             [rule(~D[2003-12-23])],
             &none/1
           ) == []

    assert Leftovers.of(
             "This Order comes into force on 23rd December 2003 and expires on 1st April 2004.",
             [rule(~D[2003-12-23])],
             &none/1
           ) == []
  end

  test "a second commencement date is still left" do
    assert [%{kind: :date, words: "1st April 2004"}] =
             Leftovers.of(
               "This Order comes into force on 23rd December 2003 and article 3 comes into force on 1st April 2004.",
               [rule(~D[2003-12-23])],
               &none/1
             )
  end
end

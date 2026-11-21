defmodule SertantaiLegal.Scraper.Commencement.LeftoversRoundMentionsTest do
  @moduledoc """
  Words of a commencement statement that are rightly left, never a
  leftover (the Waste, Water and Climate round): an end date without "on",
  the provisions an event's day is described by, the provisions a partial
  rule's purpose names, and a limit on the power to appoint a day.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Rule}

  defp rule(scope, when_, treatment, opts \\ []),
    do:
      Rule.new(
        commences: "UK_x",
        scope: scope,
        when: when_,
        purposes: opts[:purposes],
        source: %{law: "UK_x", ref: "reg.1", text: ""},
        treatment: treatment
      )

  # the reader's ref extractor, as far as these sentences need it
  defp refs(text) do
    for [_, list] <-
          Regex.scan(~r/\b(?:regulations?|articles?|sections?)\s+([\d(), and]+)/i, text),
        [n] <- Regex.scan(~r/\d+(?:\(\w+\))*/, list),
        do: "reg." <> n
  end

  test "shall cease to have effect 20th July 2001, no on (WSI 2001/1506 reg.1(2))" do
    s =
      "These Regulations shall come into force on 21st April 2001 and shall cease to have effect 20th July 2001 unless previously extended or revoked by further Regulations."

    assert Leftovers.of(s, [rule(:all, {:date, ~D[2001-04-21]}, :clause_date)], &refs/1) == []
  end

  test "the provisions an event's day is described by (SI 1994/3308 art.1(2))" do
    s =
      "Article 4 shall come into force on the expiry of the period of 90 days beginning with the day on which water is first taken by the Council in terms of articles 5 and 6(2) of this Order."

    assert Leftovers.of(s, [rule(["reg.4"], :unread, :provision_unread)], &refs/1) == []
  end

  test "a provision named beside an event's day is still left" do
    s =
      "Article 4 shall come into force on the day on which water is first taken; and article 7 shall come into force on 1st May 1995."

    assert %{kind: :provision, words: "reg.7"} in Leftovers.of(
             s,
             [rule(["reg.4"], :unread, :provision_unread)],
             &refs/1
           )
  end

  test "the provisions a partial rule's enabling purpose names (SI 2012/2079 reg.1(3A), (4))" do
    partial =
      rule(["pt.8"], {:date, ~D[2012-10-01]}, :provision_qualified,
        purposes: :for_specified_purposes
      )

    full = rule(["pt.8"], {:date, ~D[2013-01-28]}, :provision_dated)

    s =
      "Part 8 of these Regulations comes into force— (a) so far as is necessary for the purpose of enabling the Secretary of State to take action in relation to a breach of the requirements listed in regulation 63 of these Regulations (other than the requirements in regulations 24(1)(d)(i) and (2) and 26), on 1st October 2012; (b) for all remaining purposes, on 28th January 2013."

    assert Leftovers.of(s, [partial, full], &refs/1) == []

    s2 =
      "Regulation 42 comes into force— (a) so far as is necessary for the purpose of enabling the Secretary of State to make provision under section 9 and the Scottish Ministers to make provision under section 10, on the relevant date; (b) for all remaining purposes, on 28th January 2013."

    r42 = [
      rule(["reg.42"], :unread, :provision_qualified, purposes: :for_specified_purposes),
      rule(["reg.42"], {:date, ~D[2013-01-28]}, :provision_dated)
    ]

    assert Leftovers.of(s2, r42, &refs/1) == []
  end

  test "an enabling purpose no partial rule carries keeps its provisions" do
    s =
      "Part 8 of these Regulations comes into force for the purpose of enabling action under regulation 63, on 1st October 2012."

    assert %{kind: :provision, words: "reg.63"} in Leftovers.of(
             s,
             [rule(["pt.8"], {:date, ~D[2012-10-01]}, :provision_dated)],
             &refs/1
           )
  end

  test "a limit on the power to appoint a day is no statement (asp 2014/14 s.104(4))" do
    s =
      "The Scottish Ministers may not appoint a day for section 1(1) to come into force which is before the end of the period of 2 years beginning with the day of Royal Assent."

    assert Leftovers.of(s, [], &refs/1) == []
  end
end

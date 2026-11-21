defmodule SertantaiLegal.Scraper.Commencement.LeftoversNotOwnStatementTest do
  @moduledoc """
  Sentences that hold "come into force" yet state no commencement of the
  law's own leave no leftover (LAT Change Pipeline, step Commencement
  reader; the Waste, Water and Climate round): an instrument made under
  the law, another Act's provisions, and a period named by the law's
  commencement.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Leftovers

  # every provision the words name is left, were the sentence a statement
  defp refs(text),
    do:
      for(
        [_, n] <- Regex.scan(~r/\b(?:Article|regulation|paragraph)\s+\(?(\d+)/i, text),
        do: "reg." <> n
      )

  test "an order made under the law may come into operation (NISI 1981/158 art.17(12))" do
    s =
      "Notwithstanding anything in paragraph 7 of Schedule 2 an order made by a district council under this Article varying a previous order so as to exempt specified buildings or classes of building or specified fireplaces or classes of fireplace from the operation of this Article may come into operation on, or at any time after, the date of its confirmation."

    assert Leftovers.of(s, [], &refs/1) == []
  end

  test "the provisions of another Act an order commences (SSI 2005/351 art.2)" do
    s =
      "The provisions of the 2005 Act which are specified in column 1 of either Schedule 1 or Schedule 2 to this Order, the subject matter of which is described in column 2 of those Schedules shall, so far as not then in force, come into force on the day appointed in relation to that Schedule in the Table below; but where a particular purpose is specified in relation to any such provision in column 3 of those Schedules, that provision shall come into force on that day only for that purpose."

    assert Leftovers.of(s, [], &refs/1) == []
  end

  test "a period within which the law comes into force (SI 2025/910 reg.28(5)(b)(i))" do
    s =
      "for paragraph (4)(a) of this regulation, the amount of category 7 EEE placed on the market during the period beginning with the commencement of the quarter period within which these Regulations come into force and ending with the date on which these Regulations come into force;"

    assert Leftovers.of(s, [], &refs/1) == []
  end

  test "the law's own provision on a day is still a statement" do
    assert [_ | _] =
             Leftovers.of(
               "Regulation 4 comes into force on 1st July 2005.",
               [],
               &refs/1
             )
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.AffectingMadeTest do
  @moduledoc """
  The affecting law's own made day, claimed where legislation.gov.uk's feed
  dates a stage "in accordance with" that law's own clause (the agent pass,
  Environmental Protection: Evidence, Decision 4: SI 2016/562, made
  2016-05-04, "coming into force in accordance with art. 1(2)-(5)").
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AffectingMade

  @by "UK_uksi_2016_562"
  @made %{@by => ~D[2016-05-04]}

  defp change(qualification, date \\ ~D[2016-05-04]),
    do: %Change{
      key: "key-x",
      target: "reg.17(3)",
      claims:
        Enum.flat_map(
          [
            {:feed, :operation, :substituted},
            {:feed, :by, @by},
            {:feed, :date, date},
            {:feed, :qualification, qualification}
          ],
          fn {s, a, v} -> Claim.new(s, a, v, "key-x") end
        )
    }

  test "a stage qualified 'in accordance with' carries its law's made day" do
    assert [%Claim{source: :law, attribute: :made, value: ~D[2016-05-04]}] =
             AffectingMade.claims(change("in accordance with"), @made)
  end

  test "any other stage claims nothing" do
    assert AffectingMade.claims(change(nil), @made) == []
    assert AffectingMade.claims(change("purposes"), @made) == []
    assert AffectingMade.claims(change("in accordance with"), %{}) == []
  end

  test "the feed's date on its law's made day is a pointer, never the change's date" do
    c = change("in accordance with")
    c = %Change{c | claims: c.claims ++ AffectingMade.claims(c, @made)}

    assert Evidence.resolve(c, nil).resolved.date == nil
  end

  test "a stage 'in accordance with' on another day keeps its date" do
    c = change("in accordance with", ~D[2022-01-01])
    c = %Change{c | claims: c.claims ++ AffectingMade.claims(c, @made)}

    assert Evidence.resolve(c, nil).resolved.date == ~D[2022-01-01]
  end
end

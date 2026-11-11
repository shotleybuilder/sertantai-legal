defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AffectingMade do
  @moduledoc """
  The day the affecting law was made (an SI) or passed (an Act), claimed
  on a change whose feed stage is qualified "in accordance with": there
  legislation.gov.uk may date the stage on that day as a placeholder for
  the law's own clause (SI 2016/562: "coming into force in accordance with
  art. 1(2)-(5)", dated the day it was made, though its Schedule 2 waits
  for the Protocols' entry into force; the agent pass, Environmental
  Protection: Evidence, Decision 4). The evidence table never takes the
  feed's date on that day (`Evidence`, `:not_made_day`).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}

  @doc "The `{:law, :made, date}` claim for `change`, from `made` (law → day); [] otherwise."
  @spec claims(Change.t(), %{String.t() => Date.t()}) :: [Claim.t()]
  def claims(%Change{} = c, made) do
    with true <- pointer_stage?(c),
         [law | _] <- c |> Change.values(:feed, :by) |> Enum.filter(&is_binary/1),
         %Date{} = d <- Map.get(made, law) do
      Claim.new(:law, :made, d, c.key)
    else
      _ -> []
    end
  end

  defp pointer_stage?(c),
    do:
      c
      |> Change.values(:feed, :qualification)
      |> Enum.any?(&(is_binary(&1) and String.contains?(&1, "in accordance with")))
end

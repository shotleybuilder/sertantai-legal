defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement do
  @moduledoc """
  The law's own commencement as claims — primary (change vocabulary CV-03;
  Jason 2026-10-21: "The actual legal text is primary"): its commencement
  clause and the orders read (`Commencement.Rule`s, `Commencement.Store`),
  evaluated for each provision (`Commencement.Evaluator`). A provision
  partly in force first and fully later gives two stages; each is a
  `:commenced` change by the law itself (source `:commencement`).

  Not its own text: the feed's coming-into-force records (derived; the feed
  reader's), and an Act's Royal Assent where its clause leaves the rest to
  orders, or a staged clause's earliest stage (the law's start, not a
  provision's commencement: CR-06). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.Commencement.Rule

  # a staged clause's law-level rule is the law's start (its earliest
  # stage, LR-33), not when a provision came in (CR-06; EUWA 2018 s.6)
  @not_text [:feed_commencement, :act_enactment, :clause_staged]

  @doc "Claim sets `{key, target, claims}` for each provision in `ids` (LAT refs)."
  @spec read([Rule.t()], String.t(), [String.t()]) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(rules, law_name, ids) do
    text = Enum.reject(rules, &(&1.treatment in @not_text))

    for id <- ids,
        text != [],
        result = Evaluator.evaluate(text, id, Order.context()),
        {date, partial?} <- stages(result),
        do: {"#{law_name}:commencement:#{id}@#{date}", id, claims(law_name, date, partial?)}
  end

  defp stages(%{full_from: full, partial_from: partial}) do
    Enum.reject([{partial, true}, {full, false}], &is_nil(elem(&1, 0)))
  end

  defp claims(law, date, partial?) do
    ref = "#{law}:commencement"

    Enum.concat([
      Claim.new(:commencement, :operation, :commenced, ref),
      Claim.new(:commencement, :level, :provision, ref),
      Claim.new(:commencement, :date, date, ref),
      Claim.new(:commencement, :partial, partial?, ref),
      Claim.new(:commencement, :commenced_by, law, ref)
    ])
  end
end

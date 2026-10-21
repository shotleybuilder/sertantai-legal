defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw do
  @moduledoc """
  The amending law's own text as claims — the primary source (change
  vocabulary CV-03; Jason 2026-10-21: "The actual legal text is primary").

  Each stored `Amendment.Rule` (the amending law's instruction or repeals
  table entry read by `Amendment.Reader`) is one change per target, keyed
  `source law:source provision`. Claims (source `:law_text`): `operation`,
  `level`, `by` (the amending law). Its date (source `:commencement`) is
  when the amending provision came into force by the amending law's own
  text — its commencement clause and the orders read
  (`Commencement.Evaluator` over the text rules; the feed's
  coming-into-force records are derived, the feed reader's).

  Targets: a rule lists the provisions its words name and their parents
  ("s.284(3)", "s.284(3)(i)"). A words change lands on the deepest named
  (no listed provision below it); a provision change on the top-most (no
  listed provision above it — its sub-provisions follow it).

  Pure: the rules come in as data (`Amendment.Store`, `Commencement.Store`
  in the caller).
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.Commencement.Rule, as: CRule
  alias SertantaiLegal.Scraper.LatRef

  # rules that are not the amending law's own text: the feed's records
  # (derived); an Act's Royal Assent or a staged clause's earliest date is
  # the law's start, not when a provision came in (CR-06)
  @not_text [:feed_commencement, :act_enactment, :clause_staged]

  @doc """
  Claim sets `{key, target, claims}` from the rules amending a law, dated
  by `commencement` (amending law → its `Commencement.Rule`s).
  """
  @spec read([Rule.t()], %{String.t() => [CRule.t()]}, [String.t()] | nil) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(rules, commencement \\ %{}, known \\ nil) do
    known = known && MapSet.new(known)

    # a target the amended law doesn't contain is a misread, not a fact
    for %Rule{source: %{law: law, ref: ref}} = r <- rules,
        target <- targets(r),
        known == nil or MapSet.member?(known, target) do
      key = "#{law}:#{ref}"

      {key, target,
       Enum.concat([
         Claim.new(:law_text, :operation, r.operation, key),
         Claim.new(:law_text, :level, r.level, key),
         Claim.new(:law_text, :by, law, key),
         Claim.new(:commencement, :date, date(Map.get(commencement, law, []), ref), key)
       ])}
    end
  end

  defp targets(%Rule{targets: targets, level: level}) do
    ts = Enum.uniq(targets)

    Enum.filter(ts, fn t ->
      case level do
        :words -> not Enum.any?(ts, &(&1 != t and t in tl(LatRef.ancestors(&1))))
        _provision -> not Enum.any?(tl(LatRef.ancestors(t)), &(&1 in ts))
      end
    end)
  end

  # when the amending provision came fully into force by the law's own text
  defp date(rules, ref) do
    text = Enum.reject(rules, &(&1.treatment in @not_text))

    case text do
      [] -> nil
      _ -> Evaluator.evaluate(text, Order.ref(ref) || ref, Order.context()).full_from
    end
  end
end

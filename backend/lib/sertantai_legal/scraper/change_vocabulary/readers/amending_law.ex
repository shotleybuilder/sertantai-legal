defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw do
  @moduledoc """
  The amending law's own text as claims — the primary source (change
  vocabulary CV-03; Jason 2026-10-21: "The actual legal text is primary").

  Each stored `Amendment.Rule` (the amending law's instruction or repeals
  table entry read by `Amendment.Reader`) is one change per target, keyed
  `source law:source provision`. Claims (source `:law_text`): `operation`,
  `level`, `by` (the amending law), `territory` (where the amending law
  applies, by its own application clause: `AmendingLaw.Extent`, CV-07). Its date (source `:commencement`) is
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
  # (derived); a staged clause's earliest date is the law's start, not when
  # a provision came in (CR-06). An Act's Royal Assent is its own: since
  # CV-S04 an Act with a clause has the clause's rule, so a Royal Assent
  # rule is an Act with none, in force on Royal Assent (Interpretation Act
  # 1978 s.4; Jason 2026-10-23)
  @not_text [:feed_commencement, :clause_staged]

  @doc """
  Claim sets `{key, target, claims}` from the rules amending a law, dated
  by `commencement` (amending law → its `Commencement.Rule`s).
  """
  @spec read(
          [Rule.t()],
          %{String.t() => [CRule.t()]},
          [String.t()] | nil,
          %{String.t() => SertantaiLegal.Scraper.AmendingLaw.Extent.t()}
        ) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(rules, commencement \\ %{}, known \\ nil, extents \\ %{}) do
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
         Claim.new(:commencement, :date, date(Map.get(commencement, law, []), ref), key),
         # where the amending law applies (its application clause; CV-07),
         # or the amending provision's own (CV-S05 round 7)
         Claim.new(:law_text, :territory, application(extents, law, ref), key)
       ])}
    end
  end

  defp application(extents, law, ref) do
    case Map.get(extents, law) do
      %SertantaiLegal.Scraper.AmendingLaw.Extent{} = e ->
        SertantaiLegal.Scraper.AmendingLaw.Extent.application_at(e, List.wrap(Order.ref(ref)))

      %{application: a} ->
        a

      _ ->
        nil
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

  @doc """
  When the amending provision `ref` came fully into force by its law's own
  text (`rules`: the amending law's commencement rules; the feed's records,
  an Act's Royal Assent and a staged clause's start left out). Nil when
  they don't say.
  """
  @spec commenced_on([CRule.t()], String.t()) :: Date.t() | nil
  def commenced_on(rules, ref), do: date(rules, ref)

  @doc """
  The amending provision `ref`'s commencement by its law's own text (the
  evaluator's result), or nil when the law holds no text rules: what
  `commenced_on/2` dates by, for saying why it doesn't.
  """
  @spec commencement([CRule.t()], String.t()) :: Evaluator.result() | nil
  def commencement(rules, ref) do
    case Enum.reject(rules, &(&1.treatment in @not_text)) do
      [] -> nil
      text -> Evaluator.evaluate(text, Order.ref(ref) || ref, Order.context())
    end
  end

  # when the amending provision came fully into force by the law's own text
  defp date(rules, ref) do
    case commencement(rules, ref) do
      nil -> nil
      r -> r.full_from
    end
  end
end

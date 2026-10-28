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

  Targets: those the amended law holds, then — a rule lists the
  provisions its words name and their parents ("s.284(3)", "s.284(3)(i)")
  — a quoted provision change on the top-most (no listed provision above
  it: its sub-provisions follow it); any other change on the deepest named
  (no listed provision below it: "subsection (6)(e) is omitted" is
  s.15(6)(e), never s.15(6) — CV-S06 B5).

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
        target <- targets(r, known) do
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

  # the targets the amended law holds (a misread is not a fact): a quote's
  # top (its provisions follow it); a named place's readings each resolved
  # to the longest spelling held ("subsection (6)(e) is omitted" is
  # s.15(6)(e), never s.15(6) — CV-S06 B5; HSWA's CLML names s.28(3)(f)(i)
  # "section-28-f-i", so "paragraph (f)(i) of subsection (3)" is s.28(f)(i),
  # never also s.28(3) — CV-S06 seed 31 NEW); siblings stay apart
  defp targets(%Rule{targets: targets} = r, known) do
    ts = Enum.uniq(targets)
    held? = &(known == nil or MapSet.member?(known, &1))

    if r.level == :provision and r.treatment == :quoted do
      ts = Enum.filter(ts, held?)
      Enum.reject(ts, fn t -> Enum.any?(tl(LatRef.ancestors(t)), &(&1 in ts)) end)
    else
      held = Enum.filter(ts, held?)

      ts
      |> Enum.reject(fn t -> Enum.any?(ts, &(&1 != t and spells?(t, &1))) end)
      |> Enum.flat_map(&longest_held(&1, held))
      |> Enum.uniq()
      |> deepest_only()
    end
  end

  # a place resolved beside a deeper one it holds is no change of its own
  # ("paragraphs (a)(i) and (ii) of paragraph (5)": never also (5))
  defp deepest_only(ts),
    do:
      Enum.reject(ts, fn t ->
        Enum.any?(ts, &(&1 != t and (spells?(t, &1) or t in tl(LatRef.ancestors(&1)))))
      end)

  # the held spellings of a full reading with the most brackets
  defp longest_held(full, held) do
    case Enum.filter(held, &(&1 == full or spells?(&1, full))) do
      [] ->
        []

      spellings ->
        most = spellings |> Enum.map(&length(brackets(&1))) |> Enum.max()
        Enum.filter(spellings, &(length(brackets(&1)) == most))
    end
  end

  # `t` is a shorter spelling of `u`: the same provision, its brackets a
  # subsequence of `u`'s ("s.28(f)(i)" and "s.28(3)" of "s.28(3)(f)(i)")
  defp spells?(t, u) do
    {pt, bt} = split(t)
    {pu, bu} = split(u)
    pt == pu and length(bt) < length(bu) and subsequence?(bt, bu)
  end

  defp subsequence?([], _), do: true
  defp subsequence?(_, []), do: false
  defp subsequence?([x | xs], [x | ys]), do: subsequence?(xs, ys)
  defp subsequence?(xs, [_ | ys]), do: subsequence?(xs, ys)

  defp brackets(t), do: elem(split(t), 1)

  defp split(t) do
    case Regex.run(~r/^([^()]+)((?:\([^()]+\))*)$/, t) do
      [_, head, bs] ->
        {head, Regex.scan(~r/\(([^()]+)\)/, bs, capture: :all_but_first) |> List.flatten()}

      nil ->
        {t, []}
    end
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

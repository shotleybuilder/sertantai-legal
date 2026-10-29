defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingCommencement do
  @moduledoc """
  When an amending provision came into force, and by which law (change
  vocabulary; split from `Readers.AmendingLaw`, CV-S08): its law's own
  commencement rules (its clause, and the orders read for it) evaluated at
  the provision (`Commencement.Evaluator`) — never its feed's records nor a
  staged clause's start. Royal Assent dates only what no other rule
  reaches; a Schedule's paragraph comes in with the provision giving the
  Schedule effect. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order, ScheduleEffect}
  alias SertantaiLegal.Scraper.Commencement.Rule, as: CRule

  # rules that are not the amending law's own text: the feed's records
  # (derived); a staged clause's earliest date is the law's start, not when
  # a provision came in (CR-06). An Act's Royal Assent is its own: since
  # CV-S04 an Act with a clause has the clause's rule, so a Royal Assent
  # rule is an Act with none, in force on Royal Assent (Interpretation Act
  # 1978 s.4; Jason 2026-10-23)
  @not_text [:feed_commencement, :clause_staged]

  @doc "The commencement claims for the change (date and the commencing law), keyed `key`."
  @spec claims([CRule.t()], String.t(), String.t()) :: [Claim.t()]
  def claims(rules, ref, key) do
    result = commencement(rules, ref)
    date = result && result.full_from

    Claim.new(:commencement, :date, date, key) ++
      if(date, do: Claim.new(:commencement, :commenced_by, commenced_by(result), key), else: [])
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
  # An Act's Royal Assent (`:act_enactment`) is a default: it dates only a
  # provision no other rule reaches — an order's or the clause's own rule
  # wins over it (CV-S08 round 1: Employment Rights Act 2025 Sch.12 by SI
  # 2026/954, 1 October 2026, not Royal Assent; PJA 2006 Sch.15). A
  # Schedule's paragraph nothing more specific dates comes in with the
  # provision giving the Schedule effect (`Commencement.ScheduleEffect`,
  # CV-S08 round 2: Energy Act 2013 Sch.12 with s.116(1), Part 3's order)
  def commencement(rules, ref) do
    case Enum.reject(rules, &(&1.treatment in @not_text)) do
      [] ->
        nil

      text ->
        at = Order.ref(ref) || ref
        {effects, text} = Enum.split_with(text, &(&1.treatment == :schedule_effect))
        own = evaluate(text, at, Order.context())

        case specific?(own, at) || introduced(effects, text, at) do
          %{} = result -> result
          _ -> own
        end
    end
  end

  # the evaluation, Royal Assent reaching only what nothing else does
  defp evaluate(text, at, ctx) do
    {assent, rest} = Enum.split_with(text, &(&1.treatment == :act_enactment))

    case rest != [] and assent != [] and Evaluator.evaluate(rest, at, ctx) do
      %{entries: [_ | _]} = result -> result
      _ -> Evaluator.evaluate(text, at, ctx)
    end
  end

  # a rule naming the provision (or a provision holding it) dates it
  defp specific?(%{entries: entries} = result, at) do
    if not String.starts_with?(at, "sch") or
         Enum.any?(entries, &(is_list(&1.rule.scope) and &1.date != nil)),
       do: result
  end

  defp introduced(effects, text, at) do
    with %{} = effect <-
           Enum.find(effects, fn e ->
             Enum.any?(e.scope, &(at == &1 or String.starts_with?(at, &1 <> ".")))
           end),
         {provision, containers} = ScheduleEffect.introducer(effect),
         ctx =
           Map.put(
             Order.context(),
             :ancestors,
             &if(&1 == top(provision), do: containers, else: [])
           ),
         %{entries: [_ | _]} = result <- evaluate(text, provision, ctx),
         %Date{} <- result.full_from do
      result
    else
      _ -> nil
    end
  end

  defp top(ref), do: String.replace(ref, ~r/\(.*$/, "")

  @doc """
  The law whose rule brought the provision fully into force (an order, or
  the amending law's own clause): the commencement's `commenced_by`, apart
  from the law making the change (CV-S08 round 1: HSWA s.27(5), inserted
  by the Building Safety Act 2022, commenced by SI 2022/561).
  """
  @spec commenced_by(Evaluator.result() | nil) :: String.t() | nil
  def commenced_by(%{full_from: %Date{} = full, entries: entries}) do
    Enum.find_value(entries, fn
      %{date: ^full, rule: %{source: %{law: law}}} when is_binary(law) -> law
      _ -> nil
    end)
  end

  def commenced_by(_result), do: nil

  # when the amending provision came fully into force by the law's own text
  defp date(rules, ref) do
    case commencement(rules, ref) do
      nil -> nil
      r -> r.full_from
    end
  end
end

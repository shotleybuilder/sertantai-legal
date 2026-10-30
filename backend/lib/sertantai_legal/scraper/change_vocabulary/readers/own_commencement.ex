defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement do
  @moduledoc """
  The law's own commencement as claims — primary (change vocabulary CV-03;
  Jason 2026-10-21: "The actual legal text is primary"): its commencement
  clause and the orders read (`Commencement.Rule`s, `Commencement.Store`),
  evaluated for each provision (`Commencement.Evaluator`). A provision
  partly in force first and fully later gives two stages; each is a
  `:commenced` change by the law itself (source `:commencement`).

  Not its own text: the feed's coming-into-force records (derived; the feed
  reader's), and a staged clause's earliest stage (the law's start, not a
  provision's commencement: CR-06). An Act's Royal Assent is its own: an
  Act with a general clause has that clause's rule (dated, left to orders,
  tied or unread: `OwnClause`, CV-S04), so a Royal Assent rule is an Act
  with none, in force on Royal Assent (Interpretation Act 1978 s.4). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.LatRef

  # a staged clause's law-level rule is the law's start (its earliest
  # stage, LR-33), not when a provision came in (CR-06; EUWA 2018 s.6)
  @not_text [:feed_commencement, :clause_staged]

  @doc """
  Claim sets `{key, target, claims}` for each provision in `ids` (LAT
  refs). `ctx`: the law's row structure (`OwnClause.context/1`: its Parts
  and Chapters, document order; else `Order.context/0`); `extents`: each
  provision's extent, so territorial commencements covering it bring it
  fully into force (CV-S04: NI Order 1997/1774 commenced "for N.I.").
  """
  @spec read([Rule.t()], String.t(), [String.t()], map(), %{String.t() => String.t() | nil}) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(rules, law_name, ids, ctx \\ Order.context(), extents \\ %{}) do
    text = Enum.reject(rules, &(&1.treatment in @not_text))

    own =
      for id <- ids,
          text != [],
          result = Evaluator.evaluate(text, id, Map.put(ctx, :extent, Map.get(extents, id))),
          {date, partial?, by} <- stages(result, law_name),
          do: {"#{law_name}:commencement:#{id}@#{date}", id, claims(law_name, date, partial?, by)}

    own ++ unheld(text, law_name, ids, ctx, own)
  end

  # a rule naming a provision the law holds no row for (its text gone:
  # HSWA s.83(1), SI 1974/1439, of a repealed s.83) commences the nearest
  # row holding it — partly, as only that part came in (CV-S09 round 5);
  # never on a date the row has its own stage
  defp unheld(text, law_name, ids, ctx, own) do
    held = MapSet.new(ids)
    staged = MapSet.new(own, &elem(&1, 0))

    for %Rule{scope: scope} <- text,
        is_list(scope),
        ref <- scope,
        part = ref |> String.split("..") |> hd(),
        not MapSet.member?(held, part),
        row = Enum.find(tl(LatRef.ancestors(part)), &MapSet.member?(held, &1)),
        row != nil,
        result = Evaluator.evaluate(text, part, ctx),
        {date, _partial?, by} <- stages(result, law_name),
        key = "#{law_name}:commencement:#{row}@#{date}",
        not MapSet.member?(staged, key),
        uniq: true,
        do: {key, row, claims(law_name, date, true, by)}
  end

  @type outcome ::
          :dated
          | :staged
          | :partial_only
          | :by_order
          | :by_order_partly
          | :tied
          | :unread
          | :not_reached
          | :eu_directive
          | :eu_publication_relative
          | :staged_start_only
          | :no_rules

  @faults [:not_reached, :no_rules]

  @doc """
  What the reader makes of provision `id` (CV-S04: every row accounted
  for), with the evaluator's result (nil when the law holds no text rules):

  - `:dated` — fully in force on a date; `:staged` — partly first, fully
    later; `:partial_only` — partly, never fully;
  - `:by_order` — left to a day an order appoints, which no rule held
    dates (J6); `:by_order_partly` — partly in on a date, the rest so left;
  - `:tied` — with another provision's commencement, not resolved;
    `:unread` — only a statement not read reaches it;
  - `:not_reached` — the law's text rules reach it nowhere (our fault);
  - no text rules: `:eu_directive` (never in force in the UK: a known
    limit), `:eu_publication_relative` (an EU regulation or decision whose
    text counts from Official Journal publication, or whose entry-into-force
    article the retained text omits — REACH Art. 141, CLP Art. 62 — with a
    consolidation's metadata: a known limit, LR-33 P3; `LawStart.Eu` gives
    an EU regulation a rule otherwise), `:staged_start_only` (only a staged clause's start: the law's
    start, not a provision's), `:no_rules` (nothing read: our fault).
  """
  @spec outcome([Rule.t()], String.t(), String.t(), map()) ::
          {outcome(), Evaluator.result() | nil}
  def outcome(rules, law_name, id, ctx \\ Order.context()) do
    case Enum.reject(rules, &(&1.treatment in @not_text)) do
      [] -> {no_text(rules, law_name), nil}
      text -> text |> Evaluator.evaluate(id, ctx) |> then(&{class(&1), &1})
    end
  end

  @doc "True for an outcome that is our fault (pass needs none)."
  @spec fault?(outcome()) :: boolean()
  def fault?(outcome), do: outcome in @faults

  defp no_text(rules, law_name) do
    treatments = rules |> Enum.map(& &1.treatment) |> MapSet.new()

    cond do
      String.contains?(law_name, "_eudr_") -> :eu_directive
      String.contains?(law_name, ["_eur_", "_eudn_"]) -> :eu_publication_relative
      MapSet.member?(treatments, :clause_staged) -> :staged_start_only
      true -> :no_rules
    end
  end

  defp class(r) do
    appointed? = Enum.any?(r.undated, &match?({:appointed, _}, &1.when))

    cond do
      r.full_from && r.partial_from -> :staged
      r.full_from -> :dated
      r.partial_from && appointed? -> :by_order_partly
      r.partial_from -> :partial_only
      appointed? -> :by_order
      Enum.any?(r.undated, &match?({:with, _}, &1.when)) -> :tied
      r.undated != [] -> :unread
      true -> :not_reached
    end
  end

  # each stage with the law whose rule dates it: an order the law's notes
  # cite (SI 1974/1439 commencing HSWA s.78), else the law itself (CV-S09
  # round 1: an order's law was lost, so `commenced_by` read the Act)
  defp stages(%{full_from: full, partial_from: partial, entries: entries}, law) do
    for {date, partial?} <- [{partial, true}, {full, false}], date != nil do
      by =
        Enum.find_value(entries, law, fn
          %{date: ^date, rule: %{source: %{law: l}}} when is_binary(l) -> l
          _ -> nil
        end)

      {date, partial?, by}
    end
  end

  defp claims(law, date, partial?, by) do
    ref = "#{law}:commencement"

    Enum.concat([
      Claim.new(:commencement, :operation, :commenced, ref),
      Claim.new(:commencement, :level, :provision, ref),
      Claim.new(:commencement, :date, date, ref),
      Claim.new(:commencement, :partial, partial?, ref),
      Claim.new(:commencement, :commenced_by, by, ref)
    ])
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelRules do
  @moduledoc """
  The switch-over's rules (CV-06; Jason 2026-11-01: "a pass that doesn't
  rely on agents"): each fault class the agents found, as a check code
  runs over every row of a family. The pass needs no breach outside the
  named known limits.

  - `:before_amender` — a period credited to a law (`changed_by`) begins
    before that law was made or enacted (EPA 1975's Sch.15 text dated
    1974: round 2 S5);
  - `:before_insertion` — a period begins before the row's own dated
    insertion, nothing showing it was there (FA 1961 s.10A(3)(b): S7);
  - `:windsor_ni` — on a law the Windsor Framework keeps in NI (C8), a
    period from 2020-12-31 made only by UK laws reaches NI (S3);
  - `:no_made_period` — a law made before it starts, and the row there
    from its start, has no prospective period from its making (LR-39: S4);
  - `:saved_not_saved` — a repeal its law's text saves, labelled repealed
    (R2, S2).

  Not a breach, listed apart: `:legacy_unconfirmed` — a period before an
  insertion only legacy markup claims, which the fold doesn't trust (that
  markup also marks substitutions: HSWA s.30 by EPA 1975), no amending-law
  text read for it (CV-06 batch 2).

  `ctx`: `made` (the row's law's making), `law_start`, `eu` (EU law: no
  made period, its start unknown before its first dated change), `windsor`
  (listed?), `made_of` (law → its making), `existed` (the
  `Label.Existence` evidence, a function of the day).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Start

  @ip_completion ~D[2020-12-31]

  @type breach :: {atom(), String.t()}

  @doc "The rules a row's periods (`Label.fold/3`'s) break, with what shows it."
  @spec breaches([map()], [Change.t()], map()) :: [breach()]
  def breaches([], _reaching, _ctx), do: []

  def breaches(periods, reaching, ctx) do
    # the timeline's rows (`LabelPeriods`): status a string, changed_by the
    # list in changed_by_all
    periods =
      Enum.map(periods, fn p ->
        %{
          p
          | status: to_string(p.status),
            changed_by: Map.get(p, :changed_by_all, List.wrap(p.changed_by))
        }
      end)

    Enum.concat([
      before_amender(periods, ctx),
      before_insertion(periods, reaching, ctx),
      windsor_ni(periods, ctx),
      no_made_period(periods, reaching, ctx),
      saved_not_saved(periods, reaching)
    ])
  end

  defp before_amender(periods, ctx) do
    for p <- periods,
        law <- List.wrap(p.changed_by),
        made = Map.get(ctx.made_of, law),
        match?(%Date{}, made) and Date.compare(p.valid_from, made) == :lt,
        uniq: true,
        do: {:before_amender, "#{law} made #{made}, period from #{p.valid_from}"}
  end

  defp before_insertion(periods, reaching, ctx) do
    first = hd(periods).valid_from
    insertions = Enum.filter(reaching, &whole_insertion?/1)

    # an insertion of the same provision dated on or before the first day
    # began it there: a later one is another version's (EPA s.33(10)(a)[S],
    # inserted for S by SSI 2005/22, for E+W by SI 2006/937)
    begun? = fn c ->
      Enum.any?(
        insertions,
        &(&1.target == c.target and Date.compare(&1.resolved.date, first) != :gt)
      )
    end

    for c <- insertions,
        Date.compare(first, c.resolved.date) == :lt,
        not begun?.(c),
        not ctx.existed.(c.resolved.date),
        uniq: true,
        do:
          {if(Start.legacy_only?(c), do: :legacy_unconfirmed, else: :before_insertion),
           "inserted #{c.resolved.date} by #{c.resolved.by}, period from #{first}"}
  end

  defp whole_insertion?(c),
    do:
      c.resolved.operation == :inserted and c.resolved.level == :provision and
        c.resolved.date != nil

  @doc "The rules listed apart, never failing the pass."
  @spec informational() :: [atom()]
  def informational, do: [:legacy_unconfirmed]

  defp windsor_ni(_periods, %{windsor: false}), do: []

  defp windsor_ni(periods, _ctx) do
    for p <- periods,
        Date.compare(p.valid_from, @ip_completion) != :lt,
        p.changed_by != [] and Enum.all?(p.changed_by, &uk_made?/1),
        is_binary(p.territory) and String.contains?(p.territory, "NI"),
        do: {:windsor_ni, "#{p.valid_from} by #{Enum.join(p.changed_by, ",")} in #{p.territory}"}
  end

  defp no_made_period([first | _], reaching, ctx) do
    made = ctx.made
    # the law's start, else (none held: a law commenced by an order) the
    # row's first day
    start = ctx.law_start || first.valid_from

    inserted? =
      Enum.any?(
        reaching,
        &(&1.resolved.operation == :inserted and &1.resolved.level == :provision)
      )

    if match?(%Date{}, made) and match?(%Date{}, start) and Date.compare(made, start) == :lt and
         first.valid_from == start and first.status != "prospective" and not inserted? and
         not ctx.eu,
       do: [{:no_made_period, "made #{made}, first period #{first.status} from #{start}"}],
       else: []
  end

  defp saved_not_saved(periods, reaching) do
    for c <- reaching,
        c.resolved.saved == true and c.resolved.operation == :repealed and
          c.resolved.level == :provision and c.resolved.date != nil,
        p = Enum.find(periods, &(&1.valid_from == c.resolved.date)),
        p != nil and p.status == "repealed",
        uniq: true,
        do: {:saved_not_saved, "#{c.resolved.by} saves its repeal of #{c.resolved.date}"}
  end

  defp uk_made?(law), do: not String.starts_with?(law, "UK_eu")
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Stages do
  @moduledoc """
  A change's chosen stages (`resolved.stages`, RULES
  `stages-go-with-the-date`) unfolded into the commencements the label fold
  already reads (Fire and OH&S: Label fold, Decision 2 a):

  - the change itself takes its first stage: its date, whether it is
    partial, its commencing order and the territory it is for;
  - each later stage of a whole insertion is a commencement of the
    provision inserted (the change's target), with the stage's date, order
    (`commenced_by`), territory (`in_force_for`) and partial flag, at the
    tier of the stages' source (the commencement's: primary; the feed's:
    derived);
  - any other text change (words, a substitution) is one version from its
    first stage, a fact, never a commencement of the provision, which its
    own law brought into force (golden: TCPA 1990 s.284(3)(a)): a stage on
    that same day is the change again with the stage's order and
    territory, so each order is credited; a later day's stage opens
    nothing.

  - a whole removal is unfolded as the feed reader unfolds its own
    (`Readers.Feed.staged_removal/2`): a removal in part at each partial
    stage (the stage's order and territory), the repeal at the full one;
    a partial stage for one territory alone is the repeal there; stages
    all partial, it stays removed in part — unless the change is
    resolved as whole, when the repeal stands on its date. Its stages
    never reach a provision made again (a whole insertion or substitution
    of the same target) after the removal began: it is not unfolded. Words
    repealed by stages are a text change.

  The change's own date, where no stage has it, is a stage too (a full
  date later than every stage read). An unfolded change carries no
  stages, so unfolding twice changes nothing. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts

  # what the fold reads off a commencement's claims (`Label.Facts`)
  @read [:in_force_for, :qualification, :via]

  @doc "The changes with every staged text change unfolded."
  @spec unfold([Change.t()]) :: [Change.t()]
  def unfold(changes) do
    if Enum.any?(changes, &staged?/1) do
      made = made_again(changes)
      Enum.flat_map(changes, &unfold_one(&1, made))
    else
      changes
    end
  end

  # each provision's dated whole insertions and substitutions
  defp made_again(changes) do
    for %Change{target: t, resolved: %{level: :provision, operation: op, date: %Date{} = d}} <-
          changes,
        op in [:inserted, :substituted],
        reduce: %{} do
      acc -> Map.update(acc, t, [d], &[d | &1])
    end
  end

  # a removal's stages never reach a provision made again after the
  # removal began (EPA 1990 s.75(2)(a): removed by EA 1995 in stages from
  # 2005, a new one inserted for S in 2011): it folds as resolved
  defp made_again?(%Change{target: t}, [first | _], made),
    do: made |> Map.get(t, []) |> Enum.any?(&(Date.compare(&1, first.date) == :gt))

  defp staged?(%Change{resolved: %{stages: [_ | _], date: %Date{}} = r}),
    do: r.operation in Facts.text_changes() or r.operation == :repealed

  defp staged?(_c), do: false

  defp unfold_one(%Change{resolved: %{operation: :repealed, level: :provision}} = c, made) do
    stages = if staged?(c), do: ordered(c.resolved), else: []

    if stages == [] or made_again?(c, stages, made),
      do: [c],
      else: removal(c, stages)
  end

  defp unfold_one(c, _made) do
    if staged?(c) do
      [first | later] = ordered(c.resolved)

      [
        at_first(c, first)
        | later |> Enum.with_index(2) |> Enum.flat_map(&later(c, first, &1))
      ]
    else
      [c]
    end
  end

  # the removal on the day it is complete, keeping its key; each partial
  # stage a removal in part — the first keeping the key where none is full
  defp removal(%Change{resolved: r} = c, stages) do
    full = Enum.find(stages, &(not &1.partial))
    parts = stages |> Enum.filter(& &1.partial) |> Enum.with_index(2)

    cond do
      # a removal for a territory: a removal in part would leave the rest
      # of the row partly in force once it is complete there (Petroleum
      # Act 1998 s.17A, E+W+S by the Energy Act 2004), so only its stages
      # for one territory alone are folded before the full one
      full != nil and r.territory != nil ->
        Enum.flat_map(parts, &if(territory_only?(elem(&1, 0)), do: [part(c, &1)], else: [])) ++
          [at_first(c, full)]

      full != nil ->
        Enum.map(parts, &part(c, &1)) ++ [at_first(c, full)]

      r.partial ->
        [{first, _} | rest] = parts
        [part(c, {first, nil}) | Enum.map(rest, &part(c, &1))]

      true ->
        [%Change{c | resolved: %{r | stages: nil}}]
    end
  end

  # a partial stage of a removal: for one territory alone, the repeal
  # there (as a commencement for one territory is in force there, C13;
  # RULES `one-territory-repeal-narrows`); else a removal in part
  defp part(%Change{resolved: r} = c, {stage, n}) do
    there? = territory_only?(stage)

    %Change{
      c
      | key: if(n, do: stage_key(c, stage, n), else: c.key),
        claims: stage_claims(c, stage),
        resolved: %{
          r
          | operation: if(there?, do: :repealed, else: :repealed_in_part),
            date: stage.date,
            partial: not there?,
            commenced_by: stage[:commenced_by],
            territory: stage[:in_force_for] || r.territory,
            stages: nil
        }
    }
  end

  # as `Facts.territory_only/1` reads a commencement
  defp territory_only?(stage),
    do:
      is_binary(stage[:in_force_for]) and
        stage[:qualification] in [nil, "territory", "complete + territory"]

  # the stages in date order, as read within a day; the change's own date
  # a stage where none has it
  defp ordered(%{stages: stages, date: date} = r) do
    own =
      if Enum.any?(stages, &(&1.date == date)),
        do: [],
        else: [%{date: date, partial: r.partial, commenced_by: r.commenced_by, own: true}]

    (stages ++ own) |> Enum.uniq() |> Enum.sort_by(& &1.date, Date)
  end

  defp at_first(%Change{resolved: r} = c, stage) do
    %Change{
      c
      | claims: stage_claims(c, stage),
        resolved: %{
          r
          | date: stage.date,
            partial: stage.partial,
            commenced_by: stage[:commenced_by] || r.commenced_by,
            stages: nil
        }
    }
  end

  defp later(
         %Change{resolved: %{operation: :inserted, level: :provision}} = c,
         _first,
         {stage, n}
       ),
       do: [commencement(c, stage, n)]

  defp later(c, %{date: day}, {%{date: day} = stage, n}), do: [again(c, stage, n)]
  defp later(_c, _first, _later_day), do: []

  defp again(%Change{resolved: r} = c, stage, n) do
    %Change{
      c
      | key: stage_key(c, stage, n),
        claims: stage_claims(c, stage),
        resolved: %{
          r
          | date: stage.date,
            partial: stage.partial,
            commenced_by: stage[:commenced_by],
            territory: stage[:in_force_for] || r.territory,
            stages: nil
        }
    }
  end

  @attributes [:operation, :level, :date, :partial, :commenced_by, :by, :territory]

  defp commencement(%Change{resolved: r} = c, stage, n) do
    %Change{
      key: stage_key(c, stage, n),
      target: c.target,
      claims: Enum.filter(stage_claims(c, stage), &(&1.attribute in @read)),
      resolved: %{
        r
        | operation: :commenced,
          level: :provision,
          territory: stage[:in_force_for] || r.territory,
          date: stage.date,
          partial: stage.partial,
          commenced_by: stage[:commenced_by],
          retained: false,
          saved: false,
          stages: nil,
          conflicts: [],
          sources: Map.new(@attributes, &{&1, r.sources[:date]}),
          tiers: Map.new(@attributes, &{&1, Map.get(r.tiers, :date)})
      }
    }
  end

  defp stage_key(c, stage, n), do: "#{c.key}@#{stage.date}~stage#{n}"

  # the territory and purposes a stage is limited to, as the fold reads
  # them (`Facts.territory_only/1`): the stage's, never another source's
  # beside it; the change's own date as a stage keeps what the change said
  defp stage_claims(%Change{claims: claims}, %{own: true}), do: claims

  defp stage_claims(%Change{claims: claims, key: key}, stage) do
    Enum.reject(claims, &(&1.source == :feed and &1.attribute in [:in_force_for, :qualification])) ++
      Claim.new(:feed, :in_force_for, stage[:in_force_for], key) ++
      Claim.new(:feed, :qualification, stage[:qualification], key)
  end
end

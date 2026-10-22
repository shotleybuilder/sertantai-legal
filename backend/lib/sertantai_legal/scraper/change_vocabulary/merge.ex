defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge do
  @moduledoc """
  Claim sets merged into changes by identity (change vocabulary, CV-02).

  1. By key and target: every source that names the same effect id on the
     same provision is one change.
  2. A change with no effect id — read from the amending law's text
     (`:law_text`), or a legacy markup ChangeId — joins the one change on
     its provision with the same operation family by the same law (the law
     that makes it; for markup, the law its note cites: a pointer for
     identity, never a fact). The law's text joins first. With none, or
     several, it stays a change of its own (a visible gap).

  Slice limits (CV-04 widens): no source position in the secondary key; no
  conflict report. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.{EffectIndex, LatRef}

  @doc "Changes from `{key, target, claims}` sets."
  @spec merge([{String.t(), String.t(), [Claim.t()]}]) :: [Change.t()]
  def merge(sets) do
    {fed, unkeyed} =
      sets
      |> Enum.group_by(fn {key, target, _} -> {key, target} end, &elem(&1, 2))
      |> Enum.map(fn {{key, target}, claims} ->
        %Change{key: key, target: target, claims: List.flatten(claims), aliases: [key]}
      end)
      |> precise()
      |> Enum.split_with(&(Change.values(&1, :feed, :by) != []))

    # the law's own text joins first, then the markup's legacy ids; a change
    # carrying an effect id the feed doesn't place there is its own
    # the law's own commencement, and its application clauses, are their
    # own changes, never joined
    {applied, unkeyed} =
      Enum.split_with(unkeyed, &(Change.value(&1, :law_text, :operation) == :applied))

    {own, unkeyed} =
      Enum.split_with(
        unkeyed,
        &(Change.values(&1, :commencement, :by) != [] and Change.values(&1, :law_text, :by) == [])
      )

    {law_text, markup} = Enum.split_with(unkeyed, &(Change.values(&1, :law_text, :by) != []))
    {effect_keyed, legacy} = Enum.split_with(markup, &(EffectIndex.effect_id(&1.key) != nil))

    # changes indexed by target: an orphan looks only at its provision and
    # those above it
    by_target = Enum.group_by(fed, & &1.target)

    (law_text ++ legacy)
    |> Enum.reduce(by_target, &join/2)
    |> Map.values()
    |> List.flatten()
    |> Kernel.++(effect_keyed)
    |> Kernel.++(own)
    |> Kernel.++(applied)
  end

  # One effect id is one event, wherever its sources place it. The markup
  # places it precisely (the evidence table's target order): a markup
  # change with no feed claims of its own takes the event's feed facts
  # (date, law, territory) from the feed's change of the same id — on a
  # provision above it, or beside it (Forestry Act 1967 s.1(4)(a): the
  # "and" SI 2019/734 omits, which the feed records on s.1(4)(b)). A feed
  # change with the markup's below it is the coarser record and goes.
  defp precise(changes) do
    changes
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {_key, group} ->
      {marked, fed_only} = Enum.split_with(group, &marked?/1)
      # the event's facts, from the first change of it the feed records
      facts =
        case Enum.find(group, &(Change.values(&1, :feed, :by) != [])) do
          nil -> []
          c -> Enum.filter(c.claims, &(&1.source in [:feed, :law]))
        end

      # where the feed names the event (with or without markup there)
      fed_targets = for c <- group, Change.values(c, :feed, :by) != [], do: c.target

      marked =
        Enum.map(marked, fn m ->
          m = if Change.values(m, :feed, :by) == [], do: %{m | claims: m.claims ++ facts}, else: m

          # placed only by its note ref, on a provision the feed doesn't
          # name: the change there is in its words (the "and" in s.1(4)(a))
          if Change.values(m, :markup, :operation) == [] and m.target not in fed_targets,
            do: %{m | claims: m.claims ++ Claim.new(:markup, :level, :words, m.key)},
            else: m
        end)

      kept =
        Enum.reject(fed_only, fn f ->
          Enum.any?(marked, &(f.target in tl(LatRef.ancestors(&1.target))))
        end)

      marked ++ kept
    end)
  end

  defp marked?(c),
    do: Change.values(c, :markup, :operation) != [] or Change.values(c, :markup, :placed) != []

  # an unkeyed change joins the one change on its provision of the same
  # operation family by the same law (the law it names, or its note cites);
  # with none, or several, it stays its own change (a visible gap)
  defp join(%Change{} = orphan, by_target) do
    law = Change.value(orphan, :law_text, :by) || Change.value(orphan, :markup, :cited)
    family = family(operation(orphan))

    matches =
      for t <- LatRef.ancestors(orphan.target),
          c <- Map.get(by_target, t, []),
          c.key != orphan.key,
          family(operation(c)) == family,
          law == nil or by(c) == law,
          same_day?(orphan, c),
          # only a record from another source: never another unjoined change
          Change.values(c, :feed, :by) != [] or marked?(c),
          do: c

    case matches do
      [match] ->
        # the more precise target stays (the orphan's when it lies below) —
        # unless the markup placed the change: where its text sits
        joined = %{
          match
          | target: if(marked?(match), do: match.target, else: orphan.target),
            claims: match.claims ++ orphan.claims,
            aliases: match.aliases ++ orphan.aliases
        }

        by_target
        |> Map.update!(match.target, &List.delete(&1, match))
        |> Map.update(joined.target, [joined], &[joined | &1])

      _ ->
        Map.update(by_target, orphan.target, [orphan], &[orphan | &1])
    end
  end

  # a dated change from the law's text joins only a record of that day (the
  # Coronavirus Act's sunset, 2022, and its NI continuation, 2024, are two
  # removals of s.78 by the Act itself)
  defp same_day?(orphan, c) do
    case {Change.value(orphan, :law_text, :date), Change.value(c, :feed, :date)} do
      {%Date{} = a, %Date{} = b} -> Date.compare(a, b) == :eq
      _ -> true
    end
  end

  defp operation(c),
    do:
      Change.value(c, :law_text, :operation) || Change.value(c, :markup, :operation) ||
        Change.value(c, :feed, :operation)

  defp by(c), do: Change.value(c, :feed, :by) || Change.value(c, :law_text, :by)

  defp family(op) when op in [:repealed, :repealed_in_part], do: :removal
  defp family(:commenced), do: :commencement
  defp family(nil), do: nil
  defp family(_text_change), do: :text
end

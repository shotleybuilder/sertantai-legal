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
  end

  # one effect id on a provision and on provisions below it: the markup
  # places the change more precisely than the feed (the evidence table's
  # target order) — the feed's claims move to each change below, and the
  # coarser one goes (SI 2008/1597 reg.14(1): the feed says reg.14)
  defp precise(changes) do
    by_key = Enum.group_by(changes, & &1.key)

    Enum.flat_map(changes, fn c ->
      below =
        Enum.filter(by_key[c.key], fn d ->
          d != c and c.target in tl(LatRef.ancestors(d.target)) and
            Change.values(d, :markup, :operation) != []
        end)

      cond do
        below != [] and Change.values(c, :markup, :operation) == [] ->
          []

        true ->
          [
            absorb(
              c,
              Enum.filter(
                by_key[c.key],
                &(&1 != c and &1.target in tl(LatRef.ancestors(c.target)) and
                    Change.values(&1, :markup, :operation) == [])
              )
            )
          ]
      end
    end)
  end

  defp absorb(c, coarser),
    do: %{c | claims: c.claims ++ Enum.flat_map(coarser, & &1.claims)}

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
          do: c

    case matches do
      [match] ->
        # the more precise target stays (the orphan's when it lies below)
        joined = %{
          match
          | target: orphan.target,
            claims: match.claims ++ orphan.claims,
            aliases: match.aliases ++ orphan.aliases
        }

        by_target
        |> Map.update!(match.target, &List.delete(&1, match))
        |> Map.update(orphan.target, [joined], &[joined | &1])

      _ ->
        Map.update(by_target, orphan.target, [orphan], &[orphan | &1])
    end
  end

  defp operation(c),
    do:
      Change.value(c, :law_text, :operation) || Change.value(c, :markup, :operation) ||
        Change.value(c, :feed, :operation)

  defp by(c), do: Change.value(c, :feed, :by) || Change.value(c, :law_text, :by)

  defp family(op) when op in [:repealed, :repealed_in_part], do: :removal
  defp family(nil), do: nil
  defp family(_text_change), do: :text
end

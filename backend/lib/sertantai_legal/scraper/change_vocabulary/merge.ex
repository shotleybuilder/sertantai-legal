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

  @doc "Changes from `{key, target, claims}` sets."
  @spec merge([{String.t(), String.t(), [Claim.t()]}]) :: [Change.t()]
  def merge(sets) do
    {fed, unkeyed} =
      sets
      |> Enum.group_by(fn {key, target, _} -> {key, target} end, &elem(&1, 2))
      |> Enum.map(fn {{key, target}, claims} ->
        %Change{key: key, target: target, claims: List.flatten(claims), aliases: [key]}
      end)
      |> Enum.split_with(&(Change.values(&1, :feed, :by) != []))

    # the law's own text joins first, then the markup's legacy ids
    {law_text, markup} = Enum.split_with(unkeyed, &(Change.values(&1, :law_text, :by) != []))
    Enum.reduce(law_text ++ markup, fed, &join/2)
  end

  # an unkeyed change joins the one change on its provision of the same
  # operation family by the same law (the law it names, or its note cites);
  # with none, or several, it stays its own change (a visible gap)
  defp join(%Change{} = orphan, changes) do
    law = Change.value(orphan, :law_text, :by) || Change.value(orphan, :markup, :cited)
    family = family(operation(orphan))

    matches =
      Enum.filter(changes, fn c ->
        c.key != orphan.key and c.target == orphan.target and family(operation(c)) == family and
          (law == nil or by(c) == law)
      end)

    case matches do
      [match] ->
        joined = %{
          match
          | claims: match.claims ++ orphan.claims,
            aliases: match.aliases ++ orphan.aliases
        }

        Enum.map(changes, &if(&1 == match, do: joined, else: &1))

      _ ->
        changes ++ [orphan]
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

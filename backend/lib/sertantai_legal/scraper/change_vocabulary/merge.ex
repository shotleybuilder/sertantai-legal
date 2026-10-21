defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge do
  @moduledoc """
  Claim sets merged into changes by identity (change vocabulary, CV-02).

  1. By key and target: every source that names the same effect id on the
     same provision is one change.
  2. A change only the markup knows (a legacy ChangeId: no effect id) joins
     the one feed change on its provision with the same operation family —
     by the law its note cites when it cites one (a pointer for identity,
     never a fact). With none, or several, it stays a change of its own (a
     visible gap).

  Slice limits (CV-04 widens): no source position in the secondary key; no
  conflict report. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}

  @doc "Changes from `{key, target, claims}` sets."
  @spec merge([{String.t(), String.t(), [Claim.t()]}]) :: [Change.t()]
  def merge(sets) do
    {fed, markup_only} =
      sets
      |> Enum.group_by(fn {key, target, _} -> {key, target} end, &elem(&1, 2))
      |> Enum.map(fn {{key, target}, claims} ->
        %Change{key: key, target: target, claims: List.flatten(claims), aliases: [key]}
      end)
      |> Enum.split_with(&(Change.values(&1, :feed, :by) != []))

    Enum.reduce(markup_only, fed, &join/2)
  end

  defp join(%Change{} = orphan, changes) do
    cited = Change.value(orphan, :markup, :cited)
    family = family(Change.value(orphan, :markup, :operation))

    matches =
      Enum.filter(changes, fn c ->
        c.target == orphan.target and family(Change.value(c, :feed, :operation)) == family and
          (cited == nil or Change.value(c, :feed, :by) == cited)
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

  defp family(:repealed), do: :removal
  defp family(nil), do: nil
  defp family(_text_change), do: :text
end

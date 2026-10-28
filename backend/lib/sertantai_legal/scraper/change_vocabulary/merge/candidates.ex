defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Candidates do
  @moduledoc """
  Each source's records of one event as one candidate, before the merge
  joins sources (CV-S07 round 2, `docs/CHANGE-IDENTITY-DESIGN.md`):

  - `rekey/2`: a markup record keyed by a feed effect's `URI` id takes the
    effect's own id (legislation.gov.uk re-keys a corrected effect and
    keeps the first id in `URI`; the markup carries that one: NISR 2004/222
    reg.2(1)); the id it came with stays an alias.
  - `collapse/1`: markup records of one note on one provision are one
    record (HSWA s.28 repeats its markup in each territorial version under
    its own ChangeId; SI 2008/960's three ChangeIds on one note).
  - `base/1`: one effect's stages (`id@date`) are its id's.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.EffectIndex

  @doc """
  Claim sets with markup keys mapped from a feed `URI` id to the effect's
  id (`uris`: URI id → EffectId), each with the key it came with:
  `{key, target, claims, original}`.
  """
  @spec rekey([{String.t(), String.t(), [Claim.t()]}], %{String.t() => String.t()}) ::
          [{String.t(), String.t(), [Claim.t()], String.t()}]
  def rekey(sets, uris) do
    for {key, target, claims} <- sets do
      case markup?(claims) && Map.get(uris, EffectIndex.effect_id(key) || key) do
        id when is_binary(id) -> {id, target, claims, key}
        _ -> {key, target, claims, key}
      end
    end
  end

  @doc """
  Markup-only changes of one note on one provision as one change: the
  first by key (an effect id before a legacy ChangeId), the others its
  aliases, their claims once.
  """
  @spec collapse([Change.t()]) :: [Change.t()]
  def collapse(changes) do
    {notes, rest} = Enum.split_with(changes, &(note(&1) != nil and markup_only?(&1)))

    collapsed =
      notes
      |> Enum.group_by(&{note(&1), &1.target})
      |> Enum.map(fn {_, group} ->
        [first | others] = Enum.sort_by(group, &{EffectIndex.effect_id(&1.key) == nil, &1.key})

        Enum.reduce(others, first, fn c, acc ->
          own = Enum.reject(c.claims, &(&1 in acc.claims))
          %{acc | claims: acc.claims ++ own, aliases: Enum.uniq(acc.aliases ++ c.aliases)}
        end)
      end)

    rest ++ collapsed
  end

  @doc "An effect's id, its stages' (`id@date`) included."
  @spec base(String.t()) :: String.t()
  def base(key), do: key |> String.split("@", parts: 2) |> hd()

  defp note(c), do: Change.value(c, :markup, :note)

  defp markup_only?(c),
    do: Change.values(c, :feed, :by) == [] and Change.values(c, :law_text, :by) == []

  defp markup?(claims), do: Enum.any?(claims, &(&1.source == :markup))
end

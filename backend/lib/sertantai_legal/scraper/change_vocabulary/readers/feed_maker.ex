defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedMaker do
  @moduledoc """
  The feed's record of an effect's earlier maker: the amending law a text
  change's Type names as making the words, as later amended ("words
  inserted by S.I. 2019/720, Sch. 2 para. 15(b) (as substituted)", the
  effect by SI 2020/1567: C5, `EffectVerb.made_by/1`). That law made the
  text too, so it has a record of its own beside the effect, keyed
  `effect id#made`.

  The record is the maker's. It carries the effect's facts (operation,
  level, the day the words as amended took effect, application, savings),
  its `by` the maker, and the maker's own amending provision as the Type
  writes it ("Sch. 2 para. 15(b)": `EffectVerb.made_at/1`), so the maker's
  own text joins it in the merge. What the later law says of itself is
  not the maker's and is left off: its amending provision, its territory
  and competence, and its extent clause (SI 2019/696 on SI 2008/1597 reg.
  7, 13, 21; Fire and OH&S: Feed reader).

  Where the feed holds the maker's own effect for that instruction — by
  the maker, on a provision the effect names, the same day, the same
  operation at the same level ("words substituted"), naming the Type's
  amending provision or one holding it (SI
  2019/696 Sch. 16 para. 2(2)(m) on SI 2014/1638 reg. 2(1), beside SI
  2020/676's effect) — that effect is the maker's record, and no second
  one is made: two records of one instruction would leave the maker's
  text unable to choose between them. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, EffectVerb}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @suffix "#made"

  @type keyed :: {String.t(), [Claim.t()]}
  @typedoc "The makers' own effects: law, day and operation → the amending provisions and targets each names."
  @type own :: %{optional(tuple()) => [{[String.t()], MapSet.t(String.t())}]}

  @doc """
  The own effects, among `effects`, of every law one of them names as an
  earlier maker; empty where none does.
  """
  @spec own([Effect.t()]) :: own()
  def own(effects) do
    makers = for e <- effects, maker = maker(e), into: MapSet.new(), do: maker

    for %Effect{affecting: law} = e <- effects, MapSet.member?(makers, law), reduce: %{} do
      acc ->
        named = {FeedAffecting.refs(e.affecting_provisions), targets(e)}
        Map.update(acc, event(e, law), [named], &[named | &1])
    end
  end

  @doc """
  An effect's records `{key, claims}` with the maker's record after them,
  from the first record's claims; unchanged where the Type names no
  earlier maker, names the affecting law itself, or the feed holds the
  maker's own effect for the instruction (`own/1`).
  """
  @spec with_record([keyed()], Effect.t(), own()) :: [keyed()]
  def with_record(records, e, own \\ %{})

  def with_record([{key, claims} | _] = records, %Effect{} = e, own) do
    maker = maker(e)

    if maker == nil or recorded?(e, maker, own),
      do: records,
      else: records ++ [{key <> @suffix, Enum.flat_map(claims, &made(&1, maker))}]
  end

  def with_record(records, _e, _own), do: records

  @doc """
  The effect as the record keyed `key` names its law: for the maker's
  record, the maker and its own amending provision (nil where the Type
  writes none), with no territory of the later law; else the effect.
  """
  @spec effect(String.t(), Effect.t()) :: Effect.t()
  def effect(key, %Effect{} = e) do
    if String.ends_with?(key, @suffix),
      do: %{
        e
        | affecting: maker(e),
          affecting_provisions: EffectVerb.made_at(e.type),
          affecting_territory: nil
      },
      else: e
  end

  defp maker(%Effect{type: type, affecting: affecting}) do
    case EffectVerb.made_by(type) do
      maker when is_binary(maker) and maker != affecting -> maker
      _ -> nil
    end
  end

  # the feed's own effect by the maker for the instruction the Type names
  defp recorded?(%Effect{type: type} = e, maker, own) do
    at = type |> EffectVerb.made_at() |> FeedAffecting.refs()
    targets = targets(e)

    Enum.any?(Map.get(own, event(e, maker), []), fn {refs, named} ->
      not MapSet.disjoint?(named, targets) and Enum.any?(at, &held?(&1, refs))
    end)
  end

  # one of `refs` is the provision, or holds it ("sch.16.para.27(c)" holds
  # "sch.16.para.27(c)(ii)")
  defp held?(ref, refs), do: Enum.any?(refs, &(&1 == ref or String.starts_with?(ref, &1 <> "(")))

  # the day and what was done, in the Type's own words up to the maker
  # ("words substituted by S.I. …" is "words substituted"): a change of the
  # provision's words is never the record of a change of the whole of it
  # (CLP Art 2(10): SI 2019/720's own "words substituted" beside
  # "substituted by S.I. 2019/720, Sch. 2 para. 14(a) (as substituted)")
  defp event(%Effect{} = e, law), do: {law, e.in_force_date, done(e.type)}

  defp done(nil), do: nil

  defp done(type) do
    type
    |> String.downcase()
    |> String.replace(~r/\s+by\s+s\.[ir]\..*$/, "")
    |> String.replace(~r/^\s*word\b/, "words")
    |> String.trim()
  end

  defp targets(%Effect{affected_refs: refs, affected_ranges: ranges}) do
    ends = for {a, b} <- ranges || [], end_ref <- [a, b], do: end_ref
    MapSet.new(List.wrap(refs) ++ ends)
  end

  # the effect's claim as the maker's: its law the maker; the later law's
  # own territory and competence (`:law` claims) are not the maker's
  defp made(%Claim{source: :feed, attribute: :by} = c, maker), do: [%{c | value: maker}]
  defp made(%Claim{source: :law}, _maker), do: []
  defp made(%Claim{} = c, _maker), do: [c]
end

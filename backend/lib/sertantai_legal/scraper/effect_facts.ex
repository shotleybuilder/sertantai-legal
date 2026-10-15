defmodule SertantaiLegal.Scraper.EffectFacts do
  @moduledoc """
  A change's facts from its effects (legislation.gov.uk changes feed;
  lat-refactor LR-07, renamed from `ChangeFacts` in LR-25 when its note
  fallback was deleted): what it did, when it took effect, which law made
  it, and whether a provision is partly in force. Never from note text.

  Handles:
  - `effect_fact/1` — an effect's facts (the change register's feed
    collector)
  - `kind/2` — an effect Type as a change kind (substituted | inserted |
    repealed | renumbered | commenced | amended | modified | other)
  - `partial?/3` — a provision partly in force from its commencing effects'
    InForce entries: purposes, or territories short of its extent

  Jason 2026-10-09: `effective_from` is the latest dated InForce (fully in
  force); territorial commencement is partial. Pure: `today` is passed in.
  """

  alias SertantaiLegal.Scraper.{EffectIndex, EffectTerritory, Territory}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type fact :: %{
          effect: String.t(),
          effective_dates: [Date.t()],
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          change_id: String.t(),
          source: :effect,
          dates_source: :effect | nil
        }

  # the leading verb of an effect Type ("words substituted", "inserted",
  # "applied (with modifications)")
  @verbs [
    {~r/\bsubstituted\b/, "substituted"},
    {~r/\b(inserted|added)\b/, "inserted"},
    {~r/\b(repealed|revoked|omitted|ceased to have effect)\b/, "repealed"},
    {~r/\brenumbered\b/, "renumbered"},
    {~r/\bcoming into force\b/, "commenced"},
    {~r/\bamended\b/, "amended"},
    # a modification's own verb ("applied in part … (as inserted)"): the
    # earliest verb wins, so it isn't read as the text change it cites (LR-24)
    {~r/\b(applied|modified|excluded|extended|restricted|disapplied|construed|continued|transferred|functions|powers?)\b/,
     "other"}
  ]

  # an InForce qualification that completes commencement
  @complete ~r/wholly in force|fully in force|not already in force|\botherwise\b|remaining purposes|all other purposes/i
  @purposes ~r/for (?:specified|certain) purposes|for (?:the )?purposes? of/i

  @doc """
  An effect Type as a change kind: a note's `code_type`, where one is
  passed, decides commencement and modification; else the first verb in
  the type, "other" when none.
  """
  @spec kind(String.t() | nil, String.t() | nil) :: String.t()
  def kind(_type, "commencement"), do: "commenced"
  def kind(_type, "modification"), do: "modified"

  # a change to an earlier amending or affecting provision ("amendment to
  # earlier affecting provision SI 1995/3128 reg. 10(2) (as substituted)")
  # changes another law's provision, not this text (LR-24)
  def kind(type, _code_type) when is_binary(type) and type != "" do
    if Regex.match?(~r/\bearlier (affecting|amending) provision/i, type),
      do: "other",
      else: verb_kind(String.downcase(type))
  end

  def kind(_type, _code_type), do: verb_kind("")

  defp verb_kind(type) do
    @verbs
    |> Enum.flat_map(fn {re, name} ->
      case Regex.run(re, type, return: :index) do
        [{pos, _} | _] -> [{pos, name}]
        nil -> []
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> {nil, "other"} end)
    |> elem(1)
  end

  @doc """
  An effect's facts: every dated InForce (`effective_from` the latest), the
  affecting law, its kind; `change_id` is its effect id.
  """
  @spec effect_fact(Effect.t()) :: fact()
  def effect_fact(%Effect{} = e) do
    dates =
      for(f <- e.in_force || [], f.date != nil, do: f.date)
      |> Enum.uniq()
      |> Enum.sort(Date)

    %{
      effect: kind(e.type, code_type(e.type)),
      effective_dates: dates,
      effective_from: List.last(dates),
      changed_by: e.affecting,
      change_id: e.effect_id,
      source: :effect,
      dates_source: if(dates != [], do: :effect)
    }
  end

  # an effect's own type stands in for the note's code_type
  defp code_type(type) do
    cond do
      kind(type, nil) == "commenced" -> "commencement"
      kind(type, nil) == "other" -> "modification"
      true -> "amendment"
    end
  end

  @doc """
  True when commencing effects (coming into force, insertion, substitution)
  leave the provision partly in force on `today`: an entry in force for
  purposes only, or for territories short of `extent`, and none that
  completes it ("wholly in force", "in so far as not already in force",
  "otherwise", an unqualified date, or territories covering `extent`).
  Entries dated after `today` haven't commenced; unreadable qualifiers
  count neither way.
  """
  @spec partial?([Effect.t()], String.t() | nil, Date.t()) :: boolean()
  def partial?(effects, extent, today) do
    # the provision's own commencement and whole-provision changes complete
    # one another (a later "wholly in force"); each words-level amendment is
    # judged alone (1984/55 s.91A(5))
    {whole, words} =
      effects
      |> Enum.filter(&commencing?/1)
      |> Enum.split_with(&(not EffectIndex.words_level?(&1)))

    [whole | Enum.map(words, &[&1])]
    |> Enum.any?(&group_partial?(&1, extent, today))
  end

  # One group of effects judged together. Their InForce entries split into
  # commenced (dated on or before `today`) and pending (undated or later);
  # each commenced entry reads as {territory | nil, :complete | :purposes |
  # :other} (`entry/2`):
  #
  # - complete: a commenced entry with no territory that completes
  #   commencement ("wholly in force", an unqualified date) — never partial;
  # - live: the union of the territories commenced entries complete;
  # - open purposes: an entry in force for purposes only ("for W. for
  #   specified purposes": for W), its territory (or, with none, the
  #   extent) not covered by live;
  # - to come: a pending entry for a territory within the extent that live
  #   doesn't cover. A territory the effect doesn't mention at all is a gap
  #   in the feed, not "not in force" (1995/21 s.136A).
  #
  # Partial = not complete, and open purposes or something to come.
  defp group_partial?(effects, extent, today) do
    {commenced, pending} =
      effects
      |> Enum.flat_map(&(&1.in_force || []))
      |> Enum.split_with(&(&1.date != nil and Date.compare(&1.date, today) != :gt))

    entries = Enum.map(commenced, &entry(&1.qualification, extent))
    complete = Enum.any?(entries, &match?({nil, :complete}, &1))
    live = for({t, :complete} <- entries, t != nil, do: t) |> Territory.union()
    covered? = fn t -> live != nil and Territory.covers?(live, t || extent) end

    open_purposes =
      Enum.any?(entries, fn
        {t, :purposes} -> not covered?.(t)
        _ -> false
      end)

    to_come =
      for f <- pending,
          {t, _} = entry(f.qualification, extent),
          t != nil,
          extent == nil or not Territory.disjoint?(t, extent),
          not covered?.(t),
          do: t

    not complete and (open_purposes or to_come != [])
  end

  # {territory | nil, :complete | :purposes | :other}
  @purpose_territory ~r/^for ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)\s*for (?:specified|certain) purposes/

  defp entry(nil, _extent), do: {nil, :complete}

  defp entry(q, extent) do
    cond do
      t = entry_territory(q, extent) ->
        {t, :complete}

      m = Regex.run(@purpose_territory, q, capture: :all_but_first) ->
        {Territory.normalize(hd(m)), :purposes}

      Regex.match?(@complete, q) ->
        {nil, :complete}

      Regex.match?(@purposes, q) ->
        {nil, :purposes}

      true ->
        {nil, :other}
    end
  end

  defp entry_territory(q, extent) do
    case {EffectTerritory.qualifier_territory(q), EffectTerritory.except_territory(q)} do
      {t, _} when t != nil -> t
      {nil, x} when x != nil and extent != nil -> Territory.subtract(extent, x)
      _ -> nil
    end
  end

  defp commencing?(%Effect{type: type}), do: kind(type, nil) in ~w(commenced inserted substituted)
end

defmodule SertantaiLegal.Scraper.ChangeFacts do
  @moduledoc """
  A change's facts from its effects (lat-refactor LR-07): what it did, when
  it took effect, which law made it, and a row's commencement status.
  Notes are hints: their text is read (`AmendmentNote`) only where no
  effect joins (`docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md` §3).

  Handles:
  - `note/3` — a note's effect / effective_dates / effective_from /
    changed_by from its effects (legislation.gov.uk changes feed), else
    from its text; each with its `source` (`:effect` | `:note`)
  - `effect_fact/1` — the same facts for an effect no note carries
  - `kind/2` — an effect Type in the note vocabulary
  - `partial?/3` — a provision partly in force from its commencing effects'
    InForce entries: purposes, or territories short of its extent
  - `saved?/1` — a repeal with savings

  Jason 2026-10-09: `effective_from` is the latest dated InForce (fully in
  force); territorial commencement is partial. Pure: `today` is passed in.
  """

  alias SertantaiLegal.Scraper.{AmendmentNote, EffectIndex, EffectTerritory, LatStatus, Territory}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type source :: :effect | :note

  @type fact :: %{
          effect: String.t(),
          effective_dates: [Date.t()],
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          change_id: String.t(),
          source: source(),
          dates_source: source() | nil
        }

  # the leading verb of an effect Type ("words substituted", "inserted",
  # "applied (with modifications)")
  @verbs [
    {~r/\bsubstituted\b/, "substituted"},
    {~r/\b(inserted|added)\b/, "inserted"},
    {~r/\b(repealed|revoked|omitted|ceased to have effect)\b/, "repealed"},
    {~r/\brenumbered\b/, "renumbered"},
    {~r/\bcoming into force\b/, "commenced"},
    {~r/\bamended\b/, "amended"}
  ]

  # an InForce qualification that completes commencement
  @complete ~r/wholly in force|fully in force|not already in force|\botherwise\b|remaining purposes|all other purposes/i
  @purposes ~r/for (?:specified|certain) purposes|for (?:the )?purposes? of/i

  @doc """
  An effect Type in the note vocabulary (`AmendmentNote`): the note's
  `code_type` decides commencement and modification notes; else the
  first verb in the type, "other" when none.
  """
  @spec kind(String.t() | nil, String.t() | nil) :: String.t()
  def kind(_type, "commencement"), do: "commenced"
  def kind(_type, "modification"), do: "modified"

  def kind(type, _code_type) do
    type = String.downcase(type || "")

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
  A note's facts: from its effects when any joined (dates from every dated
  InForce, `effective_from` the latest, `changed_by` the affecting law of
  the effect that took effect last), else from its text (`parsed`, an
  `AmendmentNote`). `change_id` stays the note's.
  """
  @spec note(AmendmentNote.t(), String.t() | nil, [Effect.t()]) :: fact()
  def note(%AmendmentNote{} = parsed, _code_type, []),
    do:
      parsed
      |> Map.from_struct()
      |> Map.merge(%{source: :note, dates_source: if(parsed.effective_dates != [], do: :note)})

  def note(%AmendmentNote{} = parsed, code_type, [first | _] = effects) do
    dated =
      for e <- effects, f <- e.in_force || [], f.date != nil, uniq: true, do: {f.date, e}

    dates = dated |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort(Date)
    last = Enum.max_by(dated, &elem(&1, 0), Date, fn -> {nil, first} end) |> elem(1)

    # an effect silent on dates (older effects: an undated InForce) doesn't
    # contradict the note's dates: they stand, as the note's
    {dates, dates_source} =
      cond do
        dates != [] ->
          {dates, :effect}

        parsed.effective_dates != [] and not Enum.all?(effects, &prospective?/1) ->
          {parsed.effective_dates, :note}

        true ->
          {[], nil}
      end

    %{
      effect: kind(first.type, code_type),
      effective_dates: dates,
      effective_from: List.last(dates),
      changed_by: last.affecting || parsed.changed_by,
      change_id: parsed.change_id,
      source: :effect,
      dates_source: dates_source
    }
  end

  # not in force: prospective and not applied to the text
  defp prospective?(%Effect{prospective: true, applied: applied}), do: applied != true
  defp prospective?(_effect), do: false

  @doc "The facts of an effect no note carries; `change_id` is its effect id."
  @spec effect_fact(Effect.t()) :: fact()
  def effect_fact(%Effect{} = e) do
    parsed = %AmendmentNote{
      effect: "other",
      effective_dates: [],
      effective_from: nil,
      changed_by: nil,
      change_id: e.effect_id
    }

    note(parsed, code_type(e.type), [e])
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

  # Purposes: an entry in force for purposes only ("for W. for specified
  # purposes": for W), not completed by a commenced entry for its territory
  # (or for everything). Territories: an entry still to come (undated or
  # after `today`) for a territory of the extent no commenced entry covers —
  # a territory the effect doesn't mention is a gap in the feed, not "not
  # in force" (1995/21 s.136A).
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

  @type row_in :: %{
          required(:section_id) => String.t(),
          required(:status) => String.t() | nil,
          optional(:text) => String.t() | nil,
          optional(:extent_code) => String.t() | nil,
          optional(:excluded_extent) => String.t() | nil,
          optional(:effect_ids) => [String.t()] | nil
        }

  @type note_in :: %{
          required(:text) => String.t(),
          required(:code_type) => String.t() | nil,
          optional(:code) => String.t() | nil,
          optional(:affected_sections) => [String.t()] | nil,
          optional(:effect_ids) => [String.t()] | nil,
          optional(:parsed) => AmendmentNote.t()
        }

  @type row_out :: %{
          status: String.t(),
          status_source: :markup | :effect | :note,
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          change_source: source() | nil
        }

  @doc """
  A law's change facts. Each note: `note/3` from its `effect_ids`, else its
  text (`parsed`, or `AmendmentNote.parse/3`). Each row:

  - `effective_from` / `changed_by`: the latest dated change on the row or
    an ancestor (`AmendmentNote.row_effective/1`) — its notes' facts and
    the effects on those rows no note carries;
  - `status`: the parser's `prospective` / `repealed` / `repealed_saved`
    (markup) stand, except a repeal whose effect names savings
    (`repealed_saved`); `in_force` becomes `in_force_partial` from the
    commencing effects on the row or an ancestor (`partial?/3`). Where no
    such effect exists, the notes that joined no effect decide (`LatStatus`
    rules), marked `:note`.

  `effects`: effect id → effect. Options: `holders` (table / figure rows →
  the provision whose changes date them), `known_laws` (register names: a
  Welsh SI cited as plain "S.I.", `AmendmentNote.resolve_law/2`), `today`.
  """
  @spec resolve([row_in()], [note_in()], %{String.t() => Effect.t()}, String.t(), keyword()) ::
          {[fact()], %{String.t() => row_out()}}
  def resolve(rows, notes, effects, law_name, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    holders = Keyword.get(opts, :holders, %{})
    lookup = fn ids -> ids |> List.wrap() |> Enum.map(&effects[&1]) |> Enum.reject(&is_nil/1) end

    known = Keyword.get(opts, :known_laws, MapSet.new())

    notes =
      Enum.map(notes, fn n ->
        parsed =
          (Map.get(n, :parsed) || AmendmentNote.parse(n.text, n.code_type, law_name))
          |> marginal(Map.get(n, :code))
          |> then(&%{&1 | changed_by: AmendmentNote.resolve_law(&1.changed_by, known)})

        joined = lookup.(Map.get(n, :effect_ids))
        fact = parsed |> note(n.code_type, joined) |> not_self(law_name)
        Map.merge(n, %{fact: fact, joined: joined})
      end)

    note_targets =
      notes
      |> Enum.flat_map(fn n -> Enum.map(LatStatus.note_targets(n), &{&1, n}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    row_effects = Map.new(rows, &{&1.section_id, lookup.(Map.get(&1, :effect_ids))})

    # the notes no effect joined: the LatStatus fallback
    fallback =
      LatStatus.resolve(rows, Enum.filter(notes, &(&1.joined == [])))

    out =
      Map.new(rows, fn row ->
        [own | above] = LatStatus.ancestors(holders[row.section_id] || row.section_id)

        # an ancestor passes down its whole-provision changes only: a
        # words-level change in its own text doesn't date its sub-provisions
        # (1995/21 s.192A(6)); a note no effect joined passes down as before
        row_notes =
          Map.get(note_targets, own, []) ++
            for(
              level <- above,
              n <- Map.get(note_targets, level, []),
              n.joined == [] or not Enum.all?(n.joined, &EffectIndex.words_level?/1),
              do: n
            )

        on_row =
          (Map.get(row_effects, own, []) ++
             for(
               level <- above,
               e <- Map.get(row_effects, level, []),
               not EffectIndex.words_level?(e),
               do: e
             ))
          |> Enum.uniq()

        carried = row_notes |> Enum.flat_map(& &1.joined) |> MapSet.new(& &1.effect_id)

        # a note naming no change and no instrument ("OJ L 182, 21.6.2014,
        # p.52.") isn't a change
        facts =
          for(n <- row_notes, not citation_only?(n.fact), do: n.fact) ++
            for(
              e <- on_row,
              not MapSet.member?(carried, e.effect_id),
              do: e |> effect_fact() |> not_self(law_name)
            )

        {from, by} = AmendmentNote.row_effective(facts)

        source =
          Enum.find_value(
            facts,
            &(&1.effective_from == from and &1.changed_by == by and &1.source)
          )

        {status, status_source} = status(row, on_row, fallback[row.section_id], today)

        {row.section_id,
         %{
           status: status,
           status_source: status_source,
           effective_from: from,
           changed_by: by,
           change_source: if(from || by, do: source)
         }}
      end)

    {Enum.map(notes, & &1.fact), out}
  end

  defp citation_only?(%{source: :note, effect: "other", changed_by: nil}), do: true
  defp citation_only?(_fact), do: false

  # a law commencing itself ("see reg. 1") dates the change but isn't
  # changed by another law
  # (a Welsh SI and its uksi name are one instrument: one number series)
  defp not_self(%{changed_by: by} = fact, law) do
    if by != nil and twin(by) == twin(law), do: %{fact | changed_by: nil}, else: fact
  end

  defp twin("UK_wsi_" <> rest), do: "UK_uksi_" <> rest
  defp twin(name), do: name

  # A marginal citation (code "M…") only refers to laws: it changes nothing,
  # so no instrument and no dates (LH-06)
  defp marginal(parsed, "M" <> _),
    do: %{parsed | changed_by: nil, effective_dates: [], effective_from: nil}

  defp marginal(parsed, _code), do: parsed

  defp status(%{status: "repealed"}, effects, fallback, _today) do
    cond do
      Enum.any?(effects, &(kind(&1.type, nil) == "repealed")) ->
        if saved?(effects), do: {"repealed_saved", :effect}, else: {"repealed", :markup}

      fallback == "repealed_saved" ->
        {"repealed_saved", :note}

      true ->
        {"repealed", :markup}
    end
  end

  # Partial from any commencing effect; wholly in force only from the
  # provision's own commencement effects (an amendment in force everywhere
  # says nothing about when the provision commenced); else the notes no
  # effect joined.
  defp status(%{status: "in_force"} = row, effects, fallback, today) do
    extent = Map.get(row, :extent_code)

    # the provision's own commencement: coming into force, or a whole-provision
    # insertion / substitution's InForce
    commencements =
      Enum.filter(effects, &(commencing?(&1) and not EffectIndex.words_level?(&1)))

    cond do
      partial?(effects, extent, today) -> {"in_force_partial", :effect}
      commencements != [] and dated?(commencements, today) -> {"in_force", :effect}
      fallback == "in_force_partial" -> {"in_force_partial", :note}
      true -> {"in_force", :markup}
    end
  end

  defp status(row, _effects, _fallback, _today), do: {row.status || "in_force", :markup}

  defp dated?(effects, today) do
    Enum.any?(effects, fn e ->
      Enum.any?(e.in_force || [], &(&1.date != nil and Date.compare(&1.date, today) != :gt))
    end)
  end

  @doc """
  Table and figure rows sit inside a provision but their ids (table.3041)
  don't nest under it: each takes the nearest preceding other row in
  document order as the provision whose changes date it (LH-06).
  `section_ids` in document order.
  """
  @spec holders([String.t()]) :: %{String.t() => String.t()}
  def holders(section_ids) do
    {pairs, _} =
      Enum.map_reduce(section_ids, nil, fn sid, holder ->
        if Regex.match?(~r/:(table|figure)\./, sid),
          do: {{sid, holder}, holder},
          else: {nil, sid}
      end)

    for {sid, holder} <- pairs, holder != nil, into: %{}, do: {sid, holder}
  end

  @doc "True when a repeal effect names savings."
  @spec saved?([Effect.t()]) :: boolean()
  def saved?(effects),
    do: Enum.any?(effects, &(kind(&1.type, nil) == "repealed" and (&1.savings || []) != []))
end

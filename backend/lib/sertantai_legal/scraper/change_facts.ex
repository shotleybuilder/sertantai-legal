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

  alias SertantaiLegal.Scraper.{AmendmentNote, EffectTerritory, LatStatus, Territory}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type source :: :effect | :note

  @type fact :: %{
          effect: String.t(),
          effective_dates: [Date.t()],
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          change_id: String.t(),
          source: source()
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
    do: parsed |> Map.from_struct() |> Map.put(:source, :note)

  def note(%AmendmentNote{} = parsed, code_type, [first | _] = effects) do
    dated =
      for e <- effects, f <- e.in_force || [], f.date != nil, uniq: true, do: {f.date, e}

    dates = dated |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort(Date)
    last = Enum.max_by(dated, &elem(&1, 0), Date, fn -> {nil, first} end) |> elem(1)

    %{
      effect: kind(first.type, code_type),
      effective_dates: dates,
      effective_from: List.last(dates),
      changed_by: last.affecting || parsed.changed_by,
      change_id: parsed.change_id,
      source: :effect
    }
  end

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
    entries =
      for e <- effects,
          commencing?(e),
          f <- e.in_force || [],
          f.date != nil and Date.compare(f.date, today) != :gt,
          do: f.qualification

    # "for E. in so far as not already in force" completes E only
    {territorial, general} = Enum.split_with(entries, &(qualifier_territory(&1) != nil))
    territories = Enum.map(territorial, &qualifier_territory/1)
    complete = Enum.any?(general, &(&1 == nil or Regex.match?(@complete, &1)))

    covered =
      territories != [] and extent != nil and
        Territory.covers?(Territory.union(territories), extent)

    purposes = Enum.any?(entries, &(&1 != nil and Regex.match?(@purposes, &1)))

    (purposes or territories != []) and not complete and not covered
  end

  defp qualifier_territory(nil), do: nil
  defp qualifier_territory(q), do: EffectTerritory.qualifier_territory(q)

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

  `effects`: effect id → effect. `holders`: table / figure rows → the
  provision whose changes date them.
  """
  @spec resolve([row_in()], [note_in()], %{String.t() => Effect.t()}, String.t(), keyword()) ::
          {[fact()], %{String.t() => row_out()}}
  def resolve(rows, notes, effects, law_name, opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    holders = Keyword.get(opts, :holders, %{})
    lookup = fn ids -> ids |> List.wrap() |> Enum.map(&effects[&1]) |> Enum.reject(&is_nil/1) end

    notes =
      Enum.map(notes, fn n ->
        parsed = Map.get(n, :parsed) || AmendmentNote.parse(n.text, n.code_type, law_name)
        joined = lookup.(Map.get(n, :effect_ids))
        Map.merge(n, %{fact: note(parsed, n.code_type, joined), joined: joined})
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
        levels = LatStatus.ancestors(holders[row.section_id] || row.section_id)
        row_notes = Enum.flat_map(levels, &Map.get(note_targets, &1, []))
        on_row = levels |> Enum.flat_map(&Map.get(row_effects, &1, [])) |> Enum.uniq()
        carried = row_notes |> Enum.flat_map(& &1.joined) |> MapSet.new(& &1.effect_id)

        facts =
          Enum.map(row_notes, & &1.fact) ++
            for(e <- on_row, not MapSet.member?(carried, e.effect_id), do: effect_fact(e))

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

  defp status(%{status: "in_force"} = row, effects, fallback, today) do
    cond do
      Enum.any?(effects, &commencing?/1) ->
        if partial?(effects, Map.get(row, :extent_code), today),
          do: {"in_force_partial", :effect},
          else: {"in_force", :effect}

      fallback == "in_force_partial" ->
        {"in_force_partial", :note}

      true ->
        {"in_force", :markup}
    end
  end

  defp status(row, _effects, _fallback, _today), do: {row.status || "in_force", :markup}

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

defmodule SertantaiLegal.Scraper.ChangeCollector.Feed do
  @moduledoc """
  The changes-feed collector (lat-refactor LR-23): a law's effects as change
  log records, one per effect and row it reached, with how it reached it.

  Joins come from the parse (LR-19 logic, unchanged): a row's
  `effect_joins` (`:markup`, `:whole`, `:ref`) and a note's
  (`:markup`: the provisions it sits on whose own markup carries the change;
  `:own`: every provision it sits on, its `affected_sections`; `:cited`:
  only the provision the effect was found on). The note's code is the
  `pointer`. An effect reaching no
  row is kept with `section_id` nil when it may fall on a provision LAT
  holds or names none (D5: not on a Schedule, an annex or a section outside
  the law's LAT scope); a whole-instrument effect ("Act", "Regulations")
  reaches every row (`instrument`). A note join only stays where the note
  alone reaches the row (LR-23 D4): beside a direct join (`:markup`,
  `:whole`, `:ref`) it only corroborates, and its placement stays in
  `amendment_annotations`. A note's text is never read: a note joining no
  effect makes no record.

  The facts are the effect's: operation (`EffectFacts.kind/2`),
  effective_from (`EffectFacts.effect_fact/1`: the latest dated InForce),
  in-force entries, extents, savings. Ancestor inheritance and labels are
  the projection's (LR-24). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.EffectFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  # join kinds, strongest first
  @strength ~w(markup whole ref instrument note_markup note_own note_cited)

  @doc """
  Change log records for `law_name` from its parsed `rows` (`section_id`,
  `effect_joins`), its `notes` (`code`, `affected_sections`, `effect_joins`)
  and its changes-feed `effects`.
  """
  @spec records(String.t(), [map()], [map()], [Effect.t()], keyword()) :: [Record.t()]
  def records(law_name, rows, notes, effects, opts \\ []) do
    # V1-03: an effect with no territorial application of its own takes its
    # affecting law's territory (`territory`: law → code | nil — a devolved
    # type, a "(England)" title, a register extent narrower than the UK; as
    # the amending-law records, AR-09)
    territory = Keyword.get(opts, :territory, fn _law -> nil end)

    by_id = for %Effect{effect_id: id} = e <- effects, id != nil, into: %{}, do: {id, e}

    # a note's markup join is where a row's own markup carries the change
    carried =
      MapSet.new(
        for row <- rows,
            {id, :markup} <- Map.get(row, :effect_joins) || [],
            do: {id, row.section_id}
      )

    # D5: an effect on the whole instrument ("Act", "Regulations") reaches
    # every row of the law — a range over the law
    instrument =
      for %Effect{effect_id: id} = e <- effects,
          id != nil,
          instrument?(e),
          row <- rows,
          do: {{id, row.section_id}, "instrument", nil}

    joins =
      for(
        row <- rows,
        {id, kind} <- Map.get(row, :effect_joins) || [],
        do: {{id, row.section_id}, Atom.to_string(kind), nil}
      ) ++
        for(
          n <- notes,
          join <- Map.get(n, :effect_joins) || [],
          {id, kind, sid} <- note_targets(join, n, carried),
          do: {{id, sid}, "note_#{kind}", n.code}
        ) ++ instrument

    reached =
      joins
      |> Enum.filter(fn {{id, _}, _, _} -> Map.has_key?(by_id, id) end)
      |> group_ordered()
      |> Enum.map(fn {{id, sid}, vias, pointer} ->
        record(law_name, by_id[id], sid, vias, pointer, territory)
      end)

    hit = MapSet.new(reached, & &1.evidence)

    held = held_ids(rows)

    # D5: an effect reaching no row is a gap only when it may fall on a
    # provision LAT holds (or names none); one on a Schedule, an annex or a
    # section outside the law's LAT scope is not a change to LAT
    unreached =
      for %Effect{effect_id: id} = e <- effects,
          id != nil,
          not MapSet.member?(hit, id),
          on_lat?(e, held),
          do: record(law_name, e, nil, [], nil, territory)

    reached ++ unreached
  end

  @instrument ~r/\A\s*(Act|Regulations?|Order|Rules|Instrument|Measure|Scheme|Directive)\s*\z/i

  # the whole instrument: the affected provisions name the instrument alone
  defp instrument?(%Effect{affected_provisions: p}) when is_binary(p),
    do: Regex.match?(@instrument, p)

  defp instrument?(_effect), do: false

  # the law's held xml ids, and every id above one ("section-9" above
  # "section-9-2"): {held, above}
  defp held_ids(rows) do
    held =
      for row <- rows,
          id <- [Map.get(row, :xml_id), Map.get(row, :source_xml_id)],
          is_binary(id),
          into: MapSet.new(),
          do: id

    {held, MapSet.new(Enum.flat_map(held, &above/1))}
  end

  defp above(id) do
    parts = String.split(id, "-")
    for n <- 1..(length(parts) - 1)//1, do: parts |> Enum.take(n) |> Enum.join("-")
  end

  # may the effect fall on a provision LAT holds? Yes when it names none
  # (specified provisions, a blanket amendment, definitions); else when a ref
  # or a range end is a held id, inside one or above one
  defp on_lat?(%Effect{} = e, held) do
    refs =
      (e.affected_refs || []) ++
        Enum.flat_map(e.affected_ranges || [], fn {a, b} -> [a, b] end)

    refs == [] or Enum.any?(refs, &held?(&1, held))
  end

  # the ref is held, inside a held provision, or above one
  defp held?(ref, {held, above_held}) do
    MapSet.member?(held, ref) or MapSet.member?(above_held, ref) or
      Enum.any?(above(ref), &MapSet.member?(held, &1))
  end

  # a pointer join reaches the provision its effect was found on; a markup
  # join, the provisions the note sits on whose own markup carries the change
  # (a blanket note's placement isn't the change: 1991/56 "Words in Act
  # substituted … by virtue of Water Act 2003", 560 rows); an own join
  # (commencement, modification: the note sits on the provision), every
  # provision the note sits on
  defp note_targets({id, kind, sid}, _note, _carried), do: [{id, kind, sid}]

  defp note_targets({id, :markup}, note, carried),
    do:
      for(
        sid <- Map.get(note, :affected_sections) || [],
        MapSet.member?(carried, {id, sid}),
        do: {id, :markup, sid}
      )

  defp note_targets({id, kind}, note, _carried),
    do: for(sid <- Map.get(note, :affected_sections) || [], do: {id, kind, sid})

  # {key, via, pointer} → one {key, vias (strongest first), pointer} per key,
  # in first-seen order; the pointer is the first note's
  defp group_ordered(joins) do
    {order, acc} =
      Enum.reduce(joins, {[], %{}}, fn {key, via, pointer}, {order, acc} ->
        case acc do
          %{^key => {vias, p}} -> {order, Map.put(acc, key, {[via | vias], p || pointer})}
          _ -> {[key | order], Map.put(acc, key, {[via], pointer})}
        end
      end)

    for key <- Enum.reverse(order) do
      {vias, pointer} = acc[key]

      vias = vias |> Enum.uniq() |> Enum.sort_by(&Enum.find_index(@strength, fn s -> s == &1 end))
      direct = Enum.reject(vias, &String.starts_with?(&1, "note_"))

      # D4: a note join that only corroborates a direct one is dropped (its
      # placement stays in amendment_annotations); a note reaching the row
      # alone keeps its join and pointer
      if direct == [], do: {key, vias, pointer}, else: {key, direct, nil}
    end
  end

  defp record(law_name, %Effect{} = e, section_id, vias, pointer, territory) do
    %Record{
      law_name: law_name,
      section_id: section_id,
      via: vias,
      pointer: pointer,
      source: "effect",
      evidence: e.effect_id,
      affected_ref: e.affected_provisions,
      affecting_law: e.affecting,
      affecting_ref: e.affecting_provisions,
      operation: EffectFacts.kind(e.type, nil),
      effect_type: e.type,
      effective_from: EffectFacts.effect_fact(e).effective_from,
      in_force: e.in_force,
      prospective: e.prospective,
      applied: e.applied,
      savings: e.savings,
      affected_extent: e.affected_extent,
      effect_extent: e.effect_extent,
      territorial_application: e.territorial_application || territory.(e.affecting)
    }
  end
end

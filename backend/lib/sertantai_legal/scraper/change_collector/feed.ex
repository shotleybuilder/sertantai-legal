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
  row is kept with `section_id` nil. A note join only stays where the note
  alone reaches the row (LR-23 D4): beside a direct join (`:markup`,
  `:whole`, `:ref`) it only corroborates, and its placement stays in
  `amendment_annotations`. A note's text is never read: a note joining no
  effect makes no record.

  The facts are the effect's: operation (`ChangeFacts.kind/2`),
  effective_from (`ChangeFacts.effect_fact/1`: the latest dated InForce),
  in-force entries, extents, savings. Ancestor inheritance and labels are
  the projection's (LR-24). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.ChangeFacts
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  # join kinds, strongest first
  @strength ~w(markup whole ref note_markup note_own note_cited)

  @doc """
  Change log records for `law_name` from its parsed `rows` (`section_id`,
  `effect_joins`), its `notes` (`code`, `affected_sections`, `effect_joins`)
  and its changes-feed `effects`.
  """
  @spec records(String.t(), [map()], [map()], [Effect.t()]) :: [Record.t()]
  def records(law_name, rows, notes, effects) do
    by_id = for %Effect{effect_id: id} = e <- effects, id != nil, into: %{}, do: {id, e}

    # a note's markup join is where a row's own markup carries the change
    carried =
      MapSet.new(
        for row <- rows,
            {id, :markup} <- Map.get(row, :effect_joins) || [],
            do: {id, row.section_id}
      )

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
        )

    reached =
      joins
      |> Enum.filter(fn {{id, _}, _, _} -> Map.has_key?(by_id, id) end)
      |> group_ordered()
      |> Enum.map(fn {{id, sid}, vias, pointer} ->
        record(law_name, by_id[id], sid, vias, pointer)
      end)

    hit = MapSet.new(reached, & &1.evidence)

    unreached =
      for %Effect{effect_id: id} = e <- effects,
          id != nil,
          not MapSet.member?(hit, id),
          do: record(law_name, e, nil, [], nil)

    reached ++ unreached
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

  defp record(law_name, %Effect{} = e, section_id, vias, pointer) do
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
      operation: ChangeFacts.kind(e.type, nil),
      effect_type: e.type,
      effective_from: ChangeFacts.effect_fact(e).effective_from,
      in_force: e.in_force || [],
      prospective: e.prospective,
      applied: e.applied,
      savings: e.savings || [],
      affected_extent: e.affected_extent,
      effect_extent: e.effect_extent,
      territorial_application: e.territorial_application
    }
  end
end

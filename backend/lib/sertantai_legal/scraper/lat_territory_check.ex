defmodule SertantaiLegal.Scraper.LatTerritoryCheck do
  @moduledoc """
  Pre-write sanity checks on a law's parsed LAT territory (lat-refactor
  LR-03; plan `docs/LAT-EFFECTS-LAYER-PLAN.md` §8). Each finding is a rule
  breaking in the output, not a guess at the answer:

  - `:excluded_outside_extent` — `excluded_extent` names a territory the
    row doesn't extend to
  - `:child_live_where_parent_excluded` — a provision excluded somewhere
    whose sub-provision is live there
  - `:markup_effect_conflict` — a change's markup `Extent` and its effect's
    territorial application share no territory (the application is used;
    `LatTerritory.resolve/2` records the markup on the claim)
  - `:note_territory_hint` — a row excluded in its whole extent on the
    effects' evidence alone (`:effect_everywhere`: savings, purposes or the
    effect extent, the feed naming no application) while a note on it names
    a narrower territory ("omitted (E.)"; `NoteTerritory.applies/1`). A
    report for review: the note is a hint, never the source (LR-05; 2010/404
    reg.14, 2020/7 s.8)

  Pure: rows as parsed (`section_id`, `extent_code`, `excluded_extent`,
  `territory_provenance`, `text`).
  """

  alias SertantaiLegal.Scraper.{NoteTerritory, Territory}

  @type finding :: %{check: atom(), section_id: String.t(), detail: String.t()}

  @doc """
  Every finding for a law's rows, in row order. `notes` (each with
  `affected_sections` and `text`) feed the note hint check only.
  """
  @spec check([map()], [map()]) :: [finding()]
  def check(rows, notes \\ []) do
    excluded = Map.new(rows, &{&1.section_id, &1.excluded_extent})

    on_row =
      notes
      |> Enum.flat_map(fn n -> Enum.map(n[:affected_sections] || [], &{&1, n.text}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    Enum.flat_map(rows, fn row ->
      outside(row) ++
        child_live(row, excluded) ++
        conflicts(row) ++ note_hint(row, Map.get(on_row, row.section_id, []))
    end)
  end

  @doc "The enclosing provision's section id: the last \"(…)\" removed; a version qualifier kept."
  @spec parent_id(String.t()) :: String.t() | nil
  def parent_id(section_id) do
    {base, qualifier} =
      case Regex.run(~r/^(.*?)(\[[A-Z+]+\])?$/, section_id, capture: :all_but_first) do
        [base, q] -> {base, q}
        [base] -> {base, ""}
      end

    case Regex.run(~r/^(.*)\([^()]+\)$/, base, capture: :all_but_first) do
      [parent] -> parent <> qualifier
      nil -> nil
    end
  end

  defp outside(%{excluded_extent: nil}), do: []

  defp outside(%{excluded_extent: excluded, extent_code: extent} = row) do
    if Territory.covers?(Territory.subtract(extent, "") || "", excluded),
      do: [],
      else: [finding(:excluded_outside_extent, row, "#{excluded} outside #{extent || "UK"}")]
  end

  # only rows with words (dots-only rows have none to be live), and only
  # within the child's own extent
  defp child_live(row, excluded) do
    with true <- String.match?(row[:text] || "", ~r/[\p{L}\p{N}]/u),
         parent when parent != nil <- parent_id(row.section_id),
         parent_excluded when parent_excluded != nil <- Map.get(excluded, parent),
         in_child when in_child != nil <-
           Territory.subtract(
             parent_excluded,
             Territory.subtract(parent_excluded, row.extent_code) || ""
           ),
         live when live != nil <- Territory.subtract(in_child, row.excluded_extent || "") do
      [finding(:child_live_where_parent_excluded, row, live)]
    else
      _ -> []
    end
  end

  defp conflicts(row) do
    for %{conflict_markup: markup} = claim <- row.territory_provenance || [], markup != nil do
      finding(
        :markup_effect_conflict,
        row,
        "markup #{markup} used: disjoint from the effects' application (#{claim[:effect_id]})"
      )
    end
  end

  defp note_hint(%{excluded_extent: excluded, extent_code: extent} = row, texts)
       when excluded != nil and texts != [] do
    everywhere? =
      Territory.covers?(excluded, extent) and
        Enum.any?(row[:territory_provenance] || [], &(&1[:source] == :effect_everywhere))

    hinted = texts |> Enum.flat_map(&NoteTerritory.applies/1) |> Enum.uniq()

    if everywhere? and hinted != [] and not Territory.covers?(Territory.union(hinted), extent),
      do: [
        finding(
          :note_territory_hint,
          row,
          "excluded #{excluded} on effect evidence; the note says #{Enum.join(hinted, ", ")}"
        )
      ],
      else: []
  end

  defp note_hint(_row, _texts), do: []

  defp finding(check, row, detail),
    do: %{check: check, section_id: row.section_id, detail: detail}
end

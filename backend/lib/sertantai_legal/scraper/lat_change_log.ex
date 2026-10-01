defmodule SertantaiLegal.Scraper.LatChangeLog do
  @moduledoc """
  Per-row change log of one LAT parse (sertantai-legal #167, L8.5): which rows
  changed, how, and why — the row-level counterpart of the operation's cause
  (`LatCause`). Pure: `LatCause.Apply` gathers the merge plan, the new notes
  and the status changes, and writes the entries to `lat_changes`.

  Changes: `text_changed` (same id, new text), `inserted`, `removed`,
  `renamed` (merge renames, plus whole-provision renumbering notes that pair
  a removed and an inserted row), `status_changed` (status only).

  Cause per row:
  - `initial` operation → no entries (version 1 is not a change)
  - `parser` / `scope` / `correction` operation → that cause for every row
  - source changed (`legislative` / `unattributed` operation) → `legislative`
    with the row's own evidence — a note new in this parse whose target is the
    row or an ancestor, or a status change — else `unattributed` (never
    versioned by fractalaw)
  """

  alias SertantaiLegal.Scraper.{LatEffects, LatStatus}

  @type entry :: %{
          section_id: String.t() | nil,
          old_section_id: String.t() | nil,
          change: String.t(),
          cause: String.t(),
          change_ids: [String.t()]
        }

  @renumbered ~r/^(?:F\d+ )?((?:S|Reg|Art|Rule)\.? ?[^\s(]+(?:\([^)\s]*\))*) renumbered as ((?:s|reg|art|rule)\.? ?[^\s(]+(?:\([^)\s]*\))*)/

  @doc """
  `{old, new}` section_ids from a whole-provision renumbering note
  ("S. 23 renumbered as s. 24"); nil for anything else, including words moved
  within a provision ("Words in s. 39(3)(a) renumbered as …").
  """
  @spec renumber_pair(String.t(), String.t()) :: {String.t(), String.t()} | nil
  def renumber_pair(text, law_name) do
    with [_, old, new] <- Regex.run(@renumbered, text || ""),
         old_id when is_binary(old_id) <- LatEffects.target_section_id(old, law_name),
         new_id when is_binary(new_id) <- LatEffects.target_section_id(new, law_name) do
      {old_id, new_id}
    else
      _ -> nil
    end
  end

  @doc """
  The parse's entries. `plan`: `%{changed, inserted, removed, renames}` (ids;
  renames `%{old, new, match}`). `ctx`: `%{cause, new_notes, status_changes}`
  — the operation's cause, notes new in this parse (`%{target, text, parsed}`,
  `parsed` an `AmendmentNote`), and `[{section_id, before, after}]`.
  """
  @spec entries(map(), map()) :: [entry()]
  def entries(_plan, %{cause: "initial"}), do: []

  def entries(plan, %{cause: cause, new_notes: notes, status_changes: status_changes}) do
    law_name = law_of(plan, notes)

    pairs =
      for n <- notes,
          {old, new} <- [renumber_pair(n.text, law_name)],
          old in plan.removed and new in plan.inserted,
          do: {old, new, n.parsed.change_id}

    paired_old = MapSet.new(pairs, &elem(&1, 0))
    paired_new = MapSet.new(pairs, &elem(&1, 1))
    status_ids = MapSet.new(status_changes, &elem(&1, 0))
    by_target = Enum.group_by(notes, & &1.target, & &1.parsed.change_id)

    evidence = fn sid ->
      sid |> LatStatus.ancestors() |> Enum.flat_map(&Map.get(by_target, &1, [])) |> Enum.uniq()
    end

    row = fn change, sid, old, ids ->
      %{
        section_id: sid,
        old_section_id: old,
        change: change,
        cause: row_cause(cause, ids != [] or MapSet.member?(status_ids, sid || old)),
        change_ids: ids
      }
    end

    text_rows = Enum.map(plan.changed, &row.("text_changed", &1, nil, evidence.(&1)))

    inserted_rows =
      for sid <- plan.inserted,
          not MapSet.member?(paired_new, sid),
          do: row.("inserted", sid, nil, evidence.(sid))

    removed_rows =
      for old <- plan.removed,
          not MapSet.member?(paired_old, old),
          do: row.("removed", nil, old, evidence.(old))

    rename_rows =
      Enum.map(plan.renames, &row.("renamed", &1.new, &1.old, evidence.(&1.new))) ++
        for {old, new, cid} <- pairs,
            do: %{
              section_id: new,
              old_section_id: old,
              change: "renamed",
              cause: legislative_or(cause),
              change_ids: [cid]
            }

    logged = MapSet.new(plan.changed ++ plan.inserted)

    status_rows =
      for {sid, _before, _after} <- status_changes,
          not MapSet.member?(logged, sid),
          do: row.("status_changed", sid, nil, evidence.(sid))

    text_rows ++ inserted_rows ++ removed_rows ++ rename_rows ++ status_rows
  end

  # The operation's cause stands where the source didn't change; where it did,
  # only the row's own evidence makes a change legislative.
  defp row_cause(op_cause, _evidence?) when op_cause in ["parser", "scope", "correction"],
    do: op_cause

  defp row_cause(_op_cause, true), do: "legislative"
  defp row_cause(_op_cause, false), do: "unattributed"

  defp legislative_or(op_cause) when op_cause in ["parser", "scope", "correction"], do: op_cause
  defp legislative_or(_), do: "legislative"

  defp law_of(plan, notes) do
    (plan.changed ++
       plan.inserted ++
       plan.removed ++ Enum.map(plan.renames, & &1.old) ++ Enum.map(notes, & &1.target))
    |> List.first("")
    |> String.split(":", parts: 2)
    |> hd()
  end
end

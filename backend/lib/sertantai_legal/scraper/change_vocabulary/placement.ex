defmodule SertantaiLegal.Scraper.ChangeVocabulary.Placement do
  @moduledoc """
  Where a feed effect lands (CV-S02, agreed with Jason 2026-10-22: every
  effect accounted for). Given the provisions the feed reader placed it on
  (`Readers.Feed.read/5` targets) and what we hold of the law — its LAT
  rows, the provisions in its CLML, whether its LAT holds schedules — an
  effect is:

  - `:placed` — on a row we hold;
  - `:placed_versions` — on a provision we hold as territorial versions
    (C3: `s.23` → `s.23[E+W]`, `s.23[S]`);
  - `:whole_law` — on the whole instrument;
  - `{:unplaced, reason}`:
    - `:schedule_not_parsed` — in a schedule; schedules are not parsed into
      LAT (a known limit for v0.1, Jason 2026-10-22);
    - `:not_a_provision` — the feed names no provision ("specified amended
      provision(s)", "C/O");
    - `:not_in_text` — not in the current text (gone, or not yet applied);
    - `:refs_not_converted` — refs given, none converted (our fault);
    - `:not_in_rows` — in the text but not in our LAT rows (our fault until
      explained).

  Pure.
  """

  @type outcome ::
          :placed | :placed_versions | :whole_law | {:unplaced, atom()}

  @faults [:refs_not_converted, :not_in_rows]

  @doc "Where an effect lands, from its targets and what we hold of the law."
  @spec classify(map(), [String.t()], %{rows: MapSet.t(), clml: MapSet.t(), schedules?: boolean()}) ::
          outcome()
  def classify(effect, targets, held) do
    bases = MapSet.new(held.rows, &String.replace(&1, ~r/\[[^\]]+\]$/, ""))

    cond do
      "*" in targets ->
        :whole_law

      targets == ["?"] ->
        if effect.affected_refs in [nil, []],
          do: {:unplaced, :not_a_provision},
          else: {:unplaced, :refs_not_converted}

      Enum.any?(targets, &MapSet.member?(held.rows, &1)) ->
        :placed

      Enum.any?(targets, &MapSet.member?(bases, &1)) ->
        :placed_versions

      not held.schedules? and Enum.all?(targets, &String.starts_with?(&1, "sch.")) ->
        {:unplaced, :schedule_not_parsed}

      Enum.any?(targets, &MapSet.member?(held.clml, &1)) ->
        {:unplaced, :not_in_rows}

      true ->
        {:unplaced, :not_in_text}
    end
  end

  @doc "True for a reason that is the reader's fault (pass needs none)."
  @spec fault?(atom()) :: boolean()
  def fault?(reason), do: reason in @faults
end

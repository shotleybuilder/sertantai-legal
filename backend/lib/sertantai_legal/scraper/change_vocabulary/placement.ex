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
  - `:placed_ancestor` — deeper than our rows: on the nearest held row,
    whose words it changes (`retarget/3` moves it there);
  - `{:unplaced, reason}`:
    - `:schedule_not_parsed` — in a schedule (or an EU annex, the same
      role); schedules are not parsed into LAT (a known limit for v0.1,
      Jason 2026-10-22);
    - `:not_a_provision` — the feed names no provision ("specified amended
      provision(s)", "C/O");
    - `:ref_ambiguous` — the feed's ref names a part found under several
      ("chapter-2" in a law with a Chapter 2 in three Titles): the feed's
      own;
    - `:not_in_text` — not in the current text (gone, or not yet applied);
    - `:refs_not_converted` — refs given, none converted (the reader's
      fault);
    - `:row_missing` — in the text, but no row of its own nor any held
      ancestor: the LAT parse's tell-tale (#182; raised, not fixed).

  Pure.
  """

  @type outcome ::
          :placed | :placed_versions | :placed_ancestor | :whole_law | {:unplaced, atom()}

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.LatRef

  @faults [:refs_not_converted]

  # the changes that change a provision's text, so the words of the row
  # above a deep one; a commencement stays for "commenced through its
  # parts" (`ChangeVocabulary`); a modification or application changes no
  # label (Jason 2026-10-22: "I agree the logic")
  @text_changes ~w(inserted substituted repealed repealed_in_part renumbered)a

  @doc "Where an effect lands, from its targets and what we hold of the law."
  @spec classify(map(), [String.t()], %{rows: MapSet.t(), clml: MapSet.t(), schedules?: boolean()}) ::
          outcome()
  def classify(effect, targets, held) do
    bases = MapSet.new(held.rows, &String.replace(&1, ~r/\[[^\]]+\]$/, ""))

    cond do
      "*" in targets ->
        :whole_law

      # no ref naming an element (none, or bare words: "rule", "introduction")
      targets == ["?"] ->
        # an element id joins a kind and a number ("annex-XVII", "part-4")
        refs = Enum.filter(List.wrap(effect.affected_refs), &(&1 =~ ~r/[-\d]/))

        cond do
          refs == [] ->
            {:unplaced, :not_a_provision}

          Enum.all?(refs, &ambiguous?(&1, Map.get(held, :xml_ids, %{}))) ->
            {:unplaced, :ref_ambiguous}

          true ->
            {:unplaced, :refs_not_converted}
        end

      Enum.any?(targets, &MapSet.member?(held.rows, &1)) ->
        :placed

      Enum.any?(targets, &MapSet.member?(bases, &1)) ->
        :placed_versions

      not held.schedules? and Enum.all?(targets, &schedule?/1) ->
        {:unplaced, :schedule_not_parsed}

      Enum.any?(targets, &(MapSet.member?(held.clml, &1) and held_ancestor(&1, held.rows) != nil)) ->
        :placed_ancestor

      Enum.any?(targets, &MapSet.member?(held.clml, &1)) ->
        {:unplaced, :row_missing}

      true ->
        {:unplaced, :not_in_text}
    end
  end

  @doc """
  Changes deeper than our rows moved to the nearest held row, as words
  changes (Jason 2026-10-22: "choose the changes that will affect our
  labels"): a text change (inserted, substituted, repealed, renumbered —
  whole or words, in any territory) on a provision in the law's text
  (`text`) that has no row of its own, but an ancestor that does, changes
  that row's words. A commencement stays on the deep item: the row above
  is in force partly until it is ("commenced through its parts"). The
  feed's own target is kept (`:placement :below_rows`). Held, held as
  territorial versions, gone from the text, or with nothing held above:
  left alone.
  """
  @spec retarget([Change.t()], MapSet.t(), MapSet.t()) :: [Change.t()]
  def retarget(changes, rows, text) do
    bases = MapSet.new(rows, &base/1)

    changes
    |> Enum.map(fn %Change{target: t} = c ->
      with true <- c.resolved != nil and c.resolved.operation in @text_changes,
           false <- MapSet.member?(bases, t),
           true <- MapSet.member?(text, t),
           a when a != nil <- held_ancestor(t, rows) do
        %Change{
          c
          | target: a,
            claims: c.claims ++ Claim.new(:placement, :below_rows, t, c.key),
            resolved: %{c.resolved | level: :words}
        }
      else
        _ -> c
      end
    end)
    |> Enum.uniq_by(&{&1.key, &1.target})
  end

  # the nearest ancestor we hold a row for (or its territorial versions)
  defp held_ancestor(target, rows) do
    bases = MapSet.new(rows, &base/1)
    target |> LatRef.ancestors() |> tl() |> Enum.find(&MapSet.member?(bases, &1))
  end

  defp base(row), do: String.replace(row, ~r/\[[^\]]+\]$/, "")

  # the ref names a part found under several ("chapter-2" ends
  # "title-II-chapter-2" and "title-III-chapter-2"): the feed doesn't say which
  defp ambiguous?(ref, xml_ids),
    do: xml_ids |> Map.keys() |> Enum.count(&String.ends_with?(&1, "-" <> ref)) > 1

  # a schedule, or an EU annex (the same role, the same limit)
  defp schedule?(target),
    do: String.starts_with?(target, "sch.") or String.starts_with?(target, "annex.")

  @doc "True for a reason that is the reader's fault (pass needs none)."
  @spec fault?(atom()) :: boolean()
  def fault?(reason), do: reason in @faults
end

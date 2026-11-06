defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.Evidence do
  @moduledoc """
  The evidence step's family gate (Decision 1, Maritime Safety: Evidence,
  2026-11-06): every evidence decision a family's changes hold where the
  sources disagree, grouped by a cause from code and the amending law:

  - a value conflict (`EvidenceStrata` V, `Conflicts.values/1`): `"<attribute>:
    <primary source> against <derived source>"`, with both values for the
    operation and the level (`"operation: law_text repealed against feed
    substituted"`);
  - a markup–feed disagreement with no primary claim (D,
    `EvidenceStrata.disagreements/1`): `"<attribute>: markup <values>
    against feed <values>"` (the table applies one rule to all of them).

  Statuses are reviewed in `test/fixtures/evidence/evidence.json` with the
  merge gate's semantics (`MergeGate.items/3`, `gate/1`): by law, else by
  cause, else inherited from an earlier step's gate. `gaps/1` counts the
  values no source claims, a published figure that never fails. Outside
  `ChangeVocabulary.Version`'s files: a check, never what a build reads.
  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, EvidenceStrata, MergeGate}

  # the attributes whose values name the cause (a small vocabulary)
  @valued [:operation, :level]

  # the attributes a text change's gap is published for (a commencement or
  # modification has no operation, level or `by` by design)
  @gap_attributes [:level, :date, :by, :commenced_by]

  @doc "One amended law's entries: each value conflict and each markup–feed disagreement."
  @spec entries(String.t(), [Change.t()]) :: [MergeGate.entry()]
  def entries(law, changes) do
    for {c, s} <- EvidenceStrata.classify(changes), s in [:V, :D], cause <- causes(c, s) do
      %{
        law: law,
        cause: cause,
        by: by(c),
        target: c.target,
        words: "#{law} #{c.target}",
        change: c
      }
    end
  end

  @doc "A change's causes in its stratum, one per attribute in dispute."
  @spec causes(Change.t(), :V | :D) :: [String.t()]
  def causes(c, :V) do
    c.resolved.conflicts
    |> Enum.map(fn {a, {ps, pv}, {ds, dv}} ->
      "#{a}: #{side(a, ps, pv)} against #{side(a, ds, dv)}"
    end)
    |> Enum.uniq()
  end

  def causes(c, :D) do
    for {a, m, f} <- EvidenceStrata.disagreements(c),
        do: "#{a}: #{side(a, :markup, m)} against #{side(a, :feed, f)}"
  end

  defp side(a, source, value) when a in @valued, do: "#{source} #{values(value)}"
  defp side(_a, source, _value), do: to_string(source)

  defp values(vs) when is_list(vs), do: vs |> Enum.uniq() |> Enum.sort() |> Enum.join("+")
  defp values(v), do: to_string(v)

  @doc "The entries grouped by cause and amending law, each with its status (`MergeGate.items/3`)."
  @spec items([MergeGate.entry()], map(), (MergeGate.entry() -> String.t() | nil)) ::
          [MergeGate.item()]
  def items(entries, reviewed, inherited \\ fn _ -> nil end),
    do: MergeGate.items(entries, reviewed, inherited)

  @doc "The gate: `pass?` when every group is named `known:` (`MergeGate.gate/1`)."
  @spec gate([MergeGate.item()]) :: %{
          pass?: boolean(),
          failing: [MergeGate.item()],
          counts: map()
        }
  def gate(items), do: MergeGate.gate(items)

  @doc """
  The values no source claims on text changes (those with an operation):
  `{attribute, cause}` → changes, the cause the sources the change holds,
  with `"; amending law has no commencement rules"` for a commenced_by gap
  whose amending law is not in `ruled` (the laws holding commencement
  rules; the agent pass, 2026-11-06: their own clause unread). A gap is
  coverage, not a fault (Jason 2026-10-29). A commencement has no `by`.
  """
  @spec gaps([Change.t()], MapSet.t() | nil) :: %{{atom(), String.t()} => pos_integer()}
  def gaps(changes, ruled \\ nil) do
    for %Change{resolved: %{sources: sources, operation: op}} = c <- changes,
        op not in [nil, :commenced],
        a <- @gap_attributes,
        Map.get(sources, a) == nil,
        reduce: %{} do
      acc -> Map.update(acc, {a, gap_cause(c, a, ruled)}, 1, &(&1 + 1))
    end
  end

  @no_rules "; amending law has no commencement rules"

  @doc """
  Each attribute's gaps (`gaps/2`) summed: the total, and those whose
  amending law has no commencement rules (Maritime Safety: Measures: the
  published totals were summed by hand, and wrong).
  """
  @spec gap_totals(%{{atom(), String.t()} => pos_integer()}) :: %{
          atom() => %{total: non_neg_integer(), no_rules: non_neg_integer()}
        }
  def gap_totals(gaps) do
    Enum.reduce(gaps, %{}, fn {{a, cause}, n}, acc ->
      no_rules = if String.ends_with?(cause, @no_rules), do: n, else: 0

      Map.update(
        acc,
        a,
        %{total: n, no_rules: no_rules},
        &%{total: &1.total + n, no_rules: &1.no_rules + no_rules}
      )
    end)
  end

  defp gap_cause(c, :commenced_by, %MapSet{} = ruled) do
    if MapSet.member?(ruled, by(c)),
      do: held(c),
      else: held(c) <> @no_rules
  end

  defp gap_cause(c, _a, _ruled), do: held(c)

  defp held(c),
    do: c.claims |> Enum.map(& &1.source) |> Enum.uniq() |> Enum.sort() |> Enum.join("+")

  defp by(%Change{resolved: %{by: by}}) when is_binary(by), do: by

  defp by(c),
    do:
      Change.value(c, :feed, :by) || Change.value(c, :law_text, :by) ||
        Change.value(c, :markup, :cited) || "-"
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.Label do
  @moduledoc """
  The label fold's family gate (Decision 1, Maritime Safety: Label fold,
  2026-11-06): every breach a family's folded rows hold, grouped by its
  rule and the row's law:

  - a label rule (`LabelRules.breaches/3`): `"before_amender"`,
    `"before_insertion"`, `"windsor_ni"`, `"no_made_period"`,
    `"saved_not_saved"`, and the rules listed apart
    (`LabelRules.informational/0`), named by rule alone;
  - a break of the table's rules (`LabelPeriods.violations/1`):
    `"table: <why>"`;
  - a fold period whose empty field carries a tier (RULES.md
    tier-per-field; the made period's, found by the agent pass, 2026-11-06):
    `"tier: empty field"`;
  - a row whose first period begins on a Part's, Chapter's or Title's
    whole insertion later than every dated whole insertion of the row or
    its section (the agent pass: a feed range's "(Pt. 6)" locator placed
    as the Part's insertion, MSA 1995 s.130B(4)): `"start: a container's
    insertion after its own"`;
  - the agent pass's classes from Environmental Protection (2026-11-11): an
    own commencement before the law's general start left prospective
    (`"start: an own commencement before the law's start dropped"`), and an
    ancestor insertion's narrower territory lost under the row's own
    territory-less insertion (`"territory: an ancestor insertion's
    territory lost"`).

  Rows are `LabelSource.rows/1`'s, checked on their periods as compliance
  gets them (`LabelPeriods.periods/4`); the rows named known limits
  (`KnownLimits.sids/0`) are left out. Statuses are reviewed in
  `test/fixtures/label/labels.json` with the merge gate's semantics
  (`MergeGate.items/3`, `gate/1`): by law, else by rule. `gaps/1` counts
  the rows of the gap shapes (`LabelStrata.shapes/3`), a published figure
  that never fails. Outside `ChangeVocabulary.Version`'s files: a check,
  never what a build reads. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelPeriods, LabelRules, MergeGate}

  # the shapes that are gaps: a start, or a change, no source dates
  @gaps [:undated_start, :undated_change]

  # a Part, Chapter or Title row's ref
  @containers ["pt.", "ch.", "title."]

  # the fields whose tier must be nil when they are empty
  @tiered [:in_force_from, :changed_by, :commenced_by, :territory]

  @doc "One law's entries: each label-rule breach and each break of the table's rules, row by row."
  @spec entries(String.t(), [map()], (map() -> map()), MapSet.t()) :: [MergeGate.entry()]
  def entries(law, rows, ctx, known \\ MapSet.new()) do
    for r <- rows,
        not MapSet.member?(known, r.sid),
        timeline = LabelPeriods.periods(law, r.sid, r.periods, r.reaching),
        {cause, why} <- breaches(timeline, r, ctx),
        uniq: true do
      %{law: law, cause: cause, by: law, target: r.sid, words: "#{r.sid}: #{why}", change: nil}
    end
  end

  defp breaches(timeline, r, ctx) do
    rules =
      for {rule, why} <- LabelRules.breaches(timeline, r.reaching, ctx.(r)),
          do: {to_string(rule), why}

    table = for {_sid, why} <- LabelPeriods.violations(timeline), do: {"table: #{why}", "#{why}"}

    rules ++
      table ++
      tiered(r.periods) ++
      container_start(timeline, r) ++ early_own(r) ++ ancestor_territory(timeline, r)
  end

  # the agent pass, Environmental Protection: Label fold (2026-11-11): the
  # law's own clause commences the row before the law's general start, after
  # its making, while the fold has it prospective then (WSI 2026/103 Part 7)
  defp early_own(%{start: %Date{} = start, sid: sid} = r) do
    law = sid |> String.split(":") |> hd()

    early =
      for c <- r.reaching,
          c.resolved.operation == :commenced and
            String.starts_with?(c.key, law <> ":commencement:"),
          c.resolved.date != nil and Date.compare(c.resolved.date, start) == :lt,
          not before_made?(c.resolved.date, Map.get(r, :made)),
          do: c.resolved.date

    case early do
      [] ->
        []

      dates ->
        day = Enum.min(dates, Date)

        if Enum.any?(r.periods, &(&1.status == :prospective and spans?(&1, day))),
          do: [
            {"start: an own commencement before the law's start dropped",
             "own clause #{day}, law start #{start}"}
          ],
          else: []
    end
  end

  defp early_own(_r), do: []

  defp before_made?(_date, nil), do: false
  defp before_made?(date, made), do: Date.compare(date, made) == :lt

  defp spans?(p, day),
    do:
      Date.compare(p.valid_from, day) != :gt and
        (p.valid_to == nil or Date.compare(p.valid_to, day) == :gt)

  # the agent pass (2026-11-11): the row's nearest whole insertion names no
  # territory, an ancestor's names a narrower one, and the row begins wider
  # (C14: SI 1999/2228 reg.3B(10)(b), reg.3B inserted for England only)
  defp ancestor_territory([first | _], r) do
    insertions =
      Enum.filter(r.reaching, &(whole_insertion?(&1) and &1.target != "*"))
      |> Enum.sort_by(&(-length(SertantaiLegal.Scraper.LatRef.ancestors(&1.target))))

    with [%{resolved: %{territory: nil}} = own | above] <- insertions,
         [t | _] <-
           for(
             c <- above,
             c.target != own.target and is_binary(c.resolved.territory),
             Date.compare(c.resolved.date, first.valid_from) != :gt,
             do: c.resolved.territory
           ),
         true <-
           is_binary(first.territory) and
             not SertantaiLegal.Scraper.Territory.covers?(t, first.territory) do
      [
        {"territory: an ancestor insertion's territory lost",
         "#{first.territory}, inserted for #{t}"}
      ]
    else
      _ -> []
    end
  end

  defp ancestor_territory([], _r), do: []

  defp container_start([], _r), do: []

  # a container's insertion reaches the row through `Label.containers/2`,
  # not as a reaching change: the law's container insertions that day
  defp container_start([first | _], r) do
    on_start =
      r
      |> Map.get(:changes, [])
      |> Enum.filter(
        &(whole_insertion?(&1) and String.starts_with?(&1.target, @containers) and
            &1.resolved.date == first.valid_from)
      )

    own_dates =
      for c <- r.reaching,
          whole_insertion?(c),
          not String.starts_with?(c.target, @containers),
          do: c.resolved.date

    if on_start != [] and own_dates != [] and
         Enum.all?(own_dates, &(Date.compare(&1, first.valid_from) == :lt)),
       do: [
         {"start: a container's insertion after its own",
          "starts #{first.valid_from} with #{hd(on_start).target}; own insertion #{Enum.max(own_dates, Date)}"}
       ],
       else: []
  end

  defp whole_insertion?(c),
    do:
      c.resolved.operation == :inserted and c.resolved.level == :provision and
        c.resolved.date != nil

  # an empty field (nil or []) has no tier
  defp tiered(periods) do
    for p <- periods,
        f <- @tiered,
        Map.get(p, f) in [nil, []],
        get_in(p, [Access.key(:tiers, %{}), f]) != nil,
        do: {"tier: empty field", "#{p.valid_from} #{p.status}: #{f} empty, tier #{p.tiers[f]}"}
  end

  @doc "The entries grouped by rule and law, each with its status (`MergeGate.items/3`)."
  @spec items([MergeGate.entry()], map()) :: [MergeGate.item()]
  def items(entries, reviewed), do: MergeGate.items(entries, reviewed)

  @doc "The gate: `pass?` when every group is named `known:` (`MergeGate.gate/1`)."
  @spec gate([MergeGate.item()]) :: %{
          pass?: boolean(),
          failing: [MergeGate.item()],
          counts: map()
        }
  def gate(items), do: MergeGate.gate(items)

  @doc "The rows of each gap shape, from each row's shapes."
  @spec gaps([[atom()]]) :: %{atom() => pos_integer()}
  def gaps(shapes),
    do: shapes |> List.flatten() |> Enum.filter(&(&1 in @gaps)) |> Enum.frequencies()
end

defmodule SertantaiLegal.Scraper.Commencement.Check do
  @moduledoc """
  The commencement reader's check, pure (`mix lat.commencement_check` reads
  the DB and prints). It takes a law's rows, rules and feed records as data,
  and gives:

  - **rows:** each provision's own-commencement outcome
    (`Readers.OwnCommencement.outcome/4`) and, beside it, the law's own
    feed's coming-into-force record as a yardstick (never a source);
  - **gaps:** each stored change no other source dates, classed by what the
    gap-filler (`Readers.NoteDate.why/2`) makes of it;
  - the tallies the task prints, and the items a sample file holds.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmendingLaw, NoteDate, OwnCommencement}
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}
  alias SertantaiLegal.Scraper.{LatRef, Territory}

  @text_ops [:inserted, :substituted, :repealed, :repealed_in_part, :renumbered]

  # ── rows ─────────────────────────────────────────────────────────────

  @doc """
  Each provision's outcome for one law. `rows` are its LAT rows in document
  order (`section_id`, `text`, `part`, `chapter`, `extent_code`); `feed` is
  `feed_index/1`'s map; `no_clause?` marks a law `LawStart` leaves with no
  clause (a known limit, not a law never read).
  """
  @spec rows(String.t(), [map()], [Rule.t()], map(), boolean()) :: [map()]
  def rows(law, rows, rules, feed, no_clause?) do
    # the reader's context, as the build gives it (`lat.vocabulary`)
    ctx = OwnClause.context(rows)
    rows = Enum.map(rows, &Map.put(&1, :id, &1.section_id |> bare(law) |> Ref.canonical()))
    extents = base_extents(rows)

    rows
    |> Enum.map(&base(&1.id))
    |> Enum.uniq()
    |> Enum.map(fn id ->
      {outcome, result} =
        OwnCommencement.outcome(rules, law, id, Map.put(ctx, :extent, Map.get(extents, id)))

      outcome = if outcome == :no_rules and no_clause?, do: :no_clause, else: outcome
      outcome = signature(id, outcome)

      %{
        law: law,
        id: id,
        outcome: outcome,
        result: result,
        full_from: result && result.full_from,
        partial_from: result && result.partial_from,
        feed: feed |> feed_at(id) |> feed_in(Map.get(extents, id))
      }
    end)
    |> Enum.map(&Map.put(&1, :yardstick, yardstick(&1)))
  end

  # the signature block is no provision: where the clause dates the law's
  # provisions by name and no rule reaches it, nothing is left unread (SI
  # 2015/962 reg.1(2), (3): Parts 1 to 3 named, the signature not)
  defp signature("signed", :not_reached), do: :not_a_provision
  defp signature(_id, outcome), do: outcome

  @doc """
  Whether a law states no commencement of its own: `LawStart` leaves it
  with no clause (`treatment`), and nothing read from its text is a
  commencement — no rule at all, or only its Schedules given effect by
  their provisions (NISI 1973/69 and NISI 1981/158, whose commencement
  paragraphs the revised text omits; SSI 2005/351, an order commencing
  another Act and stating no day of its own).
  """
  @spec no_clause?([Rule.t()], atom()) :: boolean()
  def no_clause?(rules, treatment),
    do: treatment == :no_clause and Enum.all?(rules, &(&1.treatment == :schedule_effect))

  @doc """
  The law's own feed's coming-into-force records by target: `[target,
  first, full]` rows → `%{base_id => {first, full}}`; with a fourth, its
  stages for one place each (`[[date, place]]`), kept for `rows/5` to see
  when together they cover the row's extent.
  """
  @spec feed_index([[term()]]) :: map()
  def feed_index(records), do: Map.new(records, &feed_record/1)

  defp feed_record([t, first, full]), do: {t |> Ref.canonical() |> base(), {first, full}}

  defp feed_record([t, first, full, stages]),
    do: {t |> Ref.canonical() |> base(), {first, full, stages || []}}

  @doc "How the reader's full date (or, partly in force on both sides, its first) stands against the feed's."
  @spec yardstick(map()) :: atom()
  def yardstick(%{feed: nil, full_from: nil}), do: :neither
  def yardstick(%{feed: nil}), do: :own_only
  def yardstick(%{feed: {_, full}, full_from: full}) when full != nil, do: :agree
  # partly in force from the same day on both sides, fully on neither
  # ("Section 7, in relation to England only": SI 2010/2169 Sch.)
  def yardstick(%{feed: {first, nil}, full_from: nil, partial_from: first}) when first != nil,
    do: :agree

  def yardstick(%{full_from: nil}), do: :feed_only
  def yardstick(%{feed: {_, nil}}), do: :feed_partial_only
  def yardstick(_), do: :differ

  @doc "Rows whose outcome is our fault."
  @spec faults([map()]) :: [map()]
  def faults(rows), do: Enum.filter(rows, &OwnCommencement.fault?(&1.outcome))

  @doc """
  The row tallies: each outcome with its row and law counts (most first),
  the rows left to orders, and the yardstick counts.
  """
  @spec row_tallies([map()]) :: map()
  def row_tallies(rows) do
    %{
      laws: rows |> Enum.map(& &1.law) |> Enum.uniq() |> length(),
      outcomes:
        for {k, n} <- rows |> Enum.frequencies_by(& &1.outcome) |> Enum.sort_by(&(-elem(&1, 1))) do
          laws = rows |> Enum.filter(&(&1.outcome == k)) |> Enum.map(& &1.law) |> Enum.uniq()
          {k, n, length(laws), OwnCommencement.fault?(k)}
        end,
      by_order: Enum.count(rows, &(&1.outcome in [:by_order, :by_order_partly])),
      yardstick: rows |> Enum.frequencies_by(& &1.yardstick) |> Enum.sort_by(&(-elem(&1, 1)))
    }
  end

  # as the build: a provision's own row's extent, else its versions' together
  defp base_extents(rows) do
    rows
    |> Enum.group_by(&base(&1.id), & &1)
    |> Map.new(fn {b, rs} ->
      case Enum.find(rs, &(&1.id == b)) do
        %{extent_code: e} when is_binary(e) ->
          {b, e}

        _ ->
          {b,
           case rs |> Enum.map(& &1.extent_code) |> Enum.reject(&is_nil/1) do
             [] -> nil
             es -> Territory.union(es)
           end}
      end
    end)
  end

  defp bare(sid, law), do: String.replace_prefix(sid, law <> ":", "")
  defp base(id), do: String.replace(id, ~r/\[[^\]]+\]$/, "")

  # the nearest record at the row or above it
  # the nearest record, fully in force once it or an ancestor is (Water Act
  # 2014 s.6(1): purposes by SI 2015/1938, s.6 wholly by SI 2016/465)
  defp feed_at(feed, id) do
    case for(a <- LatRef.ancestors(id), r = Map.get(feed, a), do: r) do
      [] ->
        nil

      [nearest | _] = records ->
        with_full(nearest, records |> Enum.map(&elem(&1, 1)) |> earliest())
    end
  end

  defp earliest(dates), do: dates |> Enum.reject(&is_nil/1) |> Enum.min(Date, fn -> nil end)

  defp with_full(record, nil), do: record
  defp with_full(record, full), do: put_elem(record, 1, full)

  # the feed's full start: its own, else the day its stages for one place
  # each first cover the row's extent, as the evaluator reads ours (Water
  # Act 2003 s.77: England 1 October 2004 by SI 2004/2528, Wales 11
  # November 2004 by WSI 2004/2916)
  defp feed_in({first, nil, stages}, extent) when is_binary(extent),
    do: {first, covered(Enum.sort_by(stages, &hd/1, Date), extent)}

  defp feed_in({first, full, _stages}, _extent), do: {first, full}
  defp feed_in(feed, _extent), do: feed

  defp covered(stages, extent) do
    Enum.reduce_while(stages, [], fn [date, place], places ->
      places = [place | places]

      if Territory.covers?(Territory.union(places), extent),
        do: {:halt, date},
        else: {:cont, places}
    end)
    |> then(&if(is_struct(&1, Date), do: &1))
  end

  # ── gaps ─────────────────────────────────────────────────────────────

  @doc """
  One law's gaps: each stored change no other source dates, with what the
  gap-filler makes of it (its own claims set aside). `commencement` holds
  the amending laws' rules, by law.
  """
  @spec gaps(String.t(), [Change.t()], map()) :: [map()]
  def gaps(law, changes, commencement) do
    for c <- Enum.map(changes, &without_gap_fill/1),
        why = NoteDate.why(c, commencement),
        why != :not_a_gap,
        do: %{law: law, change: c, why: why, amender: amender(c), commencement: commencement}
  end

  # the claims that date a change: set aside to ask what its inserting law
  # says (`NoteDate.why/2` dates only a change none of them dates)
  @dated [{:feed, :date}, {:feed, :date_first}, {:commencement, :date}, {:law_text, :date}]

  @doc """
  Each provision another law inserted on `law`, judged by its inserting law
  (Decision 7 C, Jason 2026-11-21: "inserted laws are dated by the law that
  inserts them"): the insertion dated as the amending law's commencement
  gives it (`NoteDate.why/2`, the change's own dates set aside), beside the
  feed's record — `:agree`, `:differ`, `:feed_only` (the feed alone dates
  it), `:ours_only` or `:neither`. `commencement`: the amending laws' rules.
  """
  @spec inserted(String.t(), [Change.t()], map()) :: [map()]
  def inserted(law, changes, commencement) do
    for c <- changes, insertion?(c) do
      feed =
        {Change.value(c, :feed, :date_first) || Change.value(c, :feed, :date),
         Change.value(c, :feed, :date)}

      ours = c |> undated() |> NoteDate.why(commencement)
      %{law: law, id: c.target, feed: feed, ours: ours, yardstick: inserted_yardstick(ours, feed)}
    end
  end

  defp insertion?(%Change{resolved: %{operation: op}}), do: op == :inserted

  defp insertion?(c),
    do: Enum.any?([:feed, :markup, :law_text], &(Change.value(c, &1, :operation) == :inserted))

  defp undated(c),
    do: %{
      c
      | claims:
          Enum.reject(c.claims, &({&1.source, &1.attribute} in @dated or &1.attribute == :via))
    }

  defp inserted_yardstick({:dated, d, _}, {_first, %Date{} = full}),
    do: if(Date.compare(d, full) == :eq, do: :agree, else: :differ)

  defp inserted_yardstick({:dated, _, _}, _feed), do: :ours_only
  defp inserted_yardstick(_ours, {%Date{}, _}), do: :feed_only
  defp inserted_yardstick(_ours, {_, %Date{}}), do: :feed_only
  defp inserted_yardstick(_ours, _feed), do: :neither

  @doc "The law that made a change: the feed's, else the markup note's."
  @spec amender(Change.t()) :: String.t() | nil
  def amender(c), do: Change.value(c, :feed, :by) || Change.value(c, :markup, :cited)

  @doc "A change with the gap-filler's own claims (a date with `:via`) set aside, to ask it again."
  @spec without_gap_fill(Change.t()) :: Change.t()
  def without_gap_fill(%Change{} = c) do
    if Change.values(c, :commencement, :via) == [],
      do: c,
      else: %{
        c
        | claims:
            Enum.reject(c.claims, &(&1.source == :commencement and &1.attribute in [:date, :via]))
      }
  end

  @doc "A gap's class: dated via a pointer, or undated and why."
  @spec gap_class(map()) :: String.t()
  def gap_class(%{why: {:dated, _, via}}), do: "dated via #{via}"
  def gap_class(%{why: {:undated, why}}), do: "undated: #{why}"

  @doc """
  The gap tallies: the text changes; each class with its count, its text
  changes and those not in a Schedule or annex (where LAT holds no row);
  and, for each undated class, its amending laws by count.
  """
  @spec gap_tallies([map()]) :: map()
  def gap_tallies(gaps) do
    text = Enum.filter(gaps, &(&1.change.resolved.operation in @text_ops))
    on_rows = Enum.reject(text, &String.match?(&1.change.target, ~r/^(?:sch|annex)\./))

    %{
      text: length(text),
      classes:
        for {k, n} <- gaps |> Enum.frequencies_by(&gap_class/1) |> Enum.sort_by(&(-elem(&1, 1))) do
          {k, n, Enum.count(text, &(gap_class(&1) == k)),
           Enum.count(on_rows, &(gap_class(&1) == k))}
        end,
      amenders:
        for {k, gs} <-
              gaps |> Enum.reject(&match?({:dated, _, _}, &1.why)) |> Enum.group_by(&gap_class/1) do
          {k, gs |> Enum.frequencies_by(& &1.amender) |> Enum.sort_by(&(-elem(&1, 1)))}
        end
    }
  end

  # ── sample items ─────────────────────────────────────────────────────

  @doc "A sampled row, with the rules and words behind it."
  @spec row_item(map()) :: map()
  def row_item(r) do
    %{
      law: r.law,
      row: r.id,
      reader: %{
        outcome: r.outcome,
        full_from: r.full_from,
        partial_from: r.partial_from,
        entries:
          for(
            e <- (r.result && r.result.entries) || [],
            do: %{
              date: e.date,
              territory: e.territory,
              purposes: e.purposes,
              role: e.role,
              rule: rule(e.rule)
            }
          ),
        undated: for(u <- (r.result && r.result.undated) || [], do: rule(u))
      },
      feed: r.feed && %{first: elem(r.feed, 0), full: elem(r.feed, 1)},
      yardstick: r.yardstick
    }
  end

  @doc "A sampled gap, with the amending law's commencement at each provision it names."
  @spec gap_item(map()) :: map()
  def gap_item(g) do
    c = g.change
    rules = Map.get(g.commencement, g.amender, [])

    refs =
      case Change.values(c, :feed, :affecting) |> List.flatten() do
        [] -> Change.values(c, :markup, :affecting) |> List.flatten()
        feed -> feed
      end

    %{
      law: g.law,
      target: c.target,
      key: short(c.key),
      operation: c.resolved.operation,
      amending_law: g.amender,
      named_provisions: refs,
      gap_filler: inspect(g.why),
      at_each:
        for ref <- refs do
          r = AmendingLaw.commencement(rules, ref)

          %{
            ref: ref,
            full_from: r && r.full_from,
            rules:
              if(r,
                do: Enum.map(r.entries, &rule(&1.rule)) ++ Enum.map(r.undated, &rule/1),
                else: []
              )
          }
        end
    }
  end

  defp rule(%Rule{} = r) do
    %{
      text: Rule.to_text(r),
      source_law: r.source.law,
      source_ref: r.source.ref,
      words: r.source.text && String.slice(r.source.text, 0, 400)
    }
  end

  @doc "An effect id shortened (push protection)."
  @spec short(String.t()) :: String.t()
  def short("key-" <> hex), do: "key-…" <> String.slice(hex, -6, 6)
  def short(id), do: id
end

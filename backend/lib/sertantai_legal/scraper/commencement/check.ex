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

      %{
        law: law,
        id: id,
        outcome: outcome,
        result: result,
        full_from: result && result.full_from,
        partial_from: result && result.partial_from,
        feed: feed_at(feed, id)
      }
    end)
    |> Enum.map(&Map.put(&1, :yardstick, yardstick(&1)))
  end

  @doc "The law's own feed's coming-into-force records by target: `[target, first, full]` rows → `%{base_id => {first, full}}`."
  @spec feed_index([[term()]]) :: map()
  def feed_index(records),
    do:
      Map.new(records, fn [t, first, full] -> {t |> Ref.canonical() |> base(), {first, full}} end)

  @doc "How the reader's full date stands against the feed's."
  @spec yardstick(map()) :: atom()
  def yardstick(%{feed: nil, full_from: nil}), do: :neither
  def yardstick(%{feed: nil}), do: :own_only
  def yardstick(%{feed: {_, full}, full_from: full}) when full != nil, do: :agree
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
  defp feed_at(feed, id), do: Enum.find_value(LatRef.ancestors(id), &Map.get(feed, &1))

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

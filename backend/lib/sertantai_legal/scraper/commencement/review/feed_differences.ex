defmodule SertantaiLegal.Scraper.Commencement.FeedDifferences do
  @moduledoc """
  The two-way feed gate's groups (Jason 2026-11-21, Decision 5): every row
  where the commencement reader's reading (`Check.rows/5`) and the Feed
  reader's stored record of the law's own feed disagree — they date it
  differently (`differ`), only the feed dates it (`feed_only`), or the feed
  holds a partial stage where we read a full one (`feed_partial_only`) —
  grouped by the shape of its cause. Any law's feed is trusted, whatever
  its date, so a group names a misread on either side: ours (`fix:`), the
  Feed reader's (moved to it), legislation.gov.uk's own, or a yardstick
  difference (`known:`). Reviewed in `feed_differences.json`, as the
  leftovers and misreads are. Pure.
  """

  @kinds [:differ, :feed_only, :feed_partial_only]

  @type group :: %{
          rows: non_neg_integer(),
          laws: non_neg_integer(),
          by_law: %{String.t() => pos_integer()},
          examples: [map()]
        }

  @doc """
  A row's shape, or nil where the readings agree, the law has no feed
  record for it, or another law inserted it: an inserted provision is
  judged by its inserting law's commencement (`Check.inserted/3`,
  `inserted_groups/1`), never by the host law's own clause (Decision 7 C,
  Jason 2026-11-21).
  """
  @spec shape(map()) :: String.t() | nil
  def shape(%{inserted: true}), do: nil

  def shape(%{yardstick: kind} = row) when kind in @kinds,
    do: Enum.join([to_string(kind), own(row), relation(row)], " | ")

  def shape(_row), do: nil

  @doc """
  The inserted provisions' groups (`Check.inserted/3`), the widest first:
  each where the inserting law's commencement and the feed's record
  disagree, or one of them is missing, by how and why (`inserted |
  <yardstick> | ours <dated via …, or undated: why>`).
  """
  @spec inserted_groups([map()]) :: [{String.t(), group()}]
  def inserted_groups(items) do
    items
    |> Enum.reject(&(&1.yardstick in [:agree, :neither]))
    |> Enum.group_by(&inserted_shape/1)
    |> Enum.map(fn {shape, is} ->
      {shape,
       group(
         Enum.map(
           is,
           &%{law: &1.law, id: &1.id, partial_from: nil, full_from: ours(&1), feed: &1.feed}
         )
       )}
    end)
    |> Enum.sort_by(fn {shape, g} -> {-g.rows, shape} end)
  end

  defp inserted_shape(%{yardstick: y, ours: ours}),
    do: "inserted | #{y} | ours #{ours_class(ours)}"

  defp ours_class({:dated, _d, via}), do: "dated via #{via}"
  defp ours_class({:undated, why}), do: "undated: #{why}"

  defp ours(%{ours: {:dated, d, _}}), do: d
  defp ours(_item), do: nil

  # our outcome and the rule that decides it (its full date's, else the
  # first undated rule's)
  defp own(%{outcome: outcome} = row), do: "own #{outcome} by #{deciding(row)}"

  defp deciding(%{result: %{entries: entries, undated: undated}, full_from: full}) do
    full_entry = Enum.find(entries, &(&1.date == full)) || List.last(entries)

    case {full_entry, undated} do
      {%{rule: rule}, _} -> rule.treatment
      {nil, [rule | _]} -> rule.treatment
      _ -> "no rule"
    end
  end

  defp deciding(_row), do: "no rule"

  defp relation(%{yardstick: :differ, full_from: own, feed: {_first, full}}) do
    case Date.compare(own, full) do
      :lt -> "own earlier"
      :gt -> "own later"
    end
  end

  defp relation(%{yardstick: :feed_only, feed: {_first, nil}}), do: "feed partial"
  defp relation(%{yardstick: :feed_only}), do: "feed full"

  defp relation(%{yardstick: :feed_partial_only, feed: {first, nil}} = row) do
    if first == (row.partial_from || row.full_from), do: "first agrees", else: "first differs"
  end

  @doc """
  The rows' groups by shape, the widest first: rows, laws, every law with
  its rows (`by_law`: the step's work list holds every instance), and up to
  three examples from different laws (law, row, our dates, the feed's).
  """
  @spec groups([map()]) :: [{String.t(), group()}]
  def groups(rows) do
    rows
    |> Enum.map(&{shape(&1), &1})
    |> Enum.reject(&is_nil(elem(&1, 0)))
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {shape, rs} -> {shape, group(rs)} end)
    |> Enum.sort_by(fn {shape, g} -> {-g.rows, shape} end)
  end

  defp group(rs) do
    examples =
      rs
      |> Enum.uniq_by(& &1.law)
      |> Enum.take(3)
      |> Enum.map(fn r ->
        %{law: r.law, row: r.id, own: {r.partial_from, r.full_from}, feed: r.feed}
      end)

    by_law = Enum.frequencies_by(rs, & &1.law)
    %{rows: length(rs), laws: map_size(by_law), by_law: by_law, examples: examples}
  end

  @doc "The lines a check prints: each group with its status, then the count of groups with none."
  @spec summary([{String.t(), group()}], map()) :: [String.t()]
  def summary(groups, reviewed) do
    unreviewed = Enum.count(groups, fn {shape, _} -> not Map.has_key?(reviewed, shape) end)

    ["\ndifferences from the feed by cause (two-way gate): #{length(groups)} groups"] ++
      Enum.flat_map(groups, fn {shape, g} ->
        [
          "  #{g.rows} rows, #{g.laws} laws: #{shape} [#{Map.get(reviewed, shape, "no status")}]"
          | for(
              e <- g.examples,
              do: "      #{e.law} #{e.row} own #{inspect(e.own)} feed #{inspect(e.feed)}"
            )
        ]
      end) ++ ["feed difference groups with no status: #{unreviewed}"]
  end
end

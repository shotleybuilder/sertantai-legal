defmodule SertantaiLegal.Scraper.ChangeVocabulary.Parts do
  @moduledoc """
  A provision commenced through its parts (EUWA 2018 s.6: s.6(7) on
  2018-07-04, s.6(1)-(6) on 2020-12-31; OSRPA 1963 s.76): partly in force
  from the first part's commencement, fully once every part is — credited
  to the law of the last. Only for a provision with no full commencement of
  its own. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  Commencements of each provision in `bases` through its parts (`order`:
  the law's provisions as our rows name them).
  """
  @spec commencements([Change.t()], [String.t()], [String.t()]) :: [Change.t()]
  def commencements(changes, bases, order) do
    for base <- Enum.uniq(bases),
        not own_full?(changes, base),
        parts = Enum.filter(order, &(parent(&1) == base)) |> Enum.uniq(),
        parts != [],
        stages = Enum.map(parts, &stages(changes, &1)),
        Enum.any?(stages, &(&1 != [])),
        change <- parent_stages(base, stages),
        uniq: true,
        do: change
  end

  defp own_full?(changes, id),
    do:
      Enum.any?(changes, fn c ->
        c.target == id and c.resolved.operation == :commenced and not c.resolved.partial
      end)

  defp parent(ref), do: ref |> LatRef.ancestors() |> Enum.at(1)

  # a part's dated commencements: [{date, partial?, by}]
  defp stages(changes, part) do
    for c <- changes,
        c.target == part,
        c.resolved.operation == :commenced,
        c.resolved.date != nil,
        do: {c.resolved.date, c.resolved.partial, Change.credit(c), c.resolved.sources[:date]}
  end

  defp parent_stages(id, stages) do
    first = stages |> List.flatten() |> Enum.map(&elem(&1, 0)) |> Enum.min(Date)

    # each record's source: derived when any part stage on its own date is
    # (CV-S09 rounds 2–3: HSWA s.11's 1974 stages, all read from the order,
    # had read derived from a later-inserted part's feed stage)
    source = fn date ->
      stages
      |> List.flatten()
      |> Enum.filter(&(elem(&1, 0) == date))
      |> Enum.map(&elem(&1, 3))
      |> Enum.reject(&is_nil/1)
      |> Enum.find(:commencement, &(Evidence.tier(&1) == :derived))
    end

    fulls =
      Enum.map(stages, fn s ->
        s |> Enum.reject(&elem(&1, 1)) |> Enum.min_by(&elem(&1, 0), Date, fn -> nil end)
      end)

    partial = synthetic(id, first, true, nil, source.(first))

    case Enum.any?(fulls, &is_nil/1) do
      true ->
        [partial]

      false ->
        {date, _, by, _} = Enum.max_by(fulls, &elem(&1, 0), Date)

        if Date.compare(first, date) == :lt,
          do: [partial, synthetic(id, date, false, by, source.(date))],
          else: [synthetic(id, date, false, by, source.(date))]
    end
  end

  defp synthetic(id, date, partial?, by, source) do
    %Change{
      key: "parts:#{id}@#{date}",
      target: id,
      resolved: %Evidence.Resolved{
        operation: :commenced,
        level: :words,
        territory: nil,
        date: date,
        by: by,
        retained: false,
        partial: partial?,
        saved: false,
        sources: %{date: source, partial: source, commenced_by: source},
        tiers: Map.new(~w(date partial commenced_by)a, &{&1, Evidence.tier(source)})
      }
    }
  end
end

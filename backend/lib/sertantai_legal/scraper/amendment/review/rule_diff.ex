defmodule SertantaiLegal.Scraper.Amendment.Review.RuleDiff do
  @moduledoc """
  A reading's rules against the stored ones, field by field (Amending-law
  reader: review tooling; it replaces the hand-written `rule_diff.exs` and
  `classify.py`): the rules removed and added (compared as
  `Amendment.ReadReport` compares them), paired by amended law and source
  provision, each pair naming the fields that differ (targets, operation,
  level, treatment); a rule with no partner is `removed` or `added`. The
  pairs over a run group by field set, so one reader fix's reach reads as
  one group. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule

  @fields [:targets, :operation, :level, :treatment]

  @type pair :: %{
          amends: String.t(),
          source: String.t() | nil,
          fields: [atom()] | :removed | :added,
          before: Rule.t() | nil,
          after: Rule.t() | nil
        }

  @doc "The changed rules of one amending law: stored `old`, read `new`."
  @spec pairs([Rule.t()], [Rule.t()]) :: [pair()]
  def pairs(old, new) do
    gone = subtract(old, new)
    came = subtract(new, old)
    came_by = Enum.group_by(came, &place/1)

    {pairs, left} =
      Enum.map_reduce(gone, came_by, fn r, acc ->
        case Map.get(acc, place(r), []) do
          [a | rest] -> {pair(r, a), Map.put(acc, place(r), rest)}
          [] -> {pair(r, nil), acc}
        end
      end)

    pairs ++ for({_, rs} <- left, a <- rs, do: pair(nil, a))
  end

  @doc """
  A run's pairs (amending law → pairs) grouped by field set, as JSON-ready
  maps: each group's fields, count and pairs, the largest group first.
  """
  @spec grouped(%{String.t() => [pair()]}) :: [map()]
  def grouped(by_amending) do
    by_amending
    |> Enum.flat_map(fn {amending, ps} -> Enum.map(ps, &Map.put(&1, :amending, amending)) end)
    |> Enum.group_by(&name(&1.fields))
    |> Enum.map(fn {fields, ps} ->
      %{
        "fields" => fields,
        "count" => length(ps),
        "pairs" => ps |> Enum.sort_by(&order/1) |> Enum.map(&json/1)
      }
    end)
    |> Enum.sort_by(&{-&1["count"], &1["fields"]})
  end

  @doc "One line per group: its count and field set."
  @spec lines([map()]) :: [String.t()]
  def lines(groups),
    do: for(g <- groups, do: "#{String.pad_leading(to_string(g["count"]), 5)}  #{g["fields"]}")

  defp pair(before, after_) do
    r = before || after_

    %{
      amends: r.amends,
      source: r.source.ref,
      fields: fields(before, after_),
      before: before,
      after: after_
    }
  end

  defp fields(nil, _), do: :added
  defp fields(_, nil), do: :removed
  defp fields(b, a), do: Enum.filter(@fields, &(value(b, &1) != value(a, &1)))

  defp value(r, :targets), do: Enum.sort(r.targets)
  defp value(r, f), do: Map.fetch!(r, f)

  defp name(fields) when is_atom(fields), do: Atom.to_string(fields)
  defp name(fields), do: Enum.map_join(fields, "+", &Atom.to_string/1)

  defp place(%Rule{} = r), do: {r.amends, r.source.ref}

  defp key(%Rule{} = r),
    do: {r.amends, Enum.sort(r.targets), r.operation, r.level, r.source.ref, r.treatment}

  # the rules of `a` that `b` doesn't hold, counted as a multiset
  defp subtract(a, b) do
    {left, _} =
      Enum.reduce(a, {[], b |> Enum.map(&key/1) |> Enum.frequencies()}, fn r, {acc, counts} ->
        case Map.get(counts, key(r), 0) do
          0 -> {[r | acc], counts}
          n -> {acc, Map.put(counts, key(r), n - 1)}
        end
      end)

    Enum.reverse(left)
  end

  defp order(p), do: {p.amending, p.amends, p.source || ""}

  defp json(p) do
    %{
      "amending" => p.amending,
      "amends" => p.amends,
      "source" => p.source,
      "before" => rule(p.before),
      "after" => rule(p.after),
      "words" => text(p.before || p.after)
    }
  end

  defp rule(nil), do: nil

  defp rule(r),
    do: %{
      "targets" => Enum.sort(r.targets),
      "operation" => to_string(r.operation),
      "level" => to_string(r.level),
      "treatment" => to_string(r.treatment)
    }

  defp text(%Rule{source: %{text: t}}) when is_binary(t), do: String.slice(t, 0, 400)
  defp text(_), do: nil
end

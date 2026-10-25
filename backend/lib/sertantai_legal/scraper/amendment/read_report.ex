defmodule SertantaiLegal.Scraper.Amendment.ReadReport do
  @moduledoc """
  What a reading of an amending law changed against its stored rules (run
  time, 2026-10-25): the rules removed and added, counted per amended law,
  and the provisions behind them — the per-law trace done by hand after
  each read pass, as lines to read. A rule is compared by what it says
  (amended law, targets, operation, level, source provision, treatment),
  never its stored text. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule

  @type t :: %{
          before: non_neg_integer(),
          after: non_neg_integer(),
          removed: %{String.t() => pos_integer()},
          added: %{String.t() => pos_integer()},
          provisions: [String.t()]
        }

  @doc "The difference between an amending law's stored rules (`old`) and a new reading (`new`)."
  @spec diff([Rule.t()], [Rule.t()]) :: t()
  def diff(old, new) do
    o = old |> Enum.map(&key/1) |> Enum.frequencies()
    n = new |> Enum.map(&key/1) |> Enum.frequencies()
    gone = subtract(o, n)
    came = subtract(n, o)

    %{
      before: length(old),
      after: length(new),
      removed: per_law(gone),
      added: per_law(came),
      provisions:
        (Map.keys(gone) ++ Map.keys(came)) |> Enum.map(&elem(&1, 4)) |> Enum.uniq() |> Enum.sort()
    }
  end

  @doc "Whether the reading changed anything."
  @spec changed?(t()) :: boolean()
  def changed?(%{removed: r, added: a}), do: r != %{} or a != %{}

  @doc "The report line for `law` (none when unchanged)."
  @spec lines(String.t(), t()) :: [String.t()]
  def lines(law, diff) do
    if changed?(diff) do
      counts =
        Enum.map(Enum.sort(diff.removed), fn {l, c} -> "−#{c} #{l}" end) ++
          Enum.map(Enum.sort(diff.added), fn {l, c} -> "+#{c} #{l}" end)

      n = length(diff.provisions)
      shown = diff.provisions |> Enum.take(5) |> Enum.join(", ")
      more = if n > 5, do: ", …", else: ""

      [
        "#{law}: #{Enum.join(counts, ", ")} (#{n} provision#{if n == 1, do: "", else: "s"}: #{shown}#{more})"
      ]
    else
      []
    end
  end

  @doc "One line over a run's diffs (amending law → diff)."
  @spec summary(%{String.t() => t()}) :: String.t()
  def summary(diffs) do
    changed = Enum.count(diffs, fn {_, d} -> changed?(d) end)
    before = diffs |> Map.values() |> Enum.map(& &1.before) |> Enum.sum()
    after_ = diffs |> Map.values() |> Enum.map(& &1.after) |> Enum.sum()
    "#{map_size(diffs)} laws read, #{changed} changed; rules #{before} → #{after_}"
  end

  defp key(%Rule{} = r),
    do: {r.amends, Enum.sort(r.targets), r.operation, r.level, r.source.ref, r.treatment}

  defp subtract(a, b) do
    for {k, c} <- a, left = c - Map.get(b, k, 0), left > 0, into: %{}, do: {k, left}
  end

  defp per_law(keys) do
    Enum.reduce(keys, %{}, fn {{law, _, _, _, _, _}, c}, acc ->
      Map.update(acc, law, c, &(&1 + c))
    end)
  end
end

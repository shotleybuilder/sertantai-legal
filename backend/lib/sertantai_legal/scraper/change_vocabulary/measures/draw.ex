defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw do
  @moduledoc """
  The acceptance checks' sample draws (change vocabulary CV-S10), in one
  place so each is tested for reproducibility. Each check keeps the draw
  and seed it had, so a seed recorded in an earlier round draws the same
  sample:

  | check | seed | draw |
  |---|---|---|
  | feed, markup | `{s, s, s}` (default `{2026, 10, 22}` / `{2026, 10, 23}`) | `take_random/3` |
  | commencement | `{s, s, s}` (default `{2026, 10, 23}`) | `round_robin/3`, rows then gaps |
  | extent | `{s, 2, 3}` (default s = 1) | `equal_share/3`, laws then changes |
  | amending, merge, evidence | `{s, 6, 6}` | `shuffled/3` |
  | label | `{s, 9, 9}` | `shuffled/3` |

  `seed/1` seeds the process's generator; the draws after it use it in
  turn (a check drawing twice draws its second sample from where the
  first left the generator). Every draw puts its items in a stable order
  first, so the store's row order doesn't move the sample.
  """

  @doc "Seed this process's generator for the draws that follow."
  @spec seed({integer(), integer(), integer()}) :: :ok
  def seed(tuple) do
    :rand.seed(:exsss, tuple)
    :ok
  end

  @doc "`n` items at random (`Enum.take_random/2`), from a stable order by `key`."
  @spec take_random([term()], non_neg_integer(), (term() -> term())) :: [term()]
  def take_random(items, n, key), do: items |> Enum.sort_by(key) |> Enum.take_random(n)

  @doc "The first `n` of the items shuffled, from a stable order by `key`."
  @spec shuffled([term()], non_neg_integer(), (term() -> term())) :: [term()]
  def shuffled(items, n, key), do: items |> Enum.sort_by(key) |> Enum.shuffle() |> Enum.take(n)

  @doc """
  `n` items round-robin over the groups `by` gives (groups in a stable
  order), random within each. The items must already be in a stable order.
  """
  @spec round_robin([term()], (term() -> term()), non_neg_integer()) :: [term()]
  def round_robin(items, by, n) do
    items
    |> Enum.group_by(by)
    |> Enum.sort_by(&inspect(elem(&1, 0)))
    |> Enum.map(fn {_, xs} -> Enum.shuffle(xs) end)
    |> Stream.unfold(fn
      [] -> nil
      gs -> {Enum.map(gs, &hd/1), gs |> Enum.map(&tl/1) |> Enum.reject(&(&1 == []))}
    end)
    |> Enum.flat_map(& &1)
    |> Enum.take(n)
  end

  @doc """
  `n` items: an equal share of each kind `kind` gives, then the rest at
  random. The items must already be in a stable order.
  """
  @spec equal_share([term()], (term() -> term()), non_neg_integer()) :: [term()]
  def equal_share(items, kind, n) do
    groups = Enum.group_by(items, kind)
    share = max(div(n, max(map_size(groups), 1)), 1)

    first =
      groups
      |> Enum.sort()
      |> Enum.flat_map(fn {_, g} -> g |> Enum.shuffle() |> Enum.take(share) end)

    rest = (items -- first) |> Enum.shuffle() |> Enum.take(max(n - length(first), 0))
    Enum.take(first ++ rest, n)
  end
end

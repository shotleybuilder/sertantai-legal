defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.Bound do
  @moduledoc """
  The acceptance checks' pass bound (change vocabulary CV-S10): the exact
  one-sided upper confidence bound on a rate (Clopper–Pearson) from a
  checked sample of `n` items with `wrong` found wrong.

  The upper bound is the rate `p` at which seeing `wrong` or fewer in `n`
  has probability `1 - confidence`. A step passes when that bound is under
  its limit (2% of changes or rows, 5% of laws or pairs), so a clean
  sample has to be big enough: under 2% needs at least 149 clean items.

  Pure.
  """

  @doc """
  The upper bound on the wrong rate, as a fraction; `nil` for an empty
  sample.
  """
  @spec upper(non_neg_integer(), non_neg_integer(), float()) :: float() | nil
  def upper(wrong, n, confidence \\ 0.95)
  def upper(_wrong, 0, _confidence), do: nil
  def upper(n, n, _confidence), do: 1.0

  def upper(wrong, n, confidence) when wrong < n do
    alpha = 1 - confidence
    bisect(fn p -> at_most(wrong, n, p) > alpha end, 0.0, 1.0, 100)
  end

  @doc "Whether the upper bound is under `limit` (a fraction)."
  @spec passes?(non_neg_integer(), non_neg_integer(), float(), float()) :: boolean()
  def passes?(wrong, n, limit, confidence \\ 0.95) do
    case upper(wrong, n, confidence) do
      nil -> false
      bound -> bound < limit
    end
  end

  # P(X <= wrong) for X ~ Binomial(n, p), summing the terms upwards.
  defp at_most(wrong, n, p) do
    first = :math.pow(1 - p, n)

    {sum, _} =
      Enum.reduce(1..wrong//1, {first, first}, fn k, {sum, term} ->
        term = term * (n - k + 1) / k * p / (1 - p)
        {sum + term, term}
      end)

    sum
  end

  # The largest p in [lo, hi] for which below?(p) holds; below? is true
  # up to the bound and false after it.
  defp bisect(_below?, lo, _hi, 0), do: lo

  defp bisect(below?, lo, hi, steps) do
    mid = (lo + hi) / 2

    if below?.(mid),
      do: bisect(below?, mid, hi, steps - 1),
      else: bisect(below?, lo, mid, steps - 1)
  end
end

defmodule SertantaiLegal.Scraper.LabelTools.FamilyFold do
  @moduledoc """
  A family's laws folded several at once (#191, 2026-11-07), each through
  the fold cache (`LabelTools.FoldCache`), with the results in the laws'
  own order so every tool's output is the same as a fold one law at a
  time. How many at once is `LawRunner`'s guard's to say (memory, busy
  cores, no VM); a law that raises is its own `{:error, …}`.
  """

  alias SertantaiLegal.Scraper.LabelTools.FoldCache
  alias SertantaiLegal.Scraper.LawRunner

  @doc """
  `[{law, rows | {:error, why}}]` in `laws`' order. `opts`: `cache: false`
  (fold afresh, write nothing); `:workers`; `:fold` (law → result) in place
  of `FoldCache.rows/2`.
  """
  @spec rows([String.t()], keyword()) :: [{String.t(), [map()] | {:error, term()}}]
  def rows(laws, opts \\ []) do
    fold = Keyword.get(opts, :fold, &FoldCache.rows(&1, cache: Keyword.get(opts, :cache, true)))

    results =
      LawRunner.run(laws, fold, fn _, _ -> :ok end, Keyword.take(opts, [:workers]))

    case for(
           {law, {:error, {kind, _, why}}} <- results,
           kind in [:exception, :exit, :throw, :error],
           do: "#{law}: #{why}"
         ) do
      [] -> Enum.map(laws, &{&1, Map.fetch!(results, &1)})
      crashed -> raise "laws not folded: " <> Enum.join(crashed, "; ")
    end
  end
end

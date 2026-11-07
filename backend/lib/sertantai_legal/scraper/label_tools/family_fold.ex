defmodule SertantaiLegal.Scraper.LabelTools.FamilyFold do
  @moduledoc """
  A family's laws folded several at once (#191, 2026-11-07), each through
  the fold cache (`LabelTools.FoldCache`), with the results in the laws'
  own order so every tool's output is the same as a fold one law at a
  time. A fold travels back packed, so its rows still share one list of
  the law's changes. How many at once is `LawRunner`'s guard's to say (memory, busy
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
      LawRunner.run(laws, &ship(fold.(&1)), fn _, _ -> :ok end, Keyword.take(opts, [:workers]))

    case for(
           {law, {:error, {kind, _, why}}} <- results,
           kind in [:exception, :exit, :throw, :error],
           do: "#{law}: #{why}"
         ) do
      [] -> Enum.map(laws, &{&1, results |> Map.fetch!(&1) |> land()})
      crashed -> raise "laws not folded: " <> Enum.join(crashed, "; ")
    end
  end

  # a law's rows share its changes, and a message between processes copies
  # each row's own: the Merchant Shipping Act 1995's 3,492 rows × 5,565
  # changes took the machine's memory (the kernel's OOM killer, 2026-11-07).
  # So a fold travels packed, its changes once (`FoldCache.pack/1`), and is
  # unpacked, shared again, where it lands
  defp ship([%{changes: _} | _] = rows), do: FoldCache.pack(rows)
  defp ship(other), do: other

  defp land({:packed, _, _} = packed), do: FoldCache.unpack(packed)
  defp land(other), do: other
end

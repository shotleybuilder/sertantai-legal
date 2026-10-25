defmodule SertantaiLegal.Scraper.LawRunner do
  @moduledoc """
  Runs a function over laws, several at once (lat-refactor LR-31 A), for the
  corpus tasks (`mix lat.relabel`, `mix lat.wave_preview`).

  Laws are independent (LR-31 isolation check, 2026-10-16): each law's run
  writes only its own rows — `lat_change_log` and `lat_label_timeline`
  (delete + insert by `law_name`), its `lat_events`, its own
  `legal_register` row (lat stats triggers) — and reads no other law's
  freshly written data (amending laws come from the CLML store). The
  `legal_register` date-propagation triggers fire only on `md_date`, which
  no LAT path changes.

  Each law runs in its own task with its own DB connection (the pool must
  hold `workers`); an exception or exit in one law is that law's
  `{:error, …}` result and the run goes on. Results arrive as they finish
  (not in input order) and are handed to `on_result` in the caller's
  process, so report and done-file writes stay serial.

  How many at once is the machine's to say (`LawRunner.Guard`: memory,
  busy cores, no VM) unless the caller names `workers` (a `--workers N`
  choice): a 5-wide run once crashed the machine with a VM open, and the
  guard sat only in the tasks that called it (run time, 2026-10-25).
  """

  alias SertantaiLegal.Scraper.LawRunner.Guard

  @doc """
  `fun.(law)` for each law, `workers` at a time (`opts[:workers]`, else
  the guard's decision; one law runs alone without asking);
  `on_result.(law, result)` in the caller as each finishes. Returns the
  results by law.
  """
  @spec run([String.t()], (String.t() -> term()), (String.t(), term() -> any()), keyword()) ::
          %{String.t() => term()}
  def run(laws, fun, on_result, opts \\ []) do
    workers =
      case {Keyword.get(opts, :workers), laws} do
        {n, _} when is_integer(n) and n > 0 -> n
        {_, [_, _ | _]} -> Guard.workers()
        _ -> 1
      end

    laws
    |> Task.async_stream(fn law -> {law, safely(law, fun)} end,
      max_concurrency: workers,
      ordered: false,
      timeout: :infinity
    )
    |> Enum.reduce(%{}, fn {:ok, {law, result}}, acc ->
      on_result.(law, result)
      Map.put(acc, law, result)
    end)
  end

  defp safely(law, fun) do
    fun.(law)
  rescue
    e -> {:error, {:exception, law, Exception.message(e)}}
  catch
    kind, reason -> {:error, {kind, law, inspect(reason)}}
  end
end

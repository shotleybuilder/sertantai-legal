defmodule SertantaiLegal.Scraper.LabelRefresh do
  @moduledoc """
  After a LAT parse, the law's labels follow (lat-refactor LR-25): its change
  register (`ChangeCollector`: collect → fidelity gate → write) and then its
  label timeline (`LabelTimeline`: build → write). `LatStagedParser` calls
  `run/2` once the rows, notes and cause are persisted — the one parse path
  (LR-28) — so no parse leaves a stale register or timeline behind.

  Each write is one transaction per law, so a failure leaves the previous
  complete register or timeline. A failure doesn't fail the parse (the parse
  is valid on its own): it is recorded as a `labels_failed` lat_event with
  its reason, and the staleness check lists the law (its register is older
  than its parse). Thin orchestrator: the rules are the collectors' and
  `LabelProjection`'s.
  """

  require Logger

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeCollector, LabelProjection, LabelTimeline}

  @doc """
  Rebuild a law's register and timeline. `opts`: `parsed` — the parse's
  `%{rows, notes, effects}` (else the law is parsed from the store).
  """
  @spec run(String.t(), keyword()) :: :ok | {:error, term()}
  def run(law_name, opts \\ []) do
    with {:ok, %{records: by, per_row: per_row}} <-
           ChangeCollector.collect(law_name, Keyword.take(opts, [:parsed])),
         [] <- ChangeCollector.fidelity(by, per_row, ChangeCollector.db_order(law_name)),
         {:ok, _} <- ChangeCollector.write(law_name, by),
         %{periods: periods} <- LabelTimeline.build(law_name, LabelProjection.uk_today()),
         {:ok, _} <- LabelTimeline.write(law_name, periods, LabelTimeline.code_version()) do
      :ok
    else
      [_ | _] = diffs -> fail(law_name, {:fidelity, length(diffs)})
      {:error, reason} -> fail(law_name, reason)
    end
  rescue
    e -> fail(law_name, {:exception, Exception.message(e)})
  end

  defp fail(law_name, reason) do
    Logger.error("[LabelRefresh] #{law_name}: #{inspect(reason)}")
    record_failure(law_name, reason)
    {:error, reason}
  end

  @doc "Record a failed refresh as a `labels_failed` lat_event."
  @spec record_failure(String.t(), term()) :: :ok
  def record_failure(law_name, reason) do
    Repo.query!(
      """
      INSERT INTO lat_events (law_id, country, law_name, event, at, source, reason)
      SELECT id, country, name, 'labels_failed', now() AT TIME ZONE 'utc', 'label_refresh', $2
      FROM legal_register WHERE name = $1
      """,
      [law_name, inspect(reason)]
    )

    :ok
  end

  @doc "Delete a law's register and timeline (its LAT is discarded: `LatArchive`)."
  @spec discard(String.t()) :: :ok
  def discard(law_name) do
    for table <- ~w(lat_change_log lat_label_timeline),
        do: Repo.query!("DELETE FROM #{table} WHERE law_name = $1", [law_name])

    :ok
  end
end

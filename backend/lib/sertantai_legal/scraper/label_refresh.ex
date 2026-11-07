defmodule SertantaiLegal.Scraper.LabelRefresh do
  @moduledoc """
  After a LAT parse, the law's labels follow (lat-refactor LR-25): its change
  register (`ChangeCollector`: collect → fidelity gate → write) and then its
  label timeline (`LabelTimeline`: build → write) — for a family switched to
  the change vocabulary, its merged changes built and its timeline from them
  instead, the old register neither written nor read
  (`ChangeVocabulary.Build`, `LabelSwitch`; CV-06). `LatStagedParser` calls
  `run/2` once the rows, notes and cause are persisted — the one parse path
  (LR-28) — so no parse leaves a stale register or timeline behind.

  Each write is one transaction per law, so a failure leaves the previous
  complete register or timeline. A failure doesn't fail the parse (the parse
  is valid on its own): it is recorded as a `labels_failed` lat_event with
  its reason, and the staleness check lists the law (no `labels_refreshed`
  after its latest parse). Only this module writes the register and the
  timeline (`test/sertantai_legal/architecture/lat_write_path_test.exs`). Thin orchestrator: the rules are the collectors' and
  `LabelProjection`'s.
  """

  require Logger

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeCollector, LabelProjection, LabelTimeline, LabelVersion}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, LabelSwitch, Version}

  @doc """
  Rebuild a law's labels. A law in a switched family: its merged changes
  built and its timeline written from them, the known-limit rows keeping
  their stored periods; the old register is neither collected nor read
  (Maritime Safety: Switch-over, 2026-11-07: its fidelity gate had blocked
  the Merchant Shipping Act 1979's new labels). Any other law: its register
  and its timeline from it. `opts`: `parsed` — the parse's
  `%{rows, notes, effects}` (else the law is parsed from the store; the
  register path only).
  """
  @spec run(String.t(), keyword()) :: :ok | {:error, term()}
  def run(law_name, opts \\ []) do
    if LabelSwitch.switched?(law_name),
      do: run_switched(law_name),
      else: run_register(law_name, opts)
  rescue
    e -> fail(law_name, {:exception, Exception.message(e)})
  end

  # a switched family's law (CV-06): its merged changes, then its timeline
  # from them (`LabelSwitch.timeline/2`), the known limits keeping their label
  defp run_switched(law_name) do
    Build.law(law_name)

    with {:ok, periods} <- LabelSwitch.timeline(law_name, LabelSwitch.stored(law_name)),
         {:ok, _} <- LabelTimeline.write(law_name, periods, code_version(true)) do
      # no register records: the old register isn't written for it
      record_success(law_name, %{records: 0, periods: length(periods)})
    else
      {:error, reason} -> fail(law_name, reason)
    end
  end

  defp run_register(law_name, opts) do
    with {:ok, %{records: by, per_row: per_row}} <-
           ChangeCollector.collect(law_name, Keyword.take(opts, [:parsed])),
         [] <- ChangeCollector.fidelity(by, per_row, ChangeCollector.db_order(law_name)),
         {:ok, _} <- ChangeCollector.write(law_name, by),
         %{periods: periods} <- LabelTimeline.build(law_name, LabelProjection.uk_today()),
         {:ok, _} <- LabelTimeline.write(law_name, periods, code_version(false)) do
      record_success(law_name, %{
        records: by |> Map.values() |> Enum.map(&length/1) |> Enum.sum(),
        periods: length(periods)
      })
    else
      [_ | _] = diffs -> fail(law_name, {:fidelity, length(diffs)})
      {:error, reason} -> fail(law_name, reason)
    end
  end

  @doc """
  The code version stamped on a law's timeline: a switched law's is the
  change vocabulary's (`ChangeVocabulary.Version`), the code its labels are
  built by; any other law's is the register's (`LabelTimeline.code_version/0`).
  """
  @spec code_version(boolean()) :: String.t()
  def code_version(true), do: Version.current()
  def code_version(false), do: LabelTimeline.code_version()

  defp fail(law_name, reason) do
    Logger.error("[LabelRefresh] #{law_name}: #{inspect(reason)}")
    record_failure(law_name, reason)
    {:error, reason}
  end

  @doc """
  Record a refresh as a `labels_refreshed` lat_event: the labels version
  (`LabelVersion`) and the counts written, in `provenance`. The staleness
  check reads it: a law with no refresh after its latest parse, or one built
  by older label code, is stale.
  """
  @spec record_success(String.t(), %{records: non_neg_integer(), periods: non_neg_integer()}) ::
          :ok
  def record_success(law_name, %{records: records, periods: periods}) do
    Repo.query!(
      """
      INSERT INTO lat_events (law_id, country, law_name, event, at, source, provenance)
      SELECT id, country, name, 'labels_refreshed', now() AT TIME ZONE 'utc', 'label_refresh', $2
      FROM legal_register WHERE name = $1
      """,
      [law_name, %{labels_version: LabelVersion.current(), records: records, periods: periods}]
    )

    :ok
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

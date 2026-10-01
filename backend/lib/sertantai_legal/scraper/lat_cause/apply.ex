defmodule SertantaiLegal.Scraper.LatCause.Apply do
  @moduledoc """
  Gathers the facts around one LAT parse and records its cause (#167, L8.3)
  on the operation's `parsed` lat_event (`LatCause.decide/1`).

  `snapshot/1` runs before the persist (what the law held); `record/5` runs
  after the notes are persisted (what it holds now), so status and change_id
  evidence are both in place.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatCause, LatEvents}

  require Logger

  @type snapshot :: %{
          row_count: non_neg_integer(),
          lat_hash: String.t() | nil,
          statuses: %{String.t() => String.t() | nil},
          change_ids: MapSet.t(String.t()),
          last_source_hash: String.t() | nil,
          last_source_paths: [String.t()] | nil
        }

  @doc "What the law holds now (call before persisting a parse)."
  @spec snapshot(String.t()) :: snapshot()
  def snapshot(law_name) do
    %{rows: [[row_count, lat_hash]]} =
      Repo.query!(
        "SELECT (SELECT count(*) FROM legal_articles WHERE law_name = $1), (SELECT lat_hash FROM legal_register WHERE name = $1)",
        [law_name]
      )

    last =
      case Repo.query!(
             """
             SELECT source_hash, source_paths FROM lat_events
             WHERE law_name = $1 AND event = 'parsed' AND source_hash IS NOT NULL
             ORDER BY at DESC LIMIT 1
             """,
             [law_name]
           ) do
        %{rows: [[hash, paths]]} -> %{hash: hash, paths: paths}
        %{rows: []} -> %{hash: nil, paths: nil}
      end

    %{
      row_count: row_count,
      lat_hash: lat_hash,
      statuses: statuses(law_name),
      change_ids: change_ids(law_name),
      last_source_hash: last.hash,
      last_source_paths: last.paths
    }
  end

  @doc """
  Decide and record the cause of the parse whose `parsed` event has op_key
  `op_id`. `xmls`: the fetched documents; `paths`: their data.xml paths
  (`[]` when not fetched, e.g. a PDF transcript); `explicit`: a caller's
  `"correction"` / `"scope"`, else nil. Returns the cause.
  """
  @spec record(String.t(), String.t(), snapshot(), {[String.t()], [String.t()]}, String.t() | nil) ::
          String.t()
  def record(law_name, op_id, before, {xmls, paths}, explicit) do
    source_hash = LatCause.source_hash(xmls)
    after_statuses = statuses(law_name)

    %{rows: [[lat_hash]]} =
      Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [law_name])

    facts = %{
      first?: before.row_count == 0,
      explicit: explicit,
      scope_changed?:
        paths != [] and before.last_source_paths != nil and before.last_source_paths != paths,
      same_source?: source_hash != nil and source_hash == before.last_source_hash,
      new_change_ids?: not MapSet.subset?(change_ids(law_name), before.change_ids),
      status_changed?:
        Enum.any?(after_statuses, fn {sid, status} ->
          Map.has_key?(before.statuses, sid) and before.statuses[sid] != status
        end),
      content_changed?: lat_hash != before.lat_hash
    }

    cause = LatCause.decide(facts)

    Repo.query!(
      """
      UPDATE lat_events
      SET cause = $3, source_hash = $4, source_valid_date = $5, source_paths = $6
      WHERE law_name = $1 AND op_key = $2 AND event = 'parsed'
      """,
      [law_name, op_id, cause, source_hash, LatCause.valid_date(xmls), paths]
    )

    cause
  end

  @doc "`record/5`, logged and never failing the parse."
  @spec record_after_parse(
          String.t(),
          String.t(),
          snapshot(),
          {[String.t()], [String.t()]},
          String.t() | nil
        ) ::
          String.t() | nil
  def record_after_parse(law_name, op_id, before, sources, explicit) do
    cause = record(law_name, op_id, before, sources, explicit)
    Logger.info("[LatCause] #{law_name}: #{cause}")

    # The persist event fired at commit, before the cause was known: a second
    # event carries it, so a listener needn't race the manifest.
    {xmls, _paths} = sources

    LatEvents.notify(law_name, "cause", %{
      cause: cause,
      source_hash: LatCause.source_hash(xmls),
      source_valid_date: LatCause.valid_date(xmls)
    })

    cause
  rescue
    e ->
      Logger.warning("[LatCause] failed for #{law_name}: #{Exception.message(e)}")
      nil
  end

  defp statuses(law_name) do
    %{rows: rows} =
      Repo.query!("SELECT section_id, status FROM legal_articles WHERE law_name = $1", [law_name],
        timeout: :infinity
      )

    Map.new(rows, fn [sid, status] -> {sid, status} end)
  end

  defp change_ids(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT change_id FROM amendment_annotations WHERE law_name = $1 AND change_id IS NOT NULL",
        [law_name],
        timeout: :infinity
      )

    MapSet.new(rows, &hd/1)
  end
end

defmodule SertantaiLegal.Scraper.LabelStaleness do
  @moduledoc """
  Why a law's LAT or labels are stale (lat-refactor LR-25), from its latest
  lat_events. Pure: the facts are read by `facts/0`, the reasons decided
  here.

  - `:no_parse_event` — the law holds LAT but no `parsed` event
  - `:parser_version` — parsed by other parser code (`ParserVersion`), or
    before versions were recorded: re-parse
  - `:labels_behind_parse` — no `labels_refreshed` since the latest parse
  - `:labels_version` — labels built by other label code (`LabelVersion`):
    `mix lat.relabel`
  - `:labels_failed` — the latest refresh failed (`labels_failed` after the
    latest parse and refresh)

  A law in a switched family (`LabelSwitch`) is labelled from its merged
  changes, so `:labels_version` (the old path's code) is not its reason;
  instead (#193: OH&S's labels sat stale from 2026-11-02 while its changes
  were rebuilt, and nothing said so):

  - `:timeline_version` — refreshed by other change-vocabulary code
    (`ChangeVocabulary.Version`, recorded on `labels_refreshed`), or before
    it was recorded
  - `:labels_behind_changes` — the changes were built again
    (`changes_built`) after the latest refresh

  A law with no reasons is fresh. `mix lat.stale` reports them; 0 stale is
  part of every wave's verification.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelVersion, ParserVersion}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelSwitch, Version}

  @type facts :: %{
          parsed_at: NaiveDateTime.t() | nil,
          parser_version: String.t() | nil,
          refreshed_at: NaiveDateTime.t() | nil,
          labels_version: String.t() | nil,
          failed_at: NaiveDateTime.t() | nil,
          switched: boolean(),
          changes_version: String.t() | nil,
          built_at: NaiveDateTime.t() | nil
        }

  @type current :: %{parser: String.t(), labels: String.t(), changes: String.t()}

  @type reason ::
          :no_parse_event
          | :parser_version
          | :labels_behind_parse
          | :labels_version
          | :labels_failed
          | :timeline_version
          | :labels_behind_changes

  @doc "The versions now: the parser's, the old label path's, the change vocabulary's."
  @spec current() :: current()
  def current,
    do: %{
      parser: ParserVersion.current(),
      labels: LabelVersion.current(),
      changes: Version.current()
    }

  @doc "The reasons a law is stale (empty: fresh), against the versions now (`current/0`)."
  @spec reasons(facts(), current()) :: [reason()]
  def reasons(f, current) do
    refreshed = f.refreshed_at != nil

    [
      {:no_parse_event, is_nil(f.parsed_at)},
      {:parser_version, f.parsed_at != nil and f.parser_version != current.parser},
      {:labels_behind_parse, behind?(f.refreshed_at, f.parsed_at)},
      {:labels_version, not f.switched and refreshed and f.labels_version != current.labels},
      {:timeline_version, f.switched and refreshed and f.changes_version != current.changes},
      {:labels_behind_changes, f.switched and refreshed and before?(f.refreshed_at, f.built_at)},
      {:labels_failed,
       f.failed_at != nil and after_all?(f.failed_at, [f.parsed_at, f.refreshed_at])}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp behind?(nil, _parsed), do: true
  defp behind?(_refreshed, nil), do: false
  defp behind?(refreshed, parsed), do: NaiveDateTime.compare(refreshed, parsed) == :lt

  defp before?(_t, nil), do: false
  defp before?(t, other), do: NaiveDateTime.compare(t, other) == :lt

  defp after_all?(t, others),
    do: Enum.all?(others, &(is_nil(&1) or NaiveDateTime.compare(t, &1) == :gt))

  @doc """
  Each law holding LAT, with its latest parse, refresh, failure and change
  build, and whether its family is switched (DB).
  """
  @spec facts() :: [{String.t(), facts()}]
  def facts do
    %{rows: rows} =
      Repo.query!(
        """
        WITH laws AS (SELECT DISTINCT law_name FROM legal_articles),
        latest AS (
          SELECT DISTINCT ON (law_name, event) law_name, event, at, parser_version,
                 provenance->>'labels_version' AS labels_version,
                 provenance->>'changes_version' AS changes_version
          FROM lat_events
          WHERE event IN ('parsed', 'labels_refreshed', 'labels_failed', 'changes_built')
          ORDER BY law_name, event, at DESC, id DESC
        )
        SELECT l.law_name, p.at, p.parser_version, r.at, r.labels_version, f.at,
               r.changes_version, b.at,
               (SELECT family FROM uk_lrt u WHERE u.name = l.law_name AND u.family IS NOT NULL LIMIT 1)
        FROM laws l
        LEFT JOIN latest p ON p.law_name = l.law_name AND p.event = 'parsed'
        LEFT JOIN latest r ON r.law_name = l.law_name AND r.event = 'labels_refreshed'
        LEFT JOIN latest f ON f.law_name = l.law_name AND f.event = 'labels_failed'
        LEFT JOIN latest b ON b.law_name = l.law_name AND b.event = 'changes_built'
        ORDER BY 1
        """,
        [],
        timeout: :infinity
      )

    families = LabelSwitch.families()
    for [law | row] <- rows, do: {law, fact(row, families)}
  end

  defp fact([parsed_at, pv, refreshed_at, lv, failed_at, cv, built_at, family], families) do
    %{
      parsed_at: parsed_at,
      parser_version: pv,
      refreshed_at: refreshed_at,
      labels_version: lv,
      failed_at: failed_at,
      switched: LabelSwitch.family_in?(family, families),
      changes_version: cv,
      built_at: built_at
    }
  end
end

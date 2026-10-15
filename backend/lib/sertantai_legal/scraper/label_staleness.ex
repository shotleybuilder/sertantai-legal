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

  A law with no reasons is fresh. `mix lat.stale` reports them; 0 stale is
  part of every wave's verification.
  """

  alias SertantaiLegal.Repo

  @type facts :: %{
          parsed_at: NaiveDateTime.t() | nil,
          parser_version: String.t() | nil,
          refreshed_at: NaiveDateTime.t() | nil,
          labels_version: String.t() | nil,
          failed_at: NaiveDateTime.t() | nil
        }

  @type reason ::
          :no_parse_event
          | :parser_version
          | :labels_behind_parse
          | :labels_version
          | :labels_failed

  @doc "The reasons a law is stale (empty: fresh). `current`: `%{parser:, labels:}` versions."
  @spec reasons(facts(), %{parser: String.t(), labels: String.t()}) :: [reason()]
  def reasons(f, current) do
    [
      {:no_parse_event, is_nil(f.parsed_at)},
      {:parser_version, f.parsed_at != nil and f.parser_version != current.parser},
      {:labels_behind_parse, behind?(f.refreshed_at, f.parsed_at)},
      {:labels_version, f.refreshed_at != nil and f.labels_version != current.labels},
      {:labels_failed,
       f.failed_at != nil and after_all?(f.failed_at, [f.parsed_at, f.refreshed_at])}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp behind?(nil, _parsed), do: true
  defp behind?(_refreshed, nil), do: false
  defp behind?(refreshed, parsed), do: NaiveDateTime.compare(refreshed, parsed) == :lt

  defp after_all?(t, others),
    do: Enum.all?(others, &(is_nil(&1) or NaiveDateTime.compare(t, &1) == :gt))

  @doc "Each law holding LAT, with its latest parse, refresh and failure (DB)."
  @spec facts() :: [{String.t(), facts()}]
  def facts do
    %{rows: rows} =
      Repo.query!(
        """
        WITH laws AS (SELECT DISTINCT law_name FROM legal_articles),
        latest AS (
          SELECT DISTINCT ON (law_name, event) law_name, event, at, parser_version,
                 provenance->>'labels_version' AS labels_version
          FROM lat_events
          WHERE event IN ('parsed', 'labels_refreshed', 'labels_failed')
          ORDER BY law_name, event, at DESC, id DESC
        )
        SELECT l.law_name, p.at, p.parser_version, r.at, r.labels_version, f.at
        FROM laws l
        LEFT JOIN latest p ON p.law_name = l.law_name AND p.event = 'parsed'
        LEFT JOIN latest r ON r.law_name = l.law_name AND r.event = 'labels_refreshed'
        LEFT JOIN latest f ON f.law_name = l.law_name AND f.event = 'labels_failed'
        ORDER BY 1
        """,
        [],
        timeout: :infinity
      )

    for [law, parsed_at, pv, refreshed_at, lv, failed_at] <- rows,
        do:
          {law,
           %{
             parsed_at: parsed_at,
             parser_version: pv,
             refreshed_at: refreshed_at,
             labels_version: lv,
             failed_at: failed_at
           }}
  end
end

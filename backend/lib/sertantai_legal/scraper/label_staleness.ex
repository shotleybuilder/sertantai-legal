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

  A law in a switched family (`LabelSwitch`) is labelled by the fold from
  its stored changes, so `:labels_version` (the old path's code) is not its
  reason; instead (#193: OH&S's labels sat stale from 2026-11-02 while its
  changes were rebuilt, and nothing said so; #194: by the labels stage's
  own code and inputs, so a rebuild giving the same changes stales none):

  - `:fold_version` — folded by other fold code (`FoldVersion`, recorded
    on `labels_refreshed`), or before it was recorded
  - `:labels_behind_changes` — the latest build's output digest
    (`changes_digest` on `changes_built`) is not the one the labels were
    folded from, or none was recorded
  - `:fold_inputs` — the fold's other inputs (`FoldInputs`: rows, register
    record, CLML body, known limits) moved since the refresh, or were not
    recorded

  A law with no reasons is fresh. `mix lat.stale` reports them; 0 stale is
  part of every wave's verification.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LabelVersion, ParserVersion}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{FoldInputs, FoldVersion, LabelSwitch}

  @type facts :: %{
          parsed_at: NaiveDateTime.t() | nil,
          parser_version: String.t() | nil,
          refreshed_at: NaiveDateTime.t() | nil,
          labels_version: String.t() | nil,
          failed_at: NaiveDateTime.t() | nil,
          switched: boolean(),
          fold_version: String.t() | nil,
          folded_digest: String.t() | nil,
          fold_inputs: String.t() | nil,
          fold_inputs_now: String.t() | nil,
          built_at: NaiveDateTime.t() | nil,
          built_digest: String.t() | nil
        }

  @type current :: %{parser: String.t(), labels: String.t(), fold: String.t()}

  @type reason ::
          :no_parse_event
          | :parser_version
          | :labels_behind_parse
          | :labels_version
          | :labels_failed
          | :fold_version
          | :labels_behind_changes
          | :fold_inputs

  @doc "The versions now: the parser's, the old label path's, the fold's."
  @spec current() :: current()
  def current,
    do: %{
      parser: ParserVersion.current(),
      labels: LabelVersion.current(),
      fold: FoldVersion.current()
    }

  @doc "The reasons a law is stale (empty: fresh), against the versions now (`current/0`)."
  @spec reasons(facts(), current()) :: [reason()]
  def reasons(f, current) do
    refreshed = f.refreshed_at != nil

    [
      {:no_parse_event, is_nil(f.parsed_at)},
      {:parser_version, f.parsed_at != nil and f.parser_version != current.parser},
      {:labels_behind_parse, behind?(f.refreshed_at, f.parsed_at)},
      {:labels_version, not f.switched and refreshed and f.labels_version != current.labels}
    ]
    |> Enum.concat(fold_reasons(f.switched and refreshed, f, current))
    |> Enum.concat([
      {:labels_failed,
       f.failed_at != nil and after_all?(f.failed_at, [f.parsed_at, f.refreshed_at])}
    ])
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  # the labels stage's own reasons: a switched law's, once refreshed (#194)
  defp fold_reasons(false, _f, _current), do: []

  defp fold_reasons(true, f, current),
    do: [
      {:fold_version, f.fold_version != current.fold},
      {:labels_behind_changes, behind_changes?(f)},
      {:fold_inputs, moved?(f.fold_inputs, f.fold_inputs_now)}
    ]

  defp behind?(nil, _parsed), do: true
  defp behind?(_refreshed, nil), do: false
  defp behind?(refreshed, parsed), do: NaiveDateTime.compare(refreshed, parsed) == :lt

  # a law never built has no changes to be behind; one folded before
  # digests were recorded is behind (#194)
  defp behind_changes?(%{built_at: nil}), do: false
  defp behind_changes?(f), do: moved?(f.folded_digest, f.built_digest)

  defp moved?(nil, _now), do: true
  defp moved?(recorded, now), do: recorded != now

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
                 provenance->>'fold_version' AS fold_version,
                 provenance->>'changes_digest' AS changes_digest,
                 provenance->>'fold_inputs' AS fold_inputs
          FROM lat_events
          WHERE event IN ('parsed', 'labels_refreshed', 'labels_failed', 'changes_built')
          ORDER BY law_name, event, at DESC, id DESC
        )
        SELECT l.law_name, p.at, p.parser_version, r.at, r.labels_version, f.at,
               r.fold_version, r.changes_digest, r.fold_inputs, b.at, b.changes_digest,
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
    for [law | row] <- rows, do: {law, fact({law, row}, families)}
  end

  defp fact({law, [parsed_at, pv, refreshed_at, lv, failed_at | fold]}, families) do
    [fv, folded, inputs, built_at, built_digest, family] = fold
    switched = LabelSwitch.family_in?(family, families)

    %{
      parsed_at: parsed_at,
      parser_version: pv,
      refreshed_at: refreshed_at,
      labels_version: lv,
      failed_at: failed_at,
      switched: switched,
      fold_version: fv,
      folded_digest: folded,
      fold_inputs: inputs,
      # read now only where the labels stage applies
      fold_inputs_now: if(switched, do: FoldInputs.of(law)),
      built_at: built_at,
      built_digest: built_digest
    }
  end
end

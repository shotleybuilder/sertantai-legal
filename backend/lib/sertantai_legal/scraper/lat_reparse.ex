defmodule SertantaiLegal.Scraper.LatReparse do
  @moduledoc """
  Gated batch re-parse of LAT (Gemini review 2026-09-26): re-parse laws
  through the normal pipeline while proving provision enrichment survives.

  For a batch:
  1. snapshot the laws' `legal_articles` and `control_mappings` rows into
     `<snapshot>` / `<snapshot>_cm` (rollback source)
  2. re-parse each law (`LatStagedParser.parse/2` by default), which persists
     through `LatPersister`'s merge and enrichment gate
  3. record per law: rows and enriched rows before/after, carried, renamed,
     changed, ambiguous, dropped, orphaned mappings
  4. stop at the first law that errors (a failed gate keeps its old LAT);
     a law with no XML body (queued to the PDF backlog) is recorded, not a stop

  `older_format_laws/0` lists laws whose stored sort_keys predate the current
  key format — the ones a re-parse fixes.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatMerge, LatParser, LatStagedParser, LawRunner}
  alias SertantaiLegal.Scraper.LatPersister.Carry

  require Logger

  @type law_report :: %{
          law_name: String.t(),
          rows_before: non_neg_integer(),
          rows_after: non_neg_integer(),
          enriched_before: non_neg_integer(),
          enriched_after: non_neg_integer(),
          carried: non_neg_integer(),
          renamed: non_neg_integer(),
          changed: non_neg_integer(),
          ambiguous: non_neg_integer(),
          dropped: non_neg_integer(),
          orphaned_mappings: non_neg_integer(),
          error: String.t() | nil
        }

  @doc "Laws with any stored sort_key not in the current 23-segment format."
  @spec older_format_laws() :: [String.t()]
  def older_format_laws do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name FROM legal_articles
        GROUP BY law_name
        HAVING bool_or(array_length(string_to_array(split_part(sort_key, '~', 1), '.'), 1) <> 23)
        ORDER BY law_name
        """,
        [],
        timeout: 120_000
      )

    Enum.map(rows, &hd/1)
  end

  @doc "Laws with any provision carrying fractalaw enrichment."
  @spec enriched_laws() :: [String.t()]
  def enriched_laws do
    %{rows: rows} =
      Repo.query!(
        "SELECT DISTINCT law_name FROM legal_articles WHERE taxa_enriched_at IS NOT NULL OR drrp_types IS NOT NULL",
        [],
        timeout: 120_000
      )

    Enum.map(rows, &hd/1)
  end

  @doc """
  Snapshot, then re-parse `laws` in order. Options: `snapshot` (table name,
  required), `parse_fn` (`law_name -> {:ok, result}`; default
  `LatStagedParser.parse/2`), `force` (bypass the enrichment gate — for
  laws whose loss has been accepted), `cause` (`"correction"` / `"scope"`,
  recorded on each parse's lat_event; #167), `on_law` (callback per law report),
  `workers` (laws at once, default 1; LR-38).

  With several workers (`LawRunner`; laws are independent, LR-31) the
  contract holds: on the first error or failed gate no new law starts; laws
  already in flight finish; laws never started are `skipped`. Reports are in
  input order; `status` names the first failing law in input order.
  """
  @spec run([String.t()], keyword()) :: %{
          status: :ok | {:stopped, String.t()},
          laws: [law_report()],
          skipped: [String.t()]
        }
  def run(laws, opts) do
    table = Keyword.fetch!(opts, :snapshot)
    force = Keyword.get(opts, :force, false)
    cause = Keyword.get(opts, :cause)
    store = Keyword.get(opts, :store)

    parse_fn =
      Keyword.get(
        opts,
        :parse_fn,
        &LatStagedParser.parse(&1, force: force, cause: cause, store: store)
      )

    on_law = Keyword.get(opts, :on_law, fn _ -> :ok end)

    snapshot!(laws, table)

    case Keyword.get(opts, :workers, 1) do
      1 -> sequential(laws, parse_fn, on_law)
      workers -> parallel(laws, parse_fn, on_law, workers)
    end
  end

  defp sequential(laws, parse_fn, on_law) do
    Enum.reduce_while(laws, %{status: :ok, laws: [], skipped: []}, fn law, acc ->
      report = reparse_one(law, parse_fn)
      on_law.(report)
      acc = %{acc | laws: acc.laws ++ [report]}

      if failed?(report),
        do:
          {:halt,
           %{acc | status: {:stopped, law}, skipped: Enum.drop_while(laws, &(&1 != law)) |> tl()}},
        else: {:cont, acc}
    end)
  end

  # LR-38: laws `workers` at a time; a failure stops new laws starting
  defp parallel(laws, parse_fn, on_law, workers) do
    stop = :atomics.new(1, [])

    run_one = fn law ->
      if :atomics.get(stop, 1) == 1 do
        :skipped
      else
        report =
          try do
            reparse_one(law, parse_fn)
          rescue
            e -> %{law_name: law, error: Exception.message(e)}
          end

        if failed?(report), do: :atomics.put(stop, 1, 1)
        report
      end
    end

    results =
      LawRunner.run(
        laws,
        run_one,
        fn
          _law, :skipped -> :ok
          law, {:error, reason} -> on_law.(%{law_name: law, error: inspect(reason)})
          _law, report -> on_law.(report)
        end,
        workers: workers
      )

    reports =
      for law <- laws, r = results[law], r != :skipped do
        case r do
          {:error, reason} ->
            %{law_name: law, error: inspect(reason)}

          report ->
            report
        end
      end

    %{
      status:
        case Enum.find(reports, &failed?/1) do
          nil -> :ok
          r -> {:stopped, r.law_name}
        end,
      laws: reports,
      skipped: for(law <- laws, results[law] == :skipped, do: law)
    }
  end

  # an error stops the run, except a law with no XML body (queued to the
  # PDF backlog: an expected outcome)
  defp failed?(report), do: report.error != nil and not pdf_only?(report.error)

  @doc """
  Dry run for one law: fetch and parse (`rows_fn`, default
  `LatStagedParser.fetch_rows/1`), plan the merge against the stored rows,
  and count what would happen to enriched rows. Nothing is persisted.
  """
  @spec preview(String.t(), (String.t() -> {:ok, [map()], String.t()} | {:error, term()})) ::
          map()
  def preview(law, rows_fn \\ &LatStagedParser.fetch_rows/1) do
    case rows_fn.(law) do
      # as LatPersister refuses it: the stored LAT would be kept
      {:ok, [], _law_id} ->
        %{law_name: law, error: "no LAT rows in the parse (document without a body?)"}

      {:ok, rows, law_id} ->
        maps = LatParser.to_insert_maps(rows, law_id)
        existing = Carry.load_existing(law, Carry.carried_columns(Map.keys(hd(maps))))
        plan = LatMerge.plan(existing, maps)
        enriched = existing |> Enum.filter(&enriched?/1) |> MapSet.new(& &1.section_id)
        carried_old = plan.carry |> Map.values() |> MapSet.new()
        count = &Enum.count(&1, fn id -> MapSet.member?(enriched, id) end)

        %{
          law_name: law,
          rows_before: length(existing),
          rows_after: length(maps),
          enriched: MapSet.size(enriched),
          enriched_carried: count.(MapSet.to_list(carried_old)),
          enriched_changed: count.(plan.changed),
          enriched_dropped: count.(plan.removed),
          enriched_ambiguous: count.(plan.ambiguous),
          lost_unchanged: length(plan.lost_unchanged),
          renamed: Enum.count(plan.renames, &(&1.old != &1.new)),
          error: nil
        }

      {:error, reason} ->
        %{law_name: law, error: to_string(reason)}
    end
  end

  # The same "enriched" notion as counts/1: fractalaw taxa present.
  defp enriched?(%{values: v}), do: not is_nil(v[:taxa_enriched_at]) or not is_nil(v[:drrp_types])

  # A law with no XML body is queued to the PDF backlog by the parser: an
  # expected outcome, not a failure — record it and carry on.
  defp pdf_only?(error), do: String.contains?(error, "no XML body")

  defp reparse_one(law, parse_fn) do
    {rows_before, enriched_before} = counts(law)

    {stats, error} =
      case parse_fn.(law) do
        {:ok, %{has_errors: false, lat: lat}} -> {lat, nil}
        {:ok, %{error: error, lat: lat}} -> {lat, error}
        {:ok, %{lat: lat} = r} -> {lat, r[:error] || "parse failed"}
        {:error, reason} -> {%{}, to_string(reason)}
      end

    {rows_after, enriched_after} = counts(law)

    %{
      law_name: law,
      rows_before: rows_before,
      rows_after: rows_after,
      enriched_before: enriched_before,
      enriched_after: enriched_after,
      carried: Map.get(stats, :carried, 0),
      renamed: Map.get(stats, :renamed, 0),
      changed: Map.get(stats, :changed, 0),
      ambiguous: Map.get(stats, :ambiguous, 0),
      dropped: Map.get(stats, :dropped, 0),
      orphaned_mappings: Map.get(stats, :orphaned_mappings, 0),
      error: error
    }
  end

  defp counts(law) do
    %{rows: [[rows, enriched]]} =
      Repo.query!(
        "SELECT count(*), count(*) FILTER (WHERE taxa_enriched_at IS NOT NULL OR drrp_types IS NOT NULL) FROM legal_articles WHERE law_name = $1",
        [law]
      )

    {rows, enriched}
  end

  defp snapshot!(laws, table) do
    unless Regex.match?(~r/^[a-z_][a-z0-9_]*$/, table),
      do: raise(ArgumentError, "invalid snapshot table name: #{table}")

    Repo.transaction(fn ->
      Repo.query!(
        "CREATE TABLE IF NOT EXISTS #{table} AS SELECT * FROM legal_articles WHERE false"
      )

      Repo.query!(
        "CREATE TABLE IF NOT EXISTS #{table}_cm AS SELECT * FROM control_mappings WHERE false"
      )

      Repo.query!("INSERT INTO #{table} SELECT * FROM legal_articles WHERE law_name = ANY($1)", [
        laws
      ])

      Repo.query!(
        "INSERT INTO #{table}_cm SELECT * FROM control_mappings WHERE law_name = ANY($1)",
        [
          laws
        ]
      )
    end)

    Logger.info("[LatReparse] snapshot #{table}: #{length(laws)} laws")
  end
end

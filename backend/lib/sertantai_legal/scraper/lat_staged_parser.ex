defmodule SertantaiLegal.Scraper.LatStagedParser do
  @moduledoc """
  Staged LAT parser with SSE progress callbacks.

  Decomposes `LatReparser.reparse/1` into 5 stages with progress events
  suitable for streaming via Server-Sent Events.

  ## Stages
  1. `fetch_body`          - Fetch body XML from legislation.gov.uk
  2. `parse_lat`           - Parse XML into LAT rows (LatParser)
  3. `persist_lat`         - DELETE+INSERT LAT rows (LatPersister)
  4. `parse_annotations`   - Parse Commentaries block (CommentaryParser)
  5. `persist_annotations` - DELETE+INSERT annotations (CommentaryPersister)

  ## Progress Events
  Same protocol as `StagedParser`:
  - `{:stage_start, stage, stage_num, total}`
  - `{:stage_complete, stage, :ok | :error, summary}`
  - `{:parse_complete, has_errors}`
  """

  alias SertantaiLegal.Scraper.{LatParser, LatPersister, CommentaryParser, CommentaryPersister}
  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.PdfBacklog
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Repo

  @stages [:fetch_body, :parse_lat, :persist_lat, :parse_annotations, :persist_annotations]
  @total_stages length(@stages)

  @type stage ::
          :fetch_body | :parse_lat | :persist_lat | :parse_annotations | :persist_annotations
  @type progress_event ::
          {:stage_start, stage(), integer(), integer()}
          | {:stage_complete, stage(), :ok | :error, String.t() | nil}
          | {:parse_complete, boolean()}

  @doc "Returns the list of stage atoms."
  def stages, do: @stages

  @doc """
  Parse a single law's LAT data through all 5 stages.

  ## Options
  - `on_progress` — `(progress_event -> :ok | :abort)` callback for SSE streaming
  - `pdf_backlog_dir` — where to queue PDFs of no-body laws (see `PdfBacklog`)

  A law whose body XML yields no LAT rows (a scanned-PDF-only law) is not
  persisted — its existing LAT is kept — and its PDF alternatives are
  downloaded to the PDF backlog. The result then has `has_errors: true` and
  `pdf_backlog: [file]`.

  ## Returns
  `{:ok, result}` where result contains:
  - `law_name` — the law name
  - `lat` — `%{inserted: N, deleted: N}` or `%{inserted: 0, deleted: 0, error: reason}`
  - `annotations` — `%{inserted: N}` or `%{inserted: 0, error: reason}`
  - `duration_ms` — total parse time
  - `has_errors` — boolean
  """
  @spec parse(String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def parse(law_name, opts \\ []) when is_binary(law_name) do
    on_progress = Keyword.get(opts, :on_progress)
    start = System.monotonic_time(:millisecond)

    with {:ok, {type_code, slash_path}} <- parse_law_name(law_name),
         {:ok, law_id} <- lookup_law_id(law_name) do
      do_parse(law_name, type_code, slash_path, law_id, opts, start)
    else
      {:error, reason} ->
        notify(on_progress, {:parse_complete, true})
        {:error, reason}
    end
  end

  defp do_parse(law_name, type_code, slash_path, law_id, opts, start) do
    on_progress = Keyword.get(opts, :on_progress)

    # Stage 1: Fetch body XML
    notify(on_progress, {:stage_start, :fetch_body, 1, @total_stages})

    case fetch_body_xml(slash_path) do
      {:ok, body_xml} ->
        notify(on_progress, {:stage_complete, :fetch_body, :ok, "XML fetched"})
        do_run_stages(law_name, type_code, law_id, body_xml, opts, start)

      {:error, reason} ->
        notify(on_progress, {:stage_complete, :fetch_body, :error, reason})
        duration_ms = System.monotonic_time(:millisecond) - start
        notify(on_progress, {:parse_complete, true})

        {:ok,
         %{
           law_name: law_name,
           lat: %{inserted: 0, deleted: 0, error: reason},
           annotations: %{inserted: 0},
           duration_ms: duration_ms,
           has_errors: true,
           error: "fetch_body: #{reason}"
         }}
    end
  end

  @doc """
  Run stages 2–5 (parse LAT, persist LAT, parse and persist annotations) on
  an already-fetched body. Public so the stage logic can be tested with a
  fixture body. Options: `on_progress`, as for `parse/2`.

  When the LAT persist fails, the annotation stages are **skipped** (reported
  as `:skipped`), because annotations without their LAT rows are orphans.
  Any stage error sets `has_errors: true` and `error: "<stage>: <reason>"`.
  """
  @spec run_stages(String.t(), String.t(), String.t(), String.t(), keyword()) :: {:ok, map()}
  def run_stages(law_name, type_code, law_id, body_xml, opts \\ []) do
    start = System.monotonic_time(:millisecond)
    do_run_stages(law_name, type_code, law_id, body_xml, opts, start)
  end

  @doc """
  How a parse result should be recorded on its LAT session record:
  `{:parsed, result}` only when no stage failed; otherwise `{:failed, error}`.
  """
  @spec record_outcome(map()) :: {:parsed, map()} | {:failed, String.t()}
  def record_outcome(%{has_errors: false} = result), do: {:parsed, result}
  def record_outcome(result), do: {:failed, result[:error] || "parse failed"}

  defp do_run_stages(law_name, type_code, law_id, body_xml, opts, start) do
    on_progress = Keyword.get(opts, :on_progress)

    # Stage 2: Parse LAT rows
    notify(on_progress, {:stage_start, :parse_lat, 2, @total_stages})

    case LatParser.parse(body_xml, %{law_name: law_name, type_code: type_code}) do
      [] ->
        no_body(law_name, body_xml, opts, start)

      lat_rows ->
        notify(on_progress, {:stage_complete, :parse_lat, :ok, "#{length(lat_rows)} rows"})
        persist_stages(law_name, law_id, body_xml, lat_rows, on_progress, start)
    end
  end

  defp persist_stages(law_name, law_id, body_xml, lat_rows, on_progress, start) do
    # Stage 3: Persist LAT
    notify(on_progress, {:stage_start, :persist_lat, 3, @total_stages})

    {lat_result, lat_error} =
      case LatPersister.persist(lat_rows, law_name, law_id) do
        {:ok, result} ->
          notify(
            on_progress,
            {:stage_complete, :persist_lat, :ok,
             "#{result.inserted} inserted, #{result.deleted} deleted"}
          )

          {result, false}

        {:error, reason} ->
          notify(on_progress, {:stage_complete, :persist_lat, :error, reason})
          {%{inserted: 0, deleted: 0, error: reason}, true}
      end

    {annotation_result, ann_error} =
      if lat_error do
        skip_annotations(on_progress)
      else
        run_annotation_stages(law_name, law_id, body_xml, lat_rows, on_progress)
      end

    duration_ms = System.monotonic_time(:millisecond) - start
    has_errors = lat_error or ann_error
    notify(on_progress, {:parse_complete, has_errors})

    {:ok,
     %{
       law_name: law_name,
       lat: lat_result,
       annotations: annotation_result,
       duration_ms: duration_ms,
       has_errors: has_errors
     }
     |> put_error(lat_result, annotation_result)}
  end

  # No LAT rows means no XML body (typically a scanned-PDF-only law). Never
  # persist an empty parse — it would wipe the law's existing LAT. Queue any
  # PDF alternatives to the backlog for the manual OCR batch (#165).
  defp no_body(law_name, body_xml, opts, start) do
    on_progress = Keyword.get(opts, :on_progress)

    {reason, files} =
      PdfBacklog.queue_from_body(law_name, body_xml, dir: Keyword.get(opts, :pdf_backlog_dir))

    notify(on_progress, {:stage_complete, :parse_lat, :error, reason})

    for {stage, n} <- [persist_lat: 3, parse_annotations: 4, persist_annotations: 5] do
      notify(on_progress, {:stage_start, stage, n, @total_stages})
      notify(on_progress, {:stage_complete, stage, :skipped, "skipped: no LAT rows"})
    end

    notify(on_progress, {:parse_complete, true})

    {:ok,
     %{
       law_name: law_name,
       lat: %{inserted: 0, deleted: 0, error: reason},
       annotations: %{inserted: 0, skipped: true},
       duration_ms: System.monotonic_time(:millisecond) - start,
       has_errors: true,
       error: "parse_lat: #{reason}",
       pdf_backlog: files
     }}
  end

  defp put_error(result, %{error: reason}, _ann),
    do: Map.put(result, :error, "LAT persist: #{reason}")

  defp put_error(result, _lat, %{error: reason}),
    do: Map.put(result, :error, "annotations persist: #{reason}")

  defp put_error(result, _lat, _ann), do: result

  defp skip_annotations(on_progress) do
    reason = "skipped: LAT persist failed"
    notify(on_progress, {:stage_start, :parse_annotations, 4, @total_stages})
    notify(on_progress, {:stage_complete, :parse_annotations, :skipped, reason})
    notify(on_progress, {:stage_start, :persist_annotations, 5, @total_stages})
    notify(on_progress, {:stage_complete, :persist_annotations, :skipped, reason})
    {%{inserted: 0, skipped: true}, false}
  end

  defp run_annotation_stages(law_name, law_id, body_xml, lat_rows, on_progress) do
    # Stage 4: Parse annotations
    notify(on_progress, {:stage_start, :parse_annotations, 4, @total_stages})
    ref_to_sections = CommentaryParser.build_ref_to_sections(lat_rows)
    annotations = CommentaryParser.parse(body_xml, %{law_name: law_name}, ref_to_sections)

    notify(
      on_progress,
      {:stage_complete, :parse_annotations, :ok, "#{length(annotations)} annotations"}
    )

    # Stage 5: Persist annotations
    notify(on_progress, {:stage_start, :persist_annotations, 5, @total_stages})

    case CommentaryPersister.persist(annotations, law_name, law_id) do
      {:ok, result} ->
        notify(
          on_progress,
          {:stage_complete, :persist_annotations, :ok, "#{result.inserted} inserted"}
        )

        {result, false}

      {:error, reason} ->
        notify(on_progress, {:stage_complete, :persist_annotations, :error, reason})
        {%{inserted: 0, error: reason}, true}
    end
  end

  defp notify(nil, _event), do: :ok
  defp notify(callback, event) when is_function(callback, 1), do: callback.(event)

  # ── Helpers (same as LatReparser) ──────────────────────────────

  defp parse_law_name(law_name) do
    slash_path = IdField.normalize_to_slash_format(law_name)

    case String.split(slash_path, "/") do
      [type_code, _year, _number] ->
        {:ok, {type_code, slash_path}}

      _ ->
        {:error, "Invalid law_name format: #{law_name}"}
    end
  end

  defp lookup_law_id(law_name) do
    case Repo.query("SELECT id::text FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      {:ok, %{rows: [[id]]}} -> {:ok, id}
      {:ok, %{rows: []}} -> {:error, "Law not found in uk_lrt: #{law_name}"}
      {:error, err} -> {:error, "DB error: #{inspect(err)}"}
    end
  end

  defp fetch_body_xml(slash_path) do
    path = "/#{slash_path}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} -> {:ok, xml}
      {:ok, :html, _html} -> {:error, "Received HTML instead of XML for #{path}"}
      {:error, _code, reason} -> {:error, "Failed to fetch body XML: #{reason}"}
    end
  end
end

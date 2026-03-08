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
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Repo

  require Logger

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
      do_parse(law_name, type_code, slash_path, law_id, on_progress, start)
    else
      {:error, reason} ->
        notify(on_progress, {:parse_complete, true})
        {:error, reason}
    end
  end

  defp do_parse(law_name, type_code, slash_path, law_id, on_progress, start) do
    # Stage 1: Fetch body XML
    notify(on_progress, {:stage_start, :fetch_body, 1, @total_stages})

    case fetch_body_xml(slash_path) do
      {:ok, body_xml} ->
        notify(on_progress, {:stage_complete, :fetch_body, :ok, "XML fetched"})
        do_parse_stages(law_name, type_code, law_id, body_xml, on_progress, start)

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
           has_errors: true
         }}
    end
  end

  defp do_parse_stages(law_name, type_code, law_id, body_xml, on_progress, start) do
    # Stage 2: Parse LAT rows
    notify(on_progress, {:stage_start, :parse_lat, 2, @total_stages})
    lat_rows = LatParser.parse(body_xml, %{law_name: law_name, type_code: type_code})
    notify(on_progress, {:stage_complete, :parse_lat, :ok, "#{length(lat_rows)} rows"})

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

    {annotation_result, ann_error} =
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
     }}
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

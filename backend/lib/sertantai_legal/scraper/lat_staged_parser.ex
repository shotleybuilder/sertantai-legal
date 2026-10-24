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
  5. `persist_annotations` - DELETE+INSERT annotations (CommentaryPersister,
     which then refreshes per-row status and change fields, #167)

  ## Progress Events
  Same protocol as `StagedParser`:
  - `{:stage_start, stage, stage_num, total}`
  - `{:stage_complete, stage, :ok | :error, summary}`
  - `{:parse_complete, has_errors}`
  """

  require Logger
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  alias SertantaiLegal.Scraper.{
    LatParser,
    LatPersister,
    LatScope,
    CommentaryParser,
    CommentaryPersister,
    LabelRefresh,
    LatCause
  }

  alias SertantaiLegal.Scraper.LegislationGovUk.{Client, ClmlStore}
  alias SertantaiLegal.Scraper.PdfBacklog
  alias SertantaiLegal.Scraper.PdfBacklog.Batch
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Scraper.LawTerritory
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
  - `force` — persist even if `LatPersister`'s enrichment gate fails
  - `store` — local CLML store mode (#175, `Client.fetch_xml/2`): `:prefer`
    reuses a fresh stored copy, `:only` never fetches, `:refresh` always
    fetches; default `:write` fetches live and stores the result

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

    scope = LatScope.get(law_name)
    opts = Keyword.put(opts, :cut, body_cut(slash_path, scope))

    case if(LatScope.excluded?(scope),
           do: :excluded,
           else: fetch_xmls(slash_path, scope, store_opts(law_name, opts))
         )
         |> backlog_fallback(law_name, opts) do
      :excluded ->
        # #166: the law is excluded from LAT (no EHS link); nothing is fetched
        # or written, so no parse path brings its body back
        reason = "excluded from LAT (lat_scope, #166)"
        notify(on_progress, {:stage_complete, :fetch_body, :error, reason})
        notify(on_progress, {:parse_complete, true})

        {:ok,
         %{
           law_name: law_name,
           lat: %{inserted: 0, deleted: 0, error: reason},
           annotations: %{inserted: 0},
           duration_ms: System.monotonic_time(:millisecond) - start,
           has_errors: true,
           error: reason
         }}

      {:ok, xmls} ->
        notify(on_progress, {:stage_complete, :fetch_body, :ok, "XML fetched (#{length(xmls)})"})
        # the fetched paths: a change between parses is a scope change (#167)
        opts = Keyword.put(opts, :source_paths, LatScope.paths(slash_path, scope))
        do_run_stages(law_name, type_code, law_id, xmls, opts, start)

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
  Fetch and parse a law's body into LAT rows without persisting anything
  (for previews such as `LatReparse.preview/2`).
  """
  @spec fetch_rows(String.t(), keyword()) :: {:ok, [map()], String.t()} | {:error, String.t()}
  def fetch_rows(law_name, opts \\ []) do
    with {:ok, {type_code, slash_path}} <- parse_law_name(law_name),
         cut = body_cut(slash_path, LatScope.get(law_name)),
         {:ok, xmls, law_id} <- fetch_docs(law_name, opts) do
      {:ok, parse_rows(xmls, law_name, type_code, law_effects(law_name, opts), cut), law_id}
    end
  end

  @doc """
  A law's parsed rows, its notes (each with `effect_ids`,
  `CommentaryParser.with_effects/3`) and its effects, without persisting
  anything (LR-07: `mix lat.change_diff`). Options as for `fetch_rows/2`.
  """
  @spec fetch_changes(String.t(), keyword()) ::
          {:ok, %{rows: [map()], notes: [map()], effects: [ChangesFeed.Effect.t()]}}
          | {:error, String.t()}
  def fetch_changes(law_name, opts \\ []) do
    with {:ok, {type_code, slash_path}} <- parse_law_name(law_name),
         cut = body_cut(slash_path, LatScope.get(law_name)),
         {:ok, xmls, _law_id} <- fetch_docs(law_name, opts) do
      effects = law_effects(law_name, opts) || []
      rows = parse_rows(xmls, law_name, type_code, effects, cut)

      notes =
        xmls
        |> parse_annotations(law_name, rows, cut)
        |> CommentaryParser.with_effects(rows, effects)

      {:ok, %{rows: rows, notes: notes, effects: effects}}
    end
  end

  @doc """
  Fetch a law's documents without parsing: the body, or one document per
  scoped fragment (#166). Options as for `fetch_rows/2` (`store:`).
  """
  @spec fetch_docs(String.t(), keyword()) ::
          {:ok, [String.t()], String.t()} | {:error, String.t()}
  def fetch_docs(law_name, opts \\ []) do
    with {:ok, {_type_code, slash_path}} <- parse_law_name(law_name),
         {:ok, law_id} <- lookup_law_id(law_name),
         {:ok, xmls} <-
           fetch_xmls(slash_path, LatScope.get(law_name), store_opts(law_name, opts)) do
      {:ok, with_backlog(law_name, xmls, backlog_dir: Keyword.get(opts, :backlog_dir)), law_id}
    end
  end

  # the parse path reads a PDF-only law's transcript too (LR-06: wave 4 met
  # 1979/791 here, after LR-05 had covered only fetch_docs/2)
  defp backlog_fallback({:ok, xmls}, law_name, opts),
    do: {:ok, with_backlog(law_name, xmls, backlog_dir: Keyword.get(opts, :backlog_dir))}

  defp backlog_fallback(other, _law_name, _opts), do: other

  @doc """
  A law legislation.gov.uk serves without a body (a PDF-only law: metadata
  only, NumberOfProvisions="0") whose LAT came from a PDF backlog transcript
  reads that transcript's CLML (`PdfBacklog.Batch.clml/2`): a re-parse must
  reproduce the stored LAT, never an empty one (1979/791, LR-05). Else the
  documents as fetched. `opts`: `dir` / `backlog_dir`, the backlog directory.
  """
  @spec with_backlog(String.t(), [String.t()], keyword()) :: [String.t()]
  def with_backlog(law_name, xmls, opts \\ []) do
    dir = Keyword.get(opts, :dir) || Keyword.get(opts, :backlog_dir)

    if Enum.all?(xmls, &(not Regex.match?(~r/<(Body|EUBody|Schedules)[\s>]/, &1))) do
      case Batch.clml(law_name, if(dir, do: [dir: dir], else: [])) do
        {:ok, xml} -> [xml]
        :none -> xmls
      end
    else
      xmls
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
    # a whole body in hand for a scoped law is cut to its fragments
    opts = Keyword.put_new_lazy(opts, :cut, fn -> fragments(LatScope.get(law_name)) end)
    do_run_stages(law_name, type_code, law_id, body_xml, opts, start)
  end

  @doc """
  How a parse result should be recorded on its LAT session record:
  `{:parsed, result}` only when no stage failed; otherwise `{:failed, error}`.
  """
  @spec record_outcome(map()) :: {:parsed, map()} | {:failed, String.t()}
  def record_outcome(%{has_errors: false} = result), do: {:parsed, result}
  def record_outcome(result), do: {:failed, result[:error] || "parse failed"}

  # `xmls`: the body, or one document per scoped fragment (#166, LatScope).
  defp do_run_stages(law_name, type_code, law_id, body_xml, opts, start)
       when is_binary(body_xml),
       do: do_run_stages(law_name, type_code, law_id, [body_xml], opts, start)

  defp do_run_stages(law_name, type_code, law_id, xmls, opts, start) do
    on_progress = Keyword.get(opts, :on_progress)

    # Stage 2: Parse LAT rows
    notify(on_progress, {:stage_start, :parse_lat, 2, @total_stages})

    # fetched once: the rows' territory (LR-03) and the notes' effects (LR-07)
    effects = law_effects(law_name, opts)

    case parse_rows(xmls, law_name, type_code, effects, opts[:cut]) do
      [] ->
        no_body(law_name, hd(xmls), opts, start)

      lat_rows ->
        notify(on_progress, {:stage_complete, :parse_lat, :ok, "#{length(lat_rows)} rows"})

        persist_stages(
          law_name,
          law_id,
          xmls,
          lat_rows,
          Keyword.put(opts, :effects, effects),
          start
        )
    end
  end

  @doc """
  A law's annotations from its documents and parsed LAT rows (stage 4):
  placed on the rows that cite them; per document and renumbered when scoped.
  """
  @spec parse_annotations([String.t()], String.t(), [map()], [String.t()] | nil) :: [map()]
  def parse_annotations(xmls, law_name, lat_rows, cut \\ nil)

  # a body cut to a scope (CV-S05 F): only the notes on the rows kept
  def parse_annotations(xmls, law_name, lat_rows, [_ | _]) do
    xmls
    |> parse_annotations(law_name, lat_rows, nil)
    |> Enum.filter(& &1.affected_sections)
  end

  def parse_annotations(xmls, law_name, lat_rows, nil) do
    ref_to_sections = CommentaryParser.build_ref_to_sections(lat_rows)

    case xmls do
      [xml] ->
        CommentaryParser.parse(xml, %{law_name: law_name}, ref_to_sections)

      fragments ->
        fragments
        |> Enum.flat_map(&CommentaryParser.parse(&1, %{law_name: law_name}, ref_to_sections))
        |> CommentaryParser.renumber(law_name)
    end
  end

  defp parse_rows(xmls, law_name, type_code, effects, cut) do
    xmls
    |> Enum.map(
      &LatParser.parse(&1, %{law_name: law_name, type_code: type_code, effects: effects})
    )
    |> Enum.reject(&(&1 == []))
    |> case do
      [] -> []
      lists -> LatScope.merge(lists)
    end
    |> then(&if(cut, do: LatScope.cut(&1, cut), else: &1))
  end

  # A scoped law whose body is held reads the body, cut to its fragments: a
  # fragment is never fetched beside the whole text (CV-S05 F). The
  # fragments to cut to, else nil.
  defp body_cut(slash_path, scope) do
    if fragments(scope) && body_held?(slash_path), do: fragments(scope)
  end

  defp fragments(%{"fragments" => [_ | _] = fragments}), do: fragments
  defp fragments(_scope), do: nil

  defp body_held?(slash_path),
    do: match?({:ok, _, _}, ClmlStore.get("/#{slash_path}/body/data.xml"))

  defp persist_stages(law_name, law_id, xmls, lat_rows, opts, start) do
    on_progress = Keyword.get(opts, :on_progress)

    # Stage 3: Persist LAT
    notify(on_progress, {:stage_start, :persist_lat, 3, @total_stages})

    # what the law held, for this parse's cause (#167, LatCause)
    before = LatCause.Apply.snapshot(law_name)

    {lat_result, lat_error} =
      case LatPersister.persist(lat_rows, law_name, law_id,
             force: Keyword.get(opts, :force, false)
           ) do
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

    {annotation_result, ann_error, annotations} =
      if lat_error do
        skip_annotations(on_progress)
      else
        run_annotation_stages(
          law_name,
          law_id,
          xmls,
          lat_rows,
          on_progress,
          opts[:effects] || [],
          opts[:cut]
        )
      end

    # After the notes (and their status/change_id refresh): why the LAT changed.
    cause =
      unless lat_error,
        do:
          LatCause.Apply.record_after_parse(
            law_name,
            lat_result,
            before,
            {xmls, Keyword.get(opts, :source_paths, [])},
            Keyword.get(opts, :cause)
          )

    # LR-25: the law's change register and label timeline follow its parse
    labels =
      cond do
        lat_error or ann_error ->
          :skipped

        Keyword.get(opts, :labels, true) == false ->
          :skipped

        true ->
          LabelRefresh.run(law_name,
            parsed: %{rows: lat_rows, notes: annotations, effects: opts[:effects] || []}
          )
      end

    duration_ms = System.monotonic_time(:millisecond) - start
    has_errors = lat_error or ann_error
    notify(on_progress, {:parse_complete, has_errors})

    {:ok,
     %{
       law_name: law_name,
       lat: lat_result,
       annotations: annotation_result,
       cause: cause,
       labels: labels,
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
    {%{inserted: 0, skipped: true}, false, []}
  end

  defp run_annotation_stages(law_name, law_id, xmls, lat_rows, on_progress, effects, cut) do
    # Stage 4: Parse annotations (per document when scoped), each with the
    # effects behind it (LR-07)
    notify(on_progress, {:stage_start, :parse_annotations, 4, @total_stages})

    annotations =
      xmls
      |> parse_annotations(law_name, lat_rows, cut)
      |> CommentaryParser.with_effects(lat_rows, effects)

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

        {result, false, annotations}

      {:error, reason} ->
        notify(on_progress, {:stage_complete, :persist_annotations, :error, reason})
        {%{inserted: 0, error: reason}, true, annotations}
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

  # The law's effects (changes feed, LR-03) for territory the markup lacks:
  # `opts[:effects]` when given (tests), else the feed through the local
  # store in the same mode as the law's documents; markup only when
  # unavailable or switched off (`config :lat_effects`, false in tests).
  @doc false
  def law_effects(law_name, opts) do
    cond do
      Keyword.has_key?(opts, :effects) ->
        opts[:effects]

      not Application.get_env(:sertantai_legal, :lat_effects, true) ->
        []

      true ->
        [_uk, type, year, number] = String.split(law_name, "_", parts: 4)
        mode = Keyword.get(opts, :store, :write)

        case ChangesFeed.fetch(type, year, number, store: mode) do
          {:ok, effects} ->
            with_affecting_territory(effects, law_name)

          {:error, reason} ->
            Logger.warning("[LatStagedParser] #{law_name}: no effects (#{reason}): markup only")
            []
        end
    end
  end

  # V1-04: each effect's affecting-law territory (`LawTerritory`), from the
  # register's title and extent for that law — one query for the law's
  # affecting laws; a law the register doesn't hold has its type's only
  @doc false
  def with_affecting_territory([], _law_name), do: []

  def with_affecting_territory(effects, law_name) do
    laws = effects |> Enum.map(& &1.affecting) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    %{rows: rows} =
      Repo.query!("SELECT name, title_en, geo_extent FROM uk_lrt WHERE name = ANY($1)", [laws])

    extents = Map.new(rows, fn [name, title, geo] -> {name, LawTerritory.extent(title, geo)} end)

    Enum.map(effects, fn
      %{affecting: nil} = e ->
        e

      e ->
        %{
          e
          | affecting_territory:
              LawTerritory.territory(e.affecting, Map.get(extents, e.affecting), law_name)
        }
    end)
  end

  # Client store options for a law (#175): the mode, and the law's latest
  # known dct:valid for the freshness check
  @doc false
  def store_opts(law_name, opts) do
    case Keyword.get(opts, :store) do
      mode when mode in [:prefer, :only, :refresh] ->
        %{rows: rows} =
          Repo.query!(
            "SELECT md_dct_valid_date FROM legal_register WHERE country = 'uk' AND name = $1",
            [law_name]
          )

        [store: mode, law_valid: rows |> List.flatten() |> List.first()]

      _ ->
        []
    end
  end

  # The body, or each scoped fragment (all must fetch)
  defp fetch_xmls(slash_path, scope, store_opts) do
    slash_path
    |> LatScope.fetch_paths(scope, body_cut(slash_path, scope) != nil)
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, acc} ->
      case fetch_xml(path, store_opts) do
        {:ok, xml} -> {:cont, {:ok, acc ++ [xml]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp fetch_xml(path, store_opts) do
    case Client.fetch_xml(path, store_opts) do
      {:ok, xml} -> {:ok, xml}
      {:ok, :html, _html} -> {:error, "Received HTML instead of XML for #{path}"}
      {:error, _code, reason} -> {:error, "Failed to fetch body XML: #{reason}"}
    end
  end
end

defmodule SertantaiLegal.Scraper.StagedParser do
  @moduledoc """
  Staged parser for UK legislation metadata.

  Parses legislation in seven defined stages:
  1. **Metadata** - Basic metadata from introduction XML (title, dates, SI codes, subjects)
  2. **Extent** - Geographic extent from contents XML (E+W+S+NI)
  3. **Enacted_by** - Enacting parent laws from introduction/made XML
  4. **Amending** - Laws this law amends/rescinds (outgoing amendments)
  5. **Amended_by** - Laws that amend/rescind this law (incoming amendments)
  6. **Repeal/Revoke** - Repeal/revocation status and relationships
  7. **Taxa** - Actor, duty type, and POPIMAR classification

  Each stage is independent and reports its own success/error status,
  allowing partial results when some stages fail. The amending and amended_by
  stages can be re-run independently for cascade updates.

  ## Usage

      # Parse a single record with all stages
      {:ok, result} = StagedParser.parse(%{type_code: "uksi", Year: 2024, Number: "1001"})

      # Result structure:
      %{
        record: %{...merged data...},
        stages: %{
          metadata: %{status: :ok, data: %{...}},
          extent: %{status: :ok, data: %{...}},
          enacted_by: %{status: :ok, data: %{...}},
          amending: %{status: :ok, data: %{...}},
          amended_by: %{status: :error, error: "...", data: nil},
          repeal_revoke: %{status: :ok, data: %{...}},
          taxa: %{status: :ok, data: %{...}}
        },
        errors: ["amended_by: HTTP 404..."],
        has_errors: true
      }
  """

  import SweetXml

  alias SertantaiLegal.Legal.UkLrt
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Scraper.CommentaryParser
  alias SertantaiLegal.Scraper.CommentaryPersister
  alias SertantaiLegal.Scraper.LatParser
  alias SertantaiLegal.Scraper.LatPersister
  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.Amending
  alias SertantaiLegal.Scraper.EnactedBy
  alias SertantaiLegal.Scraper.Metadata
  alias SertantaiLegal.Scraper.ParsedLaw
  alias SertantaiLegal.Scraper.TaxaParser
  alias SertantaiLegal.Legal.Taxa.MakingDetector

  @stages [:metadata, :extent, :enacted_by, :amending, :amended_by, :repeal_revoke, :taxa]

  # Live status codes (matching legl conventions)
  @live_in_force "✔ In force"
  @live_part_revoked "⭕ Part Revocation / Repeal"
  @live_revoked "❌ Revoked / Repealed / Abolished"

  require Logger

  # Telemetry event names
  @telemetry_parse_complete [:staged_parser, :parse, :complete]
  @telemetry_stage_complete [:staged_parser, :stage, :complete]

  @type stage ::
          :metadata | :extent | :enacted_by | :amending | :amended_by | :repeal_revoke | :taxa
  @type stage_result :: %{
          status: :ok | :error | :skipped,
          data: map() | nil,
          error: String.t() | nil
        }
  @type parse_result :: %{
          record: map(),
          stages: %{stage() => stage_result()},
          errors: list(String.t()),
          has_errors: boolean()
        }

  @typedoc """
  Progress event types for streaming progress updates.
  """
  @type progress_event ::
          {:stage_start, stage(), integer(), integer()}
          | {:stage_complete, stage(), :ok | :error | :skipped, String.t() | nil}
          | {:parse_complete, boolean()}

  @doc """
  Parse a law record through all stages.

  ## Parameters
  - record: Map with :type_code, :Year, :Number keys
  - opts: Options
    - :stages - List of stages to run (default: all)
    - :skip_on_error - Skip remaining stages if one fails (default: false)
    - :on_progress - Callback function receiving progress events (optional)
      Callback signature: `(progress_event()) -> :ok | :abort`
      Return `:abort` to cancel parsing (e.g., when SSE client disconnects).
      Remaining stages will be marked as skipped with "Cancelled by client".

  ## Returns
  `{:ok, parse_result}` with merged data and per-stage status.
  Result includes `cancelled: true` if parsing was aborted.

  ## Performance Note

  Taxa stage runs in parallel with the sequential stage chain to optimize
  large law parsing. Taxa has no dependencies on other stages, so it can
  safely execute concurrently. This reduces total parse time from ~38s to ~25s
  for large laws like Climate Change Act 2008.
  """
  @spec parse(map(), keyword()) :: {:ok, parse_result()}
  def parse(record, opts \\ []) do
    parse_start_time = System.monotonic_time(:microsecond)

    stages_to_run = Keyword.get(opts, :stages, @stages)
    skip_on_error = Keyword.get(opts, :skip_on_error, false)
    on_progress = Keyword.get(opts, :on_progress)

    # Build law identifiers
    type_code = record[:type_code] || record["type_code"]
    year = record[:Year] || record["Year"]
    number = record[:Number] || record["Number"]
    name = "#{type_code}/#{year}/#{number}"

    IO.puts("\n=== STAGED PARSE: #{name} ===")

    # Initialize result with ParsedLaw struct for type safety and normalized keys
    # The input record is normalized via from_map, then we add the computed name
    initial_law = record |> Map.put(:name, name) |> ParsedLaw.from_map()

    initial_result = %{
      law: initial_law,
      stages: %{},
      stage_timings: %{},
      errors: [],
      has_errors: false,
      cancelled: false
    }

    # Determine if taxa should run in parallel
    # Taxa runs in parallel when: it's in the stage list, and the stage list has
    # at least 2 stages (so there's something to run in parallel with)
    run_taxa_parallel = :taxa in stages_to_run and length(stages_to_run) > 1

    # Separate taxa from sequential stages
    sequential_stages = if run_taxa_parallel, do: stages_to_run -- [:taxa], else: stages_to_run
    total_stages = length(stages_to_run)

    # Start taxa stage in parallel if applicable
    # Capture parent process for progress notifications
    caller = self()

    taxa_task =
      if run_taxa_parallel do
        IO.puts("  [PARALLEL] Starting Taxa stage in background...")
        notify_progress(on_progress, {:stage_start, :taxa, total_stages, total_stages})

        Task.async(fn ->
          taxa_start = System.monotonic_time(:microsecond)
          result = run_stage(:taxa, type_code, year, number, initial_law)
          duration = System.monotonic_time(:microsecond) - taxa_start

          # Emit per-stage telemetry from within the task
          :telemetry.execute(
            @telemetry_stage_complete,
            %{duration_us: duration},
            %{
              stage: :taxa,
              status: result.status,
              law_name: name,
              type_code: type_code
            }
          )

          # Send completion back to caller for progress notification
          send(caller, {:taxa_complete, result, duration})

          {result, duration}
        end)
      else
        nil
      end

    # Run sequential stages (excluding taxa if running in parallel)
    result =
      sequential_stages
      |> Enum.with_index(1)
      |> Enum.reduce_while(initial_result, fn {stage, stage_num}, acc ->
        cond do
          # If already cancelled, skip remaining stages
          acc.cancelled ->
            stage_result = %{status: :skipped, data: nil, error: "Cancelled by client"}
            {:cont, update_result(acc, stage, stage_result, 0)}

          # If skip_on_error and previous error, mark as skipped
          skip_on_error and acc.has_errors ->
            # Mark remaining stages as skipped
            notify_progress(on_progress, {:stage_start, stage, stage_num, total_stages})
            stage_result = %{status: :skipped, data: nil, error: "Skipped due to previous error"}
            notify_progress(on_progress, {:stage_complete, stage, :skipped, nil})
            {:cont, update_result(acc, stage, stage_result, 0)}

          # Normal case - run the stage
          true ->
            # Notify stage start (check for abort signal)
            case notify_progress(on_progress, {:stage_start, stage, stage_num, total_stages}) do
              :abort ->
                IO.puts("    ⚠ Cancelled by client before #{stage}")
                stage_result = %{status: :skipped, data: nil, error: "Cancelled by client"}
                {:halt, %{update_result(acc, stage, stage_result, 0) | cancelled: true}}

              _ ->
                # Run the stage with timing
                stage_start = System.monotonic_time(:microsecond)
                stage_result = run_stage(stage, type_code, year, number, acc.law)
                stage_duration = System.monotonic_time(:microsecond) - stage_start

                # Emit per-stage telemetry
                :telemetry.execute(
                  @telemetry_stage_complete,
                  %{duration_us: stage_duration},
                  %{
                    stage: stage,
                    status: stage_result.status,
                    law_name: name,
                    type_code: type_code
                  }
                )

                # Notify stage complete with summary (check for abort signal)
                summary = build_stage_summary(stage, stage_result)

                case notify_progress(
                       on_progress,
                       {:stage_complete, stage, stage_result.status, summary}
                     ) do
                  :abort ->
                    IO.puts("    ⚠ Cancelled by client after #{stage}")
                    updated = update_result(acc, stage, stage_result, stage_duration)
                    {:halt, %{updated | cancelled: true}}

                  _ ->
                    updated = update_result(acc, stage, stage_result, stage_duration)

                    if skip_on_error and stage_result.status == :error do
                      {:halt, updated}
                    else
                      {:cont, updated}
                    end
                end
            end
        end
      end)

    # Await taxa task if running in parallel
    result =
      if taxa_task do
        IO.puts("  [PARALLEL] Awaiting Taxa stage completion...")

        # Wait for taxa to complete (with generous timeout for large laws)
        # Handle task failures gracefully - taxa errors shouldn't crash the parse
        try do
          {taxa_result, taxa_duration} = Task.await(taxa_task, :timer.minutes(5))

          # Notify taxa completion
          summary = build_stage_summary(:taxa, taxa_result)
          notify_progress(on_progress, {:stage_complete, :taxa, taxa_result.status, summary})

          IO.puts("  [PARALLEL] Taxa stage completed (#{div(taxa_duration, 1000)}ms)")

          # Merge taxa result into accumulated result
          update_result(result, :taxa, taxa_result, taxa_duration)
        catch
          :exit, {:timeout, _} ->
            # Taxa timed out after 5 minutes
            IO.puts("    ✗ Taxa timed out after 5 minutes")

            taxa_result = %{
              status: :error,
              data: nil,
              error: "Taxa stage timed out after 5 minutes"
            }

            notify_progress(on_progress, {:stage_complete, :taxa, :error, "Timed out"})
            update_result(result, :taxa, taxa_result, 0)

          :exit, reason ->
            # Taxa task crashed
            error_msg = "Taxa stage crashed: #{inspect(reason)}"
            IO.puts("    ✗ #{error_msg}")
            taxa_result = %{status: :error, data: nil, error: error_msg}
            notify_progress(on_progress, {:stage_complete, :taxa, :error, error_msg})
            update_result(result, :taxa, taxa_result, 0)
        end
      else
        result
      end

    # Mark remaining stages as skipped if we halted early
    result =
      Enum.reduce(@stages, result, fn stage, acc ->
        if Map.has_key?(acc.stages, stage) do
          acc
        else
          # Use appropriate message based on whether cancelled or just skipped
          error_msg = if acc.cancelled, do: "Cancelled by client", else: "Skipped"
          stage_result = %{status: :skipped, data: nil, error: error_msg}
          update_result(acc, stage, stage_result, 0)
        end
      end)

    # Calculate total parse duration
    total_duration = System.monotonic_time(:microsecond) - parse_start_time

    # Emit parse complete telemetry
    :telemetry.execute(
      @telemetry_parse_complete,
      %{
        duration_us: total_duration,
        metadata_duration_us: result.stage_timings[:metadata] || 0,
        extent_duration_us: result.stage_timings[:extent] || 0,
        enacted_by_duration_us: result.stage_timings[:enacted_by] || 0,
        amending_duration_us: result.stage_timings[:amending] || 0,
        amended_by_duration_us: result.stage_timings[:amended_by] || 0,
        repeal_revoke_duration_us: result.stage_timings[:repeal_revoke] || 0,
        taxa_duration_us: result.stage_timings[:taxa] || 0,
        stages_run: length(stages_to_run),
        errors_count: length(result.errors)
      },
      %{
        law_name: name,
        type_code: type_code,
        has_errors: result.has_errors,
        cancelled: result.cancelled
      }
    )

    status_msg =
      cond do
        result.cancelled -> "CANCELLED"
        result.has_errors -> "WITH ERRORS"
        true -> "SUCCESS"
      end

    IO.puts("\n=== PARSE COMPLETE: #{status_msg} (#{div(total_duration, 1000)}ms) ===\n")

    # Notify parse complete (unless cancelled - client already disconnected)
    unless result.cancelled do
      notify_progress(on_progress, {:parse_complete, result.has_errors})
    end

    # Convert ParsedLaw to map for backwards compatibility with callers
    # The :law key contains the ParsedLaw struct, :record contains the map version
    final_result = %{
      record: ParsedLaw.to_comparison_map(result.law),
      law: result.law,
      stages: result.stages,
      errors: result.errors,
      has_errors: result.has_errors,
      cancelled: result.cancelled
    }

    {:ok, final_result}
  end

  @doc """
  Get the list of all parsing stages.
  """
  @spec stages() :: list(stage())
  def stages, do: @stages

  # Update result with stage outcome
  # Uses ParsedLaw.merge/2 which only updates fields with non-nil, non-empty values
  # After repeal_revoke stage completes, runs live status reconciliation
  defp update_result(result, stage, stage_result, stage_duration) do
    new_stages = Map.put(result.stages, stage, stage_result)
    new_timings = Map.put(result.stage_timings || %{}, stage, stage_duration)

    new_errors =
      case stage_result.status do
        :error -> result.errors ++ ["#{stage}: #{stage_result.error}"]
        _ -> result.errors
      end

    new_law =
      case stage_result.status do
        :ok -> ParsedLaw.merge(result.law, stage_result.data || %{})
        _ -> result.law
      end

    # After repeal_revoke stage completes, reconcile live status from both sources
    new_law =
      if stage == :repeal_revoke and stage_result.status == :ok do
        reconcile_live_status(new_law, new_stages)
      else
        new_law
      end

    # After metadata stage completes, run lightweight Making detection pre-filter
    new_law =
      if stage == :metadata and stage_result.status == :ok do
        run_making_detection(new_law)
      else
        new_law
      end

    # After taxa stage completes, log disagreements between pre-filter and taxa
    if stage == :taxa and stage_result.status == :ok do
      log_making_disagreement(new_law)
    end

    %{
      result
      | stages: new_stages,
        stage_timings: new_timings,
        errors: new_errors,
        has_errors: length(new_errors) > 0,
        law: new_law
    }
  end

  # ============================================================================
  # Making Detection Pre-filter (Issue #25)
  # ============================================================================
  #
  # Runs after the metadata stage completes. Uses title, description, and
  # structural metadata (paragraph counts) to classify laws as making/not_making/
  # uncertain with a confidence score. This pre-filter determines which laws
  # get sent to the future AI taxa service.

  defp run_making_detection(law) do
    metadata = %{
      title: law.title_en,
      md_description: law.md_description,
      md_body_paras: law.md_body_paras,
      md_schedule_paras: law.md_schedule_paras,
      md_attachment_paras: law.md_attachment_paras
    }

    result = MakingDetector.detect(metadata)
    fields = MakingDetector.to_parsed_law_fields(result)

    ParsedLaw.merge(law, fields)
  end

  defp log_making_disagreement(law) do
    classification = law.making_classification
    taxa_making = law.is_making

    case {classification, taxa_making} do
      # Pre-filter said not_making but taxa found Making — false negative (most important)
      {"not_making", true} ->
        Logger.warning(
          "[MakingDisagreement] FALSE_NEGATIVE #{law.name}: " <>
            "pre-filter=not_making (#{law.making_confidence}) but taxa=making"
        )

      # Pre-filter said making but taxa says not Making — false positive (less critical)
      {"making", false} ->
        Logger.info(
          "[MakingDisagreement] FALSE_POSITIVE #{law.name}: " <>
            "pre-filter=making (#{law.making_confidence}) but taxa=not_making"
        )

      # No pre-filter result or uncertain — nothing to compare
      _ ->
        :ok
    end
  end

  # ============================================================================
  # Live Status Reconciliation
  # ============================================================================
  #
  # Reconciles live status from two independent data sources:
  #
  # 1. **amended_by stage** (changes/affected endpoint):
  #    - Returns `live_from_changes` based on amendment/revocation history
  #    - Reliable for tracking which laws have revoked this one
  #
  # 2. **repeal_revoke stage** (resources/data.xml endpoint):
  #    - Returns `live` based on document metadata
  #    - Reliable for official revocation markers in the document
  #
  # Strategy: "Most Severe Wins" - If either source indicates revocation,
  # the law is considered revoked. This errs on the side of caution.
  #
  # Severity ranking: revoked (3) > partial (2) > in_force (1)

  defp reconcile_live_status(law, stages) do
    # Get live status from amended_by stage (change history)
    live_from_changes =
      case stages[:amended_by] do
        %{status: :ok, data: data} -> data[:live_from_changes] || @live_in_force
        _ -> @live_in_force
      end

    # Get live status from repeal_revoke stage (metadata)
    live_from_metadata =
      case stages[:repeal_revoke] do
        %{status: :ok, data: data} -> data[:live] || @live_in_force
        _ -> @live_in_force
      end

    # Determine severity of each status
    severity_changes = live_severity(live_from_changes)
    severity_metadata = live_severity(live_from_metadata)

    # Most severe wins
    {final_live, source, conflict} =
      cond do
        severity_changes > severity_metadata ->
          {live_from_changes, :changes, true}

        severity_metadata > severity_changes ->
          {live_from_metadata, :metadata, true}

        true ->
          # Equal severity - no conflict, use metadata as canonical
          {live_from_metadata, :both, false}
      end

    # Build conflict detail if there is a conflict
    conflict_detail =
      if conflict do
        %{
          "reason" => describe_conflict_reason(live_from_changes, live_from_metadata),
          "winner" => to_string(source),
          "changes_severity" => severity_changes,
          "metadata_severity" => severity_metadata
        }
      else
        nil
      end

    # Log conflicts for review
    if conflict do
      law_name = Map.get(law, :name) || "unknown"

      Logger.warning(
        "[LiveStatusConflict] #{law_name}: " <>
          "changes=#{live_from_changes} vs metadata=#{live_from_metadata} → #{source}=#{final_live}"
      )
    end

    # Merge reconciliation results into law
    reconciliation_data = %{
      live: final_live,
      live_source: source,
      live_conflict: conflict,
      live_from_changes: live_from_changes,
      live_from_metadata: live_from_metadata,
      live_conflict_detail: conflict_detail
    }

    ParsedLaw.merge(law, reconciliation_data)
  end

  # Describe the reason for a conflict between live status sources
  defp describe_conflict_reason(changes, metadata) do
    case {changes, metadata} do
      {@live_in_force, @live_revoked} ->
        "Metadata shows revoked but changes history shows in force"

      {@live_revoked, @live_in_force} ->
        "Changes history shows revoked but metadata shows in force"

      {@live_in_force, @live_part_revoked} ->
        "Metadata shows partial revocation but changes history shows in force"

      {@live_part_revoked, @live_in_force} ->
        "Changes history shows partial revocation but metadata shows in force"

      {@live_part_revoked, @live_revoked} ->
        "Metadata shows full revocation, changes only show partial"

      {@live_revoked, @live_part_revoked} ->
        "Changes show full revocation, metadata only shows partial"

      _ ->
        "Unknown conflict pattern"
    end
  end

  # Severity ranking for live status values
  defp live_severity(@live_revoked), do: 3
  defp live_severity(@live_part_revoked), do: 2
  defp live_severity(@live_in_force), do: 1
  defp live_severity(_), do: 0

  # Progress notification helper - only calls callback if provided
  defp notify_progress(nil, _event), do: :ok
  defp notify_progress(callback, event) when is_function(callback, 1), do: callback.(event)

  # Build human-readable summary for each stage completion
  defp build_stage_summary(:metadata, %{status: :ok, data: data}) do
    si_count = length(data[:si_code] || [])
    subjects_count = length(data[:md_subjects] || [])
    "#{si_count} SI codes, #{subjects_count} subjects"
  end

  defp build_stage_summary(:extent, %{status: :ok, data: data}) do
    data[:extent] || "unknown"
  end

  defp build_stage_summary(:enacted_by, %{status: :ok, data: data}) do
    count = length(data[:enacted_by] || [])
    "#{count} parent law(s)"
  end

  defp build_stage_summary(:amending, %{status: :ok, data: data}) do
    amends = data[:amending_count] || 0
    rescinds = data[:rescinding_count] || 0
    self_count = data[:stats_self_affects_count] || 0

    "Amends: #{amends}, Rescinds: #{rescinds} (self: #{self_count})"
  end

  defp build_stage_summary(:amended_by, %{status: :ok, data: data}) do
    amended_by = data[:amended_by_count] || 0
    rescinded_by = data[:rescinded_by_count] || 0

    "Amended by: #{amended_by}, Rescinded by: #{rescinded_by}"
  end

  defp build_stage_summary(:repeal_revoke, %{status: :ok, data: data}) do
    if data[:revoked], do: "REVOKED", else: "Active"
  end

  defp build_stage_summary(:taxa, %{status: :ok, data: data}) do
    role_count = length(data[:role] || [])
    duty_types = length(data[:duty_type] || [])
    popimar = length(data[:popimar] || [])
    lat_count = data[:lat_rows_count] || 0

    base = "#{role_count} actors, #{duty_types} duty types, #{popimar} POPIMAR"
    if lat_count > 0, do: "#{base} | #{lat_count} LAT rows", else: base
  end

  defp build_stage_summary(_stage, %{status: :error, error: error}), do: error
  defp build_stage_summary(_stage, _), do: nil

  # Run a specific stage
  defp run_stage(:metadata, type_code, year, number, record) do
    IO.puts("  [1/7] Metadata...")
    run_metadata_stage(type_code, year, number, record)
  end

  defp run_stage(:extent, type_code, year, number, _record) do
    IO.puts("  [2/7] Extent...")
    run_extent_stage(type_code, year, number)
  end

  defp run_stage(:enacted_by, type_code, year, number, _record) do
    IO.puts("  [3/7] Enacted By...")
    run_enacted_by_stage(type_code, year, number)
  end

  defp run_stage(:amending, type_code, year, number, _record) do
    IO.puts("  [4/7] Amending (this law affects others)...")
    run_amending_stage(type_code, year, number)
  end

  defp run_stage(:amended_by, type_code, year, number, _record) do
    IO.puts("  [5/7] Amended By (this law is affected by others)...")
    run_amended_by_stage(type_code, year, number)
  end

  defp run_stage(:repeal_revoke, type_code, year, number, _record) do
    IO.puts("  [6/7] Repeal/Revoke...")
    run_repeal_revoke_stage(type_code, year, number)
  end

  defp run_stage(:taxa, type_code, year, number, record) do
    IO.puts("  [7/7] Taxa Classification...")
    run_taxa_stage(type_code, year, number, record)
  end

  # ============================================================================
  # Stage 1: Metadata
  # ============================================================================
  # Fetches basic metadata from the introduction XML including:
  # - Title, description, subjects
  # - SI codes (si_code)
  # - Dates (enactment, made, coming into force)
  # - Statistics (paragraph counts, images)
  # - Geographic extent fields

  defp run_metadata_stage(type_code, year, number, existing_record) do
    fetch_record = %{type_code: type_code, Year: year, Number: number}

    case Metadata.fetch(fetch_record) do
      {:ok, metadata} ->
        # Only protect title_en from being overwritten - the introduction XML
        # may have a different Title_EN than the original scrape.
        # All other metadata fields (md_description, md_subjects, dates, etc.)
        # should be refreshed on reparse.
        protected_fields = [:title_en]

        filtered_metadata =
          metadata
          |> Enum.reject(fn {key, _value} ->
            key in protected_fields and has_key?(existing_record, key)
          end)
          |> Enum.into(%{})

        # Count key fields for summary
        si_count = length(metadata[:si_code] || [])
        subjects_count = length(metadata[:md_subjects] || [])
        IO.puts("    ✓ Metadata: #{si_count} SI codes, #{subjects_count} subjects")
        %{status: :ok, data: filtered_metadata, error: nil}

      {:error, reason} ->
        IO.puts("    ✗ Metadata failed: #{reason}")
        %{status: :error, data: nil, error: reason}
    end
  end

  # Check if a key exists in a record (handling ParsedLaw structs and maps)
  # For ParsedLaw structs, use Map.get which works on structs
  # For maps, handle both atom and string keys
  defp has_key?(%ParsedLaw{} = law, key) when is_atom(key) do
    value = Map.get(law, key)
    not is_nil(value) and value != "" and value != []
  end

  defp has_key?(%ParsedLaw{} = _law, _key) do
    # String keys don't exist in ParsedLaw struct (all keys are atoms)
    false
  end

  defp has_key?(record, key) when is_atom(key) do
    value = record[key] || record[Atom.to_string(key)]
    not is_nil(value) and value != "" and value != []
  end

  defp has_key?(record, key) when is_binary(key) do
    value = record[key] || record[String.to_existing_atom(key)]
    not is_nil(value) and value != "" and value != []
  rescue
    ArgumentError -> record[key] != nil
  end

  # ============================================================================
  # Stage 2: Extent
  # ============================================================================

  defp run_extent_stage(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/contents/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        data = parse_extent_xml(xml)
        IO.puts("    ✓ Extent: #{data[:extent] || "unknown"}")
        %{status: :ok, data: data, error: nil}

      {:error, 404, _} ->
        # Try without /contents/
        alt_path = "/#{type_code}/#{year}/#{number}/data.xml"

        case Client.fetch_xml(alt_path) do
          {:ok, xml} ->
            data = parse_extent_xml(xml)
            IO.puts("    ✓ Extent (alt path): #{data[:extent] || "unknown"}")
            %{status: :ok, data: data, error: nil}

          {:error, code, msg} ->
            IO.puts("    ✗ Extent failed: #{msg}")
            %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
        end

      {:error, code, msg} ->
        IO.puts("    ✗ Extent failed: #{msg}")
        %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
    end
  end

  defp parse_extent_xml(xml) do
    try do
      # Try multiple locations for extent:
      # 1. Legislation element's RestrictExtent attribute
      # 2. First ContentsItem's RestrictExtent attribute (most common for new legislation)
      # 3. Contents element's RestrictExtent attribute (fallback)

      extent = xpath_text(xml, ~x"//Legislation/@RestrictExtent"s)

      # Get extent from first ContentsItem if Legislation doesn't have it
      first_item_extent =
        case SweetXml.xpath(xml, ~x"//ContentsItem[1]/@RestrictExtent"s) do
          nil -> nil
          "" -> nil
          val -> to_string(val)
        end

      # Get extent from Contents element as fallback
      contents_extent =
        case SweetXml.xpath(xml, ~x"//Contents/@RestrictExtent"s) do
          nil -> nil
          "" -> nil
          val -> to_string(val)
        end

      # Parse section-level extents
      section_extents = parse_section_extents(xml)

      # Use first available extent: Legislation > first ContentsItem > Contents
      raw_extent =
        cond do
          extent != "" and extent != nil -> extent
          first_item_extent != "" and first_item_extent != nil -> first_item_extent
          contents_extent != "" and contents_extent != nil -> contents_extent
          true -> nil
        end

      normalized_extent = normalize_extent(raw_extent)
      regions = extent_to_regions(raw_extent)

      # Build base result with section-level data (always useful)
      base = %{
        section_extents: section_extents
      }

      # Only include top-level extent fields if we found data
      # This prevents overwriting values from metadata.ex (initial scrape)
      if normalized_extent do
        # Use Extent module to generate geo_detail with emoji flags and section breakdown
        {_region, _pan_region, geo_detail} =
          SertantaiLegal.Scraper.Extent.transform_extent(section_extents)

        Map.merge(base, %{
          geo_extent: regions_to_pan_region(regions),
          geo_region: regions,
          geo_detail: geo_detail,
          extent: regions_to_pan_region(regions),
          extent_regions: regions
        })
      else
        # No extent found in contents XML - preserve whatever came from metadata
        base
      end
    rescue
      e ->
        # Don't overwrite extent fields on error - just log it
        %{extent_error: "Parse error: #{inspect(e)}"}
    end
  end

  # Convert regions list to pan-region code (UK, GB, E+W, etc.)
  defp regions_to_pan_region([]), do: nil

  defp regions_to_pan_region(regions) do
    sorted = Enum.sort(regions)

    cond do
      sorted == ["England", "Northern Ireland", "Scotland", "Wales"] -> "UK"
      sorted == ["England", "Scotland", "Wales"] -> "GB"
      sorted == ["England", "Wales"] -> "E+W"
      sorted == ["England", "Scotland"] -> "E+S"
      sorted == ["England"] -> "E"
      sorted == ["Wales"] -> "W"
      sorted == ["Scotland"] -> "S"
      sorted == ["Northern Ireland"] -> "NI"
      true -> regions |> Enum.map(&region_to_code/1) |> Enum.join("+")
    end
  end

  defp region_to_code("England"), do: "E"
  defp region_to_code("Wales"), do: "W"
  defp region_to_code("Scotland"), do: "S"
  defp region_to_code("Northern Ireland"), do: "NI"
  defp region_to_code(_), do: ""

  defp parse_section_extents(xml) do
    # Try to get section-level extent data
    try do
      SweetXml.xpath(xml, ~x"//ContentsItem"l)
      |> Enum.map(fn item ->
        ref = SweetXml.xpath(item, ~x"./@ContentRef"s) |> to_string()
        ext = SweetXml.xpath(item, ~x"./@RestrictExtent"s) |> to_string()
        {ref, normalize_extent(ext)}
      end)
      |> Enum.reject(fn {ref, ext} -> ref == "" or ext == "" end)
      |> Enum.into(%{})
    rescue
      _ -> %{}
    end
  end

  defp normalize_extent(nil), do: nil
  defp normalize_extent(""), do: nil

  defp normalize_extent(extent) do
    # Raw extent from legislation.gov.uk is like "E+W+S+N.I."
    # Normalize to "E+W+S+NI" format
    extent
    |> String.upcase()
    # Handle "N.I." → "NI"
    |> String.replace("N.I.", "NI")
    # Handle "N.I" without trailing dot
    |> String.replace("N.I", "NI")
    # Remove any remaining dots
    |> String.replace(".", "")
    # Remove spaces
    |> String.replace(" ", "")
  end

  defp extent_to_regions(nil), do: []
  defp extent_to_regions(""), do: []

  defp extent_to_regions(extent) do
    extent = normalize_extent(extent)

    regions =
      []
      |> maybe_add_region(extent, "E", "England")
      |> maybe_add_region(extent, "W", "Wales")
      |> maybe_add_region(extent, "S", "Scotland")
      |> maybe_add_region(extent, "NI", "Northern Ireland")

    regions
  end

  defp maybe_add_region(acc, extent, code, name) do
    if String.contains?(extent, code) do
      acc ++ [name]
    else
      acc
    end
  end

  # ============================================================================
  # Stage 3: Enacted By
  # ============================================================================
  #
  # Fetches the "made" version of the introduction XML to find enacting parent laws.
  #
  # Secondary legislation (SIs) are "made" under powers conferred by primary legislation
  # (Acts). This stage parses the enacting text to find which Acts enabled this SI.
  #
  # Acts (ukpga, anaw, asp, nia, apni) are not enacted by other laws, so this stage
  # returns empty for those type codes.

  defp run_enacted_by_stage(type_code, _year, _number)
       when type_code in ["ukpga", "anaw", "asp", "nia", "apni"] do
    # Acts are not enacted by other laws
    IO.puts("    ⚠ Skipped (Acts are not enacted by other laws)")
    %{status: :ok, data: %{enacted_by: [], is_act: true}, error: nil}
  end

  defp run_enacted_by_stage(type_code, year, number) do
    # Use the EnactedBy module for parsing - single source of truth
    path = EnactedBy.introduction_path(type_code, to_string(year), to_string(number))

    case EnactedBy.fetch_enacting_data(path) do
      {:ok, %{text: text, urls: urls} = data} ->
        # Use EnactedBy's pattern matching to find enacted_by laws
        enacted_by_ids = EnactedBy.find_enacting_laws(text, urls)

        # Convert law IDs to richer format for downstream compatibility
        enacted_by = Enum.map(enacted_by_ids, &parse_law_id_to_map/1)

        count = length(enacted_by)
        IO.puts("    ✓ Enacted by: #{count} parent law(s)")

        %{
          status: :ok,
          data: %{
            enacted_by: enacted_by,
            enacting_text: String.slice(data.enacting_text, 0, 500),
            introductory_text: String.slice(data.introductory_text, 0, 500)
          },
          error: nil
        }

      {:error, reason} ->
        IO.puts("    ✗ Enacted by failed: #{reason}")
        %{status: :error, data: nil, error: reason}
    end
  end

  # Convert law ID like "ukpga/1974/37" to map format
  # Normalizes name to UK_type_year_number format for DB consistency
  # Looks up title from database if the law exists
  defp parse_law_id_to_map(law_id) do
    name = IdField.normalize_to_db_name(law_id)

    # Look up title from database (parent Acts should already exist)
    title = lookup_law_title(name)

    case String.split(law_id, "/") do
      [_type_code, _year, _number] ->
        %{
          name: name,
          title: title,
          uri: "http://www.legislation.gov.uk/id/#{law_id}"
        }

      _ ->
        %{
          name: name,
          title: title,
          uri: nil
        }
    end
  end

  # Look up a law's title from the database
  defp lookup_law_title(name) do
    require Ash.Query

    case UkLrt
         |> Ash.Query.filter(name == ^name)
         |> Ash.Query.select([:title_en])
         |> Ash.read_one() do
      {:ok, %{title_en: title}} when not is_nil(title) -> title
      _ -> nil
    end
  end

  # ============================================================================
  # Stage 4: Amending (this law affects others)
  # ============================================================================
  #
  # Uses the Amending module to fetch amendment data from /changes/affecting
  # endpoint. This shows laws that THIS law amends or rescinds.

  defp run_amending_stage(type_code, year, number) do
    record = %{type_code: type_code, Year: year, Number: number}

    case Amending.get_laws_amended_by_this_law(record) do
      {:ok, affecting} ->
        # Self-amendments (this law affecting itself) - "coming into force" provisions
        self_count = affecting.stats.self_amendments_count

        data = %{
          # Laws this law amends (excluding self)
          amending: affecting.amending,
          rescinding: affecting.rescinding,
          amending_count: length(affecting.amending),
          rescinding_count: length(affecting.rescinding),
          is_amending: length(affecting.amending) > 0,
          is_rescinding: length(affecting.rescinding) > 0,

          # Self-affects (this law amending itself)
          stats_self_affects_count: self_count,
          stats_self_affects_count_per_law_detailed:
            build_self_amendments_detailed(affecting.self_amendments),

          # Flattened stats - Amending (🔺 this law affects others) - excludes self
          amending_stats_affects_count: affecting.stats.amendments_count,
          amending_stats_affected_laws_count: affecting.stats.amended_laws_count,
          # Consolidated JSONB field (🔺_affects_stats_per_law) - replaces legacy text columns
          affects_stats_per_law: build_stats_per_law_jsonb(affecting.amendments),

          # Flattened stats - Rescinding (🔺 this law rescinds others) - excludes self
          rescinding_stats_rescinding_laws_count: affecting.stats.revoked_laws_count,
          # Consolidated JSONB field (🔺_rescinding_stats_per_law) - replaces legacy text columns
          rescinding_stats_per_law: build_stats_per_law_jsonb(affecting.revocations),

          # Detailed amendment data (for future use) - excludes self
          amending_details: affecting.amendments,
          rescinding_details: affecting.revocations
        }

        IO.puts(
          "    ✓ Amends: #{data.amending_count} laws, Rescinds: #{data.rescinding_count} laws (self: #{self_count})"
        )

        %{status: :ok, data: data, error: nil}

      {:error, msg} ->
        IO.puts("    ✗ Amending stage failed: #{msg}")
        %{status: :error, data: nil, error: msg}
    end
  end

  # ============================================================================
  # Stage 5: Amended By (this law is affected by others)
  # ============================================================================
  #
  # Uses the Amending module to fetch amendment data from /changes/affected
  # endpoint. This shows laws that amend or rescind THIS law.

  defp run_amended_by_stage(type_code, year, number) do
    record = %{type_code: type_code, Year: year, Number: number}

    case Amending.get_laws_amending_this_law(record) do
      {:ok, affected} ->
        data = %{
          # Laws that amend this law (excluding self)
          amended_by: affected.amended_by,
          rescinded_by: affected.rescinded_by,
          amended_by_count: length(affected.amended_by),
          rescinded_by_count: length(affected.rescinded_by),

          # Live status derived from change history (for reconciliation with repeal_revoke stage)
          live_from_changes: affected.live,

          # Flattened stats - Amended_by (🔻 this law is affected by others) - excludes self
          amended_by_stats_affected_by_count: affected.stats.amendments_count,
          amended_by_stats_affected_by_laws_count: affected.stats.amended_laws_count,
          # Consolidated JSONB field (🔻_affected_by_stats_per_law) - replaces legacy text columns
          affected_by_stats_per_law: build_stats_per_law_jsonb(affected.amendments),

          # Flattened stats - Rescinded_by (🔻 this law is rescinded by others) - excludes self
          rescinded_by_stats_rescinded_by_laws_count: affected.stats.revoked_laws_count,
          # Consolidated JSONB field (🔻_rescinded_by_stats_per_law) - replaces legacy text columns
          rescinded_by_stats_per_law: build_stats_per_law_jsonb(affected.revocations),

          # Detailed amendment data (for future use) - excludes self
          amended_by_details: affected.amendments,
          rescinded_by_details: affected.revocations
        }

        IO.puts(
          "    ✓ Amended by: #{data.amended_by_count} laws, Rescinded by: #{data.rescinded_by_count} laws"
        )

        %{status: :ok, data: data, error: nil}

      {:error, msg} ->
        IO.puts("    ✗ Amended by stage failed: #{msg}")
        %{status: :error, data: nil, error: msg}
    end
  end

  # ============================================================================
  # Stage 6: Repeal/Revoke
  # ============================================================================

  defp run_repeal_revoke_stage(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/resources/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        data = parse_repeal_revoke_xml(xml)
        status_str = if data[:revoked], do: "REVOKED", else: "Active"
        IO.puts("    ✓ Status: #{status_str}")
        %{status: :ok, data: data, error: nil}

      {:error, 404, _} ->
        # No resources file - assume not revoked (in force)
        IO.puts("    ⚠ No revocation data (404) - assuming active")

        %{
          status: :ok,
          data: %{live: @live_in_force, live_description: "", revoked: false, revoked_by: []},
          error: nil
        }

      {:error, code, msg} ->
        IO.puts("    ✗ Repeal/Revoke failed: #{msg}")
        %{status: :error, data: nil, error: "HTTP #{code}: #{msg}"}
    end
  end

  defp parse_repeal_revoke_xml(xml) do
    try do
      # Check title for REVOKED/REPEALED
      title = xpath_text(xml, ~x"//dc:title/text()"s)

      title_revoked =
        String.contains?(String.upcase(title), "REVOKED") or
          String.contains?(String.upcase(title), "REPEALED")

      # Check for ukm:RepealedLaw element
      repealed_law = SweetXml.xpath(xml, ~x"//ukm:RepealedLaw"o)
      has_repealed_element = repealed_law != nil

      # Get revocation dates
      dct_valid = xpath_text(xml, ~x"//dct:valid/text()"s)
      restrict_start_date = xpath_text(xml, ~x"//Legislation/@RestrictStartDate"s)

      # Get laws that revoke/repeal this one
      revoked_by =
        SweetXml.xpath(xml, ~x"//ukm:SupersededBy/ukm:Citation"l)
        |> Enum.map(fn citation ->
          uri = SweetXml.xpath(citation, ~x"./@URI"s) |> to_string()
          cit_title = SweetXml.xpath(citation, ~x"./@Title"s) |> to_string()
          %{uri: uri, title: cit_title, name: uri_to_name(uri)}
        end)
        |> Enum.reject(fn %{uri: uri} -> uri == "" end)

      # Determine revocation status
      # Full revocation: title explicitly says REVOKED/REPEALED or RepealedLaw element exists
      is_fully_revoked = title_revoked or has_repealed_element

      # Partial revocation: has revoking laws but not fully revoked
      # This means some provisions are revoked but the law is still partially in force
      is_partially_revoked = not is_fully_revoked and length(revoked_by) > 0

      # Build live status and description
      {live, live_description} =
        build_live_status(is_fully_revoked, is_partially_revoked, revoked_by)

      %{
        # Fields for modal display
        live: live,
        live_description: live_description,
        # Raw revocation data
        revoked: is_fully_revoked,
        partially_revoked: is_partially_revoked,
        revoked_title_marker: title_revoked,
        revoked_element: has_repealed_element,
        revoked_by: revoked_by,
        rescinded_by: format_revoked_by(revoked_by),
        md_dct_valid_date: parse_date(dct_valid),
        md_restrict_start_date: parse_date(restrict_start_date)
      }
    rescue
      e ->
        %{
          live: @live_in_force,
          live_description: "",
          revoked: false,
          repeal_revoke_error: "Parse error: #{inspect(e)}"
        }
    end
  end

  # In force - no revocations
  defp build_live_status(false, false, _revoked_by), do: {@live_in_force, ""}

  # Partial revocation - some provisions revoked but law still in force
  defp build_live_status(false, true, revoked_by) do
    names =
      Enum.map(revoked_by, fn %{name: name, title: title} ->
        if title != "", do: "#{name} (#{title})", else: name
      end)

    description = "Partially revoked by: " <> Enum.join(names, ", ")
    {@live_part_revoked, description}
  end

  # Full revocation - no details
  defp build_live_status(true, _partial, []) do
    {@live_revoked, "Revoked/Repealed"}
  end

  # Full revocation - with revoking law details
  defp build_live_status(true, _partial, revoked_by) do
    names =
      Enum.map(revoked_by, fn %{name: name, title: title} ->
        if title != "", do: "#{name} (#{title})", else: name
      end)

    description = "Revoked by: " <> Enum.join(names, ", ")
    {@live_revoked, description}
  end

  defp format_revoked_by([]), do: nil

  defp format_revoked_by(revoked_by) do
    Enum.map(revoked_by, fn %{name: name} -> name end)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date), do: date

  # ============================================================================
  # Stage 7: Taxa Classification
  # ============================================================================
  #
  # Fetches law text and runs the Taxa classification pipeline:
  # - DutyActor: Extracts actors (employers, authorities, etc.)
  # - DutyType: Classifies duty types (Duty, Right, Responsibility, Power)
  # - Popimar: Classifies by POPIMAR management framework

  defp run_taxa_stage(type_code, year, number, record) do
    case TaxaParser.run_with_body(type_code, year, number) do
      {:ok, taxa_data, body_xml} ->
        role_count = length(taxa_data[:role] || [])
        duty_types = taxa_data[:duty_type] || []
        popimar_items = taxa_data[:popimar] || []

        IO.puts(
          "    ✓ Taxa: #{role_count} actors, #{length(duty_types)} duty types, #{length(popimar_items)} POPIMAR"
        )

        # LAT sub-stage: parse body XML into LAT rows for "making" laws
        lat_count = maybe_run_lat_substage(taxa_data, body_xml, type_code, year, number, record)
        taxa_data = Map.put(taxa_data, :lat_rows_count, lat_count)

        %{status: :ok, data: taxa_data, error: nil}

      {:error, reason} ->
        IO.puts("    ✗ Taxa failed: #{reason}")
        %{status: :error, data: nil, error: reason}
    end
  end

  # LAT sub-stage: conditionally parse body XML into LAT rows + commentary annotations
  defp maybe_run_lat_substage(taxa_data, body_xml, type_code, _year, _number, record)
       when is_binary(body_xml) do
    duty_types = taxa_data[:duty_type] || []
    is_making = "Duty" in duty_types or "Responsibility" in duty_types

    if is_making do
      law_name = IdField.normalize_to_db_name(record.name)

      case lookup_law_id(law_name) do
        {:ok, law_id} ->
          rows = LatParser.parse(body_xml, %{law_name: law_name, type_code: type_code})

          case LatPersister.persist(rows, law_name, law_id) do
            {:ok, %{inserted: inserted}} ->
              IO.puts("    ✓ LAT: #{inserted} rows persisted")

              # Commentary sub-stage: parse Commentaries block and persist annotations
              maybe_run_commentary_substage(body_xml, rows, law_name, law_id)

              inserted

            {:error, reason} ->
              IO.puts("    ✗ LAT persist failed: #{reason}")
              0
          end

        {:error, reason} ->
          IO.puts("    ✗ LAT skipped: #{reason}")
          0
      end
    else
      IO.puts("    ○ LAT skipped (not a making law)")
      0
    end
  end

  defp maybe_run_lat_substage(_taxa_data, _body_xml, _type_code, _year, _number, _record), do: 0

  # Commentary sub-stage: parse <Commentaries> block from body XML and persist annotations
  defp maybe_run_commentary_substage(body_xml, lat_rows, law_name, law_id) do
    ref_to_sections = CommentaryParser.build_ref_to_sections(lat_rows)
    annotations = CommentaryParser.parse(body_xml, %{law_name: law_name}, ref_to_sections)

    if annotations == [] do
      IO.puts("    ○ Annotations: none found in body XML")
    else
      case CommentaryPersister.persist(annotations, law_name, law_id) do
        {:ok, %{inserted: inserted}} ->
          IO.puts("    ✓ Annotations: #{inserted} persisted from Commentaries block")

        {:error, reason} ->
          IO.puts("    ✗ Annotations persist failed: #{reason}")
      end
    end
  end

  # Look up the uk_lrt database ID for a given law_name
  defp lookup_law_id(law_name) do
    case Repo.query("SELECT id::text FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      {:ok, %{rows: [[id]]}} -> {:ok, id}
      {:ok, %{rows: []}} -> {:error, "law not found in uk_lrt: #{law_name}"}
      {:error, err} -> {:error, "DB error: #{inspect(err)}"}
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp uri_to_name(nil), do: nil
  defp uri_to_name(""), do: nil

  defp uri_to_name(uri) do
    # Convert URI like "http://www.legislation.gov.uk/id/uksi/2020/1234"
    # to name like "uksi/2020/1234"
    uri
    |> String.replace(~r"^https?://www\.legislation\.gov\.uk/id/", "")
    |> String.replace(~r"^https?://www\.legislation\.gov\.uk/", "")
  end

  defp xpath_text(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> ""
      "" -> ""
      value when is_binary(value) -> String.trim(value)
      value -> to_string(value) |> String.trim()
    end
  end

  # ============================================================================
  # Amendment Per-Law String Builders
  # ============================================================================
  #
  # Builds the *_count_per_law summary and detailed strings from amendment lists.
  # These match the format imported from Airtable CSV exports.
  #
  # Legacy text format functions removed - replaced by build_stats_per_law_jsonb/1
  # - build_count_per_law_summary/1
  # - build_count_per_law_detailed/1

  # Builds a JSONB-compatible map combining summary and detailed data.
  # This consolidates the separate *_count_per_law and *_count_per_law_detailed fields.
  #
  # Output format (map keyed by law name):
  #   %{
  #     "UK_uksi_2020_100" => %{
  #       "name" => "UK_uksi_2020_100",
  #       "title" => "The Example Regulations 2020",
  #       "url" => "https://legislation.gov.uk/id/uksi/2020/100",
  #       "count" => 3,
  #       "details" => [
  #         %{"target" => "reg. 1", "affect" => "inserted", "applied" => "Not yet"},
  #         %{"target" => "reg. 2", "affect" => "substituted", "applied" => "Yes"}
  #       ]
  #     }
  #   }
  # Test helper - expose private function for testing
  if Mix.env() == :test do
    def build_stats_per_law_jsonb_test(amendments), do: build_stats_per_law_jsonb(amendments)
  end

  defp build_stats_per_law_jsonb([]), do: nil

  defp build_stats_per_law_jsonb(amendments) do
    amendments
    |> group_amendments_by_law()
    |> Enum.map(fn {law_name, items} ->
      first = hd(items)
      title = Map.get(first, :title_en) || Map.get(first, "title_en") || ""
      path = Map.get(first, :path) || Map.get(first, "path") || ""

      url =
        if path != "" do
          "https://legislation.gov.uk#{path}"
        else
          nil
        end

      details =
        items
        |> Enum.map(&build_detail_map/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      entry = %{
        "name" => law_name,
        "title" => if(title != "", do: title, else: nil),
        "url" => url,
        "count" => length(items),
        "details" => details
      }

      {law_name, entry}
    end)
    |> Map.new()
  end

  # Build a detail map for JSONB output
  defp build_detail_map(%{target: target, affect: affect, applied?: applied}) do
    target = if target == "", do: nil, else: target
    affect = if affect == "", do: nil, else: affect
    applied = if applied == "", do: nil, else: applied

    if is_nil(target) and is_nil(affect) do
      nil
    else
      %{"target" => target, "affect" => affect, "applied" => applied}
    end
  end

  defp build_detail_map(%{target: target}) when is_binary(target) and target != "" do
    %{"target" => target, "affect" => nil, "applied" => nil}
  end

  defp build_detail_map(_), do: nil

  # Build "target affect [applied?]" string for detailed output
  # e.g., "reg. 2(1) words inserted [Not yet]"
  defp build_target_affect_applied(%{target: target, affect: affect, applied?: applied}) do
    target = target || ""
    affect = affect || ""
    applied = applied || ""

    cond do
      target == "" and affect == "" -> nil
      target == "" -> "#{affect} [#{applied}]"
      affect == "" -> target
      true -> "#{target} #{affect} [#{applied}]"
    end
  end

  defp build_target_affect_applied(%{target: target}) when is_binary(target) and target != "",
    do: target

  defp build_target_affect_applied(_), do: nil

  defp group_amendments_by_law(amendments) do
    amendments
    # Filter out amendments with no name
    |> Enum.reject(fn item ->
      name = Map.get(item, :name) || Map.get(item, "name")
      is_nil(name) || name == ""
    end)
    |> Enum.group_by(fn item ->
      # Handle both atom and string keys
      Map.get(item, :name) || Map.get(item, "name")
    end)
    |> Enum.sort_by(fn {_name, items} ->
      # Sort by year desc, then number desc (most recent first)
      first = hd(items)
      year = Map.get(first, :year) || Map.get(first, "year") || 0
      number = parse_number_for_sort(Map.get(first, :number) || Map.get(first, "number"))
      {-year, -number}
    end)
  end

  # Parse number string to integer for sorting, handling non-numeric suffixes
  defp parse_number_for_sort(number) when is_binary(number) do
    case Integer.parse(number) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_number_for_sort(number) when is_integer(number), do: number
  defp parse_number_for_sort(_), do: 0

  # Build detailed string for self-amendments (coming into force provisions)
  # These are amendments where the law references itself
  # Format: "235 self-amendments\n art. 1 coming into force [Yes]\n art. 2 coming into force [Yes]..."
  defp build_self_amendments_detailed([]), do: nil

  defp build_self_amendments_detailed(self_amendments) do
    count = length(self_amendments)

    # Build detailed entries
    details =
      self_amendments
      |> Enum.map(&build_target_affect_applied/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    header = "#{count} self-amendments"

    if details == [] do
      header
    else
      detail_lines = Enum.map(details, &(" " <> &1)) |> Enum.join("\n")
      "#{header}\n#{detail_lines}"
    end
  end

  # ============================================================================
  # Test Helpers - expose private functions for testing
  # ============================================================================

  if Mix.env() == :test do
    # Removed: test_build_count_per_law_detailed/1 (legacy function removed)

    @doc false
    def test_build_target_affect_applied(amendment), do: build_target_affect_applied(amendment)

    @doc false
    def test_notify_progress(callback, event), do: notify_progress(callback, event)

    @doc false
    def test_build_stage_summary(stage, result), do: build_stage_summary(stage, result)

    @doc false
    def test_reconcile_live_status(law, stages), do: reconcile_live_status(law, stages)

    @doc false
    def test_live_severity(status), do: live_severity(status)

    @doc false
    def live_in_force, do: @live_in_force

    @doc false
    def live_part_revoked, do: @live_part_revoked

    @doc false
    def live_revoked, do: @live_revoked
  end
end

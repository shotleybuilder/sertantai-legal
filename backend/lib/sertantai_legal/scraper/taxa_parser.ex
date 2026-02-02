defmodule SertantaiLegal.Scraper.TaxaParser do
  @moduledoc """
  Taxa classification parser for UK legislation.

  Fetches law text from legislation.gov.uk and runs the Taxa classification pipeline:
  - DutyActor: Extracts actors (employers, authorities, etc.)
  - DutyType: Classifies duty types (Duty, Right, Responsibility, Power)
  - PurposeClassifier: Classifies purpose (Amendment, Interpretation+Definition, etc.)
  - Popimar: Classifies by POPIMAR management framework

  ## Telemetry Events

  The following telemetry events are emitted for performance monitoring:

  - `[:taxa, :classify, :start]` - When classification begins
  - `[:taxa, :classify, :stop]` - When classification completes successfully
  - `[:taxa, :classify, :exception]` - When classification fails

  Measurements include:
  - `duration` - Total classification time in native units
  - `text_length` - Length of text being classified
  - `actor_duration` - Time for DutyActor stage
  - `duty_type_duration` - Time for DutyType stage
  - `popimar_duration` - Time for Popimar stage
  - `purpose_duration` - Time for PurposeClassifier stage

  ## Usage

      # Run Taxa classification for a law
      {:ok, taxa_data} = TaxaParser.run("uksi", "2024", "1001")

      # Returns:
      %{
        role: ["Org: Employer", "Ind: Employee"],
        role_gvt: ["Gvt: Minister"],
        duty_type: ["Duty", "Right"],
        purpose: ["Amendment"],
        duty_holder: %{"items" => ["Org: Employer"]},
        popimar: ["Risk Control", "Organisation - Competence"],
        ...
      }
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  alias SertantaiLegal.Legal.Taxa.{
    DutyActor,
    DutyType,
    Popimar,
    PurposeClassifier,
    TaxaFormatter,
    TextCleaner
  }

  require Logger
  import SweetXml

  # Large law threshold in characters - laws above this size trigger
  # additional telemetry and logging for performance analysis.
  # Future phases will add optimizations for large laws.
  # Configurable via application env.
  @default_large_law_threshold 200_000

  @doc """
  Returns the threshold (in characters) above which a law is considered "large".
  Large laws receive additional telemetry and may have optimizations applied.
  Default: 200,000 characters (~200KB).
  """
  @spec large_law_threshold() :: non_neg_integer()
  def large_law_threshold do
    Application.get_env(:sertantai_legal, :large_law_threshold, @default_large_law_threshold)
  end

  @doc """
  Returns true if the given text length exceeds the large law threshold.
  """
  @spec large_law?(non_neg_integer()) :: boolean()
  def large_law?(text_length) when is_integer(text_length) do
    text_length > large_law_threshold()
  end

  @type taxa_result :: %{
          role: list(String.t()),
          role_gvt: map() | nil,
          duty_type: list(String.t()),
          purpose: list(String.t()),
          duty_holder: map() | nil,
          rights_holder: map() | nil,
          responsibility_holder: map() | nil,
          power_holder: map() | nil,
          popimar: list(String.t()) | nil,
          popimar_details: map() | nil,
          taxa_text_source: String.t(),
          taxa_text_length: integer()
        }

  @typedoc "A P1 section tuple: {section_id, section_text}"
  @type p1_section :: {String.t(), String.t()}

  @doc """
  Run Taxa classification for a law.

  Fetches the introduction/preamble text and runs the full Taxa pipeline.
  """
  @spec run(String.t(), String.t() | integer(), String.t() | integer()) ::
          {:ok, taxa_result()} | {:error, String.t()}
  def run(type_code, year, number) do
    year = to_string(year)
    number = to_string(number)
    law_name = "#{type_code}/#{year}/#{number}"

    case fetch_law_text(type_code, year, number) do
      {:ok, text, source, p1_sections} ->
        # Law with P1 sections - use chunked processing for article field population
        # Large laws use parallel processing, small laws use sequential
        taxa_data = classify_text_chunked(text, source, p1_sections, law_name: law_name)
        {:ok, taxa_data}

      {:ok, text, source} ->
        # Law without P1 tags - use standard processing (no article granularity)
        taxa_data = classify_text(text, source, law_name: law_name)
        {:ok, taxa_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Classify text using the Taxa pipeline.

  Returns a map with all Taxa fields populated.

  Emits telemetry events with per-stage timing for performance monitoring.

  ## Options
  - `:law_name` - Law identifier for telemetry (e.g., "uksi/2024/1001")
  """
  @spec classify_text(String.t(), String.t(), keyword()) :: taxa_result()
  def classify_text(text, source \\ "unknown", opts \\ []) when is_binary(text) do
    law_name = Keyword.get(opts, :law_name)

    if String.trim(text) == "" do
      empty_result(source)
    else
      text_length = String.length(text)
      is_large_law = large_law?(text_length)
      start_time = System.monotonic_time(:microsecond)

      # Log large law detection for visibility
      if is_large_law do
        Logger.warning(
          "[Taxa] Large law detected: #{law_name || "unknown"} (#{text_length} chars > #{large_law_threshold()} threshold)"
        )

        IO.puts(
          "    ⚠ Large law detected: #{text_length} chars (threshold: #{large_law_threshold()})"
        )
      end

      # Step 0: Apply unified blacklist once (combines actor + duty_type blacklists)
      # This eliminates redundant cleaning in DutyActor and DutyTypeLib
      cleaned_text = TextCleaner.clean(text)

      # Step 1: Extract actors (using pre-cleaned text)
      actor_start = System.monotonic_time(:microsecond)

      %{actors: actors, actors_gvt: actors_gvt} =
        DutyActor.get_actors_in_text_cleaned(cleaned_text)

      actor_duration = System.monotonic_time(:microsecond) - actor_start

      # Step 2: Build record with actors for DutyType processing
      record = %{
        text: cleaned_text,
        role: actors,
        role_gvt: actors_gvt
      }

      # Step 3: Classify duty types and find role holders
      duty_type_start = System.monotonic_time(:microsecond)
      record = DutyType.process_record(record)
      duty_type_duration = System.monotonic_time(:microsecond) - duty_type_start

      # Step 4 & 5: Run POPIMAR and PurposeClassifier in parallel
      # POPIMAR only runs for "Making" laws (those with Duty or Responsibility)
      {record, popimar_duration, purpose, purpose_duration} =
        run_popimar_and_purpose_parallel(record, cleaned_text)

      popimar_skipped = not is_making_law?(record)

      total_duration = System.monotonic_time(:microsecond) - start_time

      # Emit telemetry for performance monitoring
      :telemetry.execute(
        [:taxa, :classify, :complete],
        %{
          duration_us: total_duration,
          actor_duration_us: actor_duration,
          duty_type_duration_us: duty_type_duration,
          popimar_duration_us: popimar_duration,
          purpose_duration_us: purpose_duration,
          text_length: text_length
        },
        %{
          law_name: law_name,
          source: source,
          actor_count: length(actors) + length(actors_gvt),
          duty_type_count: length(Map.get(record, :duty_type, [])),
          popimar_count: length(Map.get(record, :popimar, [])),
          popimar_skipped: popimar_skipped,
          large_law: is_large_law
        }
      )

      # Always log timing for performance monitoring
      # Log to both Logger and IO for visibility in terminal
      large_law_marker = if is_large_law, do: " [LARGE]", else: ""

      timing_msg =
        "[Taxa]#{large_law_marker} #{text_length} chars in #{div(total_duration, 1000)}ms " <>
          "(actor: #{div(actor_duration, 1000)}ms, duty_type: #{div(duty_type_duration, 1000)}ms, " <>
          "popimar: #{div(popimar_duration, 1000)}ms#{if popimar_skipped, do: " [skipped]", else: ""}, " <>
          "purpose: #{div(purpose_duration, 1000)}ms)"

      # IO.puts for immediate terminal visibility
      IO.puts("    #{timing_msg}")

      # Logger for structured logging (warning level for slow parses)
      if total_duration > 5_000_000 do
        Logger.warning(timing_msg)
      else
        Logger.info(timing_msg)
      end

      # Build result map with all Taxa fields
      # Phase 2b: DutyType now produces both legacy text and JSONB directly
      %{
        # Actor fields
        role: actors,
        role_gvt: actors_gvt,

        # Duty type field
        duty_type: Map.get(record, :duty_type, []),

        # Purpose field (function-based classification)
        purpose: purpose,

        # Role holder fields (lists)
        duty_holder: Map.get(record, :duty_holder),
        rights_holder: Map.get(record, :rights_holder),
        responsibility_holder: Map.get(record, :responsibility_holder),
        power_holder: Map.get(record, :power_holder),

        # Legacy text fields (for backwards compatibility)
        duty_holder_article_clause: Map.get(record, :duty_holder_article_clause),
        rights_holder_article_clause: Map.get(record, :rights_holder_article_clause),
        responsibility_holder_article_clause:
          Map.get(record, :responsibility_holder_article_clause),
        power_holder_article_clause: Map.get(record, :power_holder_article_clause),

        # Phase 2b: JSONB fields now produced directly by DutyType (no text parsing)
        duties: Map.get(record, :duties),
        rights: Map.get(record, :rights),
        responsibilities: Map.get(record, :responsibilities),
        powers: Map.get(record, :powers),

        # POPIMAR field (list of categories)
        popimar: Map.get(record, :popimar),
        # Phase 2 Issue #15: POPIMAR JSONB (no article context in non-chunked path)
        popimar_details: TaxaFormatter.popimar_to_jsonb(Map.get(record, :popimar), []),

        # Phase 2 Issue #16: Role JSONB (no article context in non-chunked path)
        role_details: TaxaFormatter.roles_to_jsonb(actors, []),
        role_gvt_details: TaxaFormatter.roles_to_jsonb(actors_gvt, []),

        # Metadata about the classification
        taxa_text_source: source,
        taxa_text_length: text_length
      }
    end
  end

  # ============================================================================
  # Chunked Processing for Large Laws (Phase 6)
  # ============================================================================

  @doc """
  Classify a large law using P1 (Section) chunking with parallel processing.

  For large laws (>50KB) with P1 tags, this function:
  1. Extracts actors from the full text (actors span sections)
  2. Processes each P1 section in parallel for DutyType classification
  3. Merges results with deduplication

  This is more efficient than modal windowing because:
  - Each P1 section is typically ~2KB (below windowing threshold)
  - Sections can be processed in parallel across CPU cores
  - Natural legal boundaries prevent cross-contamination

  ## Options
  - `:law_name` - Law identifier for telemetry
  """
  @spec classify_text_chunked(binary(), term(), list(), keyword()) :: map()
  def classify_text_chunked(text, source, p1_sections, opts \\ [])

  def classify_text_chunked(text, source, p1_sections, opts) do
    law_name = Keyword.get(opts, :law_name)
    text_length = String.length(text)
    section_count = length(p1_sections)
    start_time = System.monotonic_time(:microsecond)

    Logger.info(
      "[Taxa] Using P1 chunking: #{section_count} sections for #{law_name || "unknown"}"
    )

    IO.puts("    📦 P1 chunking: #{section_count} sections (#{text_length} chars total)")

    # Step 0: Apply unified blacklist to full text
    cleaned_text = TextCleaner.clean(text)

    # Step 1: Extract actors from FULL text (actors span sections)
    # This ensures we find all actors mentioned anywhere in the law
    actor_start = System.monotonic_time(:microsecond)

    %{actors: actors, actors_gvt: actors_gvt} =
      DutyActor.get_actors_in_text_cleaned(cleaned_text)

    actor_duration = System.monotonic_time(:microsecond) - actor_start

    # Step 2: Process P1 sections in parallel for DutyType, POPIMAR, and Roles
    # All now run per-section with article context for proper JSONB population
    duty_type_start = System.monotonic_time(:microsecond)

    duty_type_results =
      p1_sections
      |> Task.async_stream(
        fn {section_id, section_text} ->
          # Clean section text and build record
          cleaned_section = TextCleaner.clean(section_text)

          # Issue #16: Extract actors PER-SECTION with article context
          %{actors: section_actors, actors_gvt: section_actors_gvt} =
            DutyActor.get_actors_in_text_cleaned(cleaned_section)

          record = %{
            text: cleaned_section,
            role: section_actors,
            role_gvt: section_actors_gvt
          }

          # Process this section with article context (section_id)
          # DutyType adds duties/rights/responsibilities/powers with article
          duty_type_result = DutyType.process_record(record, article: section_id)

          # POPIMAR also runs per-section with article context (Issue #15 fix)
          # This populates popimar_details entries with the correct article reference
          popimar_result = Popimar.process_record(duty_type_result, article: section_id)

          # Issue #16: Add role JSONB fields with article context
          popimar_result
          |> Map.put(
            :role_details,
            TaxaFormatter.roles_to_jsonb(section_actors, article: section_id)
          )
          |> Map.put(
            :role_gvt_details,
            TaxaFormatter.roles_to_jsonb(section_actors_gvt, article: section_id)
          )
        end,
        max_concurrency: System.schedulers_online(),
        timeout: 30_000
      )
      |> Enum.reduce(empty_duty_type_result(), &merge_duty_type_results/2)

    duty_type_duration = System.monotonic_time(:microsecond) - duty_type_start

    # Step 3: Build merged record for POPIMAR and Purpose
    merged_record = %{
      text: cleaned_text,
      role: actors,
      role_gvt: actors_gvt,
      duty_type: duty_type_results.duty_type,
      duty_holder: duty_type_results.duty_holder,
      rights_holder: duty_type_results.rights_holder,
      responsibility_holder: duty_type_results.responsibility_holder,
      power_holder: duty_type_results.power_holder,
      duty_holder_article_clause: duty_type_results.duty_holder_article_clause,
      rights_holder_article_clause: duty_type_results.rights_holder_article_clause,
      responsibility_holder_article_clause:
        duty_type_results.responsibility_holder_article_clause,
      power_holder_article_clause: duty_type_results.power_holder_article_clause
    }

    # Step 4: Run Purpose only (POPIMAR is now handled per-section in Step 2)
    # Issue #15: POPIMAR moved to per-section processing for article context
    {purpose, purpose_duration} = run_purpose_classification(cleaned_text)

    # POPIMAR duration is now included in duty_type_duration since it runs per-section
    popimar_duration = 0
    popimar_skipped = duty_type_results.popimar == []
    total_duration = System.monotonic_time(:microsecond) - start_time

    # Emit telemetry
    :telemetry.execute(
      [:taxa, :classify, :complete],
      %{
        duration_us: total_duration,
        actor_duration_us: actor_duration,
        duty_type_duration_us: duty_type_duration,
        popimar_duration_us: popimar_duration,
        purpose_duration_us: purpose_duration,
        text_length: text_length
      },
      %{
        law_name: law_name,
        source: source,
        actor_count: length(actors) + length(actors_gvt),
        duty_type_count: length(duty_type_results.duty_type),
        popimar_count: length(duty_type_results.popimar),
        popimar_skipped: popimar_skipped,
        large_law: true,
        chunked: true,
        section_count: section_count
      }
    )

    # Log timing
    timing_msg =
      "[Taxa] [CHUNKED #{section_count}] #{text_length} chars in #{div(total_duration, 1000)}ms " <>
        "(actor: #{div(actor_duration, 1000)}ms, duty_type: #{div(duty_type_duration, 1000)}ms, " <>
        "popimar: #{div(popimar_duration, 1000)}ms#{if popimar_skipped, do: " [skipped]", else: ""}, " <>
        "purpose: #{div(purpose_duration, 1000)}ms)"

    IO.puts("    #{timing_msg}")

    if total_duration > 5_000_000 do
      Logger.warning(timing_msg)
    else
      Logger.info(timing_msg)
    end

    # Build result
    # Phase 4: Only JSONB fields are persisted (legacy text fields removed)
    %{
      # Role lists: Use full-text actors (more comprehensive - catches actors mentioned outside sections)
      # Role JSONB: Use per-section actors (provides article context)
      role: actors,
      role_gvt: actors_gvt,
      duty_type: Map.get(merged_record, :duty_type, []),
      purpose: purpose,
      duty_holder: Map.get(merged_record, :duty_holder),
      rights_holder: Map.get(merged_record, :rights_holder),
      responsibility_holder: Map.get(merged_record, :responsibility_holder),
      power_holder: Map.get(merged_record, :power_holder),

      # Consolidated JSONB holder fields (Phase 4) - get from duty_type_results, not merged_record
      duties: duty_type_results.duties,
      rights: duty_type_results.rights,
      responsibilities: duty_type_results.responsibilities,
      powers: duty_type_results.powers,
      # POPIMAR field (list of categories) - merged from per-section results
      popimar: duty_type_results.popimar,
      # Issue #15: POPIMAR JSONB with article context - merged from per-section results
      popimar_details: duty_type_results.popimar_details,
      # Issue #16: Role JSONB with article context - merged from per-section results
      role_details: duty_type_results.role_details,
      role_gvt_details: duty_type_results.role_gvt_details,
      taxa_text_source: source,
      taxa_text_length: text_length
    }
  end

  # Empty result for duty type merging
  defp empty_duty_type_result do
    %{
      duty_type: [],
      duty_holder: [],
      rights_holder: [],
      responsibility_holder: [],
      power_holder: [],
      duty_holder_article_clause: "",
      rights_holder_article_clause: "",
      responsibility_holder_article_clause: "",
      power_holder_article_clause: "",
      # Phase 2b: JSONB fields
      duties: nil,
      rights: nil,
      responsibilities: nil,
      powers: nil,
      # Issue #15: POPIMAR per-section with article context
      popimar: [],
      popimar_details: nil,
      # Issue #16: Role per-section with article context
      role: [],
      role_gvt: [],
      role_details: nil,
      role_gvt_details: nil
    }
  end

  # Merge duty type results from parallel section processing
  defp merge_duty_type_results({:ok, section_result}, acc) do
    %{
      duty_type: Enum.uniq(acc.duty_type ++ (Map.get(section_result, :duty_type) || [])),
      duty_holder: Enum.uniq(acc.duty_holder ++ (Map.get(section_result, :duty_holder) || [])),
      rights_holder:
        Enum.uniq(acc.rights_holder ++ (Map.get(section_result, :rights_holder) || [])),
      responsibility_holder:
        Enum.uniq(
          acc.responsibility_holder ++ (Map.get(section_result, :responsibility_holder) || [])
        ),
      power_holder: Enum.uniq(acc.power_holder ++ (Map.get(section_result, :power_holder) || [])),
      duty_holder_article_clause:
        merge_article_clauses(
          acc.duty_holder_article_clause,
          Map.get(section_result, :duty_holder_article_clause)
        ),
      rights_holder_article_clause:
        merge_article_clauses(
          acc.rights_holder_article_clause,
          Map.get(section_result, :rights_holder_article_clause)
        ),
      responsibility_holder_article_clause:
        merge_article_clauses(
          acc.responsibility_holder_article_clause,
          Map.get(section_result, :responsibility_holder_article_clause)
        ),
      power_holder_article_clause:
        merge_article_clauses(
          acc.power_holder_article_clause,
          Map.get(section_result, :power_holder_article_clause)
        ),
      # Phase 2b: Merge JSONB fields
      duties: merge_jsonb_fields(acc.duties, Map.get(section_result, :duties)),
      rights: merge_jsonb_fields(acc.rights, Map.get(section_result, :rights)),
      responsibilities:
        merge_jsonb_fields(acc.responsibilities, Map.get(section_result, :responsibilities)),
      powers: merge_jsonb_fields(acc.powers, Map.get(section_result, :powers)),
      # Issue #15: Merge POPIMAR per-section results
      popimar: Enum.uniq(acc.popimar ++ (Map.get(section_result, :popimar) || [])),
      popimar_details:
        merge_popimar_jsonb(acc.popimar_details, Map.get(section_result, :popimar_details)),
      # Issue #16: Merge role per-section results
      role: Enum.uniq(acc.role ++ (Map.get(section_result, :role) || [])),
      role_gvt: Enum.uniq(acc.role_gvt ++ (Map.get(section_result, :role_gvt) || [])),
      role_details: merge_roles_jsonb(acc.role_details, Map.get(section_result, :role_details)),
      role_gvt_details:
        merge_roles_jsonb(acc.role_gvt_details, Map.get(section_result, :role_gvt_details))
    }
  end

  defp merge_duty_type_results({:exit, _reason}, acc), do: acc

  # Issue #15: Merge POPIMAR JSONB fields (binary merge for reduce)
  defp merge_popimar_jsonb(nil, nil), do: nil
  defp merge_popimar_jsonb(nil, new), do: new
  defp merge_popimar_jsonb(acc, nil), do: acc

  defp merge_popimar_jsonb(acc, new) when is_map(acc) and is_map(new) do
    acc_entries = Map.get(acc, "entries", [])
    new_entries = Map.get(new, "entries", [])

    # Deduplicate by category+article combination
    merged_entries =
      Enum.uniq_by(acc_entries ++ new_entries, fn e -> {e["category"], e["article"]} end)

    if merged_entries == [] do
      nil
    else
      categories = merged_entries |> Enum.map(& &1["category"]) |> Enum.uniq() |> Enum.sort()

      articles =
        merged_entries
        |> Enum.map(& &1["article"])
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        "entries" => merged_entries,
        "categories" => categories,
        "articles" => articles
      }
    end
  end

  # Issue #16: Merge Role JSONB fields (binary merge for reduce)
  defp merge_roles_jsonb(nil, nil), do: nil
  defp merge_roles_jsonb(nil, new), do: new
  defp merge_roles_jsonb(acc, nil), do: acc

  defp merge_roles_jsonb(acc, new) when is_map(acc) and is_map(new) do
    acc_entries = Map.get(acc, "entries", [])
    new_entries = Map.get(new, "entries", [])

    # Deduplicate by role+article combination
    merged_entries =
      Enum.uniq_by(acc_entries ++ new_entries, fn e -> {e["role"], e["article"]} end)

    if merged_entries == [] do
      nil
    else
      roles = merged_entries |> Enum.map(& &1["role"]) |> Enum.uniq() |> Enum.sort()

      articles =
        merged_entries
        |> Enum.map(& &1["article"])
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        "entries" => merged_entries,
        "roles" => roles,
        "articles" => articles
      }
    end
  end

  # Merge article clause strings
  defp merge_article_clauses(acc, nil), do: acc
  defp merge_article_clauses(acc, ""), do: acc
  defp merge_article_clauses("", new), do: new
  defp merge_article_clauses(acc, new), do: acc <> "\n" <> new

  # Phase 2b: Merge JSONB holder fields
  defp merge_jsonb_fields(nil, nil), do: nil
  defp merge_jsonb_fields(nil, new), do: new
  defp merge_jsonb_fields(acc, nil), do: acc

  defp merge_jsonb_fields(acc, new) when is_map(acc) and is_map(new) do
    acc_entries = Map.get(acc, "entries", [])
    new_entries = Map.get(new, "entries", [])
    merged_entries = Enum.uniq(acc_entries ++ new_entries)

    if merged_entries == [] do
      nil
    else
      holders = merged_entries |> Enum.map(& &1["holder"]) |> Enum.uniq() |> Enum.sort()

      articles =
        merged_entries
        |> Enum.map(& &1["article"])
        |> Enum.filter(& &1)
        |> Enum.uniq()
        |> Enum.sort()

      %{
        "entries" => merged_entries,
        "holders" => holders,
        "articles" => articles
      }
    end
  end

  # ============================================================================
  # Text Fetching
  # ============================================================================

  # Fetch law text from legislation.gov.uk
  # Uses body text as primary source (contains full law text for comprehensive actor detection)
  # Falls back to introduction if body is not available
  # Returns {:ok, text, source} or {:ok, text, source, p1_sections} for large laws
  defp fetch_law_text(type_code, year, number) do
    # Use body text as primary source - this is where all actors/roles are mentioned
    # The legacy code parsed the full body text for actor extraction
    case fetch_body_text(type_code, year, number) do
      {:ok, text, p1_sections} when text != "" ->
        # Law with P1 sections - enables article field population
        {:ok, text, "body", p1_sections}

      {:ok, text} when text != "" ->
        {:ok, text, "body"}

      _ ->
        # Fallback to introduction if body not available
        case fetch_introduction_text(type_code, year, number) do
          {:ok, text} when text != "" ->
            {:ok, text, "introduction"}

          _ ->
            {:error, "Could not fetch law text from any source"}
        end
    end
  end

  # Fetch introduction/preamble text
  defp fetch_introduction_text(type_code, year, number) do
    # Try /made/ path first (for SIs), then without
    paths = [
      "/#{type_code}/#{year}/#{number}/introduction/made/data.xml",
      "/#{type_code}/#{year}/#{number}/introduction/data.xml"
    ]

    Enum.reduce_while(paths, {:error, "Not found"}, fn path, _acc ->
      case Client.fetch_xml(path) do
        {:ok, xml} ->
          text = extract_text_from_xml(xml)
          if text != "", do: {:halt, {:ok, text}}, else: {:cont, {:error, "Empty text"}}

        {:error, _, _} ->
          {:cont, {:error, "Not found"}}
      end
    end)
  end

  # Fetch body text (first few sections)
  # Returns {:ok, text} or {:ok, text, p1_sections} for large laws with P1 tags
  defp fetch_body_text(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        text = extract_text_from_xml(xml)

        # Always extract P1 sections for article field population
        # Large laws use chunked parallel processing, small laws use sequential
        p1_sections = extract_p1_sections(xml)

        if p1_sections != [] do
          {:ok, text, p1_sections}
        else
          # No P1 tags - return just text (will use modal windowing for large laws)
          {:ok, text}
        end

      {:error, _, _} ->
        {:error, "Body not found"}
    end
  end

  # Extract text from each P1 (Section) element for chunked processing
  # Returns list of {section_id, section_text} tuples
  defp extract_p1_sections(xml) do
    try do
      xml
      |> xpath(~x"//P1"l)
      |> Enum.with_index()
      |> Enum.map(fn {p1_node, index} ->
        section_id = extract_section_id(p1_node, index)
        section_text = extract_text_from_node(p1_node)
        {section_id, section_text}
      end)
      |> Enum.reject(fn {_id, text} -> String.trim(text) == "" end)
    rescue
      _ -> []
    end
  end

  # Extract section ID from P1 node attributes or use index
  defp extract_section_id(p1_node, index) do
    case xpath(p1_node, ~x"./@id"s) do
      "" -> "section-#{index}"
      nil -> "section-#{index}"
      id -> id
    end
  end

  # Extract text from a single XML node (P1 section)
  defp extract_text_from_node(node) do
    try do
      texts =
        (xpath_texts(node, ~x".//Para//text()"ls) ++
           xpath_texts(node, ~x".//Text//text()"ls) ++
           xpath_texts(node, ~x".//P//text()"ls) ++
           xpath_texts(node, ~x".//Pnumber//text()"ls))
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(" ")

      texts
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    rescue
      _ -> ""
    end
  end

  # Extract text content from XML document
  defp extract_text_from_xml(xml) do
    try do
      # Extract all Para and Text elements and concatenate
      texts =
        (xpath_texts(xml, ~x"//Para//text()"ls) ++
           xpath_texts(xml, ~x"//Text//text()"ls) ++
           xpath_texts(xml, ~x"//P//text()"ls) ++
           xpath_texts(xml, ~x"//Pnumber//text()"ls) ++
           xpath_texts(xml, ~x"//CommentaryText//text()"ls))
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join(" ")

      # Clean up whitespace
      texts
      |> String.replace(~r/\s+/, " ")
      |> String.trim()
    rescue
      _ -> ""
    end
  end

  defp xpath_texts(xml, path) do
    case SweetXml.xpath(xml, path) do
      nil -> []
      texts when is_list(texts) -> Enum.map(texts, &to_string/1)
      text -> [to_string(text)]
    end
  end

  # ============================================================================
  # POPIMAR + Purpose Parallel Processing
  # ============================================================================

  # Runs POPIMAR and PurposeClassifier in parallel for performance.
  # Run Purpose classification only (used by chunked mode where POPIMAR is per-section)
  defp run_purpose_classification(text) do
    start = System.monotonic_time(:microsecond)
    result = PurposeClassifier.classify(text)
    duration = System.monotonic_time(:microsecond) - start
    {result, duration}
  end

  # POPIMAR is only run for "Making" laws (those with Duty or Responsibility).
  # Non-making laws (Amending, Commencing, Revoking) don't need POPIMAR classification.
  defp run_popimar_and_purpose_parallel(record, text) do
    is_making = is_making_law?(record)

    # Start PurposeClassifier task (always runs)
    purpose_task =
      Task.async(fn ->
        start = System.monotonic_time(:microsecond)
        result = PurposeClassifier.classify(text)
        duration = System.monotonic_time(:microsecond) - start
        {result, duration}
      end)

    # Run POPIMAR only for Making laws, or return empty
    {record, popimar_duration} =
      if is_making do
        popimar_start = System.monotonic_time(:microsecond)
        updated_record = Popimar.process_record(record)
        popimar_duration = System.monotonic_time(:microsecond) - popimar_start
        {updated_record, popimar_duration}
      else
        # Skip POPIMAR for non-Making laws
        {Map.put(record, :popimar, []), 0}
      end

    # Await PurposeClassifier result
    {purpose, purpose_duration} = Task.await(purpose_task, 30_000)

    {record, popimar_duration, purpose, purpose_duration}
  end

  # A "Making" law creates substantive duties/responsibilities.
  # This is determined by duty_type containing "Duty" or "Responsibility".
  # Laws with only "Right" or "Power" are not "Making" - they grant permissions
  # but don't impose management obligations that POPIMAR would classify.
  defp is_making_law?(record) do
    duty_types = Map.get(record, :duty_type, [])
    "Duty" in duty_types or "Responsibility" in duty_types
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp empty_result(source) do
    %{
      role: [],
      role_gvt: nil,
      duty_type: [],
      purpose: [],
      duty_holder: nil,
      rights_holder: nil,
      responsibility_holder: nil,
      power_holder: nil,
      popimar: nil,
      popimar_details: nil,
      taxa_text_source: source,
      taxa_text_length: 0
    }
  end
end

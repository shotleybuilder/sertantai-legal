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
          popimar: map() | nil,
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
        # Large law with P1 sections - use chunked parallel processing
        taxa_data = classify_text_chunked(text, source, p1_sections, law_name: law_name)
        {:ok, taxa_data}

      {:ok, text, source} ->
        # Normal law or large law without P1 tags - use standard processing
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

      # Extract legacy text fields from record
      duty_text = Map.get(record, :duty_holder_article_clause)
      rights_text = Map.get(record, :rights_holder_article_clause)
      responsibility_text = Map.get(record, :responsibility_holder_article_clause)
      power_text = Map.get(record, :power_holder_article_clause)

      # Build result map with all Taxa fields
      # Note: Don't wrap in to_jsonb() - ParsedLaw handles JSONB conversion
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
        duty_holder_article_clause: duty_text,
        rights_holder_article_clause: rights_text,
        responsibility_holder_article_clause: responsibility_text,
        power_holder_article_clause: power_text,

        # NEW: Consolidated JSONB fields (Phase 2a dual-write)
        duties: TaxaFormatter.duties_to_jsonb(duty_text),
        rights: TaxaFormatter.rights_to_jsonb(rights_text),
        responsibilities: TaxaFormatter.responsibilities_to_jsonb(responsibility_text),
        powers: TaxaFormatter.powers_to_jsonb(power_text),

        # POPIMAR field
        popimar: Map.get(record, :popimar),

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

    # Step 2: Process P1 sections in parallel for DutyType
    duty_type_start = System.monotonic_time(:microsecond)

    duty_type_results =
      p1_sections
      |> Task.async_stream(
        fn {_section_id, section_text} ->
          # Clean section text and build record
          cleaned_section = TextCleaner.clean(section_text)

          record = %{
            text: cleaned_section,
            role: actors,
            role_gvt: actors_gvt
          }

          # Process this section
          DutyType.process_record(record)
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

    # Step 4: Run POPIMAR and Purpose in parallel (same as non-chunked)
    {merged_record, popimar_duration, purpose, purpose_duration} =
      run_popimar_and_purpose_parallel(merged_record, cleaned_text)

    popimar_skipped = not is_making_law?(merged_record)
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
        duty_type_count: length(Map.get(merged_record, :duty_type, [])),
        popimar_count: length(Map.get(merged_record, :popimar, [])),
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

    # Extract legacy text fields from merged record
    duty_text = Map.get(merged_record, :duty_holder_article_clause)
    rights_text = Map.get(merged_record, :rights_holder_article_clause)
    responsibility_text = Map.get(merged_record, :responsibility_holder_article_clause)
    power_text = Map.get(merged_record, :power_holder_article_clause)

    # Build result
    %{
      role: actors,
      role_gvt: actors_gvt,
      duty_type: Map.get(merged_record, :duty_type, []),
      purpose: purpose,
      duty_holder: Map.get(merged_record, :duty_holder),
      rights_holder: Map.get(merged_record, :rights_holder),
      responsibility_holder: Map.get(merged_record, :responsibility_holder),
      power_holder: Map.get(merged_record, :power_holder),

      # Legacy text fields (for backwards compatibility)
      duty_holder_article_clause: duty_text,
      rights_holder_article_clause: rights_text,
      responsibility_holder_article_clause: responsibility_text,
      power_holder_article_clause: power_text,

      # NEW: Consolidated JSONB fields (Phase 2a dual-write)
      duties: TaxaFormatter.duties_to_jsonb(duty_text),
      rights: TaxaFormatter.rights_to_jsonb(rights_text),
      responsibilities: TaxaFormatter.responsibilities_to_jsonb(responsibility_text),
      powers: TaxaFormatter.powers_to_jsonb(power_text),
      popimar: Map.get(merged_record, :popimar),
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
      power_holder_article_clause: ""
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
        )
    }
  end

  defp merge_duty_type_results({:exit, _reason}, acc), do: acc

  # Merge article clause strings
  defp merge_article_clauses(acc, nil), do: acc
  defp merge_article_clauses(acc, ""), do: acc
  defp merge_article_clauses("", new), do: new
  defp merge_article_clauses(acc, new), do: acc <> "\n" <> new

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
        # Large law with P1 sections for chunked processing
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
        text_length = String.length(text)

        # For large laws, also extract P1 sections for chunked processing
        if large_law?(text_length) do
          p1_sections = extract_p1_sections(xml)

          if p1_sections != [] do
            {:ok, text, p1_sections}
          else
            # No P1 tags - return just text (will use modal windowing fallback)
            {:ok, text}
          end
        else
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
      taxa_text_source: source,
      taxa_text_length: 0
    }
  end
end

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
  alias SertantaiLegal.Legal.Taxa.{DutyActor, DutyType, Popimar, PurposeClassifier, TextCleaner}

  require Logger
  import SweetXml

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
      {:ok, text, source} ->
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
      start_time = System.monotonic_time(:microsecond)

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
          popimar_skipped: popimar_skipped
        }
      )

      # Always log timing for performance monitoring
      # Log to both Logger and IO for visibility in terminal
      timing_msg =
        "[Taxa] #{text_length} chars in #{div(total_duration, 1000)}ms " <>
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
      # Note: Don't wrap in to_jsonb() - ParsedLaw handles JSONB conversion
      %{
        # Actor fields
        role: actors,
        role_gvt: actors_gvt,

        # Duty type field
        duty_type: Map.get(record, :duty_type, []),

        # Purpose field (function-based classification)
        purpose: purpose,

        # Role holder fields
        duty_holder: Map.get(record, :duty_holder),
        rights_holder: Map.get(record, :rights_holder),
        responsibility_holder: Map.get(record, :responsibility_holder),
        power_holder: Map.get(record, :power_holder),

        # POPIMAR field
        popimar: Map.get(record, :popimar),

        # Metadata about the classification
        taxa_text_source: source,
        taxa_text_length: text_length
      }
    end
  end

  # ============================================================================
  # Text Fetching
  # ============================================================================

  # Fetch law text from legislation.gov.uk
  # Uses body text as primary source (contains full law text for comprehensive actor detection)
  # Falls back to introduction if body is not available
  defp fetch_law_text(type_code, year, number) do
    # Use body text as primary source - this is where all actors/roles are mentioned
    # The legacy code parsed the full body text for actor extraction
    case fetch_body_text(type_code, year, number) do
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
  defp fetch_body_text(type_code, year, number) do
    path = "/#{type_code}/#{year}/#{number}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} ->
        text = extract_text_from_xml(xml)
        {:ok, text}

      {:error, _, _} ->
        {:error, "Body not found"}
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

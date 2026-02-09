defmodule SertantaiLegal.Legal.Taxa.DutyTypeLib do
  @moduledoc """
  Utility functions for duty type (role-based) classification.

  This module provides the core logic for finding role holders
  (duty holders, rights holders, responsibility holders, power holders) in legal text.

  Note: For function-based classification (purpose), see `PurposeClassifier`.

  ## Processing Flow

  1. Text is first cleaned with `blacklist/1` to remove false positive patterns
  2. `find_role_holders/4` searches for actor-specific duties/rights/responsibilities/powers
  3. Results identify which actors have which roles

  ## Example

      iex> DutyTypeLib.find_role_holders(:duty, ["Org: Employer"], "The employer shall ensure...", [])
      {["Org: Employer"], ["Duty"], "DUTY\\n👤Org: Employer\\n📌...", [...]}
  """

  alias SertantaiLegal.Legal.Taxa.{
    ActorLib,
    ClauseRefiner,
    DutyTypeDefnGoverned,
    DutyTypeDefnGovernment,
    DutyTypeDefnGovernmentV2
  }

  # Pattern version configuration
  # :v1 - Legacy patterns (unbounded pre-modal capture, no action capture)
  # :v2 - Improved patterns (limited pre-modal, capture groups for action)
  @default_pattern_version :v2

  @type duty_types :: list(String.t())
  @type actors :: list(String.t())
  @type text :: String.t()
  @type role :: :duty | :right | :responsibility | :power

  # Threshold for using modal-based windowed search optimization (in characters)
  # For texts larger than this, we find modal verb positions first and only
  # search in windows around those modals instead of the full text.
  @windowed_search_threshold 50_000

  # Window size around each modal verb mention
  # Before: needs to capture actor that precedes the modal (e.g., "The employer shall")
  # After: needs to capture verb phrase after modal (e.g., "shall ensure safety")
  @modal_window_before 400
  @modal_window_after 200

  # Pre-compiled modal verb pattern for finding duty/right locations
  # These are the verbs that indicate obligations or permissions in legal text
  @modal_pattern ~r/\b(?:shall|must|may(?:\s+not|\s+only)?)\b/i

  # Additional anchor patterns for non-modal duty/right indicators
  # These patterns don't use shall/must/may but still indicate duties or rights
  @non_modal_anchors ~r/\b(?:is\s+(?:liable|responsible|entitled|required)|remains\s+responsible|has\s+(?:the\s+)?duty|owes\s+a\s+duty|under\s+a\s+(?:like\s+)?duty)\b/i

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Finds role holders of a specific type in legal text.

  Returns a tuple of:
  - List of actor names found with that role
  - List containing the role type ("Duty", "Right", etc.) if found
  - Formatted string of matches for debugging/display
  - Accumulated regex patterns used

  ## Parameters

  - `role`: One of `:duty`, `:right`, `:responsibility`, `:power`
  - `actors`: List of actor names to search for
  - `text`: The legal text to search (will have blacklist applied internally)
  - `regexes`: Accumulated regex patterns (for debugging)

  Note: If text has already been cleaned by TextCleaner.clean/1, the internal
  blacklist is still applied but will have minimal effect (patterns already removed).
  For optimal performance with pre-cleaned text, the blacklist step is lightweight
  since patterns won't match.
  """
  @type match_entry :: %{
          holder: String.t(),
          duty_type: String.t(),
          clause: String.t() | nil
        }

  @spec find_role_holders(role(), actors(), text(), list()) ::
          {actors(), duty_types(), list(match_entry()), list()}
  def find_role_holders(_role, [], _text, regexes), do: {[], [], [], regexes}

  def find_role_holders(role, actors, text, regexes) when is_list(actors) do
    # Build actor-specific regex library
    actors_regex =
      case role do
        r when r in [:duty, :right] -> ActorLib.custom_actor_library(actors, :governed)
        _ -> ActorLib.custom_actor_library(actors, :government)
      end

    # Build role-specific patterns for each actor
    # Use V2 patterns for government roles (responsibility/power) when configured
    pattern_version = get_pattern_version()

    regex_lib =
      case {role, pattern_version} do
        {:duty, _} ->
          build_lib(actors_regex, &DutyTypeDefnGoverned.duty/1)

        {:right, _} ->
          build_lib(actors_regex, &DutyTypeDefnGoverned.right/1)

        {:responsibility, :v2} ->
          build_lib(actors_regex, &DutyTypeDefnGovernmentV2.responsibility/1)

        {:responsibility, _} ->
          build_lib(actors_regex, &DutyTypeDefnGovernment.responsibility/1)

        {:power, :v2} ->
          build_lib(actors_regex, &DutyTypeDefnGovernmentV2.power_conferred/1)

        {:power, _} ->
          build_lib(actors_regex, &DutyTypeDefnGovernment.power_conferred/1)
      end

    # Apply blacklist (lightweight if text already cleaned by TextCleaner)
    # Note: The unified blacklist in TextCleaner includes these patterns,
    # so this is effectively a no-op when called from taxa_parser pipeline
    cleaned_text = blacklist(text)
    label = role |> Atom.to_string() |> String.upcase()

    # Use modal-based windowed search for large texts to dramatically reduce regex processing
    # Instead of searching the full text for each pattern, we:
    # 1. Find all modal verb positions (shall, must, may)
    # 2. Create windows around those positions
    # 3. Only run patterns against those windows
    result =
      if use_windowed_search?(cleaned_text) do
        run_modal_windowed_search({cleaned_text, [], [], regexes}, regex_lib, label, cleaned_text)
      else
        run_role_regex({cleaned_text, [], [], regexes}, regex_lib, label)
      end

    case result do
      {_, [], _, regexes} ->
        {[], [], [], regexes}

      {_, role_holders, matches, regexes} ->
        # Deduplicate matches - when same clause captured for different holders,
        # keep only the most specific holder (longest holder name wins)
        deduplicated_matches = deduplicate_by_clause(matches)

        {
          Enum.uniq(role_holders),
          role |> Atom.to_string() |> String.capitalize() |> List.wrap(),
          deduplicated_matches,
          regexes
        }
    end
  end

  # Deduplicates and filters matches to remove false positives.
  #
  # Two issues addressed:
  # 1. Multiple actors matching the same clause - keep most specific holder
  # 2. Actor mentioned in text but not the subject of "must" - filter out
  #
  # Example: "Scottish Environment Protection Agency" pattern matches text containing
  # "SEPA" in a list, but the clause is "planning authority must..." - this is a
  # false positive for SEPA.
  defp deduplicate_by_clause(matches) do
    matches
    # First, filter out false positives where holder doesn't match clause subject
    |> Enum.filter(&holder_matches_clause_subject?/1)
    # Then group by similar clauses and keep most specific
    |> Enum.group_by(fn %{duty_type: d, clause: c} -> {d, normalize_clause_for_grouping(c)} end)
    |> Enum.map(fn {_key, group} ->
      # Pick the most specific holder (longest name = more specific)
      Enum.max_by(group, fn %{holder: h} -> String.length(h) end)
    end)
  end

  # Check if the holder matches the subject of the responsibility in the clause.
  # Returns false if the clause says "X must..." but the holder is Y.
  defp holder_matches_clause_subject?(%{holder: holder, clause: clause}) do
    # Extract the actor type from holder (e.g., "Authority" from "Gvt: Authority: Planning")
    holder_keywords = extract_holder_keywords(holder)

    # Find what appears before "must" or "shall" in the clause
    case Regex.run(~r/(\w+(?:\s+\w+)?)\s+(?:must|shall)/i, clause) do
      [_, subject] ->
        # Check if any holder keyword matches the subject
        subject_lower = String.downcase(subject)
        Enum.any?(holder_keywords, fn kw -> String.contains?(subject_lower, kw) end)

      nil ->
        # No clear subject found - keep the match
        true
    end
  end

  # Extract keywords from holder name for matching
  defp extract_holder_keywords(holder) do
    holder
    |> String.downcase()
    |> String.split(~r/[:\s]+/)
    |> Enum.reject(&(&1 in ["gvt", "org", "ind", "spc", "sc", ""]))
    |> Enum.flat_map(fn
      "authority" -> ["authority", "authorities"]
      "planning" -> ["planning"]
      "local" -> ["local"]
      "waste" -> ["waste", "disposal"]
      "agency" -> ["agency"]
      "minister" -> ["minister", "ministers", "scottish ministers"]
      "environment" -> ["environment", "environmental"]
      "protection" -> ["protection"]
      "scottish" -> ["scottish"]
      other -> [other]
    end)
  end

  # Normalize clause for grouping - extract the core "subject must action" part
  defp normalize_clause_for_grouping(clause) do
    # Find the "X must Y" core pattern and use that for grouping
    case Regex.run(~r/(\w+(?:\s+\w+)?)\s+(must|shall)\s+(.{1,50})/i, clause) do
      [_, subject, modal, action_start] ->
        "#{String.downcase(subject)} #{String.downcase(modal)} #{String.downcase(action_start)}"

      nil ->
        # Can't normalize - use first 100 chars
        String.slice(clause, 0, 100) |> String.downcase()
    end
  end

  @doc """
  Removes blacklisted patterns from text before processing.

  This prevents false positive matches on common phrases.
  Uses pre-compiled regexes for better performance.
  """
  @spec blacklist(text()) :: text()
  def blacklist(text) do
    blacklist_regex_compiled()
    |> Enum.reduce(text, fn regex, acc ->
      Regex.replace(regex, acc, " ")
    end)
  end

  @doc """
  Returns the current pattern version for government patterns.

  Can be overridden via application config:
      config :sertantai_legal, :duty_type_pattern_version, :v1

  Returns :v2 by default (improved patterns with capture groups).
  """
  @spec get_pattern_version() :: :v1 | :v2
  def get_pattern_version do
    Application.get_env(:sertantai_legal, :duty_type_pattern_version, @default_pattern_version)
  end

  @doc """
  Builds a library of actor-specific role patterns.

  ## Parameters

  - `actors_regex`: List of `{actor_name, regex_pattern}` tuples
  - `pattern_fn`: Function that generates role patterns for a regex
  """
  @spec build_lib(list(), function()) :: list({atom(), list()})
  def build_lib(actors_regex, pattern_fn) do
    actors_regex
    |> Enum.map(fn {actor, regex} -> {actor, pattern_fn.(regex)} end)
    |> List.flatten()
    |> Enum.reverse()
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # Runs role-specific regex patterns against text
  # Returns structured match data (Phase 2b)
  # V2 patterns: Prefers capture groups if present (action text after modal)
  # Uses Regex.scan to capture ALL matches of a pattern, not just the first
  defp run_role_regex(collector, library, label) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
        {regex_str, rm_matched_text?} =
          case regex do
            {regex, true} -> {regex, true}
            _ -> {regex, false}
          end

        case Regex.compile(regex_str, "m") do
          {:ok, regex_c} ->
            # Use Regex.scan to find ALL matches, not just the first
            all_matches = Regex.scan(regex_c, text)

            if all_matches == [] do
              acc2
            else
              # Process each match and accumulate results
              text =
                if rm_matched_text?,
                  do: Regex.replace(regex_c, text, ""),
                  else: text

              actor_str = to_string(actor)

              new_entries =
                Enum.map(all_matches, fn [full_match | captures] ->
                  full_match = ensure_valid_utf8(full_match)

                  # V2 patterns have capture groups for action text after modal
                  refined_clause =
                    case captures do
                      [captured | _] when captured != "" ->
                        captured = ensure_valid_utf8(captured)

                        ClauseRefiner.refine(full_match, label,
                          section_text: text,
                          captured_action: captured
                        )

                      _ ->
                        ClauseRefiner.refine(full_match, label, section_text: text)
                    end

                  %{
                    holder: actor_str,
                    duty_type: label,
                    clause: refined_clause
                  }
                end)

              new_debug =
                Enum.map(new_entries, fn entry ->
                  ~s/#{label}: #{actor_str}\n#{regex_str}\n-> #{entry.clause}\n/
                end)

              {
                text,
                List.duplicate(actor_str, length(new_entries)) ++ role_holders,
                new_entries ++ matches,
                new_debug ++ reg_exs
              }
            end

          {:error, {error, _pos}} ->
            IO.puts("ERROR: DutyTypeLib regex doesn't compile: #{error}\nPattern: #{regex_str}")
            acc2
        end
      end)
    end)
  end

  # ============================================================================
  # Modal-Based Windowed Search Optimization (Phase 5)
  # ============================================================================
  # For large texts, instead of running each regex against the full text,
  # we first find all positions where modal verbs (shall, must, may) appear,
  # then only search in windows around those positions. This dramatically
  # reduces the amount of text processed because:
  # 1. Modal verbs are the key indicators of duties/rights in legal text
  # 2. Most of the text (descriptions, definitions, etc.) has NO modals
  # 3. We only need to check ~100-200 modal positions vs 546KB of text

  # Determines if windowed search should be used based on text length
  defp use_windowed_search?(text) do
    String.length(text) > @windowed_search_threshold
  end

  # Finds all modal verb positions in the text
  # Returns list of {start_pos, length} tuples
  defp find_modal_positions(text) do
    modal_positions =
      Regex.scan(@modal_pattern, text, return: :index)
      |> List.flatten()

    # Also find non-modal anchor positions (is liable, remains responsible, etc.)
    non_modal_positions =
      Regex.scan(@non_modal_anchors, text, return: :index)
      |> List.flatten()

    (modal_positions ++ non_modal_positions)
    |> Enum.uniq()
    |> Enum.sort_by(fn {pos, _len} -> pos end)
  end

  # Creates windows around modal positions with asymmetric padding
  # More space before (for actor) than after (for verb phrase)
  defp create_modal_windows(positions, _text) when positions == [], do: []

  defp create_modal_windows(positions, text) do
    text_length = String.length(text)

    # Convert positions to window ranges with asymmetric padding
    ranges =
      positions
      |> Enum.map(fn {pos, len} ->
        start_pos = max(0, pos - @modal_window_before)
        end_pos = min(text_length, pos + len + @modal_window_after)
        {start_pos, end_pos}
      end)
      |> Enum.sort()

    # Merge overlapping ranges
    merged_ranges = merge_ranges(ranges)

    # Extract text slices
    Enum.map(merged_ranges, fn {start_pos, end_pos} ->
      slice = String.slice(text, start_pos, end_pos - start_pos)
      {start_pos, slice}
    end)
  end

  # Merges overlapping ranges into contiguous blocks
  defp merge_ranges([]), do: []
  defp merge_ranges([single]), do: [single]

  defp merge_ranges([{s1, e1}, {s2, e2} | rest]) when s2 <= e1 do
    # Ranges overlap - merge them
    merge_ranges([{s1, max(e1, e2)} | rest])
  end

  defp merge_ranges([first | rest]) do
    [first | merge_ranges(rest)]
  end

  # Main modal-based windowed search function
  # 1. Find all modal positions in the text
  # 2. Create windows around those positions
  # 3. For each actor, check if they appear in any window
  # 4. Only run patterns for actors that are actually present
  defp run_modal_windowed_search(collector, library, label, full_text) do
    # Step 1: Find all modal positions
    modal_positions = find_modal_positions(full_text)

    if modal_positions == [] do
      # No modals found - no duties/rights possible
      collector
    else
      # Step 2: Create windows around modal positions
      modal_windows = create_modal_windows(modal_positions, full_text)

      # Step 3: For each actor in the library, check presence and run patterns
      Enum.reduce(library, collector, fn {actor, regexes}, acc ->
        # Get simple pattern to check if actor is mentioned at all
        actor_pattern = get_actor_base_pattern(actor)

        # Check if actor appears in ANY modal window
        actor_windows = filter_windows_with_actor(modal_windows, actor_pattern)

        if actor_windows == [] do
          # Actor not in any modal window - skip all patterns for this actor
          acc
        else
          # Actor found in some windows - run patterns only against those windows
          run_patterns_in_windows(acc, actor, regexes, actor_windows, label)
        end
      end)
    end
  end

  # Filters windows to only those containing the actor pattern
  defp filter_windows_with_actor(windows, actor_pattern) do
    case Regex.compile(actor_pattern, "i") do
      {:ok, regex} ->
        Enum.filter(windows, fn {_start, window_text} ->
          Regex.match?(regex, window_text)
        end)

      {:error, _} ->
        []
    end
  end

  # Runs patterns for a specific actor against filtered windows
  # Returns structured match data (Phase 2b)
  # V2 patterns: Prefers capture groups if present (action text after modal)
  # Uses Regex.scan to capture ALL matches from all windows
  defp run_patterns_in_windows(acc, actor, regexes, windows, label) do
    Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
      {regex_str, rm_matched_text?} =
        case regex do
          {r, true} -> {r, true}
          r -> {r, false}
        end

      case Regex.compile(regex_str, "m") do
        {:ok, regex_c} ->
          # Search ALL windows for ALL matches
          all_matches = find_all_matches_in_windows(regex_c, windows)

          if all_matches == [] do
            acc2
          else
            new_text = if rm_matched_text?, do: Regex.replace(regex_c, text, ""), else: text
            actor_str = to_string(actor)

            new_entries =
              Enum.map(all_matches, fn {full_match, captures, window_text} ->
                full_match = ensure_valid_utf8(full_match)

                # V2 patterns have capture groups for action text after modal
                refined_clause =
                  case captures do
                    [captured | _] when captured != "" ->
                      captured = ensure_valid_utf8(captured)

                      ClauseRefiner.refine(full_match, label,
                        section_text: window_text,
                        captured_action: captured
                      )

                    _ ->
                      ClauseRefiner.refine(full_match, label, section_text: window_text)
                  end

                %{
                  holder: actor_str,
                  duty_type: label,
                  clause: refined_clause
                }
              end)

            new_debug =
              Enum.map(new_entries, fn entry ->
                ~s/#{label}: #{actor_str}\n#{regex_str}\n-> #{entry.clause}\n/
              end)

            {
              new_text,
              List.duplicate(actor_str, length(new_entries)) ++ role_holders,
              new_entries ++ matches,
              new_debug ++ reg_exs
            }
          end

        {:error, {error, _pos}} ->
          IO.puts("ERROR: DutyTypeLib regex doesn't compile: #{error}\nPattern: #{regex_str}")
          acc2
      end
    end)
  end

  # Searches for ALL regex matches in ALL windows
  # Returns list of {full_match, captures, window_text} tuples
  defp find_all_matches_in_windows(regex, windows) do
    Enum.flat_map(windows, fn {_start_pos, window_text} ->
      Regex.scan(regex, window_text)
      |> Enum.map(fn [full_match | captures] ->
        {full_match, captures, window_text}
      end)
    end)
  end

  # Gets the base actor pattern for finding mentions
  # This extracts the core pattern from actor definitions
  # Never matches - nil actor
  defp get_actor_base_pattern(nil), do: "(?!)"
  # Never matches - empty actor
  defp get_actor_base_pattern(""), do: "(?!)"

  defp get_actor_base_pattern(actor) do
    actor_str = to_string(actor)

    # Extract the word pattern from common actor formats
    # e.g., "Org: Employer" -> employer, "Gvt: Minister" -> minister
    cond do
      String.contains?(actor_str, "Employer") ->
        "[Ee]mployers?"

      String.contains?(actor_str, "Employee") ->
        "[Ee]mployees?"

      String.contains?(actor_str, "Worker") ->
        "[Ww]orkers?"

      String.contains?(actor_str, "Person") ->
        "[Pp]ersons?"

      String.contains?(actor_str, "Minister") ->
        "[Mm]inisters?|Secretary of State"

      String.contains?(actor_str, "Authority") ->
        "[Aa]uthority|[Aa]uthorities"

      String.contains?(actor_str, "Inspector") ->
        "[Ii]nspectors?"

      String.contains?(actor_str, "Contractor") ->
        "[Cc]ontractors?"

      String.contains?(actor_str, "Manufacturer") ->
        "[Mm]anufacturers?"

      String.contains?(actor_str, "Supplier") ->
        "[Ss]uppliers?"

      String.contains?(actor_str, "Importer") ->
        "[Ii]mporters?"

      String.contains?(actor_str, "Designer") ->
        "[Dd]esigners?"

      String.contains?(actor_str, "Owner") ->
        "[Oo]wners?"

      String.contains?(actor_str, "Operator") ->
        "[Oo]perators?"

      String.contains?(actor_str, "User") ->
        "[Uu]sers?"

      String.contains?(actor_str, "Installer") ->
        "[Ii]nstallers?"

      String.contains?(actor_str, "Company") ->
        "[Cc]ompany|[Cc]ompanies"

      String.contains?(actor_str, "Director") ->
        "[Dd]irectors?"

      String.contains?(actor_str, "Officer") ->
        "[Oo]fficers?"

      String.contains?(actor_str, "Manager") ->
        "[Mm]anagers?"

      String.contains?(actor_str, "Agent") ->
        "[Aa]gents?"

      String.contains?(actor_str, "Occupier") ->
        "[Oo]ccupiers?"

      String.contains?(actor_str, "Landlord") ->
        "[Ll]andlords?"

      String.contains?(actor_str, "Tenant") ->
        "[Tt]enants?"

      String.contains?(actor_str, "Client") ->
        "[Cc]lients?"

      String.contains?(actor_str, "Customer") ->
        "[Cc]ustomers?"

      String.contains?(actor_str, "Principal") ->
        "[Pp]rincipals?"

      # Default: try to extract the last word and make a case-insensitive pattern
      true ->
        word =
          actor_str
          |> String.split(~r/[:\s]+/)
          |> List.last()
          |> Kernel.||("")
          |> String.downcase()

        case String.first(word) do
          nil ->
            # Empty word - use the whole actor string as a literal pattern
            Regex.escape(actor_str)

          first_char ->
            "[#{String.upcase(first_char)}#{first_char}]#{String.slice(word, 1..-1//1)}s?"
        end
    end
  end

  # ============================================================================
  # Pre-compiled Blacklist Patterns
  # ============================================================================
  # These patterns cause false positives and are applied to every text.
  # Pre-compiling at module load avoids repeated Regex.compile calls.

  @blacklist_modals ~s/(?:shall|must|may[ ]only|may[ ]not)/

  @blacklist_patterns [
    "[ ]area of the authority",
    # Other subjects directly adjacent to the modal verb
    "[ ]said report (?:shall|must)|shall[ ]not[ ]apply",
    "[ ]may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)",
    "[ ]may[ ]reasonably[ ]require",
    "[ ]as[ ]the[ ]case[ ]may[ ]be",
    "[ ]as may reasonably foreseeably",
    "[ ]and[ ]#{@blacklist_modals}"
  ]

  # Pre-compile blacklist regexes at module load time
  @compiled_blacklist_regexes Enum.map(@blacklist_patterns, fn pattern ->
                                {:ok, regex} = Regex.compile(pattern)
                                regex
                              end)

  # Returns pre-compiled blacklist regexes
  defp blacklist_regex_compiled, do: @compiled_blacklist_regexes

  # Ensures string is valid UTF-8
  defp ensure_valid_utf8(str) do
    if String.valid?(str), do: str, else: to_utf8(str)
  end

  # Converts binary to UTF-8 string
  defp to_utf8(binary) do
    binary
    |> :unicode.characters_to_binary(:latin1)
    |> case do
      {:error, _, _} -> binary
      {:incomplete, _, _} -> binary
      result -> result
    end
  end
end

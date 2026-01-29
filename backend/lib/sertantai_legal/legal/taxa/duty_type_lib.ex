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
    DutyTypeDefnGoverned,
    DutyTypeDefnGovernment
  }

  @type duty_types :: list(String.t())
  @type actors :: list(String.t())
  @type text :: String.t()
  @type role :: :duty | :right | :responsibility | :power

  # Threshold for using windowed search optimization (in characters)
  # For texts larger than this, we find actor mentions first and only
  # search in windows around those mentions instead of the full text.
  @windowed_search_threshold 50_000

  # Window size around each actor mention (characters before and after)
  # Must be large enough to capture patterns like "Where...employer...shall"
  @window_padding 500

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
  @spec find_role_holders(role(), actors(), text(), list()) ::
          {actors(), duty_types(), String.t(), list()}
  def find_role_holders(_role, [], _text, regexes), do: {[], [], "", regexes}

  def find_role_holders(role, actors, text, regexes) when is_list(actors) do
    # Build actor-specific regex library
    actors_regex =
      case role do
        r when r in [:duty, :right] -> ActorLib.custom_actor_library(actors, :governed)
        _ -> ActorLib.custom_actor_library(actors, :government)
      end

    # Build role-specific patterns for each actor
    regex_lib =
      case role do
        :duty -> build_lib(actors_regex, &DutyTypeDefnGoverned.duty/1)
        :right -> build_lib(actors_regex, &DutyTypeDefnGoverned.right/1)
        :responsibility -> build_lib(actors_regex, &DutyTypeDefnGovernment.responsibility/1)
        :power -> build_lib(actors_regex, &DutyTypeDefnGovernment.power_conferred/1)
      end

    # Apply blacklist (lightweight if text already cleaned by TextCleaner)
    # Note: The unified blacklist in TextCleaner includes these patterns,
    # so this is effectively a no-op when called from taxa_parser pipeline
    cleaned_text = blacklist(text)
    label = role |> Atom.to_string() |> String.upcase()

    # Use windowed search for large texts to dramatically reduce regex processing
    result =
      if use_windowed_search?(cleaned_text) do
        run_role_regex_windowed({cleaned_text, [], [], regexes}, regex_lib, label, cleaned_text)
      else
        run_role_regex({cleaned_text, [], [], regexes}, regex_lib, label)
      end

    case result do
      {_, [], _, regexes} ->
        {[], [], "", regexes}

      {_, role_holders, matches, regexes} ->
        {
          Enum.uniq(role_holders),
          role |> Atom.to_string() |> String.capitalize() |> List.wrap(),
          matches |> Enum.uniq() |> Enum.map(&String.trim/1) |> Enum.join("\n"),
          regexes
        }
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
  defp run_role_regex(collector, library, label) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
        {regex, rm_matched_text?} =
          case regex do
            {regex, true} -> {regex, true}
            _ -> {regex, false}
          end

        case Regex.compile(regex, "m") do
          {:ok, regex_c} ->
            case Regex.run(regex_c, text) do
              [match | _] ->
                text =
                  if rm_matched_text?,
                    do: Regex.replace(regex_c, text, ""),
                    else: text

                match = ensure_valid_utf8(match)
                actor_str = to_string(actor)

                {
                  text,
                  [actor_str | role_holders],
                  [~s/#{label}\n👤#{actor_str}\n📌#{match}\n/ | matches],
                  [~s/#{label}: #{actor_str}\n#{regex}\n-> #{match}\n/ | reg_exs]
                }

              nil ->
                acc2
            end

          {:error, {error, _pos}} ->
            IO.puts("ERROR: DutyTypeLib regex doesn't compile: #{error}\nPattern: #{regex}")
            acc2
        end
      end)
    end)
  end

  # ============================================================================
  # Windowed Search Optimization
  # ============================================================================
  # For large texts, instead of running each regex against the full text,
  # we first find all positions where the actor is mentioned, then only
  # search in windows around those positions. This dramatically reduces
  # the amount of text processed by complex regex patterns.

  # Determines if windowed search should be used based on text length
  defp use_windowed_search?(text) do
    String.length(text) > @windowed_search_threshold
  end

  # Finds all positions where the actor pattern matches in the text
  # Returns list of {start_pos, length} tuples
  defp find_actor_positions(actor_pattern, text) do
    case Regex.compile(actor_pattern, "i") do
      {:ok, regex} ->
        Regex.scan(regex, text, return: :index)
        |> List.flatten()
        |> Enum.uniq()

      {:error, _} ->
        []
    end
  end

  # Extracts text windows around actor positions and merges overlapping windows
  # Returns list of {start, text_slice} tuples for searching
  defp extract_windows(positions, _text) when positions == [], do: []

  defp extract_windows(positions, text) do
    text_length = String.length(text)

    # Convert positions to window ranges
    ranges =
      positions
      |> Enum.map(fn {pos, len} ->
        start_pos = max(0, pos - @window_padding)
        end_pos = min(text_length, pos + len + @window_padding)
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

  # Runs regex patterns against windows instead of full text
  # This is the windowed version of run_role_regex
  defp run_role_regex_windowed(collector, library, label, full_text) do
    Enum.reduce(library, collector, fn {actor, regexes}, acc ->
      # Get the actor's base pattern from the library to find mentions
      actor_pattern = get_actor_base_pattern(actor)
      positions = find_actor_positions(actor_pattern, full_text)

      if positions == [] do
        # Actor not mentioned in text at all - skip all patterns
        acc
      else
        # Extract windows around actor mentions
        windows = extract_windows(positions, full_text)

        # Run patterns against each window
        Enum.reduce(regexes, acc, fn regex, {text, role_holders, matches, reg_exs} = acc2 ->
          {regex_str, rm_matched_text?} =
            case regex do
              {r, true} -> {r, true}
              r -> {r, false}
            end

          case Regex.compile(regex_str, "m") do
            {:ok, regex_c} ->
              # Search each window for a match
              case find_match_in_windows(regex_c, windows) do
                {:found, match} ->
                  # Found a match - update accumulator
                  # Note: We don't modify the original text for windowed search
                  # since windows are independent slices
                  new_text = if rm_matched_text?, do: Regex.replace(regex_c, text, ""), else: text
                  match = ensure_valid_utf8(match)
                  actor_str = to_string(actor)

                  {
                    new_text,
                    [actor_str | role_holders],
                    [~s/#{label}\n👤#{actor_str}\n📌#{match}\n/ | matches],
                    [~s/#{label}: #{actor_str}\n#{regex_str}\n-> #{match}\n/ | reg_exs]
                  }

                :not_found ->
                  acc2
              end

            {:error, {error, _pos}} ->
              IO.puts("ERROR: DutyTypeLib regex doesn't compile: #{error}\nPattern: #{regex_str}")
              acc2
          end
        end)
      end
    end)
  end

  # Searches for a regex match in a list of text windows
  defp find_match_in_windows(_regex, []), do: :not_found

  defp find_match_in_windows(regex, [{_start_pos, window_text} | rest]) do
    case Regex.run(regex, window_text) do
      [match | _] -> {:found, match}
      nil -> find_match_in_windows(regex, rest)
    end
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

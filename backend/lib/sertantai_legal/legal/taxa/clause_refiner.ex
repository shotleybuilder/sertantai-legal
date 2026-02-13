defmodule SertantaiLegal.Legal.Taxa.ClauseRefiner do
  @moduledoc """
  Refines raw clause captures from duty type detection into focused, readable clauses.

  ## Problem

  Detection patterns in `DutyTypeDefnGovernment` and `DutyTypeDefnGoverned` capture
  everything BEFORE the modal verb (shall/must/may) but often miss the actual action
  that follows. This results in:

  - Huge preambles (500+ words of consultation lists)
  - Truncated clauses ending at "must" without the action
  - Poor readability for end users

  ## Solution

  Extract a window around the modal verb that includes:
  - **Subject**: The actor performing the action (80 chars before modal)
  - **Modal**: The obligation verb (shall/must/may)
  - **Action**: What they must do (200 chars after modal)

  ## Usage

      iex> raw = "...long preamble... The planning authority must"
      iex> ClauseRefiner.refine(raw, "RESPONSIBILITY")
      "The planning authority must..."

      # With section context for action extraction
      iex> ClauseRefiner.refine(raw, "RESPONSIBILITY", section_text: full_section)
      "The planning authority must consult the bodies listed in paragraph (1)."

  ## Algorithm

  1. Find the LAST modal verb position in the raw clause (patterns end at modal)
  2. Extract subject: Find sentence start before modal, capture actor
  3. Extract action: If section_text provided, get text after modal from there
  4. Combine and truncate to max length with smart sentence boundaries
  """

  @type duty_type :: String.t()
  @type opts :: keyword()

  # Maximum refined clause length
  @max_clause_length 300

  # Window sizes for extraction
  @subject_window 100
  @action_window 200

  # Modal verb pattern string
  @modal_pattern_str "\\b(shall|must|may(?:\\s+(?:not|only))?)\\b"
  # Sentence boundary pattern string
  @sentence_end_pattern_str "[.;]|\\n\\n"

  defp modal_pattern do
    case :persistent_term.get({__MODULE__, :modal_pattern}, nil) do
      nil ->
        r = Regex.compile!(@modal_pattern_str, "i")
        :persistent_term.put({__MODULE__, :modal_pattern}, r)
        r

      cached ->
        cached
    end
  end

  defp sentence_end_pattern do
    case :persistent_term.get({__MODULE__, :sentence_end_pattern}, nil) do
      nil ->
        r = Regex.compile!(@sentence_end_pattern_str)
        :persistent_term.put({__MODULE__, :sentence_end_pattern}, r)
        r

      cached ->
        cached
    end
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Refines a raw clause capture into a focused, readable clause.

  ## Parameters

  - `raw_clause`: The raw regex match from duty type detection
  - `duty_type`: The type of duty ("RESPONSIBILITY", "DUTY", "RIGHT", "POWER")
  - `opts`: Optional keyword list
    - `:section_text` - Full section text for extracting action after modal

  ## Returns

  A refined clause string, max #{@max_clause_length} characters.

  ## Examples

      iex> ClauseRefiner.refine("the authority must", "RESPONSIBILITY")
      "the authority must..."

      iex> ClauseRefiner.refine(
      ...>   "long preamble... The planning authority must",
      ...>   "RESPONSIBILITY",
      ...>   section_text: "...The planning authority must consult the relevant bodies."
      ...> )
      "The planning authority must consult the relevant bodies."
  """
  @spec refine(String.t() | nil, duty_type(), opts()) :: String.t() | nil
  def refine(raw_clause, duty_type, opts \\ [])

  def refine(nil, _duty_type, _opts), do: nil
  def refine("", _duty_type, _opts), do: nil

  def refine(raw_clause, duty_type, opts)
      when duty_type in ["RESPONSIBILITY", "DUTY", "RIGHT", "POWER"] do
    section_text = Keyword.get(opts, :section_text)
    captured_action = Keyword.get(opts, :captured_action)

    case find_last_modal_position(raw_clause) do
      nil ->
        # No modal found - this might be V2 capture group output (action only)
        # Clean up the clause and ensure it doesn't end mid-word
        raw_clause
        |> ensure_clean_ending()
        |> truncate_smart(@max_clause_length)

      {modal_start, modal_length, modal_text} ->
        # Extract subject (text before modal, trimmed to sentence start)
        subject = extract_subject(raw_clause, modal_start)

        # Extract action (text after modal)
        # Priority: captured_action (from V2 pattern) > section_text > raw_clause
        action =
          if captured_action && captured_action != "" do
            # V2 pattern provided captured action - use it directly
            captured_action
            |> ensure_clean_ending()
          else
            # Fall back to extracting from raw clause or section text
            extract_action(raw_clause, modal_start + modal_length, section_text)
          end

        # Combine into refined clause: "Subject must action"
        combine_clause(subject, modal_text, action)
    end
  end

  def refine(raw_clause, _duty_type, _opts) do
    # Unknown duty type - just truncate
    truncate_smart(raw_clause, @max_clause_length)
  end

  # ============================================================================
  # Modal Detection
  # ============================================================================

  @doc """
  Finds the position of the LAST modal verb in the text.

  We look for the LAST modal because detection patterns typically capture
  everything up to and including the modal, so the relevant modal is at the end.

  Returns `{start_position, length, modal_text}` or `nil` if not found.
  """
  @spec find_last_modal_position(String.t()) ::
          {non_neg_integer(), non_neg_integer(), String.t()} | nil
  def find_last_modal_position(text) when is_binary(text) do
    case Regex.scan(modal_pattern(), text, return: :index) do
      [] ->
        nil

      matches ->
        # Get the last match (most relevant for our patterns)
        {start, length} = List.last(List.flatten(matches))
        modal_text = String.slice(text, start, length)
        {start, length, modal_text}
    end
  end

  # ============================================================================
  # Subject Extraction
  # ============================================================================

  @doc """
  Extracts the subject portion of a clause (actor + context before modal).

  Looks backwards from the modal position to find a sentence start,
  then captures from there to just before the modal.
  """
  @spec extract_subject(String.t(), non_neg_integer()) :: String.t()
  def extract_subject(text, modal_start) do
    # Get the window of text before the modal
    window_start = max(0, modal_start - @subject_window)
    before_modal = String.slice(text, window_start, modal_start - window_start)

    # Try to find a clean sentence start (capital letter after period/semicolon)
    case find_sentence_start(before_modal) do
      nil ->
        # No clear sentence start - use the whole window, trimmed
        before_modal
        |> String.trim_leading()
        |> clean_leading_fragments()

      sentence_start_pos ->
        # Found a sentence start - extract from there
        String.slice(before_modal, sentence_start_pos, String.length(before_modal))
        |> String.trim_leading()
    end
  end

  # Find position of last sentence start in text
  defp find_sentence_start(text) do
    case Regex.scan(~r/[.;]\s*(?=[A-Z])/, text, return: :index) do
      [] ->
        # Check if text starts with capital (beginning of sentence)
        if Regex.match?(~r/^\s*[A-Z]/, text), do: 0, else: nil

      matches ->
        # Get the last sentence boundary position
        [{pos, len}] = List.last(matches)
        # Return position after the boundary (where the capital letter starts)
        pos + len
    end
  end

  # Clean up leading fragments that don't make sense
  defp clean_leading_fragments(text) do
    text
    # Remove leading punctuation and conjunctions
    |> String.replace(~r/^[\s,;:]+/, "")
    |> String.replace(~r/^(?:and|or|but|the)\s+(?=[a-z])/i, "")
    |> String.trim()
  end

  # ============================================================================
  # Action Extraction
  # ============================================================================

  @doc """
  Extracts the action portion of a clause (what comes after the modal).

  If section_text is provided, searches for the modal in section_text and
  extracts what follows. Otherwise, extracts from raw_clause (which may be empty
  since patterns typically end at the modal).
  """
  @spec extract_action(String.t(), non_neg_integer(), String.t() | nil) :: String.t()
  def extract_action(raw_clause, modal_end_in_raw, section_text) do
    # First try to get action from raw clause (in case pattern captured some)
    action_from_raw = String.slice(raw_clause, modal_end_in_raw, @action_window)

    if section_text && String.trim(action_from_raw) == "" do
      # Raw clause has no action - try to find it in section text
      extract_action_from_section(raw_clause, section_text)
    else
      # Use action from raw clause
      action_from_raw
      |> extract_to_sentence_end()
      |> clean_trailing_fragments()
    end
  end

  # Extract action by finding the modal context in section text
  defp extract_action_from_section(raw_clause, section_text) do
    # Find the modal and some context from the raw clause to locate in section
    case find_last_modal_position(raw_clause) do
      nil ->
        ""

      {modal_start, _modal_length, modal_text} ->
        # Get context around the modal (subject + modal)
        context_start = max(0, modal_start - 40)
        context = String.slice(raw_clause, context_start, 60)

        # Try to find this context in the section text
        case find_context_in_section(context, modal_text, section_text) do
          nil ->
            ""

          action_start ->
            # Extract action from section text
            String.slice(section_text, action_start, @action_window)
            |> extract_to_sentence_end()
            |> clean_trailing_fragments()
        end
    end
  end

  # Find where context appears in section and return position after modal
  defp find_context_in_section(context, modal_text, section_text) do
    # Escape special regex characters in context
    escaped_context = Regex.escape(context)

    case Regex.run(~r/#{escaped_context}/i, section_text, return: :index) do
      [{pos, len}] ->
        # Found context - now find the modal within it
        context_in_section = String.slice(section_text, pos, len + 50)

        case Regex.run(~r/#{Regex.escape(modal_text)}/i, context_in_section, return: :index) do
          [{modal_pos, modal_len}] ->
            # Return position after the modal in section text
            pos + modal_pos + modal_len

          _ ->
            nil
        end

      _ ->
        # Context not found - try just finding the modal with similar surrounding
        nil
    end
  end

  # Extract text up to the first sentence boundary
  defp extract_to_sentence_end(text) do
    case Regex.run(sentence_end_pattern(), text, return: :index) do
      [{pos, _len}] when pos > 0 ->
        # Include the period/semicolon
        String.slice(text, 0, pos + 1)

      _ ->
        # No sentence end found - ensure we don't end mid-word
        truncate_at_word_boundary(text)
    end
  end

  # Truncate text at a word boundary (don't cut mid-word)
  defp truncate_at_word_boundary(text) do
    trimmed = String.trim_trailing(text)

    # Check if we're in the middle of a word (ends with letters, no space/punct before)
    if Regex.match?(~r/\w$/, trimmed) and not Regex.match?(~r/\s\w+$/, trimmed) do
      # We might be mid-word - find the last complete word
      case Regex.run(~r/^(.+)\s+\S*$/, trimmed) do
        [_, complete_words] ->
          String.trim_trailing(complete_words)

        _ ->
          # Can't find word boundary, return as-is
          trimmed
      end
    else
      trimmed
    end
  end

  # Clean up trailing fragments
  defp clean_trailing_fragments(text) do
    text
    |> String.trim_trailing()
    # Ensure we don't end mid-word
    |> truncate_at_word_boundary()
    # Remove trailing conjunctions
    |> String.replace(~r/\s+(?:and|or|but)\s*$/, "")
    # Remove trailing partial words (like "wa" from "was")
    |> remove_trailing_fragment()
    |> String.trim()
  end

  # Remove trailing fragments that look like partial words
  defp remove_trailing_fragment(text) do
    # If text ends with a short fragment (1-3 chars) after a space, remove it
    case Regex.run(~r/^(.+\s)\w{1,3}$/, text) do
      [_, without_fragment] ->
        String.trim_trailing(without_fragment)

      _ ->
        text
    end
  end

  # ============================================================================
  # Clause Combination
  # ============================================================================

  @doc """
  Combines subject, modal, and action into a refined clause.
  """
  @spec combine_clause(String.t(), String.t(), String.t()) :: String.t()
  def combine_clause(subject, modal, action) do
    # Build the clause
    clause =
      [subject, modal, action]
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

    # Add ellipsis if action was truncated or missing
    clause =
      if action == "" or not String.ends_with?(clause, [".", ";", "!", "?"]) do
        ensure_trailing_indicator(clause)
      else
        clause
      end

    # Truncate if needed
    truncate_smart(clause, @max_clause_length)
  end

  # Ensure clause has trailing punctuation or ellipsis
  defp ensure_trailing_indicator(clause) do
    if String.ends_with?(clause, [".", ";", "!", "?", "..."]) do
      clause
    else
      clause <> "..."
    end
  end

  # ============================================================================
  # Clean Ending
  # ============================================================================

  @doc """
  Ensures a clause ends cleanly - at a sentence boundary or complete word.
  This handles V2 capture group output that may be truncated mid-word.
  """
  @spec ensure_clean_ending(String.t()) :: String.t()
  def ensure_clean_ending(text) do
    trimmed = String.trim(text)

    cond do
      # Already ends with proper punctuation
      String.ends_with?(trimmed, [".", ";", "!", "?", ")"]) ->
        trimmed

      # Try to find last sentence boundary
      find_last_sentence_boundary(trimmed) ->
        find_last_sentence_boundary(trimmed)

      # No sentence boundary - ensure we end at a complete word
      true ->
        trimmed
        |> truncate_to_complete_word()
        |> add_ellipsis_if_needed()
    end
  end

  # Find the last sentence boundary (period or semicolon followed by space or end)
  defp find_last_sentence_boundary(text) do
    case Regex.run(~r/^(.+[.;])(?:\s|$)/, text) do
      [_, with_boundary] -> with_boundary
      _ -> nil
    end
  end

  # Truncate to the last complete word
  defp truncate_to_complete_word(text) do
    # Check if we might be mid-word (ends with letters but no preceding space+word pattern)
    if Regex.match?(~r/\s\w{1,3}$/, text) do
      # Ends with a short fragment after space - likely partial word
      # Remove the fragment
      case Regex.run(~r/^(.+\s)\w{1,3}$/, text) do
        [_, without_fragment] -> String.trim(without_fragment)
        _ -> text
      end
    else
      text
    end
  end

  # Add ellipsis if text doesn't end with punctuation
  defp add_ellipsis_if_needed(text) do
    if String.ends_with?(text, [".", ";", "!", "?", "...", ")"]) do
      text
    else
      text <> "..."
    end
  end

  # ============================================================================
  # Truncation
  # ============================================================================

  @doc """
  Truncates text to max length, preferring to break at sentence boundaries.
  """
  @spec truncate_smart(String.t(), non_neg_integer()) :: String.t()
  def truncate_smart(text, max_length) when byte_size(text) <= max_length, do: text

  def truncate_smart(text, max_length) do
    # Try to find a sentence boundary within the max length
    truncated = String.slice(text, 0, max_length - 3)

    case Regex.run(~r/^(.+[.;])\s/, truncated) do
      [_, with_boundary] when byte_size(with_boundary) > max_length / 2 ->
        # Found a good boundary that's not too short
        with_boundary

      _ ->
        # No good boundary - ensure we don't cut mid-word, then add ellipsis
        truncated
        |> truncate_to_complete_word()
        |> add_ellipsis_if_needed()
    end
  end
end

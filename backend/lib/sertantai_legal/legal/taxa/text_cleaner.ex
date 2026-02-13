defmodule SertantaiLegal.Legal.Taxa.TextCleaner do
  @moduledoc """
  Unified text cleaning for Taxa classification.

  Combines all blacklist patterns from across the Taxa pipeline and applies them
  once at the start of classification. This eliminates redundant text cleaning
  that was previously done separately in DutyActor and DutyTypeLib.

  ## Blacklist Sources

  1. **Actor blacklist** (from ActorDefinitions): Removes phrases that cause
     false positive actor matches like "local authority collected municipal waste"

  2. **DutyType blacklist** (from DutyTypeLib): Removes modal verb phrases that
     cause false positive duty/right/responsibility matches

  ## Performance

  All patterns are pre-compiled at module load time. Call `clean/1` once at the
  start of the Taxa pipeline instead of applying blacklists multiple times.

  ## Usage

      # In taxa_parser.ex:classify_text/2
      cleaned_text = TextCleaner.clean(text)
      # Use cleaned_text for all subsequent stages
  """

  # ============================================================================
  # Pre-compiled Blacklist Patterns
  # ============================================================================

  # Actor blacklist patterns (from ActorDefinitions)
  # These prevent false positive actor matches
  @actor_blacklist_patterns [
    "local authority collected municipal waste",
    "[Pp]ublic (?:nature|sewer|importance|functions?|interest|[Ss]ervices)",
    "[Rr]epresentatives? of"
  ]

  # DutyType blacklist patterns (from DutyTypeLib)
  # These prevent false positive modal verb matches
  @duty_type_blacklist_patterns (
                                  modals = ~s/(?:shall|must|may[ ]only|may[ ]not)/

                                  [
                                    "[ ]area of the authority",
                                    "[ ]said report (?:shall|must)|shall[ ]not[ ]apply",
                                    "[ ]may[ ]be[ ](?:approved|reduced|reasonably foreseeably|required)",
                                    "[ ]may[ ]reasonably[ ]require",
                                    "[ ]as[ ]the[ ]case[ ]may[ ]be",
                                    "[ ]as may reasonably foreseeably",
                                    "[ ]and[ ]#{modals}"
                                  ]
                                )

  # Combined blacklist patterns (compiled at runtime via all_blacklist_compiled/0)
  @all_blacklist_patterns @actor_blacklist_patterns ++ @duty_type_blacklist_patterns

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Cleans text by removing all blacklisted patterns.

  Call this once at the start of the Taxa pipeline. The cleaned text can then
  be passed to all classification stages without redundant cleaning.

  Returns the text with blacklisted patterns replaced with spaces (to preserve
  word boundaries for subsequent regex matching).
  """
  @spec clean(String.t()) :: String.t()
  def clean(text) when is_binary(text) do
    Enum.reduce(all_blacklist_compiled(), text, fn regex, acc ->
      Regex.replace(regex, acc, " ")
    end)
  end

  def clean(text), do: text

  # Compiles and caches all blacklist patterns at runtime.
  # Regex structs contain NIF references that can't be stored in module attributes.
  defp all_blacklist_compiled do
    case :persistent_term.get({__MODULE__, :all_blacklist_compiled}, nil) do
      nil ->
        compiled = Enum.map(@all_blacklist_patterns, &Regex.compile!(&1, "m"))
        :persistent_term.put({__MODULE__, :all_blacklist_compiled}, compiled)
        compiled

      cached ->
        cached
    end
  end

  @doc """
  Returns the pre-compiled actor blacklist patterns.
  For use by DutyActor if it needs to apply actor-specific cleaning only.
  """
  @spec actor_blacklist_compiled() :: list(Regex.t())
  def actor_blacklist_compiled do
    @actor_blacklist_patterns |> Enum.map(&Regex.compile!(&1, "m"))
  end

  @doc """
  Returns the pre-compiled duty type blacklist patterns.
  For use by DutyTypeLib if it needs to apply duty-specific cleaning only.
  """
  @spec duty_type_blacklist_compiled() :: list(Regex.t())
  def duty_type_blacklist_compiled do
    @duty_type_blacklist_patterns |> Enum.map(&Regex.compile!(&1, "m"))
  end
end

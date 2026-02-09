defmodule SertantaiLegal.Legal.Taxa.DutyTypeDefnGovernmentV2 do
  @moduledoc """
  EXPERIMENTAL: Improved regex patterns for responsibilities and powers.

  This is a V2 of DutyTypeDefnGovernment with two key improvements:

  1. **Limited pre-modal capture**: Uses `{0,150}` instead of `*?` to prevent
     capturing giant preambles (500+ words) before the modal verb.

  2. **Capture groups for action**: Adds `(.{1,200})` after the modal to capture
     what the entity must/shall actually DO, not just that they have an obligation.

  ## Comparison with V1

  V1 pattern: `"\#{government}[^—\\.]*?(?:must|shall)"`
  - Captures: "...long list of consultees... The planning authority must"
  - Problem: Ends at "must", never captures the action

  V2 pattern: `"\#{government}[^—\\.]{0,150}?(?:must|shall)\\s+(.{1,200})"`
  - Captures: "The planning authority must" + "consult the relevant bodies."
  - Benefit: Limited preamble + captures the actual responsibility

  ## Usage

  For testing/comparison only. Do not use in production until validated.

      # Compare V1 vs V2 output
      v1_patterns = DutyTypeDefnGovernment.responsibility(actor_regex)
      v2_patterns = DutyTypeDefnGovernmentV2.responsibility(actor_regex)
  """

  @type pattern :: String.t()

  # Em dash character
  @emdash <<226, 128, 148>>

  # Maximum characters to capture before modal verb (prevents giant preambles)
  @max_pre_modal 150

  # Characters to capture after modal verb (the actual action)
  @post_modal_capture 200

  @doc """
  Returns IMPROVED regex patterns for identifying responsibilities.

  Key differences from V1:
  - Pre-modal text limited to #{@max_pre_modal} chars
  - Capture group after modal to get the action (#{@post_modal_capture} chars)
  """
  @spec responsibility(String.t()) :: list(pattern())
  def responsibility(government) do
    [
      # Direct adjacency: "authority must/shall" + capture action after
      # Note: [,\\s]+ allows comma after modal (e.g., "must, not later than")
      "#{government}\\s*(?:must|shall)(?! have the power)[,\\s]+(.{1,#{@post_modal_capture}})",

      # Limited gap: up to 150 chars between actor and modal + capture action
      "#{government}[^—\\.]{0,#{@max_pre_modal}}?(?:must|shall)(?! have the power)[,\\s]+(.{1,#{@post_modal_capture}})",

      # Ellipsis pattern with limits
      "#{government}[^—\\.]{0,#{@max_pre_modal}}?[\\.\\.\\.].*?(?:must|shall)[,\\s]+(.{1,#{@post_modal_capture}})",

      # Passive: "must be done by [government]"
      "must be (?:carried out|reviewed|sent|prepared|specified by)[^.;]{0,100}?#{government}",

      # "has determined" pattern
      "#{government}[^—\\.]{0,#{@max_pre_modal}}?has determined",

      # "It shall be the duty of" pattern
      "[Ii]t shall be the duty of a?n?[^—\\.]{0,100}?#{government}",

      # Other responsibility indicators
      "#{government} owes a duty to",
      "is to be[^.;]{0,50}?by a\\s*#{government}",
      "#{government}\\s*is to (?:perform|have regard)",
      "#{government}\\s*may not[,\\s]+(.{1,#{@post_modal_capture}})",
      "#{government}\\s*is (?:liable|responsible for)",
      "[Ii]t is the duty of the\\s*#{government}",

      # Multi-line pattern with em-dash (limited)
      "#{government}[^#{@emdash}]{0,#{@max_pre_modal}}?#{@emdash}(?s:.){0,300}?(?:must|shall)[,\\s]+(.{1,#{@post_modal_capture}})"
    ]
  end

  @doc """
  Returns IMPROVED regex patterns for identifying powers conferred.

  Key differences from V1:
  - Pre-modal text limited to #{@max_pre_modal} chars
  - Capture group after "may" to get the power (#{@post_modal_capture} chars)
  """
  @spec power_conferred(String.t()) :: list(pattern())
  def power_conferred(government) do
    [
      # "may by regulations" patterns
      "#{government}[^.;]{0,#{@max_pre_modal}}?may[^.;]{0,50}?by regulations?[^.;]{0,50}?(?:specify|substitute|prescribe|make)",
      "#{government}\\s*may by regulations?[,\\s]+(.{1,#{@post_modal_capture}})",

      # "may direct/vary/make" patterns
      "#{government}\\s*may[^.;]{0,50}?direct[,\\s]+(.{1,#{@post_modal_capture}})",
      "#{government}\\s*may vary the terms",
      "#{government}\\s*may[^.;]{0,50}?make[^.;]{0,50}?(?:scheme|plans?|regulations?)[,\\s]+",

      # "considers necessary" pattern
      "#{government}\\s*considers necessary",

      # "shall have the power" pattern
      "#{government}[^.;]{0,#{@max_pre_modal}}?shall (?:have the power|be entitled)[,\\s]+(.{1,#{@post_modal_capture}})",

      # General "may" pattern (limited, with action capture)
      "#{government}[^—\\.]{0,#{@max_pre_modal}}?may(?!\\s+not|\\s+be)[,\\s]+(.{1,#{@post_modal_capture}})",

      # Ellipsis pattern
      "#{government}[^—\\.]{0,#{@max_pre_modal}}?[\\.\\.\\.].*?may(?!\\s+not)[,\\s]+(.{1,#{@post_modal_capture}})",

      # "is not required" pattern
      "#{government}\\s*is not required",

      # Passive constructions
      "may be (?:varied|terminated) by the\\s*#{government}",
      "may be excluded[^.;]{0,50}?by directions of the\\s*#{government}",

      # "in the opinion of" pattern
      "in the opinion of the\\s*#{government}",

      # Multi-line pattern with em-dash (limited)
      "#{government}[^#{@emdash}]{0,#{@max_pre_modal}}?#{@emdash}(?s:.){0,300}?may(?!\\s+not|\\s+be)[,\\s]+(.{1,#{@post_modal_capture}})"
    ]
  end
end

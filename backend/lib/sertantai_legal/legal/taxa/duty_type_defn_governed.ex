defmodule SertantaiLegal.Legal.Taxa.DutyTypeDefnGoverned do
  @moduledoc """
  Regex pattern definitions for classifying duties and rights placed on governed entities.

  Governed entities are non-government actors like employers, employees, companies,
  contractors, etc. This module provides patterns to identify when these entities
  have duties (obligations) or rights (permissions).

  ## Duty Patterns

  Common patterns include:
  - "The employer shall ensure..."
  - "Every employee must..."
  - "No person shall..."
  - "Where the employer..., he shall..."

  ## Right Patterns

  Common patterns include:
  - "The employee may request..."
  - "Any person is entitled to..."
  - "The worker may appeal..."

  ## Usage

      iex> DutyTypeDefnGoverned.duty("[Ee]mployers?")
      [{"Where.*?employer...", true}, ...]

      iex> DutyTypeDefnGoverned.right("[Ee]mployees?")
      [{"Where.*?employee..., he may", true}, ...]
  """

  @type regex :: String.t()
  @type remove? :: boolean()
  @type pattern :: String.t() | {String.t(), remove?()}

  # ============================================================================
  # Pre-computed Pattern Components (Module Attributes)
  # ============================================================================
  # These are computed once at compile time, avoiding repeated string
  # concatenation at runtime. This improves performance for pattern generation.

  # Em dash character
  @emdash <<226, 128, 148>>

  # Determiners that precede actors
  @determiners ~s/(?:[Aa]n?y?|[Tt]he|[Ee]ach|[Ee]very|[Ee]ach such|[Tt]hat|[Nn]ew|,)/

  # Modal verbs indicating obligation
  @modals ~s/(?:shall|must|may[ ]only|may[ ]not)/

  # Negative lookbehind to exclude certain preceding text
  @neg_lookbehind ~s/(?<! by | of |send it to |given |appointing | to expose | to whom | to pay | to permit |before which )/

  # Negative lookahead for middle of pattern
  @mid_neg_lookahead ~s/(?!is found to |is likely to |to a |to carry |to assess |to analyse|to perform )/

  # Verbs in passive constructions to exclude
  @eds ~s/be entitled|be carried out by|be construed|be consulted|be notified|be informed|be appointed|be retained|be included|be extended|be treated|be necessary|be subjected|be suitable|be made/

  # Negative lookahead for end of pattern (pre-computed with @eds)
  @neg_lookahead ~s/(?!#{@eds}|not apply|consist|have effect|apply)/

  @doc """
  Returns the standard duty pattern for a governed entity.

  Pattern: [neg_lookbehind][determiner][governed][mid_neg_lookahead]...[modal][neg_lookahead]
  """
  @spec duty_pattern(String.t()) :: String.t()
  def duty_pattern(governed) do
    "#{@neg_lookbehind}#{@determiners}#{governed}#{@mid_neg_lookahead}.*?#{@modals}[[:blank:][:punct:]#{@emdash}][ ]?#{@neg_lookahead}"
  end

  @doc """
  Returns duty pattern without determiner.

  Used for cases like: "Generators and distributors shall take"
  """
  @spec no_determiner_pattern(String.t()) :: String.t()
  def no_determiner_pattern(governed) do
    "#{governed}#{@mid_neg_lookahead}.*?#{@modals}[[:blank:][:punct:]#{@emdash}][ ]?#{@neg_lookahead}"
  end

  @doc """
  Returns pattern for "responsible for" constructions.

  E.g.: "The employer remains responsible for..."
  """
  @spec responsible_for_pattern(String.t()) :: String.t()
  def responsible_for_pattern(governed) do
    "#{governed}#{@mid_neg_lookahead}.*?(?:remains|is) (?:responsible|financially liable) for"
  end

  @doc """
  Returns regex patterns for identifying duties placed on governed entities.

  Returns a list of patterns, some with a `{pattern, true}` tuple indicating
  the matched text should be removed before further processing.

  ## Parameters

  - `governed`: A regex pattern for the governed entity (e.g., "[Ee]mployers?")
  """
  # Pre-computed neg_lookbehind with 'and' added for removal patterns
  @neg_lookbehind_rm String.trim_trailing(@neg_lookbehind, ")") <> ~s/|and )/

  @spec duty(String.t()) :: list(pattern())
  def duty("[[:blank:][:punct:]][Hh]e[[:blank:][:punct:]]" = governed) do
    # There is no determiner for 'he' - a 'wash-up' after all other alts
    [{"#{governed}#{@modals}", true}]
  end

  def duty(governed) do
    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]#{@modals}", true},

      # MUST & SHALL w/ REMOVAL
      # The subject and the modal verb are adjacent and are removed from further text processing
      {"#{@neg_lookbehind_rm}#{@determiners}#{governed}#{@modals}[[:blank:][:punct:]#{@emdash}]#{@neg_lookahead}",
       true},

      # SHALL - MUST - MAY ONLY - MAY NOT

      "#{@modals} be (?:carried out|reviewed|prepared).*?#{governed}",

      # Pattern when the 'governed' start on a new line
      "#{@modals} be (?:affixed|carried out) by—$[\\s\\S]*?#{governed}",

      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{@determiners}#{governed}(?s:.)*?^#{@modals} (?!be carried out by)",
      #
      "[Nn]o#{governed}(?:at work )?(?:shall|is to)",
      #
      duty_pattern(governed),
      no_determiner_pattern(governed),

      # When the subject precedes and then gets referred to as 'he'
      # e.g. competent person referred to in paragraph (3) is the user ... or owner ... shall not apply, but he shall
      "#{governed}#{@mid_neg_lookahead}[^#{@emdash}\\.]*?he[ ]shall",

      # SUBJECT 'governed' comes AFTER the VERB 'shall'
      # e.g. "These Regulations shall apply to a self-employed person as they apply to an employer and an employee"
      "shall apply to a.*?#{governed}.*?as they apply to",
      "shall be the duty of #{@determiners}#{governed}",
      "shall be the duty of the.*?and of #{@determiners}#{governed}",
      "shall be (?:selected by|reviewed by|given.*?by) the#{governed}",
      "shall also be imposed on a#{governed}",

      # OTHER VERBS
      "[Nn]o#{governed}may",
      "#{governed}may[ ](?:not|only)",
      "requiring a#{governed}.*?to",
      "#{governed}is.*?under a like duty",
      "#{governed}has taken all.*?steps",
      "Where a duty is placed.*?on an?#{governed}",
      "provided by an?#{governed}",
      responsible_for_pattern(governed),
      "#{governed}.*?(?:shall be|is) liable (?!to)"
    ]
  end

  @doc """
  Returns the standard rights pattern for a governed entity.

  Pattern: [neg_lookbehind][determiner][governed]...may[neg_lookahead]
  """
  @spec rights_pattern(String.t()) :: String.t()
  def rights_pattern(governed) do
    "#{@neg_lookbehind}#{@determiners}#{governed}.*?(?<!which|who)[ ]may[[:blank:][:punct:]][ ]?(?!need|have|require|be[ ]|not|only)"
  end

  @doc """
  Returns rights pattern for multi-line constructions.

  E.g.: "may be made—\n(a) by the employer..."
  """
  @spec rights_new_line_pattern(String.t()) :: String.t()
  def rights_new_line_pattern(governed) do
    # s modifier: single line. Dot matches newline characters
    "may be made—(?s:.)*\\([a-z]\\) by #{@determiners}#{governed}"
  end

  @doc """
  Returns regex patterns for identifying rights granted to governed entities.

  ## Parameters

  - `governed`: A regex pattern for the governed entity (e.g., "[Ee]mployees?")
  """
  @spec right(String.t()) :: list(pattern())
  def right(governed) do
    [
      # WHERE pattern
      {"Where.*?(?:an?y?|the|each|every)#{governed}.*?,[ ]he[ ]may", true},

      # SUBJECT after the VERB
      "requested by a#{governed}",
      # e.g. "the result of that review shall be notified to the employee and employer"
      "(?:shall|must) (?:be notified to the|consult).*?#{governed}",
      # e.g. may be presented to the CAC by a relevant applicant
      "may be (?:varied|terminated|presented).*?by #{@determiners}#{governed}",

      # MAY
      # Does not include 'MAY NOT' and 'MAY ONLY' which are DUTIES
      # Uses a negative lookbehind (?<!element)
      {"#{governed}may[[:blank:][:punct:]][ ]?(?!exceed|need|have|require|be[ ]|not|only)", true},
      rights_pattern(governed),
      "#{governed}.*?shall be entitled",
      "#{governed}.*?is not required",
      "#{governed}may.*?, but may not",
      #
      "permission of that#{governed}",
      "may be made by #{@determiners}.*?#{governed}",
      rights_new_line_pattern(governed)
    ]
  end
end

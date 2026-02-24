defmodule SertantaiLegal.Legal.Taxa.MakingDetector do
  @moduledoc """
  Lightweight Making/Not-Making pre-filter for UK legislation.

  Classifies laws using metadata signals BEFORE the expensive Taxa pipeline.
  Returns a confidence score (0.0-1.0) and three-way classification.

  ## Architecture

  Tiers are additive signal contributors, not a waterfall. All applicable
  tiers run, and their signals combine into a composite score using
  Bayesian-inspired updates from a base rate of 17.3% (the observed
  proportion of Making laws in the UK LRT corpus).

  - **Tier 1**: Definitive title exclusion (Commencement, Appointed Day)
  - **Tier 2**: Strong title exclusion (Amendment, Revocation, etc.)
  - **Tier 3**: Structural metadata (paragraph counts)
  - **Tier 4**: Long title / description analysis (modal language)

  ## Classification Thresholds

  | Composite Score | Classification | Action                        |
  |----------------|----------------|-------------------------------|
  | >= 0.70        | `making`       | Set is_making, send to AI     |
  | <= 0.30        | `not_making`   | Skip taxa/AI                  |
  | 0.30 - 0.70    | `uncertain`    | Queue for AI analysis         |

  ## Usage

      result = MakingDetector.detect(%{
        title_en: "Health and Safety at Work etc. Act 1974",
        md_description: "An Act to make further provision for securing...",
        md_body_paras: 85,
        md_schedule_paras: 12
      })
      # => %{confidence: 0.82, classification: :making, tier: 4, signals: [...]}

      fields = MakingDetector.to_parsed_law_fields(result)
      # => %{making_confidence: 0.82, making_classification: "making", ...}
  """

  alias SertantaiLegal.Legal.Taxa.MakingDetectorSignals, as: Signals

  @type detection_result :: %{
          confidence: float(),
          classification: :making | :not_making | :uncertain,
          tier: integer(),
          signals: [Signals.signal()],
          version: integer()
        }

  # Classification thresholds
  @making_threshold 0.70
  @not_making_threshold 0.30

  # Base rate: 17.3% of laws are Making (3,334 / 19,318 in corpus)
  @base_rate 0.173

  # Tier weights for composite score calculation.
  # Higher tiers have less weight since they are less certain.
  @tier_weights %{1 => 0.95, 2 => 0.75, 3 => 0.50, 4 => 0.65}

  # Current detection algorithm version
  @version 1

  @doc """
  Run all detection tiers on metadata and return composite result.

  ## Parameters

  - `metadata` — Map with keys from the metadata stage:
    - `:title_en` — law title (required for Tier 1-2)
    - `:md_description` — dc:description / long title (for Tier 4)
    - `:md_body_paras` — body paragraph count (for Tier 3)
    - `:md_schedule_paras` — schedule paragraph count (for Tier 3)

  ## Returns

  A detection result map with composite confidence score, classification,
  highest tier that contributed, all signals, and algorithm version.
  """
  @spec detect(map()) :: detection_result()
  def detect(metadata) when is_map(metadata) do
    signals =
      []
      |> Signals.tier1_title_definitive(metadata)
      |> Signals.tier2_title_strong(metadata)
      |> Signals.tier3_structural(metadata)
      |> Signals.tier4_description(metadata)

    composite = calculate_composite_score(signals)
    classification = classify(composite)
    highest_tier = signals |> Enum.map(& &1.tier) |> Enum.max(fn -> 0 end)

    %{
      confidence: composite,
      classification: classification,
      tier: highest_tier,
      signals: signals,
      version: @version
    }
  end

  @doc """
  Convert detection result to a map of fields for ParsedLaw merge.
  """
  @spec to_parsed_law_fields(detection_result()) :: map()
  def to_parsed_law_fields(%{} = result) do
    classification_str = Atom.to_string(result.classification)

    %{
      making_confidence: result.confidence,
      making_classification: classification_str,
      making_detection_tier: result.tier,
      making_detection_signals: %{
        "signals" => Enum.map(result.signals, &signal_to_map/1),
        "composite_score" => result.confidence,
        "classification" => classification_str,
        "detected_at" => "metadata",
        "version" => result.version
      }
    }
  end

  @doc """
  Return the current Making threshold.
  """
  @spec making_threshold() :: float()
  def making_threshold, do: @making_threshold

  @doc """
  Return the current Not-Making threshold.
  """
  @spec not_making_threshold() :: float()
  def not_making_threshold, do: @not_making_threshold

  # ============================================================================
  # Composite Score Calculation
  # ============================================================================
  #
  # Bayesian-inspired update from base rate.
  # Start at prior 0.173 (base rate: 17.3% of laws are Making).
  # Each signal adjusts the score toward 0.0 or 1.0:
  #
  #   not_making: score = score * (1 - signal.confidence * tier_weight)
  #   making:     score = score + (1 - score) * signal.confidence * tier_weight
  #
  # Signals are sorted so not_making signals apply first, then making signals.
  # This ensures making signals (e.g., high body count) can counterbalance
  # title-based exclusions, which matches the intent that structural evidence
  # should override title heuristics.

  @doc false
  @spec calculate_composite_score([Signals.signal()]) :: float()
  def calculate_composite_score([]), do: @base_rate

  def calculate_composite_score(signals) when is_list(signals) do
    # Sort: not_making signals first, then making signals.
    # Within each group, sort by tier (lower tiers first).
    sorted =
      Enum.sort_by(signals, fn s ->
        direction_order = if s.direction == :not_making, do: 0, else: 1
        {direction_order, s.tier}
      end)

    sorted
    |> Enum.reduce(@base_rate, fn signal, score ->
      weight = Map.get(@tier_weights, signal.tier, 0.5)

      case signal.direction do
        :not_making ->
          score * (1.0 - signal.confidence * weight)

        :making ->
          score + (1.0 - score) * signal.confidence * weight
      end
    end)
    |> Float.round(4)
  end

  # ============================================================================
  # Classification
  # ============================================================================

  defp classify(score) when score >= @making_threshold, do: :making
  defp classify(score) when score <= @not_making_threshold, do: :not_making
  defp classify(_score), do: :uncertain

  # ============================================================================
  # Signal Serialization
  # ============================================================================

  defp signal_to_map(signal) do
    %{
      "tier" => signal.tier,
      "signal" => signal.signal,
      "direction" => Atom.to_string(signal.direction),
      "confidence" => signal.confidence,
      "value" => to_string(signal.value)
    }
  end
end

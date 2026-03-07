defmodule SertantaiLegal.Legal.Taxa.MakingDetectorSignals do
  @moduledoc """
  Individual signal extractors for Making detection.

  Each function takes an accumulator list and metadata map,
  and appends zero or more signals to the list. Signals are maps with:

  - `:tier` — integer 1-4 indicating the detection tier
  - `:signal` — string name for the specific signal
  - `:direction` — `:making` or `:not_making`
  - `:confidence` — float 0.0-1.0 for this individual signal
  - `:value` — the evidence that triggered the signal

  ## Tier Architecture

  Tiers are additive signal contributors, not a waterfall.
  All applicable tiers run, and their signals combine into a composite score
  in `MakingDetector.calculate_composite_score/1`.

  - **Tier 1**: Definitive title exclusion (Commencement, Appointed Day)
  - **Tier 2**: Strong title exclusion (Amendment, Revocation, etc.)
  - **Tier 3**: Structural metadata (paragraph counts)
  - **Tier 4**: Long title / description analysis (modal language)
  """

  @type signal :: %{
          tier: integer(),
          signal: String.t(),
          direction: :making | :not_making,
          confidence: float(),
          value: any()
        }

  # ============================================================================
  # Tier 1: Definitive Title Exclusion
  # ============================================================================
  # "(Commencement" -> 99% not Making (12/1163 = 1.0% FP rate in Airtable data)
  # "(Appointed Day" -> 100% not Making (0 FP in Airtable data)

  @doc """
  Tier 1: Definitive title-based exclusion signals.

  Commencement orders and Appointed Day orders are definitively not Making.
  """
  @spec tier1_title_definitive([signal()], map()) :: [signal()]
  def tier1_title_definitive(signals, %{title_en: title}) when is_binary(title) do
    cond do
      String.contains?(title, "(Appointed Day") ->
        [
          %{
            tier: 1,
            signal: "title_appointed_day",
            direction: :not_making,
            confidence: 1.0,
            value: title
          }
          | signals
        ]

      String.contains?(title, "(Commencement") ->
        [
          %{
            tier: 1,
            signal: "title_commencement",
            direction: :not_making,
            confidence: 0.99,
            value: title
          }
          | signals
        ]

      true ->
        signals
    end
  end

  def tier1_title_definitive(signals, _metadata), do: signals

  # ============================================================================
  # Tier 2: Strong Title Exclusion
  # ============================================================================
  # "(Amendment" -> ~93% not Making (288/3955 = 7.3% FP rate)
  # "(Revocation" -> ~100% not Making
  # "(Consequential" -> ~96% not Making
  # "(Transitional" -> ~83% not Making
  # "(Repeal" -> ~95% not Making

  @doc """
  Tier 2: Strong title-based signals.

  Exclusion patterns strongly indicate non-Making laws.
  Positive patterns (e.g. "Regulations") indicate potential Making laws
  when no exclusion marker is present.

  Data-driven confidence from corpus analysis (19,318 records):
  - "Regulations" without exclusion: 31.3% Making (1.8x base rate)
  - "Rules" without exclusion: 21.6% Making (1.2x base rate)
  - "Directive" without exclusion: 0% Making
  - "Scheme" without exclusion: 2% Making
  """
  @spec tier2_title_strong([signal()], map()) :: [signal()]
  def tier2_title_strong(signals, %{title_en: title}) when is_binary(title) do
    has_exclusion =
      String.contains?(title, "(Revocation") or
        String.contains?(title, "(Consequential") or
        String.contains?(title, "(Repeal") or
        String.contains?(title, "(Amendment") or
        String.contains?(title, "(Transitional")

    signals
    # Exclusion signals (always checked)
    |> maybe_add_title_signal(title, "(Revocation", "title_revocation", :not_making, 0.98)
    |> maybe_add_title_signal(title, "(Consequential", "title_consequential", :not_making, 0.90)
    |> maybe_add_title_signal(title, "(Repeal", "title_repeal", :not_making, 0.92)
    |> maybe_add_title_signal(title, "(Amendment", "title_amendment", :not_making, 0.80)
    |> maybe_add_title_signal(title, "(Transitional", "title_transitional", :not_making, 0.75)
    # Positive signals (only when no exclusion marker present)
    |> maybe_add_positive_title_signal(
      title,
      has_exclusion,
      "Regulations",
      "title_regulations",
      0.55
    )
    |> maybe_add_positive_title_signal(title, has_exclusion, "Rules", "title_rules", 0.35)
    # Negative signals for non-Making instrument types
    |> maybe_add_title_signal(title, "Directive", "title_directive", :not_making, 0.85)
    |> maybe_add_title_signal(title, "Scheme", "title_scheme", :not_making, 0.70)
  end

  def tier2_title_strong(signals, _metadata), do: signals

  defp maybe_add_title_signal(signals, title, pattern, name, direction, confidence) do
    if String.contains?(title, pattern) do
      [
        %{tier: 2, signal: name, direction: direction, confidence: confidence, value: title}
        | signals
      ]
    else
      signals
    end
  end

  defp maybe_add_positive_title_signal(signals, title, has_exclusion, pattern, name, confidence) do
    if not has_exclusion and String.contains?(title, pattern) do
      [
        %{tier: 2, signal: name, direction: :making, confidence: confidence, value: title}
        | signals
      ]
    else
      signals
    end
  end

  # ============================================================================
  # Tier 3: Structural Metadata
  # ============================================================================

  @doc """
  Tier 3: Structural metadata signals from paragraph counts.

  Uses body/schedule paragraph ratios and absolute counts to
  identify amending instruments (low body, high schedule) and
  substantive laws (high body count).
  """
  @spec tier3_structural([signal()], map()) :: [signal()]
  def tier3_structural(signals, metadata) do
    signals
    |> check_body_schedule_ratio(metadata)
    |> check_high_body_count(metadata)
    |> check_moderate_body_count(metadata)
    |> check_low_body_count(metadata)
  end

  # Low body + high schedule = amending/commencement pattern
  defp check_body_schedule_ratio(signals, %{md_body_paras: body, md_schedule_paras: sched})
       when is_integer(body) and is_integer(sched) and body <= 3 and sched > 50 do
    [
      %{
        tier: 3,
        signal: "low_body_high_schedule",
        direction: :not_making,
        confidence: 0.90,
        value: "body=#{body},sched=#{sched}"
      }
      | signals
    ]
  end

  defp check_body_schedule_ratio(signals, _metadata), do: signals

  # High body count counterbalances title exclusion signals.
  # Amendment-titled laws with body > 50 are often substantive Making laws.
  defp check_high_body_count(signals, %{md_body_paras: body})
       when is_integer(body) and body > 50 do
    confidence = min(0.85, 0.50 + body / 500.0)

    [
      %{
        tier: 3,
        signal: "high_body_paras",
        direction: :making,
        confidence: Float.round(confidence, 2),
        value: body
      }
      | signals
    ]
  end

  defp check_high_body_count(signals, _metadata), do: signals

  # Moderate body count (11-50) indicates substantive content.
  # Corpus data: 39.8% Making rate in this range (2.3x base rate).
  # Lower confidence than high_body_paras since it's less definitive.
  defp check_moderate_body_count(signals, %{md_body_paras: body})
       when is_integer(body) and body >= 11 and body <= 50 do
    [
      %{
        tier: 3,
        signal: "moderate_body_paras",
        direction: :making,
        confidence: 0.40,
        value: body
      }
      | signals
    ]
  end

  defp check_moderate_body_count(signals, _metadata), do: signals

  # Very low body count = unlikely to be substantive Making
  defp check_low_body_count(signals, %{md_body_paras: body})
       when is_integer(body) and body <= 5 do
    [
      %{
        tier: 3,
        signal: "very_low_body_paras",
        direction: :not_making,
        confidence: 0.60,
        value: body
      }
      | signals
    ]
  end

  defp check_low_body_count(signals, _metadata), do: signals

  # ============================================================================
  # Tier 4: Long Title / Description Analysis
  # ============================================================================

  @making_description_patterns [
    {"to make provision for securing", "provision_securing", 0.90},
    {"to make provision for", "provision_for", 0.70},
    {"to require", "to_require", 0.80},
    {"to prohibit", "to_prohibit", 0.80},
    {"to regulate", "to_regulate", 0.75},
    {"to impose", "to_impose", 0.80},
    {"to establish", "to_establish", 0.70},
    {"to create", "to_create", 0.70}
  ]

  @not_making_description_patterns [
    {"to amend the", "desc_to_amend", 0.75},
    {"to give effect to", "desc_give_effect", 0.65},
    {"in exercise of the powers conferred by", "desc_powers_conferred", 0.55}
  ]

  @doc """
  Tier 4: Long title / description analysis.

  Examines `md_description` (the dc:description from introduction XML)
  for modal language patterns indicating Making or Not-Making.
  """
  @spec tier4_description([signal()], map()) :: [signal()]
  def tier4_description(signals, %{md_description: desc})
      when is_binary(desc) and desc != "" do
    desc_lower = String.downcase(desc)

    signals
    |> check_description_patterns(desc, desc_lower, @making_description_patterns, :making)
    |> check_description_patterns(desc, desc_lower, @not_making_description_patterns, :not_making)
  end

  def tier4_description(signals, _metadata), do: signals

  defp check_description_patterns(signals, desc, desc_lower, patterns, direction) do
    Enum.reduce(patterns, signals, fn {pattern, name, confidence}, acc ->
      if String.contains?(desc_lower, pattern) do
        [
          %{
            tier: 4,
            signal: name,
            direction: direction,
            confidence: confidence,
            value: String.slice(desc, 0, 200)
          }
          | acc
        ]
      else
        acc
      end
    end)
  end
end

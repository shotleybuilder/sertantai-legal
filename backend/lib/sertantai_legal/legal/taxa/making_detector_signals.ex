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
  Tier 2: Strong title-based exclusion signals.

  These title patterns strongly indicate non-Making laws, but have
  measurable false positive rates (especially Amendment).
  """
  @spec tier2_title_strong([signal()], map()) :: [signal()]
  def tier2_title_strong(signals, %{title_en: title}) when is_binary(title) do
    signals
    |> maybe_add_title_signal(title, "(Revocation", "title_revocation", 0.98)
    |> maybe_add_title_signal(title, "(Consequential", "title_consequential", 0.90)
    |> maybe_add_title_signal(title, "(Repeal", "title_repeal", 0.92)
    |> maybe_add_title_signal(title, "(Amendment", "title_amendment", 0.80)
    |> maybe_add_title_signal(title, "(Transitional", "title_transitional", 0.75)
  end

  def tier2_title_strong(signals, _metadata), do: signals

  defp maybe_add_title_signal(signals, title, pattern, name, confidence) do
    if String.contains?(title, pattern) do
      [
        %{tier: 2, signal: name, direction: :not_making, confidence: confidence, value: title}
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

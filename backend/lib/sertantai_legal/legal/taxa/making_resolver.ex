defmodule SertantaiLegal.Legal.Taxa.MakingResolver do
  @moduledoc """
  Decides `is_making` from the evidence gathered by the Making funnel.

  Pure: takes an `Evidence` struct, returns a `Decision`. No DB access.

  The funnel produces evidence of increasing cost and reliability. A higher
  tier always wins; a tier without a verdict defers to the next one down.

  | Tier           | Evidence                                        | Verdicts                                      |
  |----------------|-------------------------------------------------|-----------------------------------------------|
  | `:review`      | `making_review` (human)                         | making → true, not_making → false             |
  | `:enrichment`  | fractalaw DRRP enrichment verdict               | making → true, empowering / no_obligations → false |
  | `:legacy_drrp` | `duty_type` with no enrichment provenance       | Duty/Responsibility/Obligation → true, else none |
  | `:triage`      | fractalaw triage classification                 | making → true, not_making → false, uncertain → none |
  | `:legacy_is_making` | `is_making` stored before the resolver (no `is_making_source`) — curated legacy value | its value |
  | `:detector`    | MakingDetector classification                   | as triage                                     |
  | `:default`     | —                                               | keep the current value; never set → false     |

  Legacy DRRP never downgrades on its own: Rights/Powers-only legacy data
  gives no verdict. Unknown verdict strings are ignored, not guessed.

  `:legacy_is_making` sits above the detector so a first-stage guess can't
  overturn a curated pre-resolver value (e.g. provenance stamped on legacy
  laws by `legal.backfill_making_provenance` without changing `is_making`).

  The `Decision` also lists `dissent`: lower tiers whose verdict disagrees
  with the outcome, so conflicts stay visible instead of silently overwritten.
  """

  defmodule Evidence do
    @moduledoc "Evidence for one law, one field per funnel tier."
    @enforce_keys [
      :review,
      :enrichment,
      :legacy_duty_types,
      :triage,
      :legacy_is_making,
      :detector,
      :current
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            review: String.t() | nil,
            enrichment: String.t() | nil,
            legacy_duty_types: [String.t()] | nil,
            triage: String.t() | nil,
            legacy_is_making: boolean() | nil,
            detector: String.t() | nil,
            current: boolean() | nil
          }
  end

  defmodule Decision do
    @moduledoc "The resolved `is_making`, the tier that decided it, and why."
    @enforce_keys [:is_making, :source, :reason, :dissent]
    defstruct @enforce_keys

    @type tier ::
            :review
            | :enrichment
            | :legacy_drrp
            | :triage
            | :legacy_is_making
            | :detector
            | :default
    @type t :: %__MODULE__{
            is_making: boolean(),
            source: tier(),
            reason: String.t(),
            dissent: [tier()]
          }
  end

  @making_duty_types ["Duty", "Responsibility", "Obligation"]
  @tiers [:review, :enrichment, :legacy_drrp, :triage, :legacy_is_making, :detector]

  @doc """
  Resolve `is_making` from the evidence. See the moduledoc for precedence.
  """
  @spec resolve(Evidence.t()) :: Decision.t()
  def resolve(%Evidence{} = evidence) do
    verdicts = Enum.map(@tiers, fn tier -> {tier, verdict(tier, evidence)} end)

    case Enum.find(verdicts, fn {_tier, v} -> v != nil end) do
      {tier, {is_making, reason}} ->
        %Decision{
          is_making: is_making,
          source: tier,
          reason: reason,
          dissent: dissent(verdicts, tier, is_making)
        }

      nil ->
        default(evidence.current)
    end
  end

  @doc """
  Enrichment verdict from the DRRP types fractalaw found for a law.

  Duty/Responsibility/Obligation → "making"; any other DRRP (Rights, Powers)
  → "empowering"; none → "no_obligations".
  """
  @spec enrichment_verdict([String.t()]) :: String.t()
  def enrichment_verdict(duty_types) when is_list(duty_types) do
    cond do
      Enum.any?(duty_types, &(&1 in @making_duty_types)) -> "making"
      duty_types != [] -> "empowering"
      true -> "no_obligations"
    end
  end

  # ── Tier verdicts: {is_making, reason} or nil for "no verdict" ──

  defp verdict(:review, %{review: "making"}), do: {true, "review: making"}
  defp verdict(:review, %{review: "not_making"}), do: {false, "review: not_making"}

  defp verdict(:enrichment, %{enrichment: "making"}),
    do: {true, "enrichment: making (duties or responsibilities found)"}

  defp verdict(:enrichment, %{enrichment: "empowering"}),
    do: {false, "enrichment: empowering (rights or powers only)"}

  defp verdict(:enrichment, %{enrichment: "no_obligations"}),
    do: {false, "enrichment: no_obligations (no DRRP found)"}

  defp verdict(:legacy_drrp, %{legacy_duty_types: types}) when is_list(types) do
    if Enum.any?(types, &(&1 in @making_duty_types)) do
      {true, "legacy_drrp: duty types " <> Enum.join(types, ", ")}
    end
  end

  defp verdict(:legacy_is_making, %{legacy_is_making: value}) when is_boolean(value),
    do: {value, "legacy_is_making: #{value} (set before the resolver, no recorded source)"}

  defp verdict(tier, evidence) when tier in [:triage, :detector] do
    case Map.fetch!(evidence, tier) do
      "making" -> {true, "#{tier}: making"}
      "not_making" -> {false, "#{tier}: not_making"}
      _ -> nil
    end
  end

  defp verdict(_tier, _evidence), do: nil

  defp dissent(verdicts, decided_by, is_making) do
    verdicts
    |> Enum.drop_while(fn {tier, _} -> tier != decided_by end)
    |> Enum.drop(1)
    |> Enum.filter(fn {_tier, v} -> v != nil and elem(v, 0) != is_making end)
    |> Enum.map(fn {tier, _} -> tier end)
  end

  defp default(current) when is_boolean(current) do
    %Decision{
      is_making: current,
      source: :default,
      reason: "default: no verdict from any tier, kept existing #{current}",
      dissent: []
    }
  end

  defp default(nil) do
    %Decision{
      is_making: false,
      source: :default,
      reason: "default: no verdict from any tier, never set, defaults to false",
      dissent: []
    }
  end
end

defmodule SertantaiLegal.Legal.Making do
  @moduledoc """
  The single write path for Making evidence and `is_making` (QQ-01a).

  Every writer (triage and taxa subscribers, persister, admin UI, human
  review, backfill) hands its evidence to `record/3` instead of setting
  `is_making` itself. `record/3`:

  1. locks the law's row, so concurrent Zenoh subscribers apply in turn;
  2. merges the incoming evidence with the stored evidence;
  3. resolves `is_making` with `MakingResolver` (callers can't set it);
  4. writes `is_making_source`, `is_making_reason` and, when the decision
     changes, `is_making_decided_at`;
  5. appends a `record_change_log` entry (`source: "making"`) carrying the
     writer, the reason and the dissenting tiers.

  Rules applied to incoming evidence:

  - A detector classification never overwrites a triage classification.
  - A `making_review` without a timestamp is stamped now.
  - `is_making` in the incoming evidence is ignored.

  `plan/4` and `evidence/1` are pure and hold all the logic; `record/3` only
  does the locking and the update.
  """

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Taxa.MakingResolver
  alias SertantaiLegal.Legal.Taxa.MakingResolver.Evidence
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeLogger

  @estimate_fields [
    :making_classification,
    :making_classification_source,
    :making_confidence,
    :making_detection_tier,
    :making_detection_signals
  ]

  @doc """
  Record Making evidence for a law and re-resolve `is_making`, under a row lock.
  """
  @spec record(LegalRegister.t(), map(), String.t()) ::
          {:ok, LegalRegister.t()} | {:error, term()}
  def record(%LegalRegister{id: id}, evidence_attrs, changed_by) do
    Repo.transaction(fn ->
      Repo.query!("SELECT 1 FROM legal_register WHERE id = $1 FOR UPDATE", [
        Ecto.UUID.dump!(id)
      ])

      with {:ok, current} <- Ash.get(LegalRegister, id),
           attrs = plan(current, evidence_attrs, changed_by, DateTime.utc_now()),
           {:ok, updated} <- Ash.update(current, attrs, action: :update) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Pure: the update attrs for `current` given incoming evidence.

  Returns the accepted evidence fields plus `is_making`, `is_making_source`,
  `is_making_reason`, and — only when something changed — `is_making_decided_at`
  and an appended `record_change_log`.
  """
  @spec plan(map(), map(), String.t(), DateTime.t()) :: map()
  def plan(current, evidence_attrs, changed_by, now) do
    current = to_map(current)

    incoming =
      evidence_attrs
      |> Map.delete(:is_making)
      |> guard_estimate(current)
      |> stamp_review(now)

    decision = current |> Map.merge(incoming) |> evidence() |> MakingResolver.resolve()

    decision_attrs = %{
      is_making: decision.is_making,
      is_making_source: Atom.to_string(decision.source),
      is_making_reason: decision.reason
    }

    decision_attrs =
      if Enum.any?(decision_attrs, fn {k, v} -> Map.get(current, k) != v end),
        do: Map.put(decision_attrs, :is_making_decided_at, now),
        else: decision_attrs

    attrs = Map.merge(incoming, decision_attrs)

    case ChangeLogger.build_change_entry(current, attrs, changed_by, source: "making") do
      {:ok, entry} ->
        entry =
          Map.merge(entry, %{
            "reason" => decision.reason,
            "dissent" => Enum.map(decision.dissent, &Atom.to_string/1)
          })

        Map.put(
          attrs,
          :record_change_log,
          ChangeLogger.append_to_log(current[:record_change_log], entry)
        )

      {:no_changes, nil} ->
        attrs
    end
  end

  @doc """
  Pure: build resolver evidence from a record (or record-like map).

  A classification counts as triage only when `making_classification_source`
  is "triage"; otherwise it's treated as the weaker detector estimate.
  """
  @spec evidence(map()) :: Evidence.t()
  def evidence(record) do
    record = to_map(record)
    {triage, detector} = estimate(record)

    %Evidence{
      review: record[:making_review],
      enrichment: record[:making_enrichment_verdict],
      legacy_duty_types: duty_type_values(record[:duty_type]),
      triage: triage,
      legacy_is_making: legacy_is_making(record),
      detector: detector,
      current: record[:is_making]
    }
  end

  # is_making stored before the resolver existed carries no is_making_source.
  defp legacy_is_making(%{is_making_source: nil, is_making: value}) when is_boolean(value),
    do: value

  defp legacy_is_making(_record), do: nil

  defp estimate(%{making_classification_source: "triage", making_classification: c}),
    do: {c, nil}

  defp estimate(record), do: {nil, record[:making_classification]}

  defp duty_type_values(%{values: values}) when is_list(values), do: values
  defp duty_type_values(%{"values" => values}) when is_list(values), do: values
  defp duty_type_values(_), do: nil

  defp guard_estimate(
         %{making_classification_source: "detector"} = incoming,
         %{making_classification_source: "triage"}
       ),
       do: Map.drop(incoming, @estimate_fields)

  defp guard_estimate(incoming, _current), do: incoming

  defp stamp_review(%{making_review: review} = incoming, now)
       when is_binary(review) and not is_map_key(incoming, :making_review_at),
       do: Map.put(incoming, :making_review_at, now)

  defp stamp_review(incoming, _now), do: incoming

  defp to_map(%_{} = struct), do: Map.from_struct(struct)
  defp to_map(map) when is_map(map), do: map
end

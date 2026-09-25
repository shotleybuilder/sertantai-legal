defmodule SertantaiLegal.Legal.Making.Backfill do
  @moduledoc """
  Backfill Making provenance and re-resolve `is_making` corpus-wide (QQ-01a).

  Before `Legal.Making` existed, evidence was stored without its source.
  This module recovers what it can from the stored columns:

  - `making_classification_source` from the shape of `making_detection_signals`:
    detector output has `detected_at` (or is a double-encoded detector string,
    which is decoded); triage output is a map of counts.

  No enrichment verdict is inferred. Historical `duty_type` counts only as
  `legacy_drrp` evidence (it can upgrade a law, never downgrade one): fractalaw's
  published DRRP aggregates were stale (pre-hub regex pass), and fitness does
  not imply DRRP ran (triage gates it). Enrichment verdicts come only from
  fresh taxa publishes through `TaxaSubscriber`.

  `infer_evidence/1` is pure. `load_rows/1` reads the columns the resolver
  needs; `plan_rows/2` runs `Making.plan/4` over them. `Mix.Tasks.Making.Resolve`
  reports and applies the result.
  """

  alias SertantaiLegal.Legal.Making
  alias SertantaiLegal.Repo

  @columns ~w(id name country title_en live is_making is_making_source is_making_reason
              making_review making_enrichment_verdict making_classification
              making_classification_source making_confidence making_detection_tier
              making_detection_signals duty_type)a

  @doc "Pure: the evidence attrs to record for one row (only what's missing)."
  @spec infer_evidence(map()) :: map()
  def infer_evidence(row) do
    infer_classification_source(%{}, row)
  end

  @doc """
  Load the Making columns. Options: `:names` (list of law names),
  `:country` ("uk" | "au"). No options loads every law.
  """
  @spec load_rows(keyword()) :: [map()]
  def load_rows(opts \\ []) do
    select = Enum.map_join(@columns, ", ", &Atom.to_string/1)

    {conditions, params} =
      [names: "name = ANY($?)", country: "country = $?"]
      |> Enum.reduce({[], []}, fn {key, clause}, {conds, params} ->
        case opts[key] do
          nil ->
            {conds, params}

          value ->
            n = length(params) + 1
            {conds ++ [String.replace(clause, "$?", "$#{n}")], params ++ [value]}
        end
      end)

    where = if conditions == [], do: "", else: " WHERE " <> Enum.join(conditions, " AND ")

    %{rows: rows} =
      Repo.query!("SELECT #{select} FROM legal_register#{where} ORDER BY name", params)

    Enum.map(rows, fn values ->
      @columns
      |> Enum.zip(values)
      |> Map.new()
      |> Map.update!(:id, &Ecto.UUID.cast!/1)
    end)
  end

  @doc """
  Plan the backfill for each row. Returns only rows whose Making state would
  change, as `%{row, evidence, attrs}`.
  """
  @spec plan_rows([map()], DateTime.t()) :: [map()]
  def plan_rows(rows, now) do
    rows
    |> Enum.map(fn row ->
      evidence = infer_evidence(row)
      %{row: row, evidence: evidence, attrs: Making.plan(row, evidence, "backfill", now)}
    end)
    |> Enum.filter(&Map.has_key?(&1.attrs, :record_change_log))
  end

  # ── Inference ──

  defp infer_classification_source(acc, %{making_classification: nil}), do: acc

  defp infer_classification_source(acc, %{making_classification_source: source})
       when is_binary(source),
       do: acc

  defp infer_classification_source(acc, %{making_detection_signals: signals}) do
    case decode(signals) do
      {:decoded, map} ->
        Map.merge(acc, %{making_classification_source: "detector", making_detection_signals: map})

      {:ok, %{"detected_at" => _}} ->
        Map.put(acc, :making_classification_source, "detector")

      {:ok, %{} = counts} when map_size(counts) > 0 ->
        Map.put(acc, :making_classification_source, "triage")

      _ ->
        Map.put(acc, :making_classification_source, "detector")
    end
  end

  defp decode(signals) when is_binary(signals) do
    case Jason.decode(signals) do
      {:ok, %{} = map} -> {:decoded, map}
      _ -> :unknown
    end
  end

  defp decode(%{} = map), do: {:ok, map}
  defp decode(_), do: :unknown
end

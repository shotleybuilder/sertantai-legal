defmodule Mix.Tasks.Legal.InferEuFamilies do
  @shortdoc "Assign family to EU retained law using graph-based inference"

  @moduledoc """
  Uses law_edges relationships to infer family for EU retained law (eur, eudr, eudn)
  that has NULL family. EU laws have no SI codes, so family must come from graph
  neighbours — typically UK SIs that amend or are amended by the EU law.

  ## Usage

      mix legal.infer_eu_families           # Dry run (report only)
      mix legal.infer_eu_families --apply   # Apply changes to database

  ## Algorithm

  For each EU law with NULL family:
  1. Run FamilyInference.infer/1 which checks enacted_by parents, amendment
     targets, and amender sources (reverse edges)
  2. If a suggested family is returned with sufficient confidence, assign it
  3. If the top two families from amenders are close (tie), assign family_ii

  ## Prerequisites

  Requires law_edges table to be populated: `mix law_edges.rebuild`
  """

  use Mix.Task

  alias SertantaiLegal.Legal.FamilyInference
  alias SertantaiLegal.Repo

  @eu_type_codes ["eur", "eudr", "eudn"]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    apply? = "--apply" in args

    IO.puts("=== EU Retained Law Family Inference ===")
    IO.puts("Mode: #{if apply?, do: "APPLY", else: "DRY RUN"}\n")

    # Find EU laws with NULL family
    sql = """
    SELECT name, type_code, title_en
    FROM uk_lrt
    WHERE type_code = ANY($1) AND family IS NULL
    ORDER BY type_code, name
    """

    {:ok, %{rows: rows}} = Repo.query(sql, [@eu_type_codes])
    IO.puts("EU laws with NULL family: #{length(rows)}\n")

    # Run inference on each
    results =
      rows
      |> Enum.map(fn [name, type_code, title] ->
        inference = FamilyInference.infer(name)

        %{
          name: name,
          type_code: type_code,
          title: title,
          suggested: inference.suggested_family,
          confidence: inference.confidence,
          amender_families: Map.get(inference, :amender_families, []),
          parent_families: inference.parent_families,
          target_families: inference.target_families
        }
      end)

    # Partition by outcome
    {assignable, no_signal} = Enum.split_with(results, &(&1.suggested != nil))

    # For assignable laws, determine family_ii from second-ranked amender family
    assignments =
      Enum.map(assignable, fn result ->
        family_ii = second_family(result)
        Map.put(result, :family_ii, family_ii)
      end)

    # Print summary by confidence level
    by_confidence = Enum.group_by(assignments, & &1.confidence)

    for {confidence, laws} <- Enum.sort_by(by_confidence, fn {_, v} -> -length(v) end) do
      IO.puts("  #{confidence}: #{length(laws)} laws")
    end

    IO.puts("\n  Assignable: #{length(assignments)}")
    IO.puts("  No signal:  #{length(no_signal)}")

    with_ii = Enum.count(assignments, &(&1.family_ii != nil))
    IO.puts("  With family_ii: #{with_ii}\n")

    # Print sample
    IO.puts("--- Sample assignments (first 15) ---")

    assignments
    |> Enum.take(15)
    |> Enum.each(fn a ->
      ii = if a.family_ii, do: " | ii: #{a.family_ii}", else: ""
      title = truncate(a.title, 60)
      IO.puts("  #{a.name} → #{a.suggested}#{ii}")
      IO.puts("    #{a.confidence} | #{title}")
    end)

    if no_signal != [] do
      IO.puts("\n--- No signal (first 10) ---")

      no_signal
      |> Enum.take(10)
      |> Enum.each(fn r ->
        IO.puts("  #{r.name} — #{truncate(r.title, 70)}")
      end)
    end

    # Apply if requested
    if apply? and assignments != [] do
      IO.puts("\n=== Applying #{length(assignments)} family assignments ===")

      {ok, err} =
        Enum.reduce(assignments, {0, 0}, fn a, {ok_count, err_count} ->
          case apply_family(a.name, a.suggested, a.family_ii) do
            :ok -> {ok_count + 1, err_count}
            :error -> {ok_count, err_count + 1}
          end
        end)

      IO.puts("\n  Applied: #{ok}")
      IO.puts("  Errors:  #{err}")
    else
      unless apply? do
        IO.puts("\nDry run complete. Re-run with --apply to update the database.")
      end
    end
  end

  # Extract the second-ranked family from amender families, if it's meaningful
  defp second_family(%{amender_families: amenders, suggested: primary}) do
    case amenders do
      [{_, _}, {fam, cnt} | _] when cnt >= 2 and fam != primary -> fam
      _ -> nil
    end
  end

  defp apply_family(name, family, family_ii) do
    ii_clause = if family_ii, do: ", family_ii = $3", else: ""
    params = if family_ii, do: [family, name, family_ii], else: [family, name]

    sql = "UPDATE uk_lrt SET family = $1#{ii_clause} WHERE name = $2 AND family IS NULL"

    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, %{num_rows: 0}} -> :ok
      _ -> :error
    end
  end

  defp truncate(nil, _), do: "(no title)"
  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: String.slice(s, 0, max) <> "…"
end

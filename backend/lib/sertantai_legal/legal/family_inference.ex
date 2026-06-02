defmodule SertantaiLegal.Legal.FamilyInference do
  @moduledoc """
  Graph-informed family classification for UK legislation.

  Scores the assigned family against graph relationships (enacted_by,
  amending targets) to detect likely misclassifications. Used both
  during realtime LRT parse and in the admin audit UI.

  ## Confidence Levels

  - `:confirmed` — SI code family matches parent/target consensus
  - `:parent_inferred` — parent Act has a different family (high confidence)
  - `:target_consensus` — amendment targets agree on a different family
  - `:si_code_only` — no graph signal, SI code is sole source
  - `:no_family` — no family assigned and no graph signal
  """

  alias SertantaiLegal.Repo

  @placeholder_families [nil, "", "_todo"]

  @type inference :: %{
          assigned_family: String.t() | nil,
          suggested_family: String.t() | nil,
          confidence: atom(),
          parent_families: [{String.t(), non_neg_integer()}],
          target_families: [{String.t(), non_neg_integer()}],
          amender_families: [{String.t(), non_neg_integer()}],
          mismatch: boolean()
        }

  @doc """
  Infer family for a law using the law_edges graph.

  Returns an inference map with the suggested family, confidence level,
  and supporting evidence (parent/target family distributions).
  """
  @spec infer(String.t()) :: inference()
  def infer(law_name) do
    assigned = lookup_family(law_name)

    # Parent families (via enacted_by edges)
    parent_families = edge_families(law_name, "enacted_by", :target)

    # Amendment target families (what does this law amend?)
    target_families = edge_families(law_name, "amends", :target)

    # Amender families (what laws amend this law?) — reverse direction
    # Important for EU retained law which has no SI codes but is amended by UK SIs with families
    amender_families = reverse_edge_families(law_name, "amends")

    # Filter out "No Family" and todo
    meaningful_parents = reject_placeholder_families(parent_families)
    meaningful_targets = reject_placeholder_families(target_families)
    meaningful_amenders = reject_placeholder_families(amender_families)

    {suggested, confidence} =
      cond do
        # No assigned family at all
        assigned in @placeholder_families ->
          suggest_from_graph(meaningful_parents, meaningful_targets, meaningful_amenders)

        # Assigned family matches top parent — confirmed
        meaningful_parents != [] and matches_top?(assigned, meaningful_parents) ->
          {assigned, :confirmed}

        # Assigned family matches target consensus — confirmed
        meaningful_targets != [] and consensus_match?(assigned, meaningful_targets) ->
          {assigned, :confirmed}

        # Assigned family matches amender consensus — confirmed
        meaningful_amenders != [] and consensus_match?(assigned, meaningful_amenders) ->
          {assigned, :confirmed}

        # Parent suggests different family
        meaningful_parents != [] ->
          {top_family(meaningful_parents), :parent_inferred}

        # Target consensus suggests different family
        meaningful_targets != [] and has_consensus?(meaningful_targets) ->
          {top_family(meaningful_targets), :target_consensus}

        # Amender consensus suggests different family
        meaningful_amenders != [] and has_consensus?(meaningful_amenders) ->
          {top_family(meaningful_amenders), :amender_consensus}

        # No graph signal
        true ->
          {assigned, :si_code_only}
      end

    %{
      assigned_family: assigned,
      suggested_family: suggested,
      confidence: confidence,
      parent_families: meaningful_parents,
      target_families: Enum.take(meaningful_targets, 5),
      amender_families: Enum.take(meaningful_amenders, 5),
      mismatch: suggested != nil and assigned != nil and suggested != assigned
    }
  end

  @doc """
  Batch infer families for all laws with potential mismatches.

  Returns only laws where the graph suggests a different family than assigned.
  Excludes laws with no family and no graph signal.
  """
  @spec find_mismatches() :: [map()]
  def find_mismatches do
    sql = """
    SELECT DISTINCT e.source_law
    FROM law_edges e
    WHERE e.edge_type IN ('enacted_by', 'amends')
      AND e.source_family IS NOT NULL
      AND e.target_family IS NOT NULL
      AND e.source_family != e.target_family
    ORDER BY e.source_law
    """

    {:ok, %{rows: rows}} = Repo.query(sql)

    rows
    |> Enum.map(fn [law_name] -> law_name end)
    |> Enum.map(fn name ->
      inference = infer(name)
      Map.put(inference, :law_name, name)
    end)
    |> Enum.filter(& &1.mismatch)
  end

  @doc """
  Summary statistics for family inference across the corpus.
  """
  @spec summary_stats() :: map()
  def summary_stats do
    sql = """
    SELECT
      COUNT(DISTINCT source_law) AS laws_with_edges,
      COUNT(DISTINCT source_law) FILTER (
        WHERE source_family IS NOT NULL
          AND target_family IS NOT NULL
          AND source_family != target_family
      ) AS potential_mismatches,
      COUNT(DISTINCT source_law) FILTER (
        WHERE edge_type = 'enacted_by'
          AND target_family IS NOT NULL
      ) AS laws_with_classified_parents
    FROM law_edges
    """

    {:ok, %{columns: cols, rows: [row]}} = Repo.query(sql)
    Enum.zip(cols, row) |> Map.new()
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp lookup_family(law_name) do
    case Repo.query("SELECT family FROM uk_lrt WHERE name = $1", [law_name]) do
      {:ok, %{rows: [[family]]}} -> family
      _ -> nil
    end
  end

  defp edge_families(law_name, edge_type, direction) do
    col = if direction == :target, do: "target_family", else: "source_family"

    sql = """
    SELECT #{col}, COUNT(*) AS cnt
    FROM law_edges
    WHERE source_law = $1 AND edge_type = $2 AND #{col} IS NOT NULL
    GROUP BY #{col}
    ORDER BY cnt DESC
    """

    case Repo.query(sql, [law_name, edge_type]) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [fam, cnt] -> {fam, cnt} end)
      _ -> []
    end
  end

  defp reject_placeholder_families(families) do
    Enum.reject(families, fn {fam, _} -> fam in @placeholder_families end)
  end

  defp matches_top?(assigned, families) do
    case families do
      [{top, _} | _] -> top == assigned
      _ -> false
    end
  end

  defp consensus_match?(assigned, families) do
    total = families |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    case families do
      [{top, count} | _] -> top == assigned and count / max(total, 1) >= 0.5
      _ -> false
    end
  end

  defp has_consensus?(families) do
    total = families |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    case families do
      [{_, count} | _] -> count / max(total, 1) >= 0.6
      _ -> false
    end
  end

  defp top_family([{fam, _} | _]), do: fam
  defp top_family(_), do: nil

  defp suggest_from_graph(parents, targets, amenders \\ []) do
    cond do
      parents != [] -> {top_family(parents), :parent_inferred}
      targets != [] and has_consensus?(targets) -> {top_family(targets), :target_consensus}
      amenders != [] and has_consensus?(amenders) -> {top_family(amenders), :amender_consensus}
      true -> {nil, :no_family}
    end
  end

  # Reverse direction: families of laws that have edges pointing TO this law
  # e.g., for "amends" edge_type, finds source_family of laws that amend this law
  defp reverse_edge_families(law_name, edge_type) do
    sql = """
    SELECT source_family, COUNT(*) AS cnt
    FROM law_edges
    WHERE target_law = $1 AND edge_type = $2 AND source_family IS NOT NULL
    GROUP BY source_family
    ORDER BY cnt DESC
    """

    case Repo.query(sql, [law_name, edge_type]) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [fam, cnt] -> {fam, cnt} end)
      _ -> []
    end
  end
end

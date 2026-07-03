defmodule SertantaiLegal.Sync.Templates.Registry do
  @moduledoc """
  Registry of available compliance templates.

  Resolves dependencies and returns templates in creation order.
  """

  @doc "All registered template IDs."
  def all_ids, do: Map.keys(all())

  @doc """
  All registered template modules, keyed by ID.

  Add new templates here as they're built.
  """
  def all do
    %{
      foundation: SertantaiLegal.Sync.Templates.Foundation,
      personnel: SertantaiLegal.Sync.Templates.Personnel,
      compliance_assessment: SertantaiLegal.Sync.Templates.ComplianceAssessment,
      action_tracker: SertantaiLegal.Sync.Templates.ActionTracker,
      evidence_vault: SertantaiLegal.Sync.Templates.EvidenceVault,
      incident_register: SertantaiLegal.Sync.Templates.IncidentRegister,
      audit_management: SertantaiLegal.Sync.Templates.AuditManagement,
      training_tracker: SertantaiLegal.Sync.Templates.TrainingTracker,
      document_control: SertantaiLegal.Sync.Templates.DocumentControl,
      raci: SertantaiLegal.Sync.Templates.RACI,
      pdca: SertantaiLegal.Sync.Templates.PDCA,
      org_structure: SertantaiLegal.Sync.Templates.OrgStructure
    }
  end

  @doc """
  Get a template module by ID.
  """
  def get(id) do
    case Map.get(all(), id) do
      nil -> {:error, {:unknown_template, id}}
      mod -> {:ok, mod}
    end
  end

  @doc """
  Resolve a list of requested template IDs into dependency-ordered modules.

  Returns `{:ok, [module]}` in creation order, or `{:error, reason}` if
  dependencies are missing or circular.
  """
  def resolve(requested_ids) when is_list(requested_ids) do
    registry = all()

    with :ok <- validate_known(requested_ids, registry),
         {:ok, ordered} <- topological_sort(requested_ids, registry) do
      {:ok, Enum.map(ordered, &Map.fetch!(registry, &1))}
    end
  end

  defp validate_known(ids, registry) do
    unknown = Enum.reject(ids, &Map.has_key?(registry, &1))

    case unknown do
      [] -> :ok
      missing -> {:error, {:unknown_templates, missing}}
    end
  end

  defp topological_sort(requested_ids, registry) do
    # Expand requested_ids to include all transitive dependencies
    all_needed = expand_dependencies(requested_ids, registry, MapSet.new())

    # Kahn's algorithm for topological sort
    graph = build_graph(all_needed, registry)
    in_degree = compute_in_degree(all_needed, graph)

    queue = Enum.filter(all_needed, fn id -> Map.get(in_degree, id, 0) == 0 end)
    do_sort(queue, graph, in_degree, [])
  end

  defp expand_dependencies([], _registry, visited), do: MapSet.to_list(visited)

  defp expand_dependencies([id | rest], registry, visited) do
    if MapSet.member?(visited, id) do
      expand_dependencies(rest, registry, visited)
    else
      visited = MapSet.put(visited, id)
      mod = Map.fetch!(registry, id)
      deps = mod.requires()
      expand_dependencies(deps ++ rest, registry, visited)
    end
  end

  defp build_graph(ids, registry) do
    Map.new(ids, fn id ->
      mod = Map.fetch!(registry, id)
      {id, mod.requires()}
    end)
  end

  # In-degree = how many dependencies a node has that haven't been resolved yet.
  # graph maps: node → [nodes it depends on]
  # So in-degree of X = length of graph[X] (its dependency list).
  defp compute_in_degree(ids, graph) do
    Map.new(ids, fn id ->
      {id, length(Map.get(graph, id, []))}
    end)
  end

  defp do_sort([], _graph, in_degree, result) do
    remaining = Enum.filter(Map.keys(in_degree), fn k -> Map.get(in_degree, k, 0) > 0 end)

    if remaining == [] do
      {:ok, Enum.reverse(result)}
    else
      {:error, {:circular_dependency, remaining}}
    end
  end

  defp do_sort([id | rest], graph, in_degree, result) do
    # This node is resolved — decrease in-degree for all nodes that depend on it
    dependents =
      Enum.filter(Map.keys(graph), fn other_id ->
        id in Map.get(graph, other_id, [])
      end)

    in_degree =
      Enum.reduce(dependents, Map.delete(in_degree, id), fn dep, acc ->
        Map.update!(acc, dep, &(&1 - 1))
      end)

    new_ready = Enum.filter(dependents, fn dep -> Map.get(in_degree, dep, 0) == 0 end)
    do_sort(rest ++ new_ready, graph, in_degree, [id | result])
  end
end

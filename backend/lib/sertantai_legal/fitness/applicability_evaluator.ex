defmodule SertantaiLegal.Fitness.ApplicabilityEvaluator do
  @moduledoc """
  Evaluates compiled applicability expression trees against customer profiles.

  Fractalaw publishes compiled expression trees as JSON in `compiled_applicability`
  on each law record. This module walks the tree recursively to determine whether
  a law applies to a given customer profile.

  ## Node Types

  - `Match` — leaf node: does the customer's dimension contain any of the codes?
  - `And` — all children must match
  - `Or` — any child must match
  - `Not` — child must NOT match (DisappliesTo)
  - `Conditional` — evaluate `then` only if `condition` matches
  - `TimeWindow` — temporal gate: is today within [from, to]?

  ## Customer Profile

  A map of dimension → list of codes:

      %{
        "personal" => ["employer", "contractor"],
        "material" => ["construction_work"],
        "territorial" => ["england"],
        "conditional" => ["at_work"]
      }
  """

  @type profile :: %{String.t() => list(String.t())}
  @type tree :: map()
  @type result :: %{applies: boolean(), confidence: float()}

  @doc """
  Evaluate a compiled applicability tree against a customer profile.

  Returns `%{applies: boolean(), confidence: float()}`.

  If the tree is nil or invalid, returns `%{applies: false, confidence: 0.0}`.
  """
  @spec evaluate(tree() | nil, profile()) :: result()
  def evaluate(nil, _profile), do: %{applies: false, confidence: 0.0}

  def evaluate(tree, profile) when is_map(tree) and is_map(profile) do
    {applies, confidence} = eval_node(tree, profile)
    %{applies: applies, confidence: confidence}
  end

  def evaluate(tree, profile) when is_binary(tree) do
    case Jason.decode(tree) do
      {:ok, parsed} -> evaluate(parsed, profile)
      {:error, _} -> %{applies: false, confidence: 0.0}
    end
  end

  def evaluate(_, _), do: %{applies: false, confidence: 0.0}

  @doc """
  Evaluate a batch of laws against a profile.

  Takes a list of `%{name: String.t(), compiled_applicability: map() | nil}` and
  returns a list of `%{name: String.t(), applies: boolean(), confidence: float()}`.
  """
  @spec evaluate_batch(list(map()), profile()) :: list(map())
  def evaluate_batch(laws, profile) do
    Enum.map(laws, fn law ->
      result = evaluate(law.compiled_applicability, profile)
      Map.merge(%{name: law.name}, result)
    end)
  end

  # ── Hierarchy expansion ───────────────────────────────────────────

  # Territorial: each region implies its parent jurisdictions
  @territorial_ancestors %{
    "england" => ["england_and_wales", "great_britain", "united_kingdom"],
    "wales" => ["england_and_wales", "great_britain", "united_kingdom"],
    "scotland" => ["great_britain", "united_kingdom"],
    "northern_ireland" => ["united_kingdom"],
    "england_and_wales" => ["great_britain", "united_kingdom"],
    "great_britain" => ["united_kingdom"]
  }

  defp expand_codes("territorial", codes) do
    Enum.flat_map(codes, fn code ->
      [code | Map.get(@territorial_ancestors, code, [])]
    end)
    |> Enum.uniq()
  end

  defp expand_codes(_dimension, codes), do: codes

  # ── Node evaluation ──────────────────────────────────────────────

  defp eval_node(%{"op" => "Match", "dimension" => dim, "codes" => codes} = node, profile) do
    customer_codes = expand_codes(dim, Map.get(profile, dim, []))
    applies = Enum.any?(codes, &(&1 in customer_codes))
    confidence = Map.get(node, "confidence", 1.0) || 1.0
    {applies, confidence}
  end

  defp eval_node(%{"op" => "And", "children" => children}, profile) do
    results = Enum.map(children, &eval_node(&1, profile))
    applies = Enum.all?(results, fn {a, _c} -> a end)
    # And confidence: minimum of children (weakest link)
    confidence = results |> Enum.map(fn {_a, c} -> c end) |> Enum.min(fn -> 1.0 end)
    {applies, confidence}
  end

  defp eval_node(%{"op" => "Or", "children" => children}, profile) do
    results = Enum.map(children, &eval_node(&1, profile))
    applies = Enum.any?(results, fn {a, _c} -> a end)
    # Or confidence: maximum of matching children
    confidence =
      results
      |> Enum.filter(fn {a, _c} -> a end)
      |> Enum.map(fn {_a, c} -> c end)
      |> Enum.max(fn -> Enum.map(results, fn {_a, c} -> c end) |> Enum.max(fn -> 1.0 end) end)

    {applies, confidence}
  end

  defp eval_node(%{"op" => "Not", "child" => child}, profile) do
    {child_applies, confidence} = eval_node(child, profile)
    {not child_applies, confidence}
  end

  defp eval_node(%{"op" => "Conditional", "condition" => condition, "then" => then_node}, profile) do
    {cond_applies, _cond_conf} = eval_node(condition, profile)

    if cond_applies do
      eval_node(then_node, profile)
    else
      {false, 1.0}
    end
  end

  defp eval_node(%{"op" => "TimeWindow", "from" => from, "to" => to} = node, profile) do
    today = Date.utc_today()
    after_from = is_nil(from) or Date.compare(today, Date.from_iso8601!(from)) != :lt
    before_to = is_nil(to) or Date.compare(today, Date.from_iso8601!(to)) != :gt
    in_window = after_from and before_to

    # TimeWindow may wrap an inner node, or be a standalone temporal gate
    case Map.get(node, "inner") do
      nil -> {in_window, 1.0}
      inner -> if in_window, do: eval_node(inner, profile), else: {false, 1.0}
    end
  end

  # Catch-all for unknown node types
  defp eval_node(_node, _profile), do: {false, 0.0}
end

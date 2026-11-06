defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.StaleSample do
  @moduledoc """
  The change register's staleness hand sample (WORKFLOW.md step 11, Store
  and build): built and unbuilt laws drawn on a seed (`Draw.shuffled/3`,
  seed tuple `{s, 11, 11}`), each with its verdict (`ChangeStaleness`) and
  what decided it, for an agent to judge against the store. Pure; `mix
  lat.stale --sample` reads the store.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw

  @doc "`n_built` built laws, then `n_unbuilt` unbuilt ones, drawn on `seed`."
  @spec draw([String.t()], [String.t()], non_neg_integer(), non_neg_integer(), integer()) ::
          {[String.t()], [String.t()]}
  def draw(built, unbuilt, n_built, n_unbuilt, seed) do
    Draw.seed({seed, 11, 11})
    b = Draw.shuffled(built, n_built, & &1)
    {b, Draw.shuffled(unbuilt, n_unbuilt, & &1)}
  end

  @doc """
  One law as a JSON-ready item. A built law has its latest `changes_built`
  event (`%{at, provenance}`), the code version and its inputs now; an
  unbuilt one (no event) only its verdict.
  """
  @spec item(String.t(), [atom()], map() | nil, String.t(), map() | nil) :: map()
  def item(law, verdict, nil, _version, _inputs),
    do: %{"law" => law, "built" => false, "verdict" => Enum.map(verdict, &to_string/1)}

  def item(law, verdict, event, version, inputs) do
    %{
      "law" => law,
      "built" => true,
      "verdict" => Enum.map(verdict, &to_string/1),
      "event_at" => iso(event.at),
      "event" => event.provenance,
      "current_code_version" => version,
      # string keys: the sample's JSON order replicates (HandSample)
      "inputs_now" => Map.new(inputs, fn {k, v} -> {to_string(k), v} end)
    }
  end

  defp iso(%DateTime{} = t), do: DateTime.to_iso8601(t)
  defp iso(%NaiveDateTime{} = t), do: NaiveDateTime.to_iso8601(t)
end

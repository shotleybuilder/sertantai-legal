defmodule SertantaiLegal.Legal.Taxa.RegexClauseConfidence do
  @moduledoc """
  Scores the confidence of a regex-extracted DRRP clause.

  Produces a float 0.0–1.0 based on heuristics about how well the regex
  pipeline captured the clause. Low-confidence entries get queued for
  AI refinement via `GET /api/ai/drrp/clause/queue`.

  ## Scoring signals

  | Signal | Weight | Rationale |
  |--------|--------|-----------|
  | V2 capture group matched | +0.25 | Explicit action capture vs fallback extraction |
  | Clause ends cleanly (no `...`) | +0.25 | Complete sentence vs truncated |
  | Clause length adequate (>30 chars) | +0.20 | Short clauses likely incomplete |
  | Strong modal verb (shall/must) | +0.15 | Clear obligation vs discretionary "may" |
  | Has article context | +0.15 | From chunked processing, properly scoped (added in TaxaFormatter) |

  Base score is 0.0, signals are additive. Max from this module is 0.85.
  TaxaFormatter adds +0.15 for article context, capped at 1.0.
  """

  @doc """
  Score the confidence of a regex-extracted clause.

  ## Parameters

  - `clause` - The refined clause text
  - `opts` - Keyword list of signals:
    - `:captured_action` - Whether V2 capture group matched (boolean)

  ## Returns

  Float between 0.0 and 1.0.
  """
  @spec score(String.t() | nil, keyword()) :: float()
  def score(nil, _opts), do: 0.0
  def score("", _opts), do: 0.0

  def score(clause, opts) when is_binary(clause) do
    has_captured_action = Keyword.get(opts, :captured_action, false)

    signals = [
      {has_captured_action, 0.25},
      {clean_ending?(clause), 0.25},
      {adequate_length?(clause), 0.20},
      {strong_modal?(clause), 0.15}
    ]

    signals
    |> Enum.reduce(0.0, fn
      {true, weight}, acc -> acc + weight
      {false, _}, acc -> acc
    end)
    |> Float.round(2)
  end

  defp clean_ending?(clause) do
    not String.ends_with?(clause, "...")
  end

  defp adequate_length?(clause) do
    String.length(clause) > 30
  end

  defp strong_modal?(clause) do
    Regex.match?(~r/\b(shall|must)\b/i, clause)
  end
end

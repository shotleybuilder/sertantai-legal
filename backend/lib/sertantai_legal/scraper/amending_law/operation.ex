defmodule SertantaiLegal.Scraper.AmendingLaw.Operation do
  @moduledoc """
  What an amending instruction does, from its drafting verb (lat-refactor
  LR-08): `{operation, effect_type}` — "there is substituted" / "substitute"
  → substituted; "there is inserted" / "insert" / "added" → inserted;
  "shall cease to have effect" / "omit" / "is repealed" / "revoked" →
  repealed. The effect type is words-level ("words substituted") when the
  instruction quotes or names the words, definitions or entries it
  changes. nil when no change verb ("The 1989 Act is amended as
  follows."): no record. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text

  @verbs [
    {~r/\bsubstitut(?:ed|e)\b/i, "substituted"},
    {~r/\binsert(?:ed)?\b|\badded\b/i, "inserted"},
    {~r/cease to have effect|\bomit(?:ted)?\b|\brepealed\b|\brevoked\b/i, "repealed"}
  ]

  @doc "The instruction's operation and effect type; nil for none."
  @spec of(Text.t()) :: {String.t(), String.t()} | nil
  def of(%Text{instruction: s}) do
    found =
      for {re, op} <- @verbs, [{pos, _} | _] <- [Regex.run(re, s, return: :index)], do: {pos, op}

    case Enum.min_by(found, &elem(&1, 0), fn -> nil end) do
      nil -> nil
      {_, op} -> {op, if(words?(s), do: "words #{op}", else: op)}
    end
  end

  # quoted or named words, definitions or entries (LR-41: SI 2009/2861 reg.
  # 12(a) "omit the following definitions—" omits words of reg. 32, not it)
  defp words?(s),
    do: Regex.match?(~r/[“"][^”"]+[”"]|\b(?:words?|definitions?|entr(?:y|ies))\b/u, s)
end

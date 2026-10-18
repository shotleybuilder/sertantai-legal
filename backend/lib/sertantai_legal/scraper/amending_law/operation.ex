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

  @doc """
  The operation for a row the instruction's quoted text makes (CR-06): its
  insertion or substitution verb, not an earlier one of the same sentence
  ("section 68(1) and (2) … shall cease to have effect, and after section
  66 … there shall be inserted— 66A": 1991 c.40 s.9(1)).
  """
  @spec of_quoted(Text.t()) :: {String.t(), String.t()} | nil
  def of_quoted(%Text{instruction: s} = t) do
    found =
      for {re, op} <- Enum.take(@verbs, 2),
          [{pos, _} | _] <- [Regex.run(re, s, return: :index)],
          do: {pos, op}

    case Enum.min_by(found, &elem(&1, 0), fn -> nil end) do
      nil -> of(t)
      {_, op} -> {op, if(words?(s), do: "words #{op}", else: op)}
    end
  end

  # quoted or named words, definitions or entries (LR-41: SI 2009/2861 reg.
  # 12(a) "omit the following definitions—" omits words of reg. 32, not it)
  defp words?(s),
    do: Regex.match?(~r/[“"][^”"]+[”"]|\b(?:words?|definitions?|entr(?:y|ies))\b/u, s)
end

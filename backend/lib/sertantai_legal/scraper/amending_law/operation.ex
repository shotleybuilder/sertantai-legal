defmodule SertantaiLegal.Scraper.AmendingLaw.Operation do
  @moduledoc """
  What an amending instruction does, from its drafting verb (lat-refactor
  LR-08): `{operation, effect_type}` — "there is substituted" / "substitute"
  → substituted; "there is inserted" / "insert" / "add" / "added" → inserted;
  "shall cease to have effect" / "omit" / "is repealed" / "revoked" →
  repealed. The effect type is words-level ("words substituted") when the
  instruction quotes or names the words, definitions or entries it
  changes. nil when no change verb ("The 1989 Act is amended as
  follows."): no record. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text

  @verbs [
    {~r/\bsubstitut(?:ed|e)\b/i, "substituted"},
    {~r/\binsert(?:ed)?\b|\badd(?:ed)?\b/i, "inserted"},
    {~r/cease to have effect|\bomit(?:ted)?\b|\brepealed\b|\brevoked\b/i, "repealed"}
  ]

  @heading_or_mark ~r/\bfor\s+the\s+(?:italic\s+)?(?:cross[- ]?)?heading\b(?!\s+and\b)|\b(?:for|omit)\s+the\s+(?:full\s+stop|comma|semi-?colon|colon)\b|\binsert\s+a\s+(?:full\s+stop|comma|semi-?colon|colon)\b(?!\s+and\b)/iu

  @provision_with_word ~r/\b(?:sections?|subsections?|regulations?|paragraphs?|sub-?paragraphs?|articles?|heads?|points?)\s+\d*[A-Z]*(?:\([^)\s]+\))+\s+\(?and\s+the\s+(?:words?\s+)?[“"][^”"]{1,12}[”"]\s*(?:\)\s*)?(?:which\s+(?:precedes|follows)|immediately\s+(?:preceding|following|before|after)|preceding|following|before|after|at\s+the\s+end)/iu

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
  # 12(a) "omit the following definitions—" omits words of reg. 32, not it);
  # a heading or a mark that is itself what changes ("For the heading
  # substitute—", "for the full stop … substitute a comma": CV-S06 B3) —
  # never a provision going with its heading ("Omit section 27A … and the
  # heading preceding it") or a mark before an inserted provision ("insert
  # a semicolon and the following subparagraph")
  #
  # A provision named with the word joining it ("omit sub-paragraph (d) and
  # the word “or” preceding it", "regulation 5(4)(b) (and the “or” at the
  # end of sub-paragraph (a))") goes whole: the joining word is in its
  # neighbour (CV-S06 B6)
  defp words?(s),
    do:
      not Regex.match?(@provision_with_word, s) and
        (Regex.match?(~r/[“"][^”"]+[”"]|\b(?:words?|definitions?|entr(?:y|ies))\b/u, s) or
           Regex.match?(@heading_or_mark, s))
end

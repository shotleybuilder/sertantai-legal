defmodule SertantaiLegal.Scraper.Amendment.Reader.Brackets do
  @moduledoc """
  The amendment reader's bracket helpers (AR-03; decomposed from
  `Amendment.Reader`, run time 2026-10-25): what a provision bracket may
  hold, its level (subsection, paragraph, sub-paragraph, capital), the
  paths brackets named make, and a provision's ref. Pure; used by the
  reader's clause, target, law-scoping and repeals-table modules (it calls
  none of them).
  """

  @bracket ~r/^(?:\d+[A-Z]*|[a-z]{1,3}|[A-Z]{1,2}|(?:x{0,3})(?:ix|iv|v?i{0,3}))$/

  @doc "Whether `b` can be a provision bracket's contents (\"5A\", \"ca\", \"iv\", \"A\")."
  @spec bracket?(String.t()) :: boolean()
  def bracket?(b), do: b =~ @bracket

  @doc "The contents of every bracket in `s`, in order (\"7(1)(a)\" → [\"1\", \"a\"])."
  @spec plain_brackets(String.t()) :: [String.t()]
  def plain_brackets(s),
    do: for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, s, capture: :all_but_first), do: b)

  @doc "A bracket's level: 0 subsection, 1 paragraph, 2 sub-paragraph (roman), 3 capital."
  @spec bracket_level(String.t()) :: 0..3
  def bracket_level(b) do
    cond do
      b =~ ~r/^\d/ -> 0
      b =~ ~r/^[A-Z]+$/ -> 3
      b =~ ~r/^(?:ii|iii|iv|vi{1,3}|ix|xi{1,3})$/ -> 2
      true -> 1
    end
  end

  @doc "The place's brackets at levels above the clause's own (`own`); all of them when it has none."
  @spec above([String.t()], [String.t()]) :: [String.t()]
  def above(place, []), do: place

  def above(place, own) do
    top = own |> Enum.map(&bracket_level/1) |> Enum.min()
    Enum.filter(place, &(bracket_level(&1) < top))
  end

  @doc """
  A provision's ref from its prefix and path: "s" + ["25", "5A"] →
  "s.25(5A)"; a range "22..25" → "s.22..s.25" (whole provisions; with
  brackets, as before ranges were read: its first number).
  """
  @spec ref(String.t(), [String.t(), ...]) :: String.t()
  def ref(p, [n | subs]) do
    case {String.split(n, ".."), subs} do
      {[a, b], []} -> "#{p}.#{a}..#{p}.#{b}"
      {[a | _], _} -> "#{p}.#{a}" <> Enum.map_join(subs, &"(#{&1})")
    end
  end

  @doc """
  The paths the brackets named make, by level — subsection (5), (5A);
  paragraph (a), (ca); sub-paragraph (i), (iv); (A) — each level taken or
  skipped, in that order (rows whose brackets are all named, as the
  row-driven matcher's set semantics: "subsection (5), paragraphs (b) and
  (c)" → (5), (5)(b), (5)(c), (b) …; "In paragraph (a) of section 7(2)"
  → (2)(a)); a letter that is also a roman numeral is tried at both.
  """
  @spec combos([String.t()]) :: [[String.t()]]
  def combos(named) do
    named = Enum.uniq(named)
    digits = Enum.filter(named, &(&1 =~ ~r/^\d/))
    letters = Enum.filter(named, &(&1 =~ ~r/^[a-z]+$/))
    romans = Enum.filter(letters, &(&1 =~ ~r/^(?:i{1,3}|iv|v|vi{1,3}|ix|x|xi{1,3})$/))
    capitals = Enum.filter(named, &(&1 =~ ~r/^[A-Z]+$/))

    [digits, letters, romans, capitals]
    |> Enum.reduce([[]], fn level, acc ->
      acc ++ for(path <- acc, b <- level, b not in path, do: path ++ [b])
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.uniq()
  end
end

defmodule SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb do
  @moduledoc """
  The feed reader's reading of an effect Type's verb (CV-S02b), on top of
  the shared word mapping (`EffectFacts.type/1`, `EffectFacts.kind/2`) —
  kept here so the label side's version (`LabelVersion`) doesn't move. Pure.

  A verb counts only when it says what this effect did to the affected
  provision (Jason 2026-10-23, catalogue review B):

  - "(as inserted by …)", "(as substituted)", "(as amended)" say how
    another provision came to read: dropped before mapping ("fees confirmed
    by S.I. 2010/441, Sch. (as substituted)" changes no text);
  - the repeal of an affecting or earlier provision, a saving, a
    transitional provision, an appointed day: no operation ("repeal of
    affecting provision 2020 c. 7, Sch. 24"; "saving (mods) re repeal of …";
    "Appointed days (transitional provns added)").

  The feed's other words for the verbs (catalogue review C, D, G):
  "words cease to have effect", "removed", "left out", "omiited", "rep in
  pt", "lapsed" are removals; "coming into operation" is coming into force;
  "becomes" and "moved" are renumberings; "restored" and "revived" bring a
  provision back (inserted).
  """

  alias SertantaiLegal.Scraper.EffectFacts

  @as ~r/\(\s*as\s+(?:inserted|substituted|amended|added|omitted|repealed|revoked|renumbered)\b[^)]*\)?/i

  @no_operation [
    ~r/\b(?:repeal|revocation|repealed|revoked)\s+of\s+(?:an?\s+)?(?:earlier\s+)?(?:affecting|amending|commencing)\s+provision/i,
    ~r/^\s*(?:savings?|saved|transitional|transitory|appointed\s+days?)\b/i
  ]

  @words [
    {~r/\bomi+t+ed\b/i, "omitted"},
    {~r/\brep\b\.?/i, "repealed "},
    {~r/\b(?:removed|left out|lapsed)\b/i, "omitted"},
    {~r/\bceases?\s+to\s+have\s+effect\b/i, "ceased to have effect"},
    {~r/\bcoming\s+into\s+operation\b/i, "coming into force"},
    {~r/\b(?:becomes|moved)\b/i, "renumbered"},
    {~r/\b(?:restored|revived)\b/i, "inserted"}
  ]

  @doc """
  An effect Type as the reader reads it: "(as …)" dropped, the shared
  mapping's words, then the reader's (above); nil for none.
  """
  @spec type(String.t() | nil) :: String.t() | nil
  def type(nil), do: nil

  def type(type) do
    @words
    |> Enum.reduce(EffectFacts.type(Regex.replace(@as, type, " ")), fn {re, verb}, t ->
      Regex.replace(re, t, verb)
    end)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @earlier ~r/\b(?:in|to)\s+(?:an?\s+)?earlier\s+(?:amending|affecting)\s+provision/i

  @doc """
  True for an amendment to an earlier amending provision ("substituted in
  earlier amending provision S.I. 2019/758, Sch. 2"): it changed the text
  that amending law made (C5, Jason 2026-10-30) — never its revocation
  ("revocation of earlier amending provision": no operation).
  """
  @spec earlier_amendment?(String.t() | nil) :: boolean()
  def earlier_amendment?(nil), do: false
  def earlier_amendment?(type), do: Regex.match?(@earlier, type) and not no_operation?(type)

  @doc """
  Whether the type says nothing was done to the affected provision: the
  repeal of an affecting provision, a saving, a transitional provision, an
  appointed day.
  """
  @spec no_operation?(String.t() | nil) :: boolean()
  def no_operation?(nil), do: false
  def no_operation?(type), do: type |> type() |> none?()

  @doc "An effect Type as a change kind (`EffectFacts.kind/2` over `type/1`); \"other\" for no operation."
  @spec kind(String.t() | nil) :: String.t()
  def kind(nil), do: EffectFacts.kind(nil, nil)

  def kind(type) do
    words = type(type)
    if none?(words), do: "other", else: EffectFacts.kind(words, nil)
  end

  # the words (already read) say nothing was done to the provision
  defp none?(words), do: Enum.any?(@no_operation, &(words =~ &1))
end

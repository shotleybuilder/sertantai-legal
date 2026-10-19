defmodule SertantaiLegal.Scraper.EffectKind do
  @moduledoc """
  An effect Type as a change kind (substituted | inserted | repealed |
  renumbered | commenced | amended | modified | other) — the one part of an
  effect's facts the parse uses (`CommentaryParser`), apart from
  `EffectFacts` (CR-06) so that only it counts toward `ParserVersion`: a
  label-only change to `EffectFacts` no longer makes every law's parse
  stale. Pure.
  """

  # the leading verb of an effect Type ("words substituted", "inserted",
  # "applied (with modifications)")
  @verbs [
    {~r/\bsubstituted\b/, "substituted"},
    {~r/\b(inserted|added)\b/, "inserted"},
    {~r/\b(repealed|revoked|omitted|ceased to have effect)\b/, "repealed"},
    {~r/\brenumbered\b/, "renumbered"},
    {~r/\bcoming into force\b/, "commenced"},
    {~r/\bamended\b/, "amended"},
    # a modification's own verb ("applied in part … (as inserted)"): the
    # earliest verb wins, so it isn't read as the text change it cites (LR-24)
    {~r/\b(applied|modified|excluded|extended|restricted|disapplied|construed|continued|transferred|functions|powers?)\b/,
     "other"}
  ]

  @doc """
  An effect Type as a change kind: a note's `code_type`, where one is
  passed, decides commencement and modification; else the first verb in
  the type, "other" when none.
  """
  @spec kind(String.t() | nil, String.t() | nil) :: String.t()
  def kind(_type, "commencement"), do: "commenced"
  def kind(_type, "modification"), do: "modified"

  # a change to an earlier amending or affecting provision ("amendment to
  # earlier affecting provision SI 1995/3128 reg. 10(2) (as substituted)")
  # changes another law's provision, not this text (LR-24)
  def kind(type, _code_type) when is_binary(type) and type != "" do
    if Regex.match?(~r/\bearlier (affecting|amending) provision/i, type),
      do: "other",
      else: verb_kind(String.downcase(type))
  end

  def kind(_type, _code_type), do: verb_kind("")

  defp verb_kind(type) do
    @verbs
    |> Enum.flat_map(fn {re, name} ->
      case Regex.run(re, type, return: :index) do
        [{pos, _} | _] -> [{pos, name}]
        nil -> []
      end
    end)
    |> Enum.min_by(&elem(&1, 0), fn -> {nil, "other"} end)
    |> elem(1)
  end
end

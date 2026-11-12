defmodule SertantaiLegal.Scraper.Amendment.Review.StandardStatus do
  @moduledoc """
  The standard statuses for the amending gate's unnamed groups
  (Amending-law reader: review tooling; it replaces the hand-written
  `name_groups.py`): the wording each cause has been named with across
  three families' reviews, proposed for a group whose cause fits, citing
  the review that read it. Only proposals: a group is named in
  `disagreements.json` once Jason decides (frozen expectations are never
  written first). A value conflict (`operation …`, `level …`) other than
  legislation.gov.uk's "in part", and every one-law wording, has no
  standard: it stays hand-written. Pure.
  """

  @standards [
    {"law text only: ", "legislation.gov.uk holds no record of it; the reading is right"},
    {"no operation from legislation.gov.uk: ",
     ~s(legislation.gov.uk records the change with no operation (the feed's "amended", legacy markup\); the reading is right)},
    {"unjoined",
     "the merge left the law's text apart from legislation.gov.uk's record (Merge's); the reading is right"},
    {"operation repealed/repealed_in_part",
     ~s(legislation.gov.uk's "in part"; the law repeals the provision whole, or each item its table lists)},
    {"quote-dropped-number", "by design (RULES.md quote-dropped-numbers-are-repealed)"},
    {"quote-new-number",
     "by design (RULES.md quote-new-numbers-are-inserted); legislation.gov.uk records them substituted, or on the provision substituted only"}
  ]

  @doc """
  The status proposed for a cause, citing `review` (the report the group
  was read in), or nil when the cause has no standard.
  """
  @spec propose(String.t(), String.t()) :: String.t() | nil
  def propose(cause, review) do
    case Enum.find(@standards, fn {prefix, _} -> String.starts_with?(cause, prefix) end) do
      {"quote-" <> _, words} -> "known: " <> words
      {_, words} -> "known: #{words} (review: #{review})"
      nil -> nil
    end
  end

  @doc """
  The proposals for the gate's unnamed items: `{key, status}` for each
  with a standard, and the keys left to write by hand.
  """
  @spec proposals([map()], String.t()) :: %{
          proposed: [{String.t(), String.t()}],
          by_hand: [String.t()]
        }
  def proposals(failing, review) do
    {proposed, by_hand} =
      failing
      |> Enum.map(fn i -> {"#{i.shape} @ #{i.law}", propose(i.shape, review)} end)
      |> Enum.split_with(fn {_, status} -> status != nil end)

    %{proposed: Enum.sort(proposed), by_hand: by_hand |> Enum.map(&elem(&1, 0)) |> Enum.sort()}
  end

  @doc "The reviewed statuses with the proposals added, as the fixture's JSON (sorted keys)."
  @spec write(map(), [{String.t(), String.t()}]) :: String.t()
  def write(reviewed, proposed) do
    merged = Map.merge(reviewed, Map.new(proposed))

    body =
      merged
      |> Enum.sort()
      |> Enum.map_join(",\n", fn {k, v} -> "  #{Jason.encode!(k)}: #{Jason.encode!(v)}" end)

    "{\n" <> body <> "\n}\n"
  end
end

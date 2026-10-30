defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.OwnCommencement do
  @moduledoc """
  The law's own commencement read twice joins as one change (CV-S09 round
  3, M1): the commencement reader's record (`LAW:commencement:<target>@<date>`,
  from the law's own clause or orders) and the feed's "coming into force"
  effect by the law itself on the same provision and day are one event.
  Kept apart, the feed's copy made the provision's start rest on the feed
  (NISR 1999/305 reg.20, SI 1992/3004 reg.22). The joined change keeps the
  reader's key; the feed's claims and key ride along (as an alias), and
  the evidence table chooses as for any merged change. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

  @doc "The changes with each feed self-commencement joined to the reader's record of it."
  @spec join([Change.t()], String.t()) :: [Change.t()]
  def join(changes, law) do
    prefix = law <> ":commencement:"

    own =
      for c <- changes,
          String.starts_with?(c.key, prefix),
          d = Change.value(c, :commencement, :date),
          d != nil,
          into: %{},
          do: {{c.target, d}, c.key}

    feed =
      for c <- changes,
          not String.starts_with?(c.key, prefix),
          Change.value(c, :feed, :operation) == :commenced,
          Change.value(c, :feed, :by) == law,
          key = Map.get(own, {c.target, Change.value(c, :feed, :date)}),
          key != nil,
          into: %{},
          do: {c.key <> "|" <> c.target, key}

    joined =
      changes
      |> Enum.filter(&Map.has_key?(feed, &1.key <> "|" <> &1.target))
      |> Enum.group_by(&{&1.target, Map.fetch!(feed, &1.key <> "|" <> &1.target)})

    changes
    |> Enum.reject(&Map.has_key?(feed, &1.key <> "|" <> &1.target))
    |> Enum.map(fn c ->
      case Map.get(joined, {c.target, c.key}) do
        nil ->
          c

        copies ->
          %{
            c
            | claims: c.claims ++ Enum.flat_map(copies, & &1.claims),
              aliases: Enum.uniq(c.aliases ++ Enum.flat_map(copies, &[&1.key | &1.aliases]))
          }
      end
    end)
  end
end

defmodule SertantaiLegal.Scraper.ChangeDigest do
  @moduledoc """
  A digest of a law's changes (CV-S11), for "same input, same output": two
  builds from the same inputs store the same changes when their digests
  match. Covers each change's key, target, aliases, claims (in order) and
  resolved values as stored; not the row ids or build times, nor what
  `Store.for_law/1` derives on read (`tiers`, `conflicts`: the digest is of
  the build's output; Maritime Safety: Store and build). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

  # derived on read, never stored
  @derived [:tiers, :conflicts]

  @doc """
  A build's output as the label fold reads it (#194): the stored changes'
  digest (`of/1`) and the law's start the build recorded, as 16 hex
  characters. Recorded on `changes_built` and, for the build a timeline was
  folded from, on `labels_refreshed`: labels are behind their changes when
  the two differ, never because a build ran.
  """
  @spec build([Change.t()], map() | nil) :: String.t()
  def build(changes, start), do: hex({of(changes), start})

  @doc "16 hex characters over `changes`, whatever their order."
  @spec of([Change.t()]) :: String.t()
  def of(changes) do
    changes
    |> Enum.map(fn c ->
      {c.key, c.target, c.aliases,
       Enum.map(c.claims, &{&1.source, &1.attribute, &1.value, &1.ref}),
       c.resolved && c.resolved |> Map.from_struct() |> Map.drop(@derived)}
    end)
    |> Enum.sort()
    |> hex()
  end

  defp hex(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end

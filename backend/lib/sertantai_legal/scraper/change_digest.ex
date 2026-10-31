defmodule SertantaiLegal.Scraper.ChangeDigest do
  @moduledoc """
  A digest of a law's changes (CV-S11), for "same input, same output": two
  builds from the same inputs store the same changes when their digests
  match. Covers each change's key, target, aliases, claims (in order) and
  resolved values; not the row ids or build times. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change

  @doc "16 hex characters over `changes`, whatever their order."
  @spec of([Change.t()]) :: String.t()
  def of(changes) do
    changes
    |> Enum.map(fn c ->
      {c.key, c.target, c.aliases,
       Enum.map(c.claims, &{&1.source, &1.attribute, &1.value, &1.ref}),
       c.resolved && Map.from_struct(c.resolved)}
    end)
    |> Enum.sort()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end
end

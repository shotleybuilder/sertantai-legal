defmodule SertantaiLegal.Scraper.ChangeVocabulary.Change do
  @moduledoc """
  One legal change event on one provision (change vocabulary, CV-02):
  identified by `key` (the effect id when any source carries one, else a
  source's own id) and `target` (the provision, LAT grammar, no law
  prefix). `claims` hold every source's statements; `aliases` every source
  id merged in. `ChangeVocabulary.Evidence.resolve/2` fills `resolved` (the
  chosen value per attribute). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim

  @enforce_keys [:key, :target]
  defstruct [:key, :target, claims: [], aliases: [], resolved: %{}]

  @type t :: %__MODULE__{
          key: String.t(),
          target: String.t(),
          claims: [Claim.t()],
          aliases: [String.t()],
          resolved: map()
        }

  @doc "The values every claim of `source` makes for `attribute`."
  @spec values(t(), atom(), atom()) :: [term()]
  def values(%__MODULE__{claims: claims}, source, attribute),
    do: for(%Claim{source: ^source, attribute: ^attribute, value: v} <- claims, do: v)

  @doc "The first value `source` claims for `attribute`; nil when none."
  @spec value(t(), atom(), atom()) :: term()
  def value(change, source, attribute), do: change |> values(source, attribute) |> List.first()
end

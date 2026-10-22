defmodule SertantaiLegal.Scraper.ChangeVocabulary.Change do
  @moduledoc """
  One legal change event on one provision (change vocabulary, CV-02):
  identified by `key` (the effect id when any source carries one, else a
  source's own id) and `target` (the provision, LAT grammar, no law
  prefix). `claims` hold every source's statements; `aliases` every source
  id merged in. `ChangeVocabulary.Evidence.resolve/2` fills `resolved` (an
  `Evidence.Resolved`: the chosen value per attribute, and its source). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim

  @enforce_keys [:key, :target]
  defstruct [:key, :target, :resolved, claims: [], aliases: []]

  @type t :: %__MODULE__{
          key: String.t(),
          target: String.t(),
          claims: [Claim.t()],
          aliases: [String.t()],
          resolved: SertantaiLegal.Scraper.ChangeVocabulary.Evidence.Resolved.t() | nil
        }

  @doc "The values every claim of `source` makes for `attribute`."
  @spec values(t(), atom(), atom()) :: [term()]
  def values(%__MODULE__{claims: claims}, source, attribute),
    do: for(%Claim{source: ^source, attribute: ^attribute, value: v} <- claims, do: v)

  @doc """
  The law a label credits with the change (D1 `changed_by`): for a
  commencement, the law bringing it into force; else the law making it.
  """
  @spec credit(t()) :: String.t() | nil
  def credit(%__MODULE__{resolved: %{operation: :commenced, commenced_by: by}}) when by != nil,
    do: by

  def credit(%__MODULE__{resolved: %{by: by}}), do: by

  @doc "The first value `source` claims for `attribute`; nil when none."
  @spec value(t(), atom(), atom()) :: term()
  def value(change, source, attribute), do: change |> values(source, attribute) |> List.first()
end

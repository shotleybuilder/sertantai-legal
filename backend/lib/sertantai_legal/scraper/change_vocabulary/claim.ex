defmodule SertantaiLegal.Scraper.ChangeVocabulary.Claim do
  @moduledoc """
  One source's statement about one attribute of a change (change vocabulary,
  CV-02): `source` (`:markup`, `:feed`, `:law`, …), `attribute` (`:operation`,
  `:level`, `:territory`, `:date`, …), `value`, and `ref` — where in the
  source it was read (a ChangeId, an effect id). Readers emit claims; the
  merge groups them by change; `ChangeVocabulary.Evidence` picks each
  attribute's value. Pure.
  """

  @enforce_keys [:source, :attribute, :value]
  defstruct [:source, :attribute, :value, :ref]

  @type t :: %__MODULE__{
          source: atom(),
          attribute: atom(),
          value: term(),
          ref: String.t() | nil
        }

  @doc "A claim; a nil value is no claim (`[]`)."
  @spec new(atom(), atom(), term(), String.t() | nil) :: [t()]
  def new(_source, _attribute, nil, _ref), do: []

  def new(source, attribute, value, ref),
    do: [%__MODULE__{source: source, attribute: attribute, value: value, ref: ref}]
end

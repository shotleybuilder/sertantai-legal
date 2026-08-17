defmodule SertantaiLegal.Scraper.RootResolver.Resolution do
  @moduledoc """
  Struct representing the result of resolving a single cross-reference definition.

  Used as the data payload in tagged tuples returned by `Matcher.resolve_one/5`:

      {:resolved, %Resolution{id: id, citation: "...", root_ids: [...]}}
      {:citation_only, %Resolution{id: id, citation: "...", target_law: "..."}}
      {:internal, %Resolution{id: id, root_ids: [...]}}
      {:unresolved, %Resolution{id: id, term: "...", law_name: "..."}}
  """

  @type status :: :resolved | :citation_only | :internal | :unresolved

  @type t :: %__MODULE__{
          id: binary(),
          citation: String.t() | nil,
          root_ids: [binary()],
          target_law: String.t() | nil,
          term: String.t() | nil,
          law_name: String.t() | nil
        }

  @enforce_keys [:id]
  defstruct [
    :id,
    :citation,
    :target_law,
    :term,
    :law_name,
    root_ids: []
  ]
end

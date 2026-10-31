defmodule SertantaiLegal.Scraper.ChangeStaleness do
  @moduledoc """
  Why a law's stored changes (`provision_changes`) are stale (CV-S11), from
  its latest `changes_built` event. Pure, as `LabelStaleness`: the facts
  are read by `ChangeVocabulary.Store.builds/0` and
  `ChangeVocabulary.Store.Inputs.of/3`, the reasons decided here.

  - `:no_build` — the law has no build
  - `:code_version` — built by other code (`ChangeVocabulary.Version`)
  - an input that moved since the build (`inputs/0`): `:lat_rows` (the
    rows the build placed changes on), `:law_text` and `:feed` (the stored
    documents' content), `:amendment_rules`, `:commencement_rules`,
    `:extent_rules` (each store's latest reading the build read)

  An input the build didn't record counts as moved: the build is older than
  the fingerprint, so nothing says it is current. A law with no reasons is
  fresh. `mix lat.stale` reports them; the fix is `mix lat.vocabulary
  --build`.
  """

  @inputs [:lat_rows, :law_text, :feed, :amendment_rules, :commencement_rules, :extent_rules]

  @type build :: %{code_version: String.t() | nil, inputs: map()}
  @type reason ::
          :no_build
          | :code_version
          | :lat_rows
          | :law_text
          | :feed
          | :amendment_rules
          | :commencement_rules
          | :extent_rules

  @doc "The inputs compared, in the order their reasons are given."
  @spec inputs() :: [atom()]
  def inputs, do: @inputs

  @doc """
  The reasons `build` is stale (empty: fresh). `current`: the code version
  now and the law's inputs now.
  """
  @spec reasons(build() | nil, build()) :: [reason()]
  def reasons(nil, _current), do: [:no_build]

  def reasons(build, current) do
    code = if build.code_version != current.code_version, do: [:code_version], else: []

    moved =
      for i <- @inputs,
          not Map.has_key?(build.inputs, i) or build.inputs[i] != current.inputs[i],
          do: i

    code ++ moved
  end
end

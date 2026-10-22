defmodule SertantaiLegal.Scraper.ChangeVocabulary.Evidence do
  @moduledoc """
  The evidence table (change vocabulary, CV-01 design): for each attribute
  of a change, which source's claim wins. One table replaces the pairwise
  reconciling rules (`EffectTerritory.claim`'s step order, rule 3's gate, J2).

  `table/0` is the table as data: per attribute, the sources in order, each
  `{source, claim attribute}` or `{source, claim attribute, condition}`. A
  condition is a named test (`condition?/3`) on the claim's value, the
  provision and the change's own claims — stated in the table, never hidden
  in code. The first source in order with a claim that passes wins.
  `resolve/2` writes a `Resolved` struct, with the winning source of each
  attribute and its tier.

  **Authority (Jason 2026-10-21):** "The actual legal text is primary.
  These other sources are derived and secondary." Every attribute's order
  starts with the primary sources (`:law_text` — the amending law's
  instruction, extent and application; `:commencement` — its commencement
  provisions and orders), then legislation.gov.uk's markup, then its
  changes feed. Derived sources fill only what the primary text doesn't
  say. A primary claim and a derived claim that disagree are both kept as a
  conflict (`Resolved.conflicts`) — reported, never reconciled. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Conflicts}
  alias SertantaiLegal.Scraper.Territory

  defmodule Resolved do
    @moduledoc "A change's chosen attributes, and the source each came from."
    @enforce_keys [
      :operation,
      :level,
      :territory,
      :date,
      :by,
      :retained,
      :partial,
      :saved,
      :sources
    ]
    defstruct [
      :operation,
      :level,
      :territory,
      :date,
      :by,
      :retained,
      :partial,
      :saved,
      :sources,
      commenced_by: nil,
      tiers: %{},
      conflicts: []
    ]

    @type t :: %__MODULE__{
            operation: atom() | nil,
            level: :provision | :words,
            territory: String.t() | nil,
            date: Date.t() | nil,
            by: String.t() | nil,
            commenced_by: String.t() | nil,
            retained: boolean(),
            partial: boolean(),
            saved: boolean(),
            sources: %{atom() => atom() | nil},
            tiers: %{atom() => :primary | :derived | nil},
            conflicts: [{atom(), term(), term()}]
          }
  end

  # the tier of each source
  @tiers %{
    law_text: :primary,
    commencement: :primary,
    markup: :derived,
    feed: :derived,
    law: :derived,
    # a parent commenced through its parts (`ChangeVocabulary`)
    parts: :derived
  }

  @table [
    # the primary text first; then the feed's "in part" outranks a whole-provision Repeal in the markup
    # (Jason 2026-10-11: "revoked in part will not mean full revocation")
    operation: [
      {:law_text, :operation},
      {:commencement, :operation},
      {:feed, :operation, :in_part},
      {:markup, :operation},
      {:feed, :operation}
    ],
    level: [{:law_text, :level}, {:commencement, :level}, {:markup, :level}, {:feed, :level}],
    retained: [{:markup, :retained}],
    # where the change applies: the feed's application, the markup's Extent,
    # an effect extent narrower than the provision, then the affecting law's
    # territory — only for a removal whose text is retained (V1-04: an
    # insertion by a devolved law can apply across the border)
    territory: [
      {:law_text, :territory},
      {:feed, :territory},
      {:markup, :territory},
      {:feed, :effect_extent, :narrower_than_provision},
      {:law, :territory, :retained_removal_narrower},
      # an insertion by a devolved legislature's Act: its competence
      {:law, :competence, :insertion}
    ],
    date: [{:commencement, :date}, {:law_text, :date}, {:feed, :date_first}, {:feed, :date}],
    # a commencement stage that doesn't complete the provision
    partial: [{:commencement, :partial}, {:feed, :partial}],
    # a removal with savings (D3: repealed_saved)
    saved: [{:feed, :savings, :non_empty}],
    # the law making the change; the law bringing it into force is apart
    # (a commencing order is not the law that made the change)
    by: [{:law_text, :by}, {:feed, :by}, {:markup, :cited}],
    commenced_by: [{:commencement, :commenced_by}]
  ]

  @doc "The tier of a claim source: `:primary` (the legal text) or `:derived`."
  @spec tier(atom()) :: :primary | :derived | nil
  def tier(source), do: Map.get(@tiers, source)

  @doc "Each source's tier."
  @spec tiers() :: %{atom() => :primary | :derived}
  def tiers, do: @tiers

  @doc "The evidence table: attribute → sources in order (with named conditions)."
  @spec table() :: keyword()
  def table, do: @table

  @doc """
  The change with each attribute chosen; `extent` is the provision's
  extent, `facts` the provision's markup facts (`shows_text`).
  """
  @spec resolve(Change.t(), String.t() | nil, map()) :: Change.t()
  def resolve(%Change{} = c, extent, facts \\ %{}) do
    chosen =
      @table
      |> Map.new(fn {attribute, order} -> {attribute, first(c, order, extent, facts)} end)
      |> bound(c, extent)

    value = &elem(chosen[&1], 0)

    resolved =
      %Resolved{
        operation: value.(:operation),
        level: value.(:level) || :provision,
        territory: value.(:territory),
        date: value.(:date),
        by: value.(:by),
        commenced_by: value.(:commenced_by),
        retained: value.(:retained) == true,
        partial: value.(:partial) == true,
        saved: value.(:saved) not in [nil, []],
        sources: Map.new(chosen, fn {attribute, {_v, source}} -> {attribute, source} end)
      }

    derive(%Change{c | resolved: resolved})
  end

  @doc """
  A resolved change's tiers and conflicts, from its sources and claims —
  never stored (CV-04): a change read back from `provision_changes` gets
  them here.
  """
  @spec derive(Change.t()) :: Change.t()
  def derive(%Change{resolved: %Resolved{} = r} = c) do
    tiers = Map.new(r.sources, fn {attribute, source} -> {attribute, tier(source)} end)
    c = %Change{c | resolved: %Resolved{r | tiers: tiers}}
    %Change{c | resolved: %Resolved{c.resolved | conflicts: Conflicts.values(c)}}
  end

  # The amending provision's extent (primary: its Act's extent clause) bounds
  # where the change applies: extent is not application (an E+W provision
  # may apply in W only), so a stated territory is cut to it; with none
  # stated, the extent is the territory when narrower than the provision
  defp bound(chosen, c, provision_extent) do
    case {Change.value(c, :law_text, :extent), chosen.territory} do
      {nil, _} ->
        chosen

      {ext, {nil, _}} ->
        if Territory.covers?(ext, provision_extent),
          do: chosen,
          else: %{chosen | territory: {ext, :law_text}}

      {ext, {t, source}} ->
        case Territory.subtract(t, Territory.subtract(t, ext) || "") do
          # disjoint: kept as stated; the conflict is reported
          nil -> chosen
          ^t -> %{chosen | territory: {t, source}}
          cut -> %{chosen | territory: {cut, :law_text}}
        end
    end
  end

  defp first(change, order, extent, facts) do
    Enum.find_value(order, {nil, nil}, fn entry ->
      {source, attribute, condition} =
        case entry do
          {s, a} -> {s, a, nil}
          {s, a, cond} -> {s, a, cond}
        end

      case Change.value(change, source, attribute) do
        nil ->
          nil

        v ->
          if condition == nil or
               condition?(condition, v, Map.merge(facts, %{change: change, extent: extent})),
             do: {v, source}
      end
    end)
  end

  @doc """
  The table's named conditions:
  - `:in_part` — the claim is a removal in part
  - `:non_empty` — the list claim has an item
  - `:insertion` — the change inserts text
  - `:narrower_than_provision` — the territory doesn't cover the provision's extent
  - `:retained_removal_narrower` — the change removes text that is
    retained (the markup's RetainText; with no Repeal markup, the provision
    still showing its words: `shows_text`), and the territory is narrower
    than the provision's extent
  """
  @spec condition?(atom(), term(), %{change: Change.t(), extent: String.t() | nil}) :: boolean()
  def condition?(:in_part, operation, _context), do: operation == :repealed_in_part
  def condition?(:non_empty, list, _context), do: list != []

  def condition?(:insertion, _territory, %{change: c}),
    do:
      (Change.value(c, :law_text, :operation) || Change.value(c, :markup, :operation) ||
         Change.value(c, :feed, :operation)) == :inserted

  def condition?(:narrower_than_provision, territory, %{extent: extent}),
    do: not Territory.covers?(territory, extent)

  def condition?(:retained_removal_narrower, territory, %{change: c, extent: extent} = context) do
    operation = Change.value(c, :markup, :operation) || Change.value(c, :feed, :operation)

    retained =
      case Change.value(c, :markup, :retained) do
        # no Repeal markup: the provision still showing its words (V1-04)
        nil -> Map.get(context, :shows_text, false)
        r -> r
      end

    operation == :repealed and retained == true and not Territory.covers?(territory, extent)
  end
end

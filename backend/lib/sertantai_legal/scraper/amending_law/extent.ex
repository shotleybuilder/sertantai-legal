defmodule SertantaiLegal.Scraper.AmendingLaw.Extent do
  @moduledoc """
  An amending Act's own extent clause, read (change vocabulary CV-03;
  primary text): where each of its provisions extends, so where a change it
  makes applies. Serious Organised Crime and Police Act 2005 s.179:

  - "(2) … this Act extends to England and Wales only" — the default;
  - "(3) The following extend also to Scotland— sections 1 to 54 …" —
    the default and that territory;
  - "(4) The following extend to Scotland only— …" — that territory;
  - "(7) The following have the same extent as the enactments to which
    they relate— … section 174(2) and Schedule 17" — the amended law's
    (a repeals schedule follows the enactment it repeals);
  - "(8) So far as Schedule 17 contains a repeal … which corresponds to the
    repeal … by another provision of this Act, that Schedule … [has] the
    same extent as that other provision" — `corresponds: true`.

  An SI stating no extent extends as far as its enabling powers
  (`from_powers/2`: each enabling provision by its parent Act's extent
  clause; CV-07), used only where it states none (`powers`). An Act
  stating no extent clause and no lists takes the extent legislation.gov.uk
  states on the whole Act (`stated`; Decision 3, Jason 2026-11-05).

  A Schedule extends as the section introducing it ("111 Schedule 7 … has
  effect"), unless the clause names it.

  This module is the reading's struct and its lookups only: the reading
  itself is `Extent.Reader` (`read/1` takes the Act's document), so the
  build, which calls the lookups (`of_change/3`, `application_at/2`), holds
  none of the sentence readers in its stamp (`StageSplitTest`; the Extent
  reader stamps session). `of/2` answers for one provision: a territory
  code, `:same` (the enactment's own), or nil (not read). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lookup, Rows, Targeted}

  defstruct default: nil,
            lists: [],
            corresponds: false,
            introduced_by: %{},
            ref: nil,
            text: nil,
            application: nil,
            applies: [],
            powers: nil,
            stated: nil,
            competence: nil,
            targets: []

  @type list_kind :: :also | :only | :same | :not | :named | :unread
  @type applies_kind :: :applies | :applies_not
  @type t :: %__MODULE__{
          default: String.t() | nil,
          lists: [{list_kind(), String.t() | nil, [String.t()]}],
          corresponds: boolean(),
          introduced_by: %{String.t() => String.t()},
          ref: String.t() | nil,
          text: String.t() | nil,
          application: String.t() | nil,
          applies: [{applies_kind(), String.t(), [String.t()]}],
          powers: String.t() | nil,
          stated: String.t() | nil,
          competence: String.t() | nil,
          targets: [Targeted.t()]
        }

  @doc "The extent read as `extent_rules` rows (`Extent.Rows.to_rows/2`)."
  @spec to_rows(t(), String.t()) :: [map()]
  defdelegate to_rows(e, law), to: Rows

  @doc "The extent from its `extent_rules` rows (`Extent.Rows.from_rows/1`); nil when none."
  @spec from_rows([map()]) :: t() | nil
  defdelegate from_rows(rows), to: Rows

  @doc "Where the amending provision `ref` extends (`Extent.Lookup.of/2`): a code, `:same`, or nil."
  @spec of(t(), String.t()) :: String.t() | :same | nil
  defdelegate of(e, ref), to: Lookup

  @doc "The territory of a change made by the amending provisions `refs`, to its target where known (`Extent.Lookup.of_change/3`)."
  @spec of_change(t(), [String.t()], Lookup.change() | nil) :: String.t() | :same | nil
  defdelegate of_change(e, refs, change \\ nil), to: Lookup

  @doc """
  Where the changes made by the amending provisions `refs` apply
  (`Extent.Lookup.application_at/2`): a provision's own application, else
  the law's.
  """
  @spec application_at(t(), [String.t()]) :: String.t() | nil
  defdelegate application_at(e, refs), to: Lookup

  @doc "A devolved instrument's extent by its legislature's competence (`Extent.Lookup.competence/1`)."
  @spec competence(String.t()) :: String.t() | nil
  defdelegate competence(law), to: Lookup

  @doc "True when the extent rests on the legislature's competence alone (`Extent.Lookup.competence_only?/1`)."
  @spec competence_only?(t()) :: boolean()
  defdelegate competence_only?(e), to: Lookup

  @doc "An SI's extent from its enabling powers (`Extent.Lookup.from_powers/2`)."
  @spec from_powers([map()], %{String.t() => t()}, map()) :: String.t() | nil
  defdelegate from_powers(provisions, parents, stated \\ %{}), to: Lookup
end

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
  clause; CV-07), used only where it states none (`powers`).

  A Schedule extends as the section introducing it ("111 Schedule 7 … has
  effect"), unless the clause names it. `read/1` takes the Act's document;
  `of/3` answers for one provision: a territory code, `:same` (the
  enactment's own), or nil (not read). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, ScheduleRefs}

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{
    Amends,
    Application,
    Applies,
    Excepted,
    Default,
    Excepting,
    Forms,
    Lists,
    Lookup,
    Named,
    Rows,
    Same,
    Units
  }

  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.Territory

  defstruct default: nil,
            lists: [],
            corresponds: false,
            introduced_by: %{},
            ref: nil,
            text: nil,
            application: nil,
            applies: [],
            powers: nil,
            competence: nil

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
          competence: String.t() | nil
        }

  @doc "The Act's extent clause read from its document; empty when it has none read."
  @spec read(Doc.t()) :: t()
  def read(%Doc{} = doc) do
    # lines joined with spaces: a paragraph label never runs into the
    # words before it ("Schedule 10.7 The following …")
    sections =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil,
          do:
            {ref,
             doc
             |> Doc.element(id)
             |> Units.own_words()
             |> Doc.lines()
             |> Enum.join(" ")
             |> Units.unlettered()}

    # built once: the named and same-extent readers both walk them
    unit_sentences = Units.unit_sentences(doc)

    clauses =
      Enum.filter(sections, fn {ref, text} ->
        not String.contains?(ref, "(") and
          (Regex.match?(Forms.extends(), text) or Regex.match?(Forms.extends_and(), text) or
             Regex.match?(Forms.not_extends(), text) or
             Regex.match?(Forms.except_list(), text) or Regex.match?(Forms.heading(), text) or
             Regex.match?(Forms.cited_list(), text) or Regex.match?(Forms.only_following(), text) or
             Regex.match?(Forms.extends_except(), text) or Regex.match?(Forms.extends_exc(), text))
      end)

    # the first stating a default, else the first: "31 The following
    # provisions … do not extend to Scotland— …"; "32 It is hereby declared
    # that this Act extends to Northern Ireland" (ukpga 1981/45, CV-S05
    # round 8 NEW-4; s.31's list is read as any other provision's)
    {clause_ref, clause} =
      Enum.find(clauses, List.first(clauses, {nil, ""}), fn {_, text} ->
        Default.default(text) != nil
      end)

    default = Default.westminster(Default.default(clause), clause, doc.type)
    # a provision's own application, and an "extends and applies" extent
    applies = Applies.applies(doc)

    %__MODULE__{
      default: default,
      lists:
        (Lists.apart(clause, clause_ref, doc) ++
           Lists.only_following(clause, clause_ref, doc) ++
           Lists.extends_except(clause, clause_ref, doc) ++
           Default.exception_lists(clause, clause_ref, doc) ++
           Lists.headed_lists(sections, clause_ref, clause, doc) ++
           Lists.part_not(sections, doc) ++
           Named.named(unit_sentences, doc) ++
           Excepting.leads(unit_sentences, doc) ++
           Same.amendments_same(unit_sentences, doc) ++
           Amends.amends(unit_sentences, doc) ++
           Excepted.excepted(unit_sentences, doc) ++
           extent_entries(applies))
        |> Enum.flat_map(&excepted(&1, default)),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introductions(doc),
      ref: clause_ref,
      text: if(clause != "", do: clause),
      application: Application.application(doc, Default.default(clause)),
      applies: for({k, _, _} = a <- applies, k in [:applies, :applies_not], do: a)
    }
  end

  defp extent_entries(applies), do: for({k, _, _} = a <- applies, k in [:only, :named], do: a)

  # a list item's own exceptions (`Lists`: "Part 5 …, except— i …") keep
  # the default: what the list adds is taken from them; with no default,
  # unknown (CV-S05 round 6)
  defp excepted({:except, place, refs}, default) when is_binary(default) and is_binary(place) do
    case Territory.subtract(place, default) do
      added when added in [nil, ""] -> []
      added -> [{:not, added, refs}]
    end
  end

  defp excepted({:except, _place, refs}, _default), do: [{:unread, nil, refs}]
  defp excepted(list, _default), do: [list]

  defdelegate units(doc, id), to: Units
  defdelegate statements(s), to: Units

  @doc "What one sentence of an extent clause states (`Extent.Default.statement/2`)."
  @spec statement(String.t(), String.t() | nil) ::
          {:default, String.t()}
          | {:list, list_kind(), String.t() | nil}
          | {:part_not, String.t()}
          | nil
  defdelegate statement(sentence, type \\ nil), to: Default

  # each Schedule's introducing section (`ScheduleRefs.references/1`,
  # the one reader of it), as refs: "sch.7" => "s.111"
  defp introductions(doc) do
    for {sch, sec} <- ScheduleRefs.references(doc),
        s = Order.ref(sch),
        r = Order.ref(sec),
        s != nil and r != nil,
        into: %{},
        do: {s, r}
  end

  @doc "The extent read as `extent_rules` rows (`Extent.Rows.to_rows/2`)."
  @spec to_rows(t(), String.t()) :: [map()]
  defdelegate to_rows(e, law), to: Rows

  @doc "The extent from its `extent_rules` rows (`Extent.Rows.from_rows/1`); nil when none."
  @spec from_rows([map()]) :: t() | nil
  defdelegate from_rows(rows), to: Rows

  @doc "Where the amending provision `ref` extends (`Extent.Lookup.of/2`): a code, `:same`, or nil."
  @spec of(t(), String.t()) :: String.t() | :same | nil
  defdelegate of(e, ref), to: Lookup

  @doc "The territory of a change made by the amending provisions `refs` (`Extent.Lookup.of_change/2`)."
  @spec of_change(t(), [String.t()]) :: String.t() | :same | nil
  defdelegate of_change(e, refs), to: Lookup

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
  @spec from_powers([map()], %{String.t() => t()}) :: String.t() | nil
  defdelegate from_powers(provisions, parents), to: Lookup
end

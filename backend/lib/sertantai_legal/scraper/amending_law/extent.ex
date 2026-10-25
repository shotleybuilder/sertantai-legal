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

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{
    Application,
    Default,
    Forms,
    Lists,
    Named,
    Same,
    Units
  }

  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.Territory

  defstruct default: nil,
            lists: [],
            corresponds: false,
            introduced_by: %{},
            ref: nil,
            text: nil,
            application: nil,
            powers: nil,
            competence: nil

  @type list_kind :: :also | :only | :same | :not | :named | :unread
  @type t :: %__MODULE__{
          default: String.t() | nil,
          lists: [{list_kind(), String.t() | nil, [String.t()]}],
          corresponds: boolean(),
          introduced_by: %{String.t() => String.t()},
          ref: String.t() | nil,
          text: String.t() | nil,
          application: String.t() | nil,
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
          do: {ref, doc |> Doc.element(id) |> Units.own_words() |> Doc.lines() |> Enum.join(" ")}

    # built once: the named and same-extent readers both walk them
    unit_sentences = Units.unit_sentences(doc)

    {clause_ref, clause} =
      Enum.find(sections, {nil, ""}, fn {ref, text} ->
        not String.contains?(ref, "(") and
          (Regex.match?(Forms.extends(), text) or Regex.match?(Forms.extends_and(), text) or
             Regex.match?(Forms.not_extends(), text) or
             Regex.match?(Forms.except_list(), text) or Regex.match?(Forms.heading(), text) or
             Regex.match?(Forms.cited_list(), text) or Regex.match?(Forms.only_following(), text) or
             Regex.match?(Forms.extends_except(), text) or Regex.match?(Forms.extends_exc(), text))
      end)

    %__MODULE__{
      default: Default.westminster(Default.default(clause), clause, doc.type),
      lists:
        Lists.apart(clause, clause_ref, doc) ++
          Lists.only_following(clause, clause_ref, doc) ++
          Lists.extends_except(clause, clause_ref, doc) ++
          Default.exception_lists(clause, clause_ref, doc) ++
          Lists.headed_lists(sections, clause_ref, clause, doc) ++
          Lists.part_not(sections, doc) ++
          Named.named(unit_sentences, doc) ++
          Same.amendments_same(unit_sentences, doc),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introductions(doc),
      ref: clause_ref,
      text: if(clause != "", do: clause),
      application: Application.application(doc, Default.default(clause))
    }
  end

  defdelegate units(doc, id), to: Units
  defdelegate statements(s), to: Units

  @doc "What one sentence of an extent clause states (`Extent.Default.statement/2`)."
  @spec statement(String.t(), String.t() | nil) ::
          {:default, String.t()}
          | {:list, list_kind(), String.t() | nil}
          | {:part_not, String.t()}
          | nil
  defdelegate statement(sentence, type \\ nil), to: Default

  # each Schedule's introducing section (`Amendment.Reader.references/1`,
  # the one reader of it), as refs: "sch.7" => "s.111"
  defp introductions(doc) do
    for {sch, sec} <- Reader.references(doc),
        s = Order.ref(sch),
        r = Order.ref(sec),
        s != nil and r != nil,
        into: %{},
        do: {s, r}
  end

  @doc """
  The extent read as `extent_rules` rows, one per statement (CV-04): the
  default (`"default"`, with the clause's ref and words), each list
  (`"also"`, `"only"`, `"same"`, in order), the corresponding-repeal
  sentence (`"corresponds"`) and each Schedule's introducing section
  (`"introduces"`: `items` the Schedule, `source_ref` the section). An Act
  read with no clause gives a `"none"` row, so read is told from unread.
  """
  @spec to_rows(t(), String.t()) :: [map()]
  def to_rows(%__MODULE__{} = e, law) do
    row = fn kind, place, items, ref, text, position ->
      %{
        kind: kind,
        place: place,
        items: items,
        source_law: law,
        source_ref: ref,
        source_text: text,
        position: position
      }
    end

    # the lists are kept with no default too ("Sections 107 and 116A extend
    # to Scotland only" alone): before CV-S05 (N9) only a "none" row was
    # written then, and the lists were lost
    lists =
      e.lists
      |> Enum.with_index(1)
      |> Enum.map(fn {{kind, place, items}, i} ->
        row.(to_string(kind), place, items, e.ref, nil, i)
      end)

    corresponds = if e.corresponds, do: [row.("corresponds", nil, [], e.ref, nil, 0)], else: []

    clause =
      case {e.default, lists} do
        {nil, []} -> [row.("none", nil, [], nil, nil, 0)] ++ corresponds
        {nil, _} -> lists ++ corresponds
        {d, _} -> [row.("default", d, [], e.ref, e.text, 0)] ++ lists ++ corresponds
      end

    applies =
      if e.application, do: [row.("applies", e.application, [], e.ref, nil, 0)], else: []

    powers = if e.powers, do: [row.("powers", e.powers, [], nil, nil, 0)], else: []

    competence =
      if e.competence, do: [row.("competence", e.competence, [], nil, nil, 0)], else: []

    clause ++
      applies ++
      powers ++
      competence ++
      for {sch, sec} <- Enum.sort(e.introduced_by),
          do: row.("introduces", nil, [sch], sec, nil, 0)
  end

  @doc "The extent from its `extent_rules` rows; nil when there are none (not read)."
  @spec from_rows([map()]) :: t() | nil
  def from_rows([]), do: nil

  def from_rows(rows) do
    default = Enum.find(rows, &(&1.kind == "default"))

    %__MODULE__{
      default: default && default.place,
      ref: default && default.source_ref,
      text: default && default.source_text,
      lists:
        for(
          r <- Enum.sort_by(rows, & &1.position),
          # ("not" was dropped here before CV-S05: a stored "Part III …
          # does not extend to Scotland" read back as nothing)
          r.kind in ~w(also only same not named unread),
          do: {String.to_existing_atom(r.kind), r.place, r.items}
        ),
      corresponds: Enum.any?(rows, &(&1.kind == "corresponds")),
      application: Enum.find_value(rows, &(&1.kind == "applies" && &1.place)),
      powers: Enum.find_value(rows, &(&1.kind == "powers" && &1.place)),
      competence: Enum.find_value(rows, &(&1.kind == "competence" && &1.place)),
      introduced_by:
        for(r <- rows, r.kind == "introduces", into: %{}, do: {hd(r.items), r.source_ref})
    }
  end

  # the order lists apply in (`of/2`)
  @apply_order %{same: 0, unread: 0, only: 1, named: 2, also: 3, not: 4}

  @doc """
  Where the amending provision `ref` ("s.111", "sch.7.para.27(2)",
  "sch.17.pt.2") extends: a territory code, `:same` (the enactment it
  changes), or nil (the clause wasn't read).
  """
  @spec of(t(), String.t()) :: String.t() | :same | nil
  # stating none, an SI extends as far as its enabling powers (`powers`),
  # else a devolved instrument as far as its legislature (`competence`)
  def of(%__MODULE__{default: nil, lists: [], powers: powers, competence: c}, _ref),
    do: powers || c

  # with no default, only a list naming the provision decides ("The
  # following provisions of this Act extend to England and Wales only—")
  def of(%__MODULE__{} = e, ref) do
    candidates = [ref | containers(ref)] ++ introducing(e, ref)

    # every list naming it, in order: "only" sets, "also" widens, "not"
    # narrows (HSWA s.77: also NI by s.84(1), not Scotland by s.84(2))
    naming =
      Enum.filter(e.lists, fn {_kind, _place, items} ->
        items != ["*"] and Enum.any?(candidates, &named?(&1, items))
      end)

    # "every amendment the law makes" only where no list names it
    naming = if naming == [], do: Enum.filter(e.lists, &match?({_, _, ["*"]}, &1)), else: naming

    # a list naming its own extent ("only", "named") is more specific than
    # one deferring to the enactment ("same", or unknown "unread"): "Subject
    # to paragraph (7), the modifications in Schedule 2 have the same extent
    # …"; "(7) … paragraphs 65 … and 76 of Schedule 2 … extend to Scotland
    # only" (SI 2013/602 art.1: CV-S05 round 3 C)
    naming =
      if Enum.any?(naming, &match?({k, _, _} when k in [:only, :named], &1)),
        do: Enum.reject(naming, &match?({k, _, _} when k in [:same, :unread], &1)),
        else: naming

    # in a fixed order, whatever order they were stated or stored in: the
    # same extent, then the lists that set it, then those that widen, then
    # those that narrow (Police and Justice Act 2006 s.54: CV-S05 C)
    naming
    |> Enum.sort_by(fn {kind, _, _} -> Map.fetch!(@apply_order, kind) end)
    |> Enum.reduce_while(e.default || e.powers || e.competence, fn
      {:same, _, _}, _acc ->
        {:halt, :same}

      # stated, but not plainly: unknown, never the default
      {:unread, _, _}, _acc ->
        {:halt, nil}

      {:named, place, _}, nil ->
        {:cont, place}

      # a stated default is widened; an extent implied (powers, competence) is not
      {:named, place, _}, acc ->
        {:cont, if(e.default, do: Territory.union([acc, place]), else: place)}

      {:only, place, _}, _acc ->
        {:cont, place}

      {:also, _place, _}, nil ->
        {:cont, nil}

      {:also, place, _}, acc ->
        {:cont, Territory.union([acc, place])}

      {:not, _place, _}, nil ->
        {:cont, nil}

      {:not, place, _}, acc ->
        {:cont, Territory.subtract(acc, place)}
    end)
  end

  # "sch.7.para.27(2)" → ["sch.7.para.27", "sch.7"]; "sch.17.pt.2" → ["sch.17"]
  defp containers(ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> Enum.reject([String.replace(ref, ~r/\(.*$/, ""), sch], &(&1 == ref))
      nil -> [String.replace(ref, ~r/\(.*$/, "")] |> Enum.reject(&(&1 == ref))
    end
  end

  # a Schedule not named in the clause extends as its introducing section
  defp introducing(e, ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> List.wrap(Map.get(e.introduced_by, sch))
      nil -> []
    end
  end

  defp named?(ref, items), do: Enum.any?(items, &RefList.covers?(&1, ref))

  # a devolved legislature's instruments extend no further than its
  # competence (a Welsh Minister's SI forms part of the law of England and
  # Wales)
  @competence %{
    "nisr" => "NI",
    "nisi" => "NI",
    "nia" => "NI",
    "apni" => "NI",
    "ssi" => "S",
    "asp" => "S",
    "wsi" => "E+W",
    "anaw" => "E+W",
    "asc" => "E+W"
  }

  @doc """
  A devolved instrument's extent by its legislature's competence (CV-07),
  used only where it states none and its enabling powers aren't read: an
  NI statutory rule extends to Northern Ireland. Nil for a UK instrument.
  """
  @spec competence(String.t()) :: String.t() | nil
  def competence(law) do
    case String.split(law || "", "_", parts: 4) do
      [_, type, _, _] -> Map.get(@competence, type)
      _ -> nil
    end
  end

  @doc """
  True when the extent rests on the legislature's competence alone (the
  instrument states none and its powers aren't read). Such an extent
  doesn't confine an insertion the instrument makes (V1-04, signed off: a
  Welsh SI's insertion into a GB Act's single text applies across it;
  Forestry Act 1967 s.1(1A)).
  """
  @spec competence_only?(t()) :: boolean()
  def competence_only?(%__MODULE__{default: nil, lists: [], powers: nil, competence: c}),
    do: c != nil

  def competence_only?(%__MODULE__{}), do: false

  @doc """
  An SI's extent from its enabling powers (CV-07), where it states none:
  it can reach only as far as the provisions that empower it. `provisions`
  are its enabling provisions (`EnactedBy.EnablingCache`: per parent law,
  its sections and schedules); each is placed by its parent Act's own
  extent clause (`parents`: law → `t()`). The union of them; nil when any
  parent is unread or places a provision nowhere known (all or nothing: a
  partial union would understate the SI's reach), or none is named.
  """
  @spec from_powers([map()], %{String.t() => t()}) :: String.t() | nil
  def from_powers([], _parents), do: nil

  def from_powers(provisions, parents) do
    extents =
      for %{"law" => law} = p <- provisions,
          ref <-
            Enum.map(p["sections"] || [], &"s.#{&1}") ++
              Enum.map(p["schedules"] || [], &"sch.#{&1}"),
          do: with(%__MODULE__{} = e <- Map.get(parents, law), do: of(powers_extent(e), ref))

    if extents != [] and Enum.all?(extents, &is_binary/1),
      do: Territory.union(extents)
  end

  # a parent Act's extent at its enabling sections: what "every amendment
  # the law makes" follows (a `*` same or unread list) is no enabling
  # section's (REUL 2023 s.23(2): uksi 2025/82, CV-S05 round 5)
  defp powers_extent(%__MODULE__{lists: lists} = e),
    do: %{e | lists: Enum.reject(lists, &match?({k, _, ["*"]} when k in [:same, :unread], &1))}

  @doc """
  The territory of a change made by the amending provisions `refs` (an
  effect may name several: "Sch. 7 para. 27(2) Sch. 17 Pt. 2"): a repeals
  schedule with the enactment's extent follows the provision it corresponds
  to (`corresponds`); the provisions that remain must agree. Nil when none
  is read, or they disagree.
  """
  @spec of_change(t(), [String.t()]) :: String.t() | :same | nil
  def of_change(%__MODULE__{} = e, refs) do
    extents = Enum.map(refs, &of(e, &1))

    extents =
      if e.corresponds and Enum.any?(extents, &is_binary/1),
        do: Enum.reject(extents, &(&1 == :same)),
        else: extents

    case Enum.uniq(extents) do
      [one] -> one
      _ -> nil
    end
  end
end

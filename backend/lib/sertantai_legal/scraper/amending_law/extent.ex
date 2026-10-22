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
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.ApplicationClause
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

  @type list_kind :: :also | :only | :same | :not
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

  @places "England and Wales|Great Britain|the United Kingdom|United Kingdom|England|Wales|Scotland|Northern Ireland"
  @codes %{
    "england and wales" => "E+W",
    "great britain" => "E+W+S",
    "the united kingdom" => "E+W+S+NI",
    "united kingdom" => "E+W+S+NI",
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI"
  }

  # the law speaking of itself (an Act, an SI; "The provisions of this
  # Order"), not of some provisions of it ("The following provisions of
  # this Act extend …" is a list)
  @subject "(?:\\bThe provisions of |(?<!of )\\b)(?:this Act|these Regulations|this Order|these Rules|this Scheme)"
  # "England and Wales and Scotland", "England and Wales, Scotland and
  # Northern Ireland"
  @place_list "(?:#{@places})(?:\\s*,\\s*(?:#{@places}))*(?:\\s+and\\s+(?:#{@places}))*"
  @heading ~r/The following (?:provisions (?:of this (?:Act|Part) )?)?(?:extend(?:s)? (also )?to (#{@places})( only)?|ha(?:s|ve) the same extent as the enactments? to which (?:it|they) relates?)\s*[—–:-]/iu
  @extends Regex.compile!(
             "#{@subject}(?:,\\s*which)?\\s+(?:shall\\s+)?extends?\\s+to\\s+(?:the\\s+whole\\s+of\\s+)?(#{@place_list})(?:\\s+only)?(?!\\s*[—–])",
             "iu"
           )
  # "This Act, except— (a) …; and (b) …, does not extend to Northern Ireland"
  @except_list Regex.compile!(
                 "#{@subject},\\s*except\\s*[—–]\\s*(.+?),\\s*(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(#{@place_list})",
                 "isu"
               )
  # "Part III, except section 75 and Schedule 7, does not extend to Scotland"
  @part_not Regex.compile!(
              "\\b(Parts?\\s+[IVXLC\\d]+[A-Z]*(?:\\s*(?:,|and)\\s*[IVXLC\\d]+[A-Z]*)*)(?:,\\s*except\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(#{@place_list})",
              "u"
            )
  @not_extends Regex.compile!(
                 "#{@subject}(?:,\\s*(?:apart from|except(?: for)?)\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(#{@place_list})",
                 "iu"
               )

  @doc "The Act's extent clause read from its document; empty when it has none read."
  @spec read(Doc.t()) :: t()
  def read(%Doc{} = doc) do
    # lines joined with spaces: a paragraph label never runs into the
    # words before it ("Schedule 10.7 The following …")
    sections =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil,
          do: {ref, doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" ")}

    {clause_ref, clause} =
      Enum.find(sections, {nil, ""}, fn {ref, text} ->
        not String.contains?(ref, "(") and
          (Regex.match?(@extends, text) or Regex.match?(@not_extends, text) or
             Regex.match?(@except_list, text) or Regex.match?(@heading, text))
      end)

    %__MODULE__{
      default: default(clause),
      lists: apart(clause, clause_ref, doc) ++ lists(clause, clause_ref),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introductions(doc),
      ref: clause_ref,
      text: if(clause != "", do: clause),
      application: application(sections, default(clause))
    }
  end

  # the law's whole-instrument application clause ("These Regulations …
  # apply in relation to England only"; `ApplicationClause`), as a code:
  # where the changes it makes apply (CV-07)
  defp application(sections, extent) do
    clauses =
      for {ref, text} <- sections,
          not String.contains?(ref, "("),
          c = ApplicationClause.parse(text),
          c != nil,
          do: c

    extent_regions = extent && String.split(extent, "+")

    case ApplicationClause.resolve(clauses, extent_regions) do
      nil -> nil
      regions -> Enum.join(regions, "+")
    end
  end

  # "These Regulations extend to England and Wales and Scotland" → E+W+S;
  # "This Act does not extend to Northern Ireland" → the rest of the UK
  defp default(clause) do
    cond do
      m = Regex.run(@except_list, clause) ->
        Territory.subtract("E+W+S+NI", places(List.last(m)))

      m = Regex.run(@extends, clause) ->
        places(Enum.at(m, 1))

      m = Regex.run(@not_extends, clause) ->
        Territory.subtract("E+W+S+NI", places(List.last(m)))

      true ->
        nil
    end
  end

  # "… apart from sections 82 and 83, does not extend to Northern
  # Ireland": those extend there too
  defp apart(clause, clause_ref, doc) do
    except_list =
      case Regex.run(@except_list, clause) do
        # each item; one "so far as may be necessary …" is limited to a
        # purpose and doesn't carry its provisions there (HSWA s.84(1)(a))
        [_, items, place] ->
          refs =
            for item <- String.split(items, ";"),
                not (item =~ ~r/\bso far as\b/i),
                ref <- RefList.parse(item, clause_ref) ++ parts(item, doc, clause_ref),
                do: ref

          if refs != [], do: [{:also, places(place), refs}], else: []

        nil ->
          case Regex.run(@not_extends, clause) do
            [_, except, place] when except != "" ->
              [{:also, places(place), RefList.parse(except, clause_ref)}]

            _ ->
              []
          end
      end

    part_not =
      for [_, part, except, place] <- Regex.scan(@part_not, clause),
          refs = parts(part, doc, clause_ref) -- RefList.parse(except || "", clause_ref),
          refs != [],
          do: {:not, places(place), refs}

    except_list ++ part_not
  end

  # the sections of the Parts named ("Part III", "Parts I and II"; "this
  # Part": the one holding the clause), from the document
  defp parts(text, doc, clause_ref) do
    named =
      case Regex.run(~r/\bParts?\s+([IVXLC\d]+[A-Z]*(?:\s*(?:,|and)\s*[IVXLC\d]+[A-Z]*)*)/u, text) do
        [_, list] ->
          Regex.scan(~r/[IVXLC\d]+[A-Z]*/u, list) |> List.flatten() |> Enum.map(&"part-#{&1}")

        nil ->
          []
      end

    this =
      if text =~ ~r/\bthis Part\b/i and clause_ref,
        do: Enum.filter(doc.ids, &(&1 =~ ~r/^part-/ and holds?(doc, &1, clause_ref))),
        else: []

    for part <- named ++ this,
        el = Doc.element(doc, part),
        el != nil,
        id <- doc.ids,
        id =~ ~r/^section-\d+[A-Z]*$/,
        holds_id?(doc, part, id),
        ref = Order.ref(id),
        uniq: true,
        do: ref
  end

  defp holds?(doc, part, ref) do
    Enum.any?(doc.ids, &(Order.ref(&1) == ref and holds_id?(doc, part, &1)))
  end

  # the element `id` lies inside the Part (document order: after it, before
  # the next Part)
  defp holds_id?(doc, part, id) do
    case {Map.get(doc.pos, part), Map.get(doc.pos, id)} do
      {p, i} when is_integer(p) and is_integer(i) and i > p ->
        next = doc.ids |> Enum.drop(p + 1) |> Enum.find(&(&1 =~ ~r/^part-[^-]+$/))
        next == nil or i < Map.fetch!(doc.pos, next)

      _ ->
        false
    end
  end

  defp places(list) do
    Regex.scan(~r/#{@places}/iu, list)
    |> List.flatten()
    |> Enum.map(&@codes[String.downcase(&1)])
    |> Territory.union()
  end

  # each list: "The following extend also to Scotland— …", "… to Scotland
  # only— …", "… have the same extent as the enactments to which they
  # relate— …", up to the next such heading

  defp lists(clause, clause_ref) do
    parts = Regex.split(@heading, clause, include_captures: true, trim: true)

    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [head, body] ->
      case Regex.run(@heading, head) do
        nil -> []
        match -> [{kind(match), place(match), refs(cut(body), clause_ref)}]
      end
    end)
  end

  defp kind([whole | _]) do
    cond do
      whole =~ ~r/same extent/i -> :same
      whole =~ ~r/\bonly\b/i -> :only
      true -> :also
    end
  end

  defp place([whole | _]) do
    case Regex.run(~r/\bto (#{@places})\b/i, whole) do
      [_, p] -> @codes[String.downcase(p)]
      nil -> nil
    end
  end

  # the list ends at the next subsection's words ("(8) So far as …")
  # (and before the next list's heading, its subsection number: "… and 15.4")
  defp cut(body),
    do:
      body
      |> String.split(~r/\.\s*\d+[A-Z]?\s+(?=[A-Z])/u, parts: 2)
      |> hd()
      |> String.replace(~r/\.\s*\d+[A-Z]?\s*$/u, ".")

  defp refs(text, clause_ref), do: RefList.parse(text, clause_ref)

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

    clause =
      case e.default do
        nil ->
          [row.("none", nil, [], nil, nil, 0)]

        d ->
          [row.("default", d, [], e.ref, e.text, 0)] ++
            (e.lists
             |> Enum.with_index(1)
             |> Enum.map(fn {{kind, place, items}, i} ->
               row.(to_string(kind), place, items, e.ref, nil, i)
             end)) ++
            if(e.corresponds, do: [row.("corresponds", nil, [], e.ref, nil, 0)], else: [])
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
          r.kind in ~w(also only same),
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
    e.lists
    |> Enum.filter(fn {_kind, _place, items} -> Enum.any?(candidates, &named?(&1, items)) end)
    |> Enum.reduce_while(e.default || e.powers || e.competence, fn
      {:same, _, _}, _acc -> {:halt, :same}
      {:only, place, _}, _acc -> {:cont, place}
      {:also, _place, _}, nil -> {:cont, nil}
      {:also, place, _}, acc -> {:cont, Territory.union([acc, place])}
      {:not, _place, _}, nil -> {:cont, nil}
      {:not, place, _}, acc -> {:cont, Territory.subtract(acc, place)}
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
          do: with(%__MODULE__{} = e <- Map.get(parents, law), do: of(e, ref))

    if extents != [] and Enum.all?(extents, &is_binary/1),
      do: Territory.union(extents)
  end

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

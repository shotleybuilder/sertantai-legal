defmodule SertantaiLegal.Scraper.Commencement.Misreads do
  @moduledoc """
  The words of a commencement statement a rule uses wrongly: a rule whose
  scope or extent its statement does not give it, found in code over every
  statement held (Decision 1, Jason 2026-11-20: "zero new patterns" as a
  code fact). `Commencement.Leftovers` finds the words no rule uses; this
  is its twin. Kinds:

  - `:other_law` — a ref in a rule's scope the statement gives to another
    law ("sections 37 and 133 of the Magistrates' Courts Act 1980": 1988
    c.33 s.171(5));
  - `:no_row` — a ref in a rule's scope the law holds no row for, misnamed:
    a deeper row under its parent ends in its last bracket ("section
    118(1)(a), …, (n) and (o)" read s.118(n) where the Act holds
    s.118(1)(n): SI 1992/3253 art.3). Only where the caller gives the law's
    row ids;
  - `:qualifier` — a partial rule reaching a ref its qualifier does not: a
    ref of a list item with no qualifier of its own (SI 2010/490 reg.1(4)),
    a ref standing before the provisions a trailing qualifier points back
    to ("…, in so far as they relate to those paragraphs": 1996 c.52
    s.232(2)), a territory stated only in a bracketed heading, or an item
    limited to its repeals or entries that a rule holds whole (2005 c.16
    s.108(2)(h));
  - `:container` — a list headed by a container ("The following provisions
    of Schedule 2") with a rule ref outside it;
  - `:whole_law` — a rule for the whole law read from a list of provisions
    ("The following provisions come into force …—": 2005 c.15 s.178(1));
  - `:item_dropped` — a list item whose provisions no rule of the
    statement holds (SI 2012/3039 reg.1(3)(b)).

  A ref with no row and no such sign (a repealed provision's row is gone:
  SI 1964/1045 art.1) is `:not_held`: counted (`not_held/1`), never grouped
  as a misread.

  It reads rules, never shapes them: outside every reader's version
  patterns (the catalogue's cache alone is keyed on it). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, Order, OrderPatterns, Rule}
  alias SertantaiLegal.Scraper.Commencement.Order.Asides
  alias SertantaiLegal.Scraper.LawStart.Provisions

  @type kind ::
          :other_law
          | :no_row
          | :not_held
          | :qualifier
          | :container
          | :whole_law
          | :item_dropped
  @type misread :: %{kind: kind(), words: String.t()}
  @type statement :: %{head: String.t(), items: [String.t()]}
  @type ctx :: %{
          required(:refs) => (String.t() -> [String.t()]),
          optional(:ids) => MapSet.t() | nil,
          optional(:own) => %{title: String.t() | nil, year: String.t()} | nil
        }

  @provision ~S"(?i:(?:sub-?)?sections?|regulations?|rules?|paragraphs?|articles?|Schedules?|Parts?)\s+\d[\w()]*(?:\s*(?:,|and|to|–|-)\s*[\d(][\w()]*)*(?:\s+of(?:\s+and)?\s+(?:Schedule|Part)\s+\w+)*"
  @law ~S"(?:that\s+(?:Act|Order|Measure)|those\s+Regulations|the\s+\d{4}\s+(?:Act|Order|Regulations)|the\s+(?:\(?[A-Z][\w(),'’.-]*\s+|(?:and|of|the|for|in|on|to|etc\.?)\s+){1,16}(?:Act|Order|Regulations|Measure)(?:\s+\([^)]*\))?\s+\d{4})"
  @other_law Regex.compile!("\\b(#{@provision})\\s+(?:of|to)\\s+(#{@law})", "u")
  @named_law Regex.compile!(
               String.replace_prefix(
                 @law,
                 "(?:that\\s+(?:Act|Order|Measure)|those\\s+Regulations|",
                 "(?:"
               ),
               "u"
             )
  @points_to_law ~r/^th(?:at|ose)\s/
  @as_purpose ~r/\b(?:for\s+the\s+purposes?\s+of|in\s+relation\s+to)(?:\s+the\s+application\s+of)?\s*$/i

  @qualifier ~r/\b(?:in\s+relation\s+to|for\s+the\s+purposes?\s+(?:only\s+)?of|(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent|as\s+re(?:gards|spects))\b/i
  @place ~r/\b(?:England|Wales|Scotland|Northern\s+Ireland|Great\s+Britain|United\s+Kingdom|extends?\s+to)\b/
  @points_back ~r/\b(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\s+(?:(?:it|they)\s+relates?|relating)\s+to\s+th(?:ose|at)\s+(paragraph|section|regulation|article|Part|Schedule)s?\b/i
  @limit ~r/\bthe\s+(?:repeals?|revocations?|entry|entries)\s+(?:to|of|in|relating\s+to)\b/i
  # (possessive: "Schedule 11 to the Act" is never Schedule 1 — WSI 2006/345)
  @container ~r/\bprovisions\s+of\s+((?:Part\s+\w+\s+of\s+)?Schedule\s+\d++[A-Z]*+|Part\s+[\dIVXL]++[A-Z]?+)(?!\s+(?:of|to)\s+(?:this|the|that)\b)/
  # "(and Article 65 so far as relating thereto)": a bracket naming its own
  # provision with its qualifier (NISI 2003/419 art.1(3))
  @own_aside ~r/\(\s*and\s+(?:Articles?|sections?|regulations?|rules?|paragraphs?)\s+\d(?:[^()]|\([^()]*\))*\)/i
  @list_head ~r/^\W*(?:The\s+following|These)\s+provisions\b/
  @pointer ~r/\bprovisions\s+(?:specified|mentioned|listed|set\s+out)\s+in\s+(?:subsection|paragraph)\s+\((\w+)\)/

  @doc """
  The misreads of a statement — its `head` sentence and the `items` of the
  list it opens, each whole — given the `rules` read from it and `ctx`:
  `refs` the reader's own ref extractor (text → bare refs), `ids` the bare
  ids of the law's rows (nil: not checked), `own` the law an order
  commences (its provisions are never another law's).
  """
  @spec of(statement(), [Rule.t()], ctx()) :: [misread()]
  def of(_statement, [], _ctx), do: []

  def of(%{head: head, items: items} = statement, rules, ctx) do
    text = Enum.join([head | items], " ")

    Enum.uniq(
      other_law(text, rules, ctx) ++
        no_row(rules, ctx[:ids]) ++
        unmarked(statement, rules, ctx) ++
        Enum.flat_map([head | items], &points_back(&1, rules, ctx)) ++
        Enum.flat_map(items, &limited(&1, rules, ctx)) ++
        container(statement, rules, ctx) ++
        whole_law(statement, rules) ++ dropped(statement, rules, ctx)
    )
  end

  # ── another law's provisions ────────────────────────────────────────

  defp other_law(text, rules, ctx) do
    held = scope_refs(rules)
    own = ctx.refs.(Regex.replace(@other_law, text, "another law"))

    for [{at, _}, {p, pn}, {l, ln}] <- Regex.scan(@other_law, text, return: :index),
        before = binary_part(text, 0, at),
        law = antecedent(binary_part(text, l, ln), before),
        not own_law?(law, ctx[:own]),
        ref <- named(binary_part(text, p, pn), ctx),
        ref in held and ref not in own,
        do: %{kind: :other_law, words: "#{ref} of #{squash(law)}" <> as_purpose(before)}
  end

  # "section 3ZA of the Road Traffic Act 1988 has effect for the purposes of
  # sections 3 and 3A of that Act": that Act is the law named before it in
  # its item, the order's own only where none is (SI 2007/2472 art.2(h))
  defp antecedent(law, before) do
    item = before |> String.split(";") |> List.last()

    case law =~ @points_to_law && Regex.scan(@named_law, item) do
      [_ | _] = named -> named |> List.last() |> hd()
      _ -> law
    end
  end

  # "for the purposes of the application of Part 1 of the 2006 Act": the
  # other law's provision is the purpose, never what commences (SI 2021/1322)
  defp as_purpose(before),
    do: if(before =~ @as_purpose, do: ": a purpose's words, not commenced", else: "")

  # an order's "the 2005 Act", "that Act", the Act's own title: the Act it
  # commences
  defp own_law?(_law, nil), do: false

  defp own_law?(law, %{year: year} = own),
    do:
      law =~ @points_to_law or
        (String.contains?(law, year) and (law =~ ~r/^the\s+\d{4}\s/ or titled?(law, own[:title])))

  defp titled?(_law, nil), do: true
  defp titled?(law, title), do: String.contains?(squash(law), squash(title))

  # the provisions as the reader names its own; an Act's by the order
  # reader's names where it names none
  defp named(words, ctx) do
    [ctx.refs.(words), Order.refs_in(words), numbered(words)]
    |> Enum.find([], &(&1 != []))
    |> spread()
  end

  # an instrument's regulations, where the law holds no such row to name
  defp numbered(words) do
    if words =~ ~r/^(?:regulations?|articles?|rules?)\b/i,
      do: for([n] <- Regex.scan(~r/\d+[A-Z]*(?:\(\w+\))*/, words), do: "reg." <> n),
      else: []
  end

  # ── no row ──────────────────────────────────────────────────────────

  defp no_row(_rules, nil), do: []

  defp no_row(rules, ids) do
    # (a ref to one extent's version, "s.79[S]", is its provision's)
    for ref <- scope_refs(rules),
        not row?(ids, String.replace(ref, ~r/\[[^\]]*\]$/, "")),
        do: missing(ref, ids)
  end

  # misnamed where a deeper row under the ref's parent ends in its last
  # bracket; else the provision is simply not held
  defp missing(ref, ids) do
    with [_, parent, last] <- Regex.run(~r/^(.*)(\([^()]+\))(?:\[[^\]]*\])?$/, ref),
         [_ | _] = held <- Enum.filter(ids, &deeper?(&1, parent, last)) do
      %{kind: :no_row, words: "#{ref}: misnamed (#{Enum.min(held)} held)"}
    else
      _ -> %{kind: :not_held, words: ref}
    end
  end

  defp deeper?(id, parent, last) do
    String.starts_with?(id, parent <> "(") and String.ends_with?(id, last) and
      id != parent <> last
  end

  # (a Schedule the law holds no row of is not parsed: never counted)
  defp row?(ids, "sch." <> _ = ref) do
    schedule = ref |> String.split(".") |> Enum.take(2) |> Enum.join(".")
    MapSet.member?(ids, ref) or not MapSet.member?(ids, schedule)
  end

  defp row?(ids, ref), do: MapSet.member?(ids, ref)

  # ── a qualifier's reach ─────────────────────────────────────────────

  # a partial rule's ref named in items with no qualifier of their own, the
  # head stating none; a territory no words outside a heading state
  defp unmarked(%{head: head, items: items}, rules, ctx) do
    for %Rule{scope: [_ | _] = scope} = rule <- rules,
        not Rule.full?(rule),
        not marked?(head, rule),
        ref <- scope,
        unmarked?(ref, rule, items, ctx),
        do: %{kind: :qualifier, words: "#{ref}: no #{mark(rule)} of its own"}
  end

  # (an order's territory is its maker's or its own articles': never asked
  # of the statement)
  defp unmarked?(_ref, %Rule{territory: t}, [], ctx), do: t != nil and ctx[:own] == nil

  defp unmarked?(ref, rule, items, ctx) do
    naming = Enum.filter(items, fn item -> item |> ctx.refs.() |> spread() |> held?([ref]) end)
    naming != [] and not Enum.any?(naming, &marked?(&1, rule))
  end

  # (an item limited to a Part's repeals, "in Part 1 of Schedule 5, the
  # repeal to …": 2005 c.16 s.108(3)(g), or to the provisions of Parts
  # "which— confer power to make orders": 2008 c.29 s.241(1)(a), carries
  # its own limit)
  @described ~r/\bprovisions?\s+of\s+[^;]*?\b(?:which|that)\b/i

  defp marked?(text, %Rule{territory: nil}),
    do: own_words(text) =~ @qualifier or text =~ @limit or text =~ @described

  defp marked?(text, _territorial), do: own_words(text) =~ @place

  # the text less its headings, a bracket naming its own provision kept
  defp own_words(text) do
    kept = @own_aside |> Regex.scan(text) |> Enum.map_join(" ", &hd/1)
    Asides.drop_headings(text) <> " " <> kept
  end

  defp mark(%Rule{territory: nil}), do: "qualifier"
  defp mark(_territorial), do: "territory"

  # "…, and sections 222 and 227, …, in so far as they relate to those
  # paragraphs": what stands before the paragraphs is never so limited
  defp points_back(text, rules, ctx) do
    with [{at, _}, {k, n}] <- Regex.run(@points_back, text, return: :index),
         before = binary_part(text, 0, at),
         kind = binary_part(text, k, n),
         [_ | _] = found <- Regex.scan(~r/\b#{kind}s?\s+\d/i, before, return: :index) do
      [{antecedent, _}] = List.last(found)
      earlier = before |> binary_part(0, antecedent) |> ctx.refs.() |> spread()

      # (a rule partial only by the territory its head states is not the
      # qualifier's: 2022 c.30 s.170(4)(b)(ix))
      for ref <- rules |> Enum.reject(&(&1.purposes == nil)) |> partial_refs(), ref in earlier do
        %{kind: :qualifier, words: "#{ref}: before the #{String.downcase(kind)}s limited"}
      end
    else
      _ -> []
    end
  end

  # "in Part 4 of Schedule 5, the repeals to …": the Part's repeals only
  defp limited(item, rules, ctx) do
    with [before, _] <- Regex.split(@limit, item, parts: 2),
         tail = before |> String.split(~r/\band\b|;/) |> List.last(),
         last = [List.last(Order.refs_in(tail)), List.last(ctx.refs.(tail))],
         ref when is_binary(ref) <- Enum.find(last, &(&1 in whole_refs(rules))) do
      [%{kind: :qualifier, words: "#{ref}: its repeals or entries only"}]
    else
      _ -> []
    end
  end

  # ── a container's list ──────────────────────────────────────────────

  defp container(%{head: head}, rules, ctx) do
    with [{at, _}, {w, n}] <- Regex.run(@container, head, return: :index),
         # ("… in so far as it relates to the following provisions of Schedule
         # 22": the qualifier's, never the list's — SSI 2003/206 art.2)
         false <- binary_part(head, 0, at) =~ @qualifier,
         [holder] <- Order.refs_in(binary_part(head, w, n)) do
      stated = spread(ctx.refs.(head))

      for ref <- scope_refs(rules), outside?(ref, holder), ref not in stated do
        %{kind: :container, words: "#{ref}: not of #{holder}"}
      end
    else
      _ -> []
    end
  end

  defp outside?(ref, "sch." <> _ = holder),
    do: ref != holder and not String.starts_with?(ref, holder <> ".")

  # (a Part's sections are named bare: its Chapters and Parts alone tell)
  defp outside?(ref, holder),
    do:
      String.starts_with?(ref, ["pt.", "ch."]) and ref != holder and
        not String.starts_with?(ref, holder <> ".")

  # ── the whole law from a list ───────────────────────────────────────

  defp whole_law(%{head: head}, rules) do
    if Regex.match?(@list_head, head) and Enum.any?(rules, &(&1.scope == :all)),
      do: [%{kind: :whole_law, words: "all, from a list of provisions"}],
      else: []
  end

  # ── an item no rule holds ───────────────────────────────────────────

  defp dropped(%{items: items}, rules, ctx) do
    held = scope_refs(rules) ++ Enum.flat_map(rules, & &1.except)

    for item <- items,
        held != [],
        [first | _] = refs <- [item |> subject() |> ctx.refs.() |> spread()],
        not held?(refs, held),
        # (a container's item, "Part 2" of Schedule 2, is held as the Schedule's)
        not Enum.any?(held, &String.ends_with?(&1, "." <> first)),
        do: %{kind: :item_dropped, words: first}
  end

  # the item's own provisions: before its qualifier, its heading dropped
  defp subject(item),
    do: item |> Asides.drop_headings() |> String.split(@qualifier, parts: 2) |> hd()

  # one of `refs` is one of `held`, holds it or is held by it
  defp held?(refs, held) do
    Enum.any?(refs, fn ref ->
      Enum.any?(
        held,
        &(ref == &1 or String.starts_with?(ref, [&1 <> "(", &1 <> "."]) or
            String.starts_with?(&1, [ref <> "(", ref <> "."]))
      )
    end)
  end

  # ── a law's own clause ──────────────────────────────────────────────

  @doc """
  Each statement of a law's own clause (`Leftovers.sentences/2`) with its
  `misreads`: its sentence and the items under its row (or under the
  subsection it points to: "The provisions specified in subsection (2)"),
  the rules `read` holds from it, the law's rows.
  """
  @spec sentences([map()], map()) :: [map()]
  def sentences(rows, read) do
    ids = row_ids(Enum.map(rows, & &1.section_id))

    for %{row: row, sentence: s, form: f} = statement <- Leftovers.sentences(rows, read) do
      misreads =
        if f.subject == "instrument" or f.role == "mention",
          do: [],
          else: for_sentence(row, s, rows, read, ids)

      Map.put(statement, :misreads, misreads)
    end
  end

  @doc "The bare ids of a law's rows from their section ids: no law, no extent suffix."
  @spec row_ids([String.t()]) :: MapSet.t()
  def row_ids(section_ids) do
    MapSet.new(section_ids, fn id ->
      id |> String.split(":", parts: 2) |> List.last() |> String.replace(~r/\[[^\]]*\]$/, "")
    end)
  end

  defp for_sentence(row, sentence, rows, read, ids) do
    {text, own} = Leftovers.statement(row, sentence, rows, read)
    base = row |> String.split("(") |> hd()
    # (a sentence pointing to another subsection's list keeps its own items'
    # words: "… come into force— (a) in relation to England, …")
    head = if sentence =~ @pointer, do: text, else: sentence

    of(
      %{head: head, items: items(row, sentence, rows)},
      own,
      %{refs: &Provisions.refs_in(&1, rows, base), ids: ids}
    )
  end

  @doc """
  The items of the list the sentence of `row` opens (it ends in a dash, or
  points to a subsection's list): each item under it whole, its own
  sub-items' words with it.
  """
  @spec items(String.t(), String.t(), [map()]) :: [String.t()]
  def items(row, sentence, rows) do
    case list_row(row, sentence) do
      nil ->
        []

      parent ->
        under = Enum.filter(rows, &String.starts_with?(&1.section_id, parent <> "("))
        depth = brackets(parent) + 1

        for %{section_id: id} <- under, brackets(id) == depth do
          under
          |> Enum.filter(&(&1.section_id == id or String.starts_with?(&1.section_id, id <> "(")))
          |> Enum.map_join(" ", &(&1.text || ""))
        end
    end
  end

  defp list_row(row, sentence) do
    case Regex.run(@pointer, sentence) do
      [_, n] -> (row |> String.split("(") |> hd()) <> "(#{n})"
      nil -> if sentence =~ ~r/[—–:-]\s*$/u, do: row
    end
  end

  defp brackets(id), do: length(String.split(id, "(")) - 1

  # ── a commencement order ────────────────────────────────────────────

  @doc """
  Each statement of a commencement order (`Leftovers.order_units/2`) with
  its `misreads`, given the order's `rules` and `ctx`: the Act it commences
  (`own`) and the bare ids of the Act's rows (`ids`, nil where none held).
  """
  @spec order_units(Doc.t(), [Rule.t()], map()) :: [map()]
  def order_units(doc, rules, ctx) do
    ctx = Map.put(ctx, :refs, &Order.refs_in/1)

    for %{unit: unit} = statement <- Leftovers.order_units(doc, rules) do
      Map.put(statement, :misreads, order_misreads(unit, rules, ctx))
    end
  end

  defp order_misreads(%{kind: kind}, _rules, _ctx) when kind in ["own", "table_header"], do: []

  defp order_misreads(unit, rules, ctx) do
    text = if unit.kind == "table", do: unit.text |> String.split(" | ") |> hd(), else: unit.text
    own = OrderPatterns.own_rules(unit, rules)
    Enum.uniq(of(%{head: text, items: []}, own, ctx) ++ order_items(own, ctx))
  end

  @doc """
  Another law's provisions in the rules of an order's list items: each
  item (a rule's source words after its head, "head … item") read with the
  rules it gave.
  """
  @spec order_items([Rule.t()], ctx()) :: [misread()]
  def order_items(rules, ctx) do
    rules
    |> Enum.group_by(&item/1)
    |> Enum.sort()
    |> Enum.flat_map(fn
      {nil, _} -> []
      {item, of_item} -> other_law(item, of_item, ctx)
    end)
  end

  defp item(%Rule{source: %{text: text}}) when is_binary(text) do
    case String.split(text, " … ", parts: 2) do
      [_head, item] -> item
      _ -> nil
    end
  end

  defp item(_rule), do: nil

  # ── groups, as the leftovers' ───────────────────────────────────────

  @doc "A group's shape: the statement's pattern and the kinds misread."
  @spec shape(String.t(), [misread()]) :: String.t()
  def shape(pattern, misreads),
    do:
      pattern <>
        " | misread: " <>
        (misreads
         |> Enum.map(&to_string(&1.kind))
         |> Enum.uniq()
         |> Enum.sort()
         |> Enum.join("+"))

  @doc """
  Adds one statement's misreads to `groups` under its shape
  (`Leftovers.add/6`); the provisions simply not held are never grouped.
  """
  @spec add(map(), String.t(), String.t(), String.t(), [misread()], integer()) :: map()
  def add(groups, pattern, law, row, misreads, reach) do
    wrong = without(misreads, [:not_held])
    Leftovers.add(groups, shape(pattern, wrong), law, row, wrong, reach)
  end

  @doc """
  The misreads without the kinds in `skip` (a law whose rows are no
  measure: `:no_row`, and with it the provisions not held).
  """
  @spec without([misread()], [kind()]) :: [misread()]
  def without(misreads, skip) do
    skip = if :no_row in skip, do: [:not_held | skip], else: skip
    Enum.reject(misreads, &(&1.kind in skip))
  end

  @doc "How many refs of `misreads` the law holds no row for with no sign of a misnaming."
  @spec not_held([misread()]) :: non_neg_integer()
  def not_held(misreads), do: Enum.count(misreads, &(&1.kind == :not_held))

  @doc "The line a catalogue prints for the `count` of them."
  @spec not_held_line(non_neg_integer()) :: String.t()
  def not_held_line(count), do: "no row, not misnamed: #{count}"

  @doc "The summary a catalogue prints: the groups, the widest `n` with their review status, those with none."
  @spec summary([{String.t(), integer(), map()}], map(), integer()) :: [String.t()]
  def summary(ranked, reviewed, n \\ 30) do
    statements = ranked |> Enum.map(&elem(&1, 2).count) |> Enum.sum()
    unreviewed = Enum.count(ranked, fn {shape, _, _} -> not Map.has_key?(reviewed, shape) end)

    [
      "\nmisreads by shape (words a rule uses wrongly): #{length(ranked)} groups, #{statements} statements"
    ] ++
      for(
        {shape, reach, g} <- Enum.take(ranked, n),
        do: "  #{reach} reach, #{g.count}: #{shape} [#{Map.get(reviewed, shape, "no status")}]"
      ) ++ ["misread groups with no status: #{unreviewed}"]
  end

  defp scope_refs(rules),
    do: rules |> Enum.flat_map(&List.wrap(if is_list(&1.scope), do: &1.scope)) |> spread()

  defp partial_refs(rules), do: rules |> Enum.reject(&Rule.full?/1) |> scope_refs()
  defp whole_refs(rules), do: rules |> Enum.filter(&(&1.purposes == nil)) |> scope_refs()

  # a range's two ends
  defp spread(refs), do: refs |> Enum.flat_map(&String.split(&1, "..")) |> Enum.uniq()
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()
end

defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Lists do
  @moduledoc """
  The lists an extent clause states (CV-S05; decomposed from
  `AmendingLaw.Extent`, run time 2026-10-25): headed lists ("The following
  extend also to Scotland— …"), the provisions excepted from a default
  ("This Act, except— …, does not extend to Northern Ireland"; "… with the
  exception of— …"; "Only the following provisions … extend to …"), and a
  Part that does not extend ("Part III, except section 75 …"). Each list is
  `{kind, place, refs}`. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, Parts, Places, Units}

  @type list_entry :: {atom(), String.t() | nil, [String.t()]}

  @place_list Places.place_list()
  # a qualified aside: with the number it qualifies ("370 (so far as
  # relating to section 374)"), or alone where it adds one ("Schedule 2
  # (and article 26 so far as relating to it)")
  @qualified_aside ~r/(?:\b\d+[A-Z]*(?:\(\w+\))*\s*(?=\(\s*(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b))?\([^()]*\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b[^()]*\)/iu

  # an item led by its qualifier ("b in so far as relating to …, section 52")
  @leading_qualifier ~r/^\s*(?:and\s*)?(?:\(?[a-z]{1,2}\)?\s+)?(?:in\s+so\s+far|so\s+far|insofar|to\s+the\s+extent)\b/iu

  @qualifier_object ~r/\b(?:in\s+)?so\s+far\s+as\s+(?:it\s+|they\s+)?(?:relat(?:es?|ing)|appl(?:ies|y|ying)|ha(?:s|ve)\s+effect)\b[^,;—–]*/iu

  @amending_not_so ~r/\bany\s+provision\s+(?:of\s+this\s+Act\s+)?(?:amending|repealing|which\s+(?:amends|repeals))\b[^;]*?\benactments?\s+which\s+(?:does|do)\s+not\s+(?:so\s+)?extend\b/iu

  # "… apart from sections 82 and 83, does not extend to Northern
  # Ireland": those extend there too
  @doc "Those excepted from a clause's \"does not extend\" (\"This Act, except— …\", \"apart from …\"): they extend there too."
  @spec apart(String.t(), String.t() | nil, Doc.t()) :: [list_entry()]
  def apart(clause, clause_ref, doc) do
    case Regex.named_captures(Forms.except_list(), clause) do
      # each item; one "so far as may be necessary …" is limited to a
      # purpose and doesn't carry its provisions there (HSWA s.84(1)(a));
      # "except this section and …": the clause's own provision too
      %{"items" => items, "places" => place, "self" => self} ->
        refs =
          for item <- String.split(items, ";"),
              not (item =~ ~r/\bso\s+(?:far|much)\s+(?:as|of)\b/i),
              ref <- RefList.parse(item, clause_ref) ++ Parts.parts(item, doc, clause_ref),
              do: ref

        refs = if self != "" and clause_ref, do: [clause_ref | refs], else: refs
        if refs != [], do: [{:also, Places.places(place), Enum.uniq(refs)}], else: []

      nil ->
        case Regex.run(Forms.not_extends(), clause) do
          [_, except, _, place] when except != "" ->
            # (an item not parsed, "section seventy-seven", gives none:
            # Factories Act 1961 s.185(3), CV-S05 round 4 N-E)
            case RefList.parse(except, clause_ref) do
              [] -> []
              refs -> [{:also, Places.places(place), refs}]
            end

          _ ->
            []
        end
    end
  end

  # "Part III, except section 75 and Schedule 7, does not extend to
  # Scotland", in any provision (SENDA 2001 s.43(12): CV-S05 E)
  @doc "\"Part III, except section 75 …, does not extend to Scotland\", in any top-level provision of `sections`."
  @spec part_not([{String.t(), String.t()}], Doc.t()) :: [list_entry()]
  def part_not(sections, doc) do
    for {ref, text} <- sections,
        not String.contains?(ref, "("),
        not String.starts_with?(ref, "sch."),
        [_, part, except, place] <- Regex.scan(Forms.part_not(), text),
        refs = Parts.parts(part, doc, ref) -- RefList.parse(except || "", ref),
        refs != [],
        uniq: true,
        do: {:not, Places.places(place), refs}
  end

  @doc "The Parts and provisions excepted from \"This Act shall extend to Northern Ireland with the exception of— …\"."
  @spec extends_except(String.t(), String.t() | nil, Doc.t()) :: [list_entry()]
  def extends_except(clause, clause_ref, doc) do
    case Regex.named_captures(Forms.extends_except(), clause) do
      nil ->
        []

      m ->
        refs =
          for item <- String.split(m["list"], ";"),
              not Regex.match?(
                ~r/\b(?:so\s+far|in\s+so\s+far|any\s+(?:other\s+)?provision|which|except)\b/iu,
                item
              ),
              ref <- RefList.parse(item, clause_ref) ++ Parts.parts(item, doc, clause_ref),
              do: ref

        # (b) "any provision amending or repealing an enactment which does
        # not so extend": the law's amendments go where the enactment does
        # (CPA 1987 s.49(1)(b), CV-S05 round 8 NEW-3)
        same =
          if m["list"] =~ @amending_not_so, do: [{:same, nil, ["*"]}], else: []

        if(refs == [], do: [], else: [{:not, Places.places(m["places"]), Enum.uniq(refs)}]) ++
          same
    end
  end

  # the items of "Only the following provisions … extend to X, namely— …",
  # each not qualified, and the clause itself where it says so
  @doc "The items of \"Only the following provisions … extend to X, namely— …\"."
  @spec only_following(String.t(), String.t() | nil, Doc.t()) :: [list_entry()]
  def only_following(clause, clause_ref, doc) do
    case Regex.named_captures(Forms.only_following(), Units.no_dots(clause)) do
      nil ->
        []

      m ->
        refs =
          for item <- String.split(m["list"], ";"),
              not Regex.match?(
                ~r/\b(?:so\s+far|in\s+so\s+far|insofar|except|to\s+the\s+extent)\b/iu,
                item
              ),
              ref <- RefList.parse(item, clause_ref) ++ Parts.parts(item, doc, clause_ref),
              do: ref

        refs = if m["self"] != "", do: [clause_ref | refs], else: refs
        if refs == [], do: [], else: [{:also, Places.places(m["places"]), Enum.uniq(refs)}]
    end
  end

  # each list: "The following extend also to Scotland— …", "… to Scotland
  # only— …", "… have the same extent as the enactments to which they
  # relate— …", up to the next such heading

  # the clause's lists, then any other provision's (uksi 2019/696: the
  # clause in reg.2, "The following provisions extend to the United
  # Kingdom— …" in reg.3; CV-S05 J)
  @doc "The clause's headed lists, then any other top-level provision's."
  @spec headed_lists([{String.t(), String.t()}], String.t() | nil, String.t(), Doc.t()) :: [
          list_entry()
        ]
  def headed_lists(sections, clause_ref, clause, doc) do
    others =
      for {ref, text} <- sections,
          ref != clause_ref,
          not String.contains?(ref, "("),
          not String.starts_with?(ref, "sch."),
          Regex.match?(Forms.heading(), text),
          list <- lists(text, ref, doc),
          do: list

    Enum.uniq(lists(clause, clause_ref, doc) ++ others)
  end

  @doc "Each headed list in `clause` (\"The following extend also to Scotland— …\")."
  @spec lists(String.t(), String.t() | nil, Doc.t()) :: [list_entry()]
  def lists(clause, clause_ref, doc) do
    parts = Regex.split(Forms.heading(), clause, include_captures: true, trim: true)

    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [head, body] ->
      case Regex.run(Forms.heading(), head) do
        nil ->
          []

        match ->
          {body, excepted} = item_exceptions(own_list(cut(body)), clause_ref, doc)
          {body, qualified} = qualified_items(body, clause_ref, doc)

          self = if head =~ ~r/^\s*This\s+\w+\s+and\b/iu, do: [clause_ref], else: []

          case self ++ list_refs(body, clause_ref, doc) do
            [] ->
              []

            refs ->
              [{kind(match), place(match), refs}] ++
                if(excepted != [], do: [{:except, place(match), excepted}], else: []) ++
                if(qualified != [], do: [{:unread, nil, qualified}], else: [])
          end
      end
    end)
  end

  # (no "also" or "only": widens a default, else decides — `:named`,
  # "The following provisions of these Regulations extend to England and
  # Wales— …" with no default: SI 2025/361, CV-S05)
  @doc "A list heading's kind, from its match."
  @spec kind([String.t()]) :: :same | :not | :only | :also | :named
  def kind([whole | _]) do
    cond do
      whole =~ ~r/same extent/i -> :same
      whole =~ ~r/\bnot\s+extend/i -> :not
      whole =~ ~r/\bonly\b/i -> :only
      whole =~ ~r/\balso\b/i -> :also
      true -> :named
    end
  end

  # a list inside an enumerated item ("In this Act— … b the following
  # provisions extend to Northern Ireland namely— sections 38 to 40, …;c
  # section 31 …"): a body not starting with its own labels ends at the
  # parent's next one (1977/45 s.65(10): CV-S05 N3)
  defp own_list(body) do
    if body =~ ~r/^\s*\(?[a-z]\)?\s/u,
      do: body,
      else: body |> String.split(~r/;\s*(?:and\s+)?\(?[a-z]\)?\s+(?=[A-Za-z])/u, parts: 2) |> hd()
  end

  @doc "A list heading's place, from its match; nil for \"the same extent\"."
  @spec place([String.t()]) :: String.t() | nil
  def place([whole | _]) do
    case Regex.run(~r/\bextends?\s+(?:also\s+)?to (#{@place_list})/iu, whole) do
      [_, list] -> Places.places(list)
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

  # a list's items, each read plainly: never a qualified item ("so far as
  # …"), another law's provisions ("… of the Prison Act 1952"), nor a
  # subsection "of this section" (1977/45 s.65(10): CV-S05 N3)
  # (a bare Chapter takes the Part named before it, before the split:
  # "in Part 2— (i) Chapter 1 …"; an item's bracketed exception taken out
  # of it, "Chapter 1 of Part 3 (except section 84)": CV-S05 NEW-A)
  defp list_refs(text, clause_ref, doc, plain? \\ true) do
    for item <-
          text
          |> Parts.qualify_chapters()
          |> Units.no_dots()
          |> String.split(
            ~r/;|,\s*(?=(?:and\s+)?(?:[a-z]|[ivx]{2,4})\s)|,\s*(?=(?:and\s+)?(?:sections?|subsections?|Schedules?|in\s+Schedule|Parts?|paragraphs?\s+[^,;]*?\bof\s+Schedule|regulations?|articles?)\b)/u
          )
          |> own_items(),
        # (a qualified aside is no part of the item, nor what it qualifies:
        # "370 (so far as relating to section 374), 374": 1975/21
        # s.463(1)(b), round 7 NEW-2)
        item = String.replace(item, @qualified_aside, " "),
        {item, minus} = bracketed_except(item, clause_ref),
        # (a locator is no item: "and in section 47, subsection (1) in so
        # far as …": ukpga 1993/9 s.48, round 8)
        not Regex.match?(
          ~r/^\s*(?:and\s+)?in\s+(?:section|regulation|article)\s+\S+\s*$/iu,
          item
        ),
        not plain? or
          not Regex.match?(
            # (a description is some of a Chapter, never all: "the service
            # courts provisions of Chapter 2 of Part 3", CJA 2009 s.181(2)(b))
            ~r/\bthe\s+(?:[\w-]+\s+){1,3}provisions\s+of\s+(?:Chapter|Part)\b|\b(?:so\s+far\s+as|in\s+so\s+far|insofar|except|exception|so\s+much\s+of|to\s+the\s+extent|of\s+this\s+section|(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4})\b/u,
            item
          ),
        # (a qualified item's own provisions, never another law's)
        plain? or
          not Regex.match?(
            ~r/(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4}/u,
            item
          ),
        ref <- RefList.parse(item, clause_ref) ++ Parts.parts(item, doc, clause_ref),
        ref not in minus,
        uniq: true,
        do: ref
  end

  # the items, without one qualified by a sub-list of what it relates to
  # and that sub-list ("d in Schedule 9, the amendments relating to— i …;
  # ii the Criminal Justice Act 1961; …": 1975/21 s.463(1)(d), (e), round
  # 7 NEW-2; its sub-items named another Act's sections)
  defp own_items(items) do
    items
    |> Enum.map_reduce(false, fn item, skipping ->
      sub? = item =~ ~r/^\s*(?:and\s*)?[ivx]{1,4}\s/u

      cond do
        item =~ ~r/\brelating\s+to\s*[—–]/u -> {nil, true}
        skipping and sub? -> {nil, true}
        true -> {item, false}
      end
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
  end

  # an item's own exceptions, a sub-list ("c Part 5 and its related
  # schedules, except— i paragraphs 29 to 40 of Schedule 34 …; ii …; d
  # Part 6": uksi 2019/696 reg.3, CV-S05): the item kept, its sub-items
  # taken out as the provisions excepted (`{:except, place, refs}`: they
  # keep the default, `Extent.read/1`)
  defp item_exceptions(body, clause_ref, doc) do
    case Regex.run(
           ~r/,?\s*except\s*[—–]\s*((?:i|[ivx]{2,4})\s.*?)(?=;\s*(?:and\s*)?\(?[a-hj-uw-z]\)?\s+(?=[A-Z])|$)/u,
           body
         ) do
      [whole, sub] ->
        {String.replace(body, whole, ""), list_refs(sub, clause_ref, doc)}

      nil ->
        {body, []}
    end
  end

  # the items led by a qualifier ("b in so far as relating to
  # sections 26 to 27A of the Fire Services Act 1947, section 52"; "c in so
  # far as relating to— i …, iv the Superannuation Act 1972, section 53(1)
  # and Schedule 1": FRSA 2004 s.63(2), CV-S05 round 9): out of the list,
  # their provisions' bound withheld (`:unread`), never read whole
  defp qualified_items(body, clause_ref, doc) do
    {qualified, plain} =
      body
      # (a letter after a comma, never a roman sub-item: "…, v the Superannuation Act 1972")
      |> String.split(~r/;|,\s*(?=(?:and\s*)?[a-hj-uwyz]\s)/u)
      |> Enum.split_with(&String.match?(&1, @leading_qualifier))

    # (the qualifier's object is no item: "subsection (1) in so far as
    # relating to Schedule 5", ukpga 1993/9 s.48)
    refs =
      if qualified == [],
        do: [],
        else:
          qualified
          |> Enum.join(";")
          |> String.replace(@qualifier_object, " ")
          |> list_refs(clause_ref, doc, false)

    {Enum.join(plain, ";"), refs}
  end

  # "Chapter 1 of Part 3 (except section 84)": the item without its
  # exception, and the provisions excepted
  defp bracketed_except(item, clause_ref) do
    case Regex.run(~r/\s*\((?:except|other\s+than|excluding)\s+([^()]*)\)/u, item) do
      [whole, except] -> {String.replace(item, whole, ""), RefList.parse(except, clause_ref)}
      nil -> {item, []}
    end
  end
end

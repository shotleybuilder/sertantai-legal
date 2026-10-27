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

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{
    ExceptionList,
    Forms,
    ItemExceptions,
    ListItems,
    Parts,
    Places,
    Units
  }

  @type list_entry :: {atom(), String.t() | nil, [String.t()]}

  @place_list Places.place_list()
  @amending_not_so ~r/\bany\s+provision\s+(?:of\s+this\s+Act\s+)?(?:amending|repealing|which\s+(?:amends|repeals))\b[^;]*?\benactments?\s+which\s+(?:does|do)\s+not\s+(?:so\s+)?extend\b/iu

  # "… apart from sections 82 and 83, does not extend to Northern
  # Ireland": those extend there too
  @doc "Those excepted from a clause's \"does not extend\" (\"This Act, except— …\", \"apart from …\"): they extend there too."
  @spec apart(String.t(), String.t() | nil, Doc.t()) :: [list_entry()]
  def apart(clause, clause_ref, doc) do
    # every exception-list wording, each item read plainly; a qualified one
    # keeps the default (HSWA s.84(1)(a)): `ExceptionList`, round 13 S1
    case ExceptionList.statements(clause) do
      [_ | _] ->
        ExceptionList.lists(clause, clause_ref, doc)

      [] ->
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
        items =
          for item <- String.split(m["list"], ";"),
              not Regex.match?(
                ~r/\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b/iu,
                item
              ),
              do: item

        # (an item with its own exception, "section 153 except subsection
        # (1)(k) and (m)": read as a list item, the provision holding the
        # exception withheld; ukpga 1990/43 s.164, CV-S05 census run-05 R3)
        {own_except, plain} = Enum.split_with(items, &(&1 =~ ~r/\bexcept\b/iu))
        r = ListItems.read(Enum.join(own_except, "; "), clause_ref, doc)

        refs =
          for(
            item <- plain,
            ref <- RefList.parse(item, clause_ref) ++ Parts.parts(item, doc, clause_ref),
            do: ref
          ) ++ r.refs

        refs = if m["self"] != "", do: [clause_ref | refs], else: refs

        if(refs == [], do: [], else: [{:also, Places.places(m["places"]), Enum.uniq(refs)}]) ++
          if(r.unread != [], do: [{:unread, nil, r.unread}], else: [])
    end
  end

  # a list whose verb comes after it: "Subject to subsection (6) below, the
  # following provisions of this Act— (a) sections 3, 4 and 6; (b) …,
  # extend to England and Wales only" (ukpga 1982/53 s.77); "The following
  # provisions of this Act, namely— sections 39, 40 …; and Part III, do not
  # extend to Scotland" (1981/69 s.74): round 13 S6
  @late ~r/(?:^|[.;]\s+|,\s*)(?:Subject\s+to\s+[^,—–]{1,80},\s*)?the\s+following\s+provisions\s+of\s+this\s+(?:Act|Order|Part)\s*,?\s*(?:namely|that\s+is\s+to\s+say)?\s*,?\s*[—–:]\s*(?<items>[^.]+?),?\s*(?:shall\s+)?(?<not>(?:do|does|shall)\s+not\s+)?extend\s+(?<also>also\s+)?to\s+(?<places>(?>#{@place_list}))(?<only>\s+only)?/iu

  @doc "The \"the following provisions …— (a) …, extend to P\" form."
  @spec late() :: Regex.t()
  def late, do: @late

  @doc "The kind of a late-verb list from its match."
  @spec late_kind(map()) :: :not | :only | :also | :named
  def late_kind(m) do
    cond do
      m["not"] != "" -> :not
      m["only"] != "" -> :only
      m["also"] != "" -> :also
      true -> :named
    end
  end

  @doc "Each top-level provision's late-verb lists, its qualified items withheld."
  @spec late_lists([{String.t(), String.t()}], Doc.t()) :: [list_entry()]
  def late_lists(sections, doc) do
    for {ref, text} <- sections,
        not String.contains?(ref, "("),
        m <- for(m <- Regex.scan(@late, text, capture: :all_names), do: named(m)),
        r = ListItems.read(m["items"], ref, doc),
        list <-
          if(r.refs != [], do: [{late_kind(m), Places.places(m["places"]), r.refs}], else: []) ++
            if(r.unread != [], do: [{:unread, nil, r.unread}], else: []),
        uniq: true,
        do: list
  end

  # (capture: :all_names gives the names in order)
  defp named([also, items, not_, only, places]),
    do: %{"also" => also, "items" => items, "not" => not_, "only" => only, "places" => places}

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
          {body, sub_excepted} = item_exceptions(own_list(cut(body)), clause_ref, doc)
          r = ListItems.read(body, clause_ref, doc)
          excepted = Enum.uniq(sub_excepted ++ r.excepted)

          self =
            if head =~ ~r/^\s*This\s+\w+\s*,?\s+and\b|\(together\s+with\s+this\s+section\)/iu,
              do: [clause_ref],
              else: []

          # (an excepted provision is never also in the list: "this Part,
          # except— i sections 82 and 83 …", ukpga 2000/19 s.87, round 11;
          # one only some of which is excepted is withheld)
          {refs, partly} =
            (self ++ r.refs)
            |> Enum.reject(&(ItemExceptions.touched?(&1, excepted) == :excepted))
            |> Enum.split_with(&(ItemExceptions.touched?(&1, excepted) == false))

          unread = Enum.uniq(r.unread ++ partly)

          if(refs == [], do: [], else: [{kind(match), place(match), refs}]) ++
            if(excepted != [] and refs != [], do: [{:except, place(match), excepted}], else: []) ++
            if(unread != [], do: [{:unread, nil, unread}], else: [])
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
      whole =~ ~r/\bonly\b(?!\s+of\b)/i -> :only
      whole =~ ~r/\balso\b/i -> :also
      true -> :named
    end
  end

  # a list inside an enumerated item ("In this Act— … b the following
  # provisions extend to Northern Ireland namely— sections 38 to 40, …;c
  # section 31 …"): a body not starting with its own labels ends at the
  # parent's next one (1977/45 s.65(10): CV-S05 N3)
  defp own_list(body) do
    if body =~ ~r/^\s*[—–:]?\s*\(?z?[a-z]\d{0,2}\)?\s/u,
      do: body,
      else: body |> String.split(~r/;\s*(?:and\s+)?\(?[a-z]\)?\s+(?=[A-Za-z])/u, parts: 2) |> hd()
  end

  @doc "A list heading's place, from its match; nil for \"the same extent\"."
  @spec place([String.t()]) :: String.t() | nil
  def place([whole | _]) do
    case Regex.run(
           ~r/\bextends?\s+(?:also\s+)?to (?:the\s+whole\s+of\s+)?(#{@place_list})/iu,
           whole
         ) do
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
        {String.replace(body, whole, ""), ListItems.refs(sub, clause_ref, doc)}

      nil ->
        {body, []}
    end
  end
end

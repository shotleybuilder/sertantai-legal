defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Same do
  @moduledoc """
  Provisions having the same extent as the enactments they change (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): "The
  amendments and repeals in Schedules 20 and 21 have the same extent as the
  enactments to which they refer" → `{:same, nil, ["sch.20", "sch.21"]}`;
  "… made by this Act" → `["*"]`; with the exceptions stated after it, or
  `:unread` where they don't read plainly. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{
    Forms,
    ItemExceptions,
    ListItems,
    Named,
    Parts,
    Places
  }

  @place_list Places.place_list()

  # "Sections 240 and 242 and Schedules 1 and 3 have the same extent as the
  # provisions amended" (1996/18 s.244(4): CV-S05)
  @named_same ~r/^(?:\(\w+\)\s*)?(?<subj>(?:Sections?|Schedules?|Parts?|paragraphs?|regulations?|articles?)\s+[\dIVXL][^.;:—–]*?)\s+(?:has|have|shall\s+have)\s+the\s+same\s+extent\s+(?:within\s+the\s+United\s+Kingdom\s+)?as\s+the\s+(?:enactments?|provisions?)\s+(?:amended|repealed|revoked|modified|to\s+which\s+(?:it|they)\s+relates?|which\s+(?:it|they)\s+amends?(?:\s+or\s+repeals?)?)\b/iu

  # "This Act does not extend to Northern Ireland except so far as it
  # affects other enactments extending to Northern Ireland" (1988/54,
  # 1989/13, 1997/11): the default stands, and every amendment the law
  # makes follows the enactment it changes (CV-S05)
  # "Any amendment or repeal by this Act of an enactment which extends to
  # Scotland or Northern Ireland has the same extent as that enactment but,
  # save as aforesaid, this Act extends to England and Wales only" (LGA 1985
  # s.106(2), CV-S05 round 8 NEW-6): the default stands, and every
  # amendment follows its enactment (one extending no further has effect no
  # further)
  @of_enactment_same ~r/^(?:\(\w+\)\s*)?Any\s+(?:amendments?|repeals?|revocations?)(?:\s*(?:,|or|and)\s*(?:amendments?|repeals?|revocations?))*\s+(?:made\s+)?by\s+this\s+(?:Act|Order|Regulations)\s+of\s+(?:an|any)\s+enactments?\s+which\s+extends?\s+to\s+[^.]*?\bha(?:s|ve)\s+the\s+same\s+extent\s+as\s+(?:that|the)\s+enactments?\b/iu

  @not_extends_amending ~r/\bnot\s+extend\s+to\s+[^.]*?\bexcept\b[^.]*?\bso\s+far\s+as\s+(?:it|they)\s+(?:affects?|amends?|repeals?|revokes?)\s+(?:any\s+)?(?:other\s+)?enactments?\b/iu

  # "The amendments and repeals in Schedules 20 and 21 have the same extent
  # as the enactments to which they refer" → {:same, nil, ["sch.20",
  # "sch.21"]}; "… made by this Act / Order" (or none named) → ["*"]
  # (never with exceptions after it: "…, except that nothing extends to
  # Northern Ireland"; "made by the following provisions— (a) section 10;
  # …": those listed)
  @doc """
  The provisions with the same extent as the enactments they change, from
  the unit sentences (`Units.unit_sentences/1`): `{:same, nil, refs}` ("*"
  for every amendment the law makes), with any list its exceptions state.
  """
  @spec amendments_same([{String.t(), String.t()}], Doc.t()) :: [
          {atom(), String.t() | nil, [String.t()]}
        ]
  def amendments_same(unit_sentences, doc) do
    for(
      {ref, s} <- unit_sentences,
      form <- [Forms.amendments_same(), Forms.extent_of_same()],
      m = Regex.named_captures(form, s),
      m != nil,
      [_, tail] <- [Regex.split(form, s, parts: 2)],
      # (a subject with its own exception, read less it: "an amendment or
      # repeal made by Part 1, other than the amendment made by section
      # 17(7), has the same extent as …", ukpga 2015/7 s.56(2)(b), round
      # 12; never one not read)
      {subj, excepted} = subject_except(m["subj"], ref),
      excepted != :unread,
      refs = same_refs(that_schedule(subj, ref, unit_sentences), tail, ref, doc),
      refs != :none,
      refs = apart(refs, excepted),
      refs != [],
      list <- same_lists(refs, tail, ref),
      uniq: true,
      do: list
    ) ++
      for(
        {_ref, s} <- unit_sentences,
        Regex.match?(Forms.amendments_where(), s) or Regex.match?(@not_extends_amending, s) or
          Regex.match?(@of_enactment_same, s),
        uniq: true,
        do: {:same, nil, ["*"]}
      ) ++
      also_there(unit_sentences, doc) ++
      for {ref, s} <- unit_sentences,
          m = Regex.named_captures(@named_same, s),
          m != nil,
          not Regex.match?(Named.excepted(), m["subj"]),
          # (a qualified piece withheld, the plain read: "paragraphs 1 and 14
          # of the Schedule, and article 3 in so far as it relates to those
          # paragraphs, have the same extent as …", SI 2005/2060 art.1(4))
          r = ListItems.read(m["subj"], ref, doc),
          list <-
            if(r.refs != [], do: [{:same, nil, r.refs}], else: []) ++
              if(r.unread != [], do: [{:unread, nil, r.unread}], else: []),
          uniq: true,
          do: list
  end

  # amendments that "also extend there" (CV-S05 round 7, from the sweep):
  # "The amendment by this Act of any enactment extending to Northern
  # Ireland also extends there" (ukpga 1999/24 s.7) → every amendment the
  # law makes follows the enactment; "Regulations 6 and 7 also extend to
  # any place (except Scotland) to which the enactments they amend extend"
  # (SI 2007/1843 reg.3) → those, or unread with an exception
  @also_there ~r/^(?:\(\w+\)\s*)?The\s+(?:amendments?|repeals?|revocations?)\b[^.]*?\bby\s+this\s+(?:Act|Order|Regulations)\s+of\s+any\s+enactments?\s+extending\s+to\s+[^.]*?\balso\s+extends?\s+there\b/iu
  @also_any_place ~r/^(?:\(\w+\)\s*)?(?<subj>(?:Sections?|Regulations?|Articles?|Schedules?|Parts?)\s+[\dIVXL][^.;]*?)\s+also\s+extends?\s+to\s+any\s+place\s*(?<except>\(\s*except[^)]*\))?\s+to\s+which\s+the\s+enactments?\b/iu

  @doc "The `@named_same` form: \"Sections 240 and 242 have the same extent as the provisions amended\"."
  @spec named_same() :: Regex.t()
  def named_same, do: @named_same

  @doc "Whether a sentence says amendments \"also extend there\" (`@also_there`, `@also_any_place`)."
  @spec also_there?(String.t()) :: boolean()
  def also_there?(s), do: Regex.match?(@also_there, s) or Regex.match?(@also_any_place, s)

  defp also_there(unit_sentences, doc) do
    for {ref, s} <- unit_sentences, list <- also_there(s, ref, doc), uniq: true, do: list
  end

  defp also_there(s, ref, doc) do
    cond do
      Regex.match?(@also_there, s) ->
        [{:same, nil, ["*"]}]

      m = Regex.named_captures(@also_any_place, s) ->
        case Enum.uniq(RefList.parse(m["subj"], ref) ++ Parts.parts(m["subj"], doc, ref)) do
          [] -> []
          refs -> [{if(m["except"] != "", do: :unread, else: :same), nil, refs}]
        end

      true ->
        []
    end
  end

  # the same extent, with its exceptions: none → same; "except that the
  # amendments made by paragraphs 11 to 13 of that Schedule extend to
  # Scotland only" → same, and those paragraphs only there; any other
  # exception → the provisions' extent is unknown (`:unread`), never the
  # default (SI 2014/469 art.3(5): CV-S05 round 3 E)
  defp same_lists(refs, tail, ref) do
    cond do
      not Regex.match?(~r/^[^—–]*?\b(?:except|save|but)\b/iu, tail) ->
        [{:same, nil, refs}]

      (m =
         Regex.named_captures(
           ~r/^(?:\s+(?:which|to\s+which|being)\b[^,;—–]*)?\s*,?\s*except\s+that\s+the\s+(?:amendments?|modifications?|repeals?|revocations?)\s+(?:made\s+by|specified\s+in)\s+(?<paras>paragraphs?\s+[^,;:—–]+?)\s+of\s+(?:that\s+Schedule|Schedule\s+\d+[A-Z]*)\s+(?:shall\s+)?(?<not>do\s+not\s+)?extends?\s+to\s+(?<places>(?>#{@place_list}))(?<only>\s+only)?\s*\.?\s*$/iu,
           tail
         )) && match?([<<"sch.", _::binary>>], refs) ->
        [sch] = refs
        n = String.replace_prefix(sch, "sch.", "")
        paras = RefList.parse("#{m["paras"]} of Schedule #{n}", ref)
        kind = if m["not"] != "", do: :not, else: :only

        if paras == [],
          do: [{:unread, nil, refs}],
          else: [{:same, nil, refs}, {kind, Places.places(m["places"]), paras}]

      true ->
        [{:unread, nil, refs}]
    end
  end

  # "any repeal in that Schedule" (ukpga 1994/40 s.81): the Schedule the
  # provision named last before it
  defp that_schedule(subj, ref, unit_sentences) do
    if subj =~ ~r/\bthat\s+Schedule\b/u do
      named =
        for {^ref, s} <- unit_sentences,
            [_, n] <- Regex.scan(~r/\bSchedule\s+(\d+[A-Z]*)\b/u, s),
            do: n

      case named do
        [] -> subj
        _ -> String.replace(subj, ~r/\bthat\s+Schedule\b/u, "Schedule #{List.last(named)}")
      end
    else
      subj
    end
  end

  defp same_refs(subj, tail, ref, doc) do
    # "made by the provisions in Parts 2 and 3": those Parts (uksi
    # 2023/1071 reg.1(2): CV-S05 round 4 N-A)
    subj = Regex.replace(~r/\bprovisions\s+(?:in|of)\s+(?=Parts?\s+[\dIVXL])/iu, subj, "")

    cond do
      subj =~ ~r/\bfollowing\b/i ->
        # (each item read as a list's: its Parts and Chapters, less its
        # own exception, "Part 2 (…), other than paragraph 2 of Schedule
        # 4": ukpga 2009/23 s.323(2), CV-S05 round 11)
        case tail |> String.split(~r/[—–:]/u, parts: 2) do
          [_, list] -> with([] <- ListItems.refs(list, ref, doc), do: :none)
          _ -> :none
        end

      # "made by Parts 4, 5 and 6", "made by regulations 3, 4, 6": those
      # (CV-S05 N13); a subject naming provisions not read is no "*"
      subj =~
          ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\s+[\dIVXL]/i ->
        case Enum.uniq(RefList.parse(subj, ref) ++ Parts.parts(subj, doc, ref)) do
          [] -> :none
          refs -> refs
        end

      true ->
        ["*"]
    end
  end

  # a subject and what it excepts from itself: none, the provisions, or
  # `:unread` where the exception names none
  defp subject_except(subj, ref) do
    case ItemExceptions.split(subj) do
      {_, nil, _, _} ->
        if subj =~ ~r/\b(?:other\s+than|apart\s+from|except|save|excluding)\b/iu,
          do: {subj, :unread},
          else: {subj, []}

      # (an exception in another law's provisions names none of this
      # law's: "apart from the repeal of sections 4 and 6 of the
      # Promissory Oaths Act 1868", ukpga 2002/26 s.91)
      {main, ex, _, _} ->
        case not (ex =~ ~r/\b(?:of|to)\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\b/u) &&
               RefList.parse(ex, ref) do
          excepted when is_list(excepted) and excepted != [] -> {main, excepted}
          _ -> {subj, :unread}
        end
    end
  end

  # (one only some of which is excepted is no longer the same whole)
  defp apart(["*"], _), do: ["*"]
  defp apart(refs, []), do: refs
  defp apart(refs, excepted), do: refs |> ItemExceptions.apart(excepted) |> elem(0)
end

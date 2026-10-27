defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Named do
  @moduledoc """
  Named provisions' own extent, wherever the law states it (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): "Sections
  107 and 116A of this Act extend to Scotland only" → `{:only, "S",
  ["s.107", "s.116A"]}`, read only where stated plainly. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Asides, Forms, ListItems, Parts, Places}

  # named provisions' own extent, wherever stated: "Sections 107 and 116A of
  # this Act extend to Scotland only" → {:only, "S", ["s.107", "s.116A"]};
  # "… extend to Scotland" (no "only") widens a default (`:also`), else
  # it is where they extend (`:only`); "do not extend" → `:not`
  @doc "Named provisions' own extent, from the unit sentences (`Units.unit_sentences/1`)."
  @spec named([{String.t(), String.t()}], Doc.t()) :: [{atom(), String.t() | nil, [String.t()]}]
  def named(unit_sentences, doc) do
    for(
      {ref, s} <- unit_sentences,
      s = other_repeal_out(s),
      not Regex.match?(Forms.heading(), s),
      not Regex.match?(Forms.part_not(), s),
      m = Regex.named_captures(Forms.named(), s),
      m != nil,
      plain_named?(m, s),
      subj = described_out(m["subj"]),
      refs = Enum.uniq(RefList.parse(subj, ref) ++ Parts.parts(subj, doc, ref)),
      refs != [],
      do: {named_kind(m), Places.places(m["places"]), refs}
    ) ++
      excluding(unit_sentences, doc) ++
      qualified(unit_sentences, doc) ++ asides(unit_sentences, doc)
  end

  # "The repeal by this Act of section 14(1) of the Limitation Act 1963 and
  # the corresponding saving in paragraph 2 of Schedule 2 to this Act shall
  # extend to Northern Ireland": the saving its own provision, the repeal
  # another law's (ukpga 1980/58 s.41, CV-S05 census run-05 R11)
  defp other_repeal_out(s),
    do:
      Regex.replace(
        ~r/^\s*The\s+repeals?\s+by\s+this\s+Act\s+of\s+[^,;]*?\b(?:Act|Regulations|Order)\s+\d{4}\s+and\s+(?:the\s+corresponding\s+\w+\s+in\s+)?(?=(?:paragraphs?|sections?|Schedules?)\s)/iu,
        s,
        ""
      )

  # a plain statement's qualified aside withheld, never dropped: "Part 6
  # (including Schedule 13 so far as it relates to Part 6) extends to …"
  # (ukpga 2023/55 s.254, round 13 S4)
  defp asides(unit_sentences, doc) do
    for {ref, s} <- unit_sentences,
        m = Regex.named_captures(Forms.named(), s),
        m != nil,
        plain_named?(m, s),
        refs = Asides.asides(m["subj"], ref, doc),
        refs != [],
        uniq: true,
        do: {:unread, nil, refs}
  end

  # a subject with a qualified piece, plain without it ("Part III of this
  # Act, and Schedule 24 to this Act so far as relating to Part III,
  # extends to England and Wales only": Environment Act 1995 s.125(8),
  # round 12): its plain pieces read, the qualified withheld (`ListItems`)
  # (never across items: "This Act, except— (a) Part I … so far as may be
  # necessary …; and (b) …, does not extend to Northern Ireland", HSWA
  # s.84(1), is an exception list's item, not a statement)
  @qualified_clause ~r/,?\s*(?:(?:so\s+far|in\s+so\s+far|insofar)\s+as|to\s+the\s+extent\s+that)\s+[^,;—–]*,?/iu

  # (never an item split out of an exception list: "This Act,
  # except— … (d) Schedule 6 and section 17(5) so far as relating to …,
  # does not extend to Northern Ireland" is an exception list, 1995/45 s.18;
  # 1976/55 s.27)
  # an exception list's lead: "This Act, except— …", "Except for the
  # following provisions, namely— …"
  @exception_list ~r/^\s*(?:This\s+(?:Act|Order|Regulations)\s*,?\s+)?except\b|\bexcept\s+(?:for\s+)?(?:the\s+following\b[^—–]*)?[—–]/iu

  defp qualified(unit_sentences, doc) do
    # (or an item of a sentence ending in its "save as aforesaid" default:
    # "In this Act— (a) sections 23, 24, … and this section, … section 64(1)
    # and Schedule 5 so far as they relate to …, extend to Scotland; … but
    # save as aforesaid, this Act extends to England and Wales only", 1972/71
    # s.66, found by the census's default-sentence check, run-03)
    # (an item of any other lettered sentence is read: "In Part 5— … (b)
    # sections 30(2) to (4) … and section 34 so far as applying to Part 5
    # and section 37(6) extend to England and Wales only", 2015/7 s.56(6))
    whole =
      Enum.reject(unit_sentences, fn {ref, s} ->
        Enum.any?(unit_sentences, fn {r2, s2} ->
          r2 == ref and s2 != s and String.contains?(s2, s) and s2 =~ @exception_list
        end)
      end)

    for {ref, s} <- whole,
        not Regex.match?(Forms.heading(), s),
        not Regex.match?(Forms.part_not(), s),
        m = Regex.named_captures(Forms.named(), s),
        m != nil,
        m["subj"] =~ @qualified_clause,
        not plain_named?(m, s),
        plain_named?(%{m | "subj" => Regex.replace(@qualified_clause, m["subj"], " ")}, s),
        r = ListItems.read(described_out(m["subj"]), ref, doc),
        list <-
          if(r.refs != [], do: [{named_kind(m), Places.places(m["places"]), r.refs}], else: []) ++
            if(r.unread != [], do: [{:unread, nil, r.unread}], else: []),
        uniq: true,
        do: list
  end

  # "Part 2 (civil partnership: England and Wales), excluding section 35
  # but including Schedules 1 to 9, extends to England and Wales only"
  # (Civil Partnership Act 2004 s.262(1), CV-S05 round 10): the Part, less
  # what it excludes, with what it includes
  @excluding Regex.compile!(
               "^\\s*(?<main>(?:Parts?|Chapters?|Schedules?|Sections?)\\s+[^,;]+?)\\s*,\\s*excluding\\s+(?<ex>[^,;]+?)(?:\\s+but\\s+including\\s+(?<inc>[^,;]+?))?\\s*,\\s*(?:shall\\s+)?extends?\\s+(?<only>only\\s+)?to\\s+(?<places>(?>#{Places.place_list()}))(?<only2>\\s+only)?\\s*\\.?\\s*$",
               "u"
             )

  defp excluding(unit_sentences, doc) do
    for {ref, s} <- unit_sentences, l = excluding_list(s, ref, doc), l != nil, uniq: true, do: l
  end

  @doc "The list \"X, excluding A but including B, extends to P\" states, or nil."
  @spec excluding_list(String.t(), String.t(), Doc.t()) ::
          {atom(), String.t(), [String.t()]} | nil
  def excluding_list(s, ref, doc) do
    with %{} = m <- Regex.named_captures(@excluding, s),
         false <- Regex.match?(~r/\b(?:so\s+far|in\s+so\s+far|insofar|which|except)\b/iu, s),
         [_ | _] = ex <- RefList.parse(m["ex"], ref) ++ Parts.parts(m["ex"], doc, ref),
         inc = RefList.parse(m["inc"], ref) ++ Parts.parts(m["inc"], doc, ref),
         main = described_out(m["main"]),
         [_ | _] = refs <-
           Enum.reject(
             Enum.uniq(RefList.parse(main, ref) ++ Parts.parts(main, doc, ref)),
             fn r -> Enum.any?(ex, &(&1 == r or RefList.covers?(&1, r))) end
           ) do
      kind = if m["only"] != "" or m["only2"] != "", do: :only, else: :named
      {kind, Places.places(m["places"]), Enum.uniq(refs ++ inc)}
    else
      _ -> nil
    end
  end

  @doc """
  A subject without what describes it: a bracket that describes
  ("paragraph 25 (amendment to section 24A of the Nuclear Installations
  Act 1965 …)": Energy Act 2013 s.155(5)(a), CV-S05 NEW-C; "Section 114
  (power … under section 113)") or an "as amended by" aside ("Paragraphs
  9A, 9C and 10, as amended by the preceding provisions of this section,
  extend to …" are another Act's: ukpga 2013/22 s.27(13), round 7 NEW-1).
  A number in brackets is kept ("section 73(2)"), and so is a bracket
  naming provisions too ("Section 82 above (with Schedule 9)", "(and
  sections 236 and 243, this section and section 245)": round 8).
  """
  @spec described_out(String.t()) :: String.t()
  def described_out(subj) do
    # (a bracket naming provisions too goes after the subject, so the
    # numbers after it stay the list's: "sections 228, 229 (and Schedule
    # 22), 230, 233 to 236", ukpga 2023/55 s.254(12), round 13 S15)
    {subj, naming} =
      Regex.scan(~r/\((?=[^()]*\s)((?:[^()]|\([^()]*\))*)\)/u, subj)
      |> Enum.reduce({subj, []}, fn [whole, inner], {acc, naming} ->
        # (never a qualified one: "(and article 27 in so far as it relates
        # to those paragraphs)", SI 2013/602 art.1(8))
        if inner =~ ~r/^\s*(?:and|with|including|together\s+with)\b/iu and
             not (inner =~ ~r/\b(?:so\s+far|in\s*so\s*far|insofar|to\s+the\s+extent)\b/iu),
           do: {String.replace(acc, whole, " ", global: false), naming ++ [inner]},
           else: {String.replace(acc, whole, " ", global: false), naming}
      end)

    Enum.map_join([subj | naming], ", ", & &1)
    |> String.replace(~r/,?\s*as\s+(?:amended|inserted|substituted)\s+by\b[^,]*,?/iu, " ")
  end

  # read only as plainly stated: never another law's provisions ("… of that
  # Act shall continue to extend", "… the 1989 Act shall cease to extend"),
  # a mention ("so far as they extend to"), a subject with its own
  # exceptions ("excluding section 35"), nor a qualified or excepted extent
  # ("… so far as they amend—", "…, except that— …"): those stay unread
  # (CV-S05, counted in the catalogue)
  @named_not_plain ~r/\b(?:of|to),?\s+(?:that|the\s+\d{4}|the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)(?:\s+\d{4})?)\b(?!\s+(?:Act|Order)\s+(?:extends?|shall))|\b(?:continue|cease)s?\s+to\b|\bso\s+much\s+of\b|\bcorresponding\b|\btogether\s+with\b|\bas\s+relates?\b|\bso\s+far\s+as\b|\bin\s+so\s+far\b|\binsofar\b|\bto\s+the\s+extent\s+that\b|\bexcept\b|\bexcluding\b|\bother\s+than\b|\bapart\s+from\b|\bwhich\b|\bmay\b|\bunder\s+this\b|[;:—–]/iu
  @named_tail ~r/^\s*[,(]?\s*(?:but\s+only\s+|only\s+)?(?:so\s+far\s+as|in\s+so\s+far\b|insofar\b|to\s+the\s+extent|for\s+the\s+purposes?|except|apart\s+from|other\s+than|excluding|in\s+relation\s+to|as\s+respects|subject\s+to)\b/iu
  @named_excepted ~r/\b(?:except|excluding|other\s+than|apart\s+from)\b/iu

  @doc "Whether `m` (`Forms.named/0`'s captures in `s`) is stated plainly."
  @spec plain_named?(map(), String.t()) :: boolean()
  def plain_named?(m, s) do
    # the words after the match (not after the first mention of its places:
    # "(environmental governance: Northern Ireland) extends to Northern
    # Ireland, except that—")
    tail =
      case Regex.run(Forms.named(), s, return: :index) do
        [{at, len} | _] -> binary_part(s, at + len, byte_size(s) - at - len)
        nil -> ""
      end

    # a description in brackets ("(amendments of the … Act 1974)") is no
    # other law's provision; an exception in brackets ("(except paragraph
    # 12)", "(other than sections 37 and 38)") still is an exception
    bare = String.replace(m["subj"], ~r/\((?:[^()]|\([^()]*\))*\)/u, "")

    # (a complement is no compound: ", but otherwise this Act extends
    # there"; "; but this Act does not otherwise so extend")
    String.length(m["subj"]) <= 250 and not Regex.match?(@named_not_plain, bare) and
      not Regex.match?(@named_excepted, m["subj"]) and not Regex.match?(@named_tail, tail) and
      not Regex.match?(
        ~r/\balso\s+extends?\b|[;,]\s*but\b(?!\s+(?:otherwise|the\s+other\s+provisions|this\s+Act\s+does\s+not\s+otherwise|not\s+otherwise)|\s*,\s*with\s+the\s+exception\s+of\s+th(?:ose|ese)\s+provisions\s*,)/iu,
        tail
      )
  end

  @doc "The list kind of a named statement: `:not`, `:only`, `:also`, else `:named`."
  @spec named_kind(map()) :: :not | :only | :also | :named
  def named_kind(m) do
    cond do
      m["not"] != "" -> :not
      m["only"] != "" or m["only2"] != "" -> :only
      m["also"] != "" or m["also2"] != "" -> :also
      true -> :named
    end
  end

  @doc "The words excepting provisions from a subject (\"except\", \"excluding\", …)."
  @spec excepted() :: Regex.t()
  def excepted, do: @named_excepted
end

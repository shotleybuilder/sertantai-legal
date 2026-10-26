defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Named do
  @moduledoc """
  Named provisions' own extent, wherever the law states it (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): "Sections
  107 and 116A of this Act extend to Scotland only" → `{:only, "S",
  ["s.107", "s.116A"]}`, read only where stated plainly. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, Parts, Places}

  # named provisions' own extent, wherever stated: "Sections 107 and 116A of
  # this Act extend to Scotland only" → {:only, "S", ["s.107", "s.116A"]};
  # "… extend to Scotland" (no "only") widens a default (`:also`), else
  # it is where they extend (`:only`); "do not extend" → `:not`
  @doc "Named provisions' own extent, from the unit sentences (`Units.unit_sentences/1`)."
  @spec named([{String.t(), String.t()}], Doc.t()) :: [{atom(), String.t() | nil, [String.t()]}]
  def named(unit_sentences, doc) do
    for {ref, s} <- unit_sentences,
        not Regex.match?(Forms.heading(), s),
        not Regex.match?(Forms.part_not(), s),
        m = Regex.named_captures(Forms.named(), s),
        m != nil,
        plain_named?(m, s),
        subj = described_out(m["subj"]),
        refs = Enum.uniq(RefList.parse(subj, ref) ++ Parts.parts(subj, doc, ref)),
        refs != [],
        do: {named_kind(m), Places.places(m["places"]), refs}
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
    ~r/\((?=[^()]*\s)((?:[^()]|\([^()]*\))*)\)/u
    |> Regex.replace(subj, fn _, inner ->
      # (never a qualified one: "(and article 27 in so far as it relates to
      # those paragraphs)", SI 2013/602 art.1(8))
      if inner =~ ~r/^\s*(?:and|with|including|together\s+with)\b/iu and
           not (inner =~ ~r/\b(?:so\s+far|in\s*so\s*far|insofar|to\s+the\s+extent)\b/iu),
         do: " " <> inner <> " ",
         else: " "
    end)
    |> String.replace(~r/,?\s*as\s+(?:amended|inserted|substituted)\s+by\b[^,]*,?/iu, " ")
  end

  # read only as plainly stated: never another law's provisions ("… of that
  # Act shall continue to extend", "… the 1989 Act shall cease to extend"),
  # a mention ("so far as they extend to"), a subject with its own
  # exceptions ("excluding section 35"), nor a qualified or excepted extent
  # ("… so far as they amend—", "…, except that— …"): those stay unread
  # (CV-S05, counted in the catalogue)
  @named_not_plain ~r/\b(?:of|to),?\s+(?:that|the\s+\d{4}|the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)(?:\s+\d{4})?)\b(?!\s+(?:Act|Order)\s+(?:extends?|shall))|\b(?:continue|cease)s?\s+to\b|\bso\s+much\s+of\b|\bcorresponding\b|\btogether\s+with\b|\bas\s+relates?\b|\bso\s+far\s+as\b|\bin\s+so\s+far\b|\binsofar\b|\bexcept\b|\bexcluding\b|\bother\s+than\b|\bapart\s+from\b|\bwhich\b|\bmay\b|\bunder\s+this\b|[;:—–]/iu
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
        ~r/\balso\s+extends?\b|[;,]\s*but\b(?!\s+(?:otherwise|the\s+other\s+provisions|this\s+Act\s+does\s+not\s+otherwise|not\s+otherwise))/iu,
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

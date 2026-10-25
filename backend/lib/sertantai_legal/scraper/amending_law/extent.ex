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
  alias SertantaiLegal.Scraper.LawStart.Clause
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
  # (also "the preceding provisions of this Act (including the Schedules)":
  # 1998/8 s.16(1), CV-S05 N7)
  @subject "(?:\\bThe provisions of |\\bthe preceding provisions of |(?<!of )(?<!in )(?<!to )(?<!to, )\\b)(?:this Act|these Regulations|this Order|these Rules|this Scheme)(?:\\s*\\(including the Schedules?(?: to it)?\\))?"
  # "England and Wales and Scotland", "England and Wales, Scotland and
  # Northern Ireland"
  # ("… to England and Wales, and Scotland": a comma before the "and", CV-S05)
  # ("… to Scotland or Northern Ireland": CV-S05 B)
  @place_list "(?:#{@places})(?:\\s*,\\s*(?:#{@places}))*(?:\\s*,?\\s+(?:and|or|as\\s+well\\s+as)\\s+(?:to\\s+)?(?:#{@places}))*"
  # (also "… of this Act, and no others, shall extend to Scotland—", "…
  # extend to Scotland, namely, Part III; …": CV-S05)
  # (several places: "… extend to England and Wales, Scotland and Northern
  # Ireland—"; "of these Regulations", "of this Order": CV-S05 N4, N11)
  # (also "The following provisions of Part II do not extend to Northern
  # Ireland— …": a `:not` list, CV-S05 A)
  @heading ~r/The following (?:provisions (?:of (?:this (?:Act|Part|Order)|these Regulations|Part [IVXLC\d]+[A-Z]*(?: of this Act)?) )?)?(?:,?\s*and no others,\s*)?(?:shall\s+)?(?:(?:also\s+)?extend(?:s)? (also )?to (#{@place_list})( only)?|(?:do|does|shall) not extend to (#{@place_list})|ha(?:s|ve) the same extent as the enactments? to which (?:it|they) relates?)(?:\s*[—–:-]|,?\s+(?:namely|that\s+is\s+to\s+say)\b[,:—–]?)/iu
  @extends Regex.compile!(
             # (", which subject to subsections (8) to (10) below extends to
             # Scotland only— (a) may be cited as …": the dash lists what the
             # Act does, 1995/36 s.105(1); never with exceptions after it:
             # "… with the exception of—", ", except …" — CV-S05 N6, N15)
             "#{@subject}(?:,\\s*which(?:\\s+subject\\s+to\\s+[^—–,]{1,80}?)?)?\\s+(?:shall\\s+)?extends?\\s+(?:(?:only\\s+)?to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)((?>#{@place_list}))(?:\\s+only)?(?!\\s*[—–](?!\\s*\\(?a\\)?\\s*may\\s+be\\s+cited))(?!\\s*,?\\s*(?:with\\s+the\\s+exception|except|save\\s+(?:as|that|for)|apart\\s+from|other\\s+than|excluding)\\b)",
             "iu"
           )
  # "The provisions of this Act extend to England and Wales and, except as
  # mentioned below, to Northern Ireland" (Arbitration Act 1996 s.108(1)):
  # both; the exceptions are stated below and read there (CV-S05 A)
  @extends_and Regex.compile!(
                 "#{@subject}\\s+(?:shall\\s+)?extends?\\s+to\\s+(?<a>(?>#{@place_list}))\\s+and\\s*,\\s*(?:except|save)\\s+as\\s+(?:otherwise\\s+)?(?:mentioned|provided|stated|specified)\\s+(?:below|above|in\\s+[^,]{1,80}),\\s*to\\s+(?<b>(?>#{@place_list}))",
                 "iu"
               )

  # the default with exceptions after it ("This Act extends to the whole of
  # the United Kingdom, except for Part 1, which extends to England and
  # Wales only"; "… except regulation 15"; "… except as otherwise provided
  # by subsections (2) to (6)"): read where the exceptions read plainly
  # (`exceptions/3`), else unread (CV-S05)
  @extends_exc Regex.compile!(
                 "#{@subject}(?:,\\s*which)?\\s+(?:shall\\s+)?extends?\\s+(?:to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)(?<places>(?>#{@place_list}))(?:\\s+only)?\\s*,?\\s*(?<exc>(?:except|save|apart\\s+from|other\\s+than|excluding)\\b[^.]*)",
                 "iu"
               )

  # "These Regulations— (a) may be cited as …; (b) come into force …; and
  # (c) extend to Scotland only" (a citation clause's list: CV-S05)
  @cited_list Regex.compile!(
                "#{@subject}\\s*[—–][^.]*?;\\s*(?:and\\s+)?(?:\\(?[a-z]\\)?\\s*)?(?:shall\\s+)?(?<not>do\\s+not\\s+|does\\s+not\\s+)?extends?\\s+to\\s+(?:the\\s+whole\\s+of\\s+)?(#{@place_list})",
                "iu"
              )
  # "Sections 107 and 116A of this Act extend to Scotland only", "Section 82
  # above (with Schedule 9) extends to Northern Ireland only", "Parts 2 and
  # 3 do not extend to Northern Ireland", "This Part of this Act shall
  # extend to Scotland and Northern Ireland": named provisions' own extent
  # (CV-S05)
  @named Regex.compile!(
           # (also articles, regulations, rules; "Subject to …, Parts 1 to 5
           # extend …"; "The amendments made by regulations 8 and 12 extend
           # …", "The modifications specified in paragraphs 65 … of Schedule
           # 2 extend …": CV-S05 N5, N8, N14)
           "^(?:\\(\\w+\\)\\s*)?(?:Subject\\s+to\\s+[^,—–]{1,120},\\s*)?(?<subj>(?:(?:The\\s+)?(?:amendments?|modifications?|repeals?|revocations?)\\s+(?:made\\s+by|specified\\s+in|in)\\s+)?(?:Sections?|Articles?|Regulations?|Rules?|Parts?|Schedules?|paragraphs?|This\\s+Part|This\\s+section|This\\s+regulation|This\\s+article)\\b(?:(?!\\bextends?\\b|\\bextend\\b).)*?)\\s+(?:shall\\s+)?(?<also>also\\s+)?(?<not>(?:do|does|shall)\\s+not\\s+)?extends?\\s+(?<only>only\\s+)?(?<also2>also\\s+)?(?:to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)(?<places>#{@place_list})(?<only2>\\s+only)?",
           "iu"
         )
  # "The amendments and repeals in Schedules 20 and 21 have the same extent
  # as the enactments to which they refer", "An amendment, repeal or
  # revocation made by this Order has the same extent as the provision to
  # which it relates": those provisions follow the enactment they change
  # (`:same`; "*" for every one the law makes) — CV-S05
  @amendments_same ~r/^(?:\(\w+\)\s*)?(?:Subject\s+to[^,]*,\s*)?(?:An?|The|Any|Each)\s+(?:amendments?|repeals?|revocations?|modifications?)(?:\s*,\s*|\s+(?:and|or)\s+)?(?:(?:amendments?|repeals?|revocations?|modifications?)(?:\s*,\s*|\s+(?:and|or)\s+)?)*(?<subj>.*?)\s+(?:(?:has|have|shall\s+have)\s+the\s+same\s+(?:application\s+and\s+)?extent\s+as\s+(?:that\s+of\s+)?|extends?\s+to\s+the\s+same\s+part\s+or\s+parts\s+of\s+the\s+United\s+Kingdom\s+as\s+)the\s+(?:enactments?|provisions?|instruments?|legislation)\b(?!\s+as\s+if)/iu

  # "This Act shall extend to Northern Ireland with the exception of— (a)
  # the provisions of Part 1; (b) any provision amending … which does not so
  # extend; …" (CPA 1987 s.49(1)): an Act of the UK Parliament, so Great
  # Britain and that place; the Parts and provisions named, plainly, not
  # there (CV-S05 N15)
  @extends_except Regex.compile!(
                    "\\bThis\\s+Act\\s+(?:shall\\s+)?extends?\\s+to\\s+(?<places>#{@place_list})\\s+with\\s+the\\s+exception\\s+of\\s*[—–:]\\s*(?<list>[^.]*)",
                    "iu"
                  )

  # "Only the following provisions of this Act (together with this section)
  # extend to Northern Ireland, namely— section 3(5) to (8); …; Part V; …"
  # (EPA 1990 s.164): the rest of the UK is the default; the items not
  # qualified ("in so far as it relates to importation") also extend there
  @only_following Regex.compile!(
                    "\\bOnly\\s+the\\s+following\\s+provisions\\s+of\\s+this\\s+(?:Act|Order|Part)\\s*(?<self>\\(together\\s+with\\s+this\\s+section\\)\\s*)?(?:shall\\s+)?extend\\s+to\\s+(?<places>#{@place_list})\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)?\\s*,?\\s*[—–:]\\s*(?<list>[^.]*)",
                    "iu"
                  )
  # "Where any enactment amended or repealed by this Act extends to any part
  # of the United Kingdom, the amendment or repeal extends to that part"
  # (EPA 1990 s.164(5)): every amendment the law makes has the enactment's
  # extent
  @amendments_where ~r/^(?:\(\w+\)\s*)?Where\s+any\s+enactment\s+amended(?:\s+or\s+repealed)?\s+by\s+this\s+(?:Act|Order)\s+extends\s+to\s+any\s+part\s+of\s+the\s+United\s+Kingdom,\s+the\s+amendment(?:\s+or\s+repeal)?\s+extends\s+to\s+that\s+part\b/iu

  # "This Act, except— (a) …; and (b) …, does not extend to Northern Ireland"
  # (also "This Act, except this section and the following provisions,
  # namely— …, does not extend to Northern Ireland": Gas Act 1986 s.68(6),
  # CV-S05 D)
  @except_list Regex.compile!(
                 "#{@subject},\\s*except\\s*(?:for\\s*)?(?<self>this\\s+section\\s+and\\s+)?(?:the\\s+following\\s+provisions\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)?\\s*,?\\s*)?[—–:]\\s*(?<items>.+?),\\s*(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(?<places>#{@place_list})",
                 "isu"
               )
  # "Part III, except section 75 and Schedule 7, does not extend to Scotland"
  @part_not Regex.compile!(
              "(?<!provisions of )\\b(Parts?\\s+[IVXLC\\d]+[A-Z]*(?:\\s*(?:,|and)\\s*[IVXLC\\d]+[A-Z]*)*)(?:,\\s*except\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(#{@place_list})",
              "u"
            )
  # (also "Nothing in this Act extends to Scotland or Northern Ireland":
  # 1957/42, CV-S05)
  @not_extends Regex.compile!(
                 "(?:#{@subject}(?:,\\s*(?:apart from|except(?: for)?)\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend|\\bNothing\\s+in\\s+(?:this Act|these Regulations|this Order|these Rules)()\\s+(?:shall\\s+)?extends?)\\s+to\\s+((?>#{@place_list}))",
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
          do: {ref, doc |> Doc.element(id) |> own_words() |> Doc.lines() |> Enum.join(" ")}

    {clause_ref, clause} =
      Enum.find(sections, {nil, ""}, fn {ref, text} ->
        not String.contains?(ref, "(") and
          (Regex.match?(@extends, text) or Regex.match?(@extends_and, text) or
             Regex.match?(@not_extends, text) or
             Regex.match?(@except_list, text) or Regex.match?(@heading, text) or
             Regex.match?(@cited_list, text) or Regex.match?(@only_following, text) or
             Regex.match?(@extends_except, text) or Regex.match?(@extends_exc, text))
      end)

    %__MODULE__{
      default: westminster(default(clause), clause, doc.type),
      lists:
        apart(clause, clause_ref, doc) ++
          only_following(clause, clause_ref, doc) ++
          extends_except(clause, clause_ref, doc) ++
          exception_lists(clause, clause_ref, doc) ++
          headed_lists(sections, clause_ref, clause, doc) ++
          part_not(sections, doc) ++ named(doc) ++ amendments_same(doc),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introductions(doc),
      ref: clause_ref,
      text: if(clause != "", do: clause),
      application: application(doc, default(clause))
    }
  end

  @doc """
  What one sentence of an extent clause states, in the reader's terms
  (CV-S05, the catalogue's outcome): `{:default, code}` (the law's own
  extent: "This Act extends to …", "… does not extend to …", "This Act,
  except— …, does not extend to …"), `{:list, kind, code}` (a list heading:
  "The following extend also to Scotland—"; `code` nil for "the same extent
  as the enactments"), `{:part_not, code}` ("Part III … does not extend to
  Scotland"), or nil (no statement the reader reads).
  """
  @spec statement(String.t(), String.t() | nil) ::
          {:default, String.t()}
          | {:list, list_kind(), String.t() | nil}
          | {:part_not, String.t()}
          | nil
  def statement(sentence, type \\ nil)

  # (an Act of the UK Parliament's "This Act extends to Northern Ireland"
  # is the UK, as `read/1` reads it: `type` the law's type code)
  def statement(sentence, type) do
    case statement_alone(sentence) do
      {:default, d} -> {:default, westminster(d, sentence, type)}
      other -> other
    end
  end

  defp statement_alone(sentence) do
    cond do
      Regex.match?(@extends_and, sentence) ->
        {:default, default(sentence)}

      Regex.match?(@except_list, sentence) or Regex.match?(@extends, sentence) or
        Regex.match?(@not_extends, sentence) or Regex.match?(@cited_list, sentence) ->
        {:default, default(sentence)}

      Regex.match?(@amendments_same, sentence) or Regex.match?(@amendments_where, sentence) ->
        {:list, :same, nil}

      m = Regex.named_captures(@extends_except, sentence) ->
        {:default, Territory.union(["E+W+S", places(m["places"])])}

      (m = Regex.named_captures(@extends_exc, sentence)) && exceptions(m, nil, nil) != :unread ->
        {:default, places(m["places"])}

      m = Regex.named_captures(@only_following, sentence) ->
        {:default, Territory.subtract("E+W+S+NI", places(m["places"]))}

      match = Regex.run(@heading, sentence) ->
        {:list, kind(match), place(match)}

      m = Regex.run(@part_not, sentence) ->
        {:part_not, places(List.last(m))}

      (m = Regex.named_captures(@named, sentence)) && plain_named?(m, sentence) ->
        {:list, named_kind(m), places(m["places"])}

      true ->
        nil
    end
  end

  # the law's whole-instrument application clause ("These Regulations …
  # apply in relation to England only"; `ApplicationClause`), as a code:
  # where the changes it makes apply (CV-07)
  # Read from the law's own words only: never the words an amending
  # instruction inserts into another law ("After regulation 1 insert— …
  # These Regulations apply to Northern Ireland": a BlockAmendment), nor
  # words inserted into this law later (an Addition or Substitution: SI
  # 2008/2852 reg.1A, inserted 2020, never confines the changes it made in
  # 2008) — CV-S05 N1, N2
  @not_own ~w(BlockAmendment Addition Substitution)
  @not_own_extent ~w(BlockAmendment)

  defp application(doc, extent) do
    clauses =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil,
          not String.contains?(ref, "("),
          text = doc |> Doc.element(id) |> own_words(@not_own) |> Doc.lines() |> Enum.join(" "),
          # (never "… revoked to the extent that they apply in Northern
          # Ireland": other laws' application, nisr 2018/17 — CV-S05 round 3 B)
          c =
            text
            |> String.replace(
              ~r/\b(?:to\s+the\s+extent\s+that|so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as)\s+(?:it|they)\s+appl(?:y|ies)\b[^.;]*/iu,
              ""
            )
            |> ApplicationClause.parse(),
          c != nil,
          do: c

    extent_regions = extent && String.split(extent, "+")

    case ApplicationClause.resolve(clauses, extent_regions) do
      nil -> nil
      regions -> Enum.join(regions, "+")
    end
  end

  # the words that aren't the law's own: for its application, words it
  # inserts elsewhere and words inserted into it later (as made); for its
  # extent, only words it inserts elsewhere — an amended extent clause is
  # still the law's own extent ("This Part extends only to Scotland" in a
  # Part inserted later: CV-S05 H)

  defp own_words(el, not_own \\ @not_own_extent)

  defp own_words({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el, not_own) do
    kept =
      for child <- children,
          not match?({:xmlElement, _, _, _, _, _, _, _, _, _, _, _}, child) or
            local(elem(child, 1)) not in not_own,
          do: own_words(child, not_own)

    put_elem(el, 8, kept)
  end

  defp own_words(node, _not_own), do: node

  defp local(name), do: name |> Atom.to_string() |> String.split(":") |> List.last()

  # an Act of the UK Parliament that "extends to Northern Ireland" (no
  # "only") extends there as well as to Great Britain (Ministers of the
  # Crown Act 1975 s.9(2): CV-S05 round 3 A)
  defp westminster("NI", clause, "ukpga") do
    if clause =~ ~r/\bNorthern\s+Ireland\s+only\b|\bonly\s+to\s+Northern\s+Ireland\b/iu,
      do: "NI",
      else: "E+W+S+NI"
  end

  defp westminster(default, _clause, _type), do: default

  # "These Regulations extend to England and Wales and Scotland" → E+W+S;
  # "This Act does not extend to Northern Ireland" → the rest of the UK
  defp default(clause) do
    cond do
      m = Regex.named_captures(@extends_and, clause) ->
        Territory.union([places(m["a"]), places(m["b"])])

      m = Regex.named_captures(@except_list, clause) ->
        Territory.subtract("E+W+S+NI", places(m["places"]))

      m = Regex.run(@extends, clause) ->
        places(Enum.at(m, 1))

      (m = Regex.named_captures(@extends_exc, clause)) &&
          exceptions(m, nil, nil) != :unread ->
        places(m["places"])

      m = Regex.run(@not_extends, clause) ->
        Territory.subtract("E+W+S+NI", places(List.last(m)))

      m = Regex.named_captures(@extends_except, clause) ->
        Territory.union(["E+W+S", places(m["places"])])

      m = Regex.named_captures(@only_following, no_dots(clause)) ->
        Territory.subtract("E+W+S+NI", places(m["places"]))

      m = Regex.run(@cited_list, clause) ->
        [_, not_, list] = m
        if not_ == "", do: places(list), else: Territory.subtract("E+W+S+NI", places(list))

      true ->
        nil
    end
  end

  # "… apart from sections 82 and 83, does not extend to Northern
  # Ireland": those extend there too
  defp apart(clause, clause_ref, doc) do
    case Regex.named_captures(@except_list, clause) do
      # each item; one "so far as may be necessary …" is limited to a
      # purpose and doesn't carry its provisions there (HSWA s.84(1)(a));
      # "except this section and …": the clause's own provision too
      %{"items" => items, "places" => place, "self" => self} ->
        refs =
          for item <- String.split(items, ";"),
              not (item =~ ~r/\bso\s+(?:far|much)\s+(?:as|of)\b/i),
              ref <- RefList.parse(item, clause_ref) ++ parts(item, doc, clause_ref),
              do: ref

        refs = if self != "" and clause_ref, do: [clause_ref | refs], else: refs
        if refs != [], do: [{:also, places(place), Enum.uniq(refs)}], else: []

      nil ->
        case Regex.run(@not_extends, clause) do
          [_, except, _, place] when except != "" ->
            [{:also, places(place), RefList.parse(except, clause_ref)}]

          _ ->
            []
        end
    end
  end

  # "Part III, except section 75 and Schedule 7, does not extend to
  # Scotland", in any provision (SENDA 2001 s.43(12): CV-S05 E)
  defp part_not(sections, doc) do
    for {ref, text} <- sections,
        not String.contains?(ref, "("),
        not String.starts_with?(ref, "sch."),
        [_, part, except, place] <- Regex.scan(@part_not, text),
        refs = parts(part, doc, ref) -- RefList.parse(except || "", ref),
        refs != [],
        uniq: true,
        do: {:not, places(place), refs}
  end

  @doc """
  A top-level provision's units: its subsections (direct children:
  "section-84-1"), each whole with its lists, else the provision itself,
  the leading number CLML runs into the words dropped ("841 This Act" →
  "This Act"). The units a statement is read from (CV-S05).
  """
  @spec units(Doc.t(), String.t()) :: [String.t()]
  def units(%Doc{} = doc, id) do
    child = ~r/^#{Regex.escape(id)}-[^-]+$/
    children = for c <- doc.ids, c =~ child, do: c

    for el_id <- if(children == [], do: [id], else: children),
        text = doc |> Doc.element(el_id) |> own_words() |> Doc.lines() |> Enum.join(" "),
        do: String.replace(text, ~r/^\s*\d+[A-Z]*\s*(?=[A-Z(])/u, "")
  end

  # each top-level provision's unit sentences, with its ref
  defp unit_sentences(doc) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        not String.starts_with?(ref, "sch."),
        unit <- units(doc, id),
        s <- Clause.sentences(unit),
        do: {ref, s}
  end

  # named provisions' own extent, wherever stated: "Sections 107 and 116A of
  # this Act extend to Scotland only" → {:only, "S", ["s.107", "s.116A"]};
  # "… extend to Scotland" (no "only") widens a default (`:also`), else
  # it is where they extend (`:only`); "do not extend" → `:not`
  defp named(doc) do
    for {ref, s} <- unit_sentences(doc),
        not Regex.match?(@heading, s),
        not Regex.match?(@part_not, s),
        m = Regex.named_captures(@named, s),
        m != nil,
        plain_named?(m, s),
        subj = m["subj"],
        refs = Enum.uniq(RefList.parse(subj, ref) ++ parts(subj, doc, ref)),
        refs != [],
        do: {named_kind(m), places(m["places"]), refs}
  end

  # read only as plainly stated: never another law's provisions ("… of that
  # Act shall continue to extend", "… the 1989 Act shall cease to extend"),
  # a mention ("so far as they extend to"), a subject with its own
  # exceptions ("excluding section 35"), nor a qualified or excepted extent
  # ("… so far as they amend—", "…, except that— …"): those stay unread
  # (CV-S05, counted in the catalogue)
  @named_not_plain ~r/\b(?:of|to),?\s+(?:that|the\s+\d{4}|the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)(?:\s+\d{4})?)\b(?!\s+(?:Act|Order)\s+(?:extends?|shall))|\b(?:continue|cease)s?\s+to\b|\bso\s+much\s+of\b|\bcorresponding\b|\btogether\s+with\b|\bas\s+relates?\b|\bso\s+far\s+as\b|\bin\s+so\s+far\b|\binsofar\b|\bexcept\b|\bexcluding\b|\bother\s+than\b|\bapart\s+from\b|\bwhich\b|[;:—–]/iu
  @named_tail ~r/^\s*[,(]?\s*(?:but\s+only\s+|only\s+)?(?:so\s+far\s+as|in\s+so\s+far\b|insofar\b|to\s+the\s+extent|for\s+the\s+purposes?|except|apart\s+from|other\s+than|excluding|in\s+relation\s+to|as\s+respects|subject\s+to)\b/iu
  @named_excepted ~r/\b(?:except|excluding|other\s+than|apart\s+from)\b/iu

  defp plain_named?(m, s) do
    # the words after the match (not after the first mention of its places:
    # "(environmental governance: Northern Ireland) extends to Northern
    # Ireland, except that—")
    tail =
      case Regex.run(@named, s, return: :index) do
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

  defp named_kind(m) do
    cond do
      m["not"] != "" -> :not
      m["only"] != "" or m["only2"] != "" -> :only
      m["also"] != "" or m["also2"] != "" -> :also
      true -> :named
    end
  end

  # "The amendments and repeals in Schedules 20 and 21 have the same extent
  # as the enactments to which they refer" → {:same, nil, ["sch.20",
  # "sch.21"]}; "… made by this Act / Order" (or none named) → ["*"]
  # (never with exceptions after it: "…, except that nothing extends to
  # Northern Ireland"; "made by the following provisions— (a) section 10;
  # …": those listed)
  defp exception_lists(clause, clause_ref, doc) do
    with nil <- Regex.run(@extends, clause),
         m when m != nil <- Regex.named_captures(@extends_exc, clause),
         lists when is_list(lists) <- exceptions(m, clause_ref, doc) do
      lists
    else
      _ -> []
    end
  end

  # the exceptions after a default: [] (stated elsewhere), lists, or :unread
  defp exceptions(%{"exc" => exc, "places" => default_places}, clause_ref, doc) do
    exc = String.trim(exc)

    cond do
      # stated elsewhere: the named provisions' own statements are read
      exc =~
          ~r/^(?:except|save)\s+(?:as|where|in\s+so\s+far\s+as)\s+(?:otherwise\s+)?(?:expressly\s+)?(?:provided|stated|specified|mentioned)\b/iu ->
        []

      # "except for Part 1, which extends to England and Wales only"
      m =
          Regex.run(
            ~r/^(?:except|save)\s+(?:for\s+)?(.+?),?\s+which\s+(?:shall\s+)?extends?\s+(?:only\s+)?to\s+((?>#{@place_list}))(?:\s+only)?\s*$/iu,
            exc
          ) ->
        [_, subj, list] = m

        # never another law's provisions ("paragraph 23 of Schedule 12A to
        # the Data Protection Act 2018")
        if subj =~
             ~r/\b(?:of|to)\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)(?:\s+\d{4})?/u,
           do: :unread,
           else: with_refs(subj, clause_ref, doc, &[{:only, places(list), &1}])

      # "except that section 12 (…) extends to England and Wales and Scotland only"
      m = Regex.run(~r/^except\s+that\s+(.+)$/iu, exc) ->
        rest = Enum.at(m, 1)

        with n when n != nil <-
               Regex.named_captures(
                 @named,
                 String.capitalize(String.first(rest)) <> String.slice(rest, 1..-1//1)
               ),
             true <- plain_named?(n, rest),
             refs =
               if(doc,
                 do:
                   Enum.uniq(
                     RefList.parse(n["subj"], clause_ref) ++ parts(n["subj"], doc, clause_ref)
                   ),
                 else: [:any]
               ),
             [_ | _] <- refs do
          [{named_kind(n), places(n["places"]), refs}]
        else
          _ -> :unread
        end

      # "except regulation 15": those don't extend there
      m =
          Regex.run(
            ~r/^(?:except|save|apart\s+from|other\s+than|excluding)\s+(?:for\s+)?(.+?)\s*$/iu,
            exc
          ) ->
        subj = Enum.at(m, 1)

        if subj =~ ~r/\b(?:so\s+far|which|where|that|of\s+the\s+[A-Z]|to\s+the\s+[A-Z])/u,
          do: :unread,
          else: with_refs(subj, clause_ref, doc, &[{:not, places(default_places), &1}])

      true ->
        :unread
    end
  end

  # the provisions named, plainly; :unread where none are read (no doc: a
  # sentence alone, `default/1` — read when they name any provision)
  defp with_refs(subj, _clause_ref, nil, _fun),
    do:
      if(
        subj =~ ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\b/i,
        do: [],
        else: :unread
      )

  defp with_refs(subj, clause_ref, doc, fun) do
    case Enum.uniq(RefList.parse(subj, clause_ref) ++ parts(subj, doc, clause_ref)) do
      [] -> :unread
      refs -> fun.(refs)
    end
  end

  defp extends_except(clause, clause_ref, doc) do
    case Regex.named_captures(@extends_except, clause) do
      nil ->
        []

      m ->
        refs =
          for item <- String.split(m["list"], ";"),
              not Regex.match?(
                ~r/\b(?:so\s+far|in\s+so\s+far|any\s+(?:other\s+)?provision|which|except)\b/iu,
                item
              ),
              ref <- RefList.parse(item, clause_ref) ++ parts(item, doc, clause_ref),
              do: ref

        if refs == [], do: [], else: [{:not, places(m["places"]), Enum.uniq(refs)}]
    end
  end

  # repealed words' dots (". . .") are no sentence's end
  defp no_dots(text), do: String.replace(text, ~r/(?:\.\s*){2,}/u, " ")

  # the items of "Only the following provisions … extend to X, namely— …",
  # each not qualified, and the clause itself where it says so
  defp only_following(clause, clause_ref, doc) do
    case Regex.named_captures(@only_following, no_dots(clause)) do
      nil ->
        []

      m ->
        refs =
          for item <- String.split(m["list"], ";"),
              not Regex.match?(
                ~r/\b(?:so\s+far|in\s+so\s+far|insofar|except|to\s+the\s+extent)\b/iu,
                item
              ),
              ref <- RefList.parse(item, clause_ref) ++ parts(item, doc, clause_ref),
              do: ref

        refs = if m["self"] != "", do: [clause_ref | refs], else: refs
        if refs == [], do: [], else: [{:also, places(m["places"]), Enum.uniq(refs)}]
    end
  end

  # "Sections 240 and 242 and Schedules 1 and 3 have the same extent as the
  # provisions amended" (1996/18 s.244(4): CV-S05)
  @named_same ~r/^(?:\(\w+\)\s*)?(?<subj>(?:Sections?|Schedules?|Parts?|paragraphs?|regulations?|articles?)\s+[\dIVXL][^.;:—–]*?)\s+(?:has|have|shall\s+have)\s+the\s+same\s+extent\s+as\s+the\s+(?:enactments?|provisions?)\s+(?:amended|repealed|revoked|modified|to\s+which\s+(?:it|they)\s+relates?)\b/iu

  # "This Act does not extend to Northern Ireland except so far as it
  # affects other enactments extending to Northern Ireland" (1988/54,
  # 1989/13, 1997/11): the default stands, and every amendment the law
  # makes follows the enactment it changes (CV-S05)
  @not_extends_amending ~r/\bnot\s+extend\s+to\s+[^.]*?\bexcept\b[^.]*?\bso\s+far\s+as\s+(?:it|they)\s+(?:affects?|amends?|repeals?|revokes?)\s+(?:any\s+)?(?:other\s+)?enactments?\b/iu

  defp amendments_same(doc) do
    for(
      {ref, s} <- unit_sentences(doc),
      m = Regex.named_captures(@amendments_same, s),
      m != nil,
      [_, tail] <- [Regex.split(@amendments_same, s, parts: 2)],
      not Regex.match?(
        ~r/\b(?:other\s+than|apart\s+from|except|save|excluding)\b/iu,
        m["subj"]
      ),
      refs = same_refs(m["subj"], tail, ref, doc),
      refs != :none,
      list <- same_lists(refs, tail, ref),
      uniq: true,
      do: list
    ) ++
      for(
        {_ref, s} <- unit_sentences(doc),
        Regex.match?(@amendments_where, s) or Regex.match?(@not_extends_amending, s),
        uniq: true,
        do: {:same, nil, ["*"]}
      ) ++
      for {ref, s} <- unit_sentences(doc),
          m = Regex.named_captures(@named_same, s),
          m != nil,
          not Regex.match?(@named_excepted, m["subj"]),
          refs = Enum.uniq(RefList.parse(m["subj"], ref) ++ parts(m["subj"], doc, ref)),
          refs != [],
          uniq: true,
          do: {:same, nil, refs}
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
           ~r/^(?:\s+(?:which|to\s+which|being)\b[^,;—–]*)?\s*,?\s*except\s+that\s+the\s+(?:amendments?|modifications?|repeals?|revocations?)\s+(?:made\s+by|specified\s+in)\s+(?<paras>paragraphs?\s+[^,;:—–]+?)\s+of\s+that\s+Schedule\s+(?:shall\s+)?(?<not>do\s+not\s+)?extends?\s+to\s+(?<places>(?>#{@place_list}))(?<only>\s+only)?\s*\.?\s*$/iu,
           tail
         )) && match?([<<"sch.", _::binary>>], refs) ->
        [sch] = refs
        n = String.replace_prefix(sch, "sch.", "")
        paras = RefList.parse("#{m["paras"]} of Schedule #{n}", ref)
        kind = if m["not"] != "", do: :not, else: :only

        if paras == [],
          do: [{:unread, nil, refs}],
          else: [{:same, nil, refs}, {kind, places(m["places"]), paras}]

      true ->
        [{:unread, nil, refs}]
    end
  end

  defp same_refs(subj, tail, ref, doc) do
    cond do
      subj =~ ~r/\bfollowing\b/i ->
        case tail |> String.split(~r/[—–:]/u, parts: 2) do
          [_, list] -> with([] <- RefList.parse(list, ref), do: :none)
          _ -> :none
        end

      # "made by Parts 4, 5 and 6", "made by regulations 3, 4, 6": those
      # (CV-S05 N13); a subject naming provisions not read is no "*"
      subj =~
          ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\s+[\dIVXL]/i ->
        case Enum.uniq(RefList.parse(subj, ref) ++ parts(subj, doc, ref)) do
          [] -> :none
          refs -> refs
        end

      true ->
        ["*"]
    end
  end

  # the sections of the Parts named ("Part III", "Parts I and II"; "this
  # Part": the one holding the clause), from the document
  defp parts(text, doc, clause_ref) do
    # (never a Schedule's Part: "Part 2 of Schedule 10", "Parts 4 and 5 of
    # Schedule 13" — the list matched whole, CV-S05)
    # (nor a Chapter's Part: "Chapter 3 of Part 1", 2004/20; nor a
    # bracketed description: "paragraphs 53 and 59 of Schedule 15 (Part 7:
    # consequential provision etc.)", HSCA 2012 s.308(3)(f) — CV-S05)
    text = Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, text, "")

    text =
      Regex.replace(
        ~r/\bChapters?\s+[\dIVXLC]+[A-Z]*(?:\s*(?:,|and|to)\s*[\dIVXLC]+[A-Z]*)*\s+of\s+Part\s+[\dIVXLC]+[A-Z]*/u,
        text,
        ""
      )

    named =
      case Regex.run(
             ~r/(?<![Ii]n\s)\bParts?\s+((?>[IVXLC\d]+[A-Z]*(?:\s*(?:,|and|to)\s*[IVXLC\d]+[A-Z]*)*))\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)/u,
             text
           ) do
        [_, list] ->
          # "Part 1" where the document's ids are "part-I", and the reverse
          # (CPA 1987 s.49(1): CV-S05 N15)
          for n <- part_numbers(list),
              id <- ["part-#{n}", "part-#{other_numeral(n)}"],
              Doc.element(doc, id) != nil,
              uniq: true,
              do: id

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
        id =~ ~r/^(?:section|regulation|article|rule)-\d+[A-Z]*$/,
        holds_id?(doc, part, id),
        ref = Order.ref(id),
        uniq: true,
        do: ref
  end

  # "I and III", "1 to 5" (each between: CV-S05 N5), "IV to VI"
  defp part_numbers(list) do
    list
    |> String.split(~r/\s*(?:,|\band\b)\s*/u, trim: true)
    |> Enum.flat_map(fn piece ->
      case Regex.run(~r/^([IVXLC\d]+)\s+to\s+([IVXLC\d]+)$/u, String.trim(piece)) do
        [_, a, b] ->
          roman? = a =~ ~r/^[IVXLC]+$/

          {x, y} =
            if roman?,
              do: {arabic(a), arabic(b)},
              else: {String.to_integer(a), String.to_integer(b)}

          for i <- x..y//1, do: if(roman?, do: roman(i), else: Integer.to_string(i))

        nil ->
          List.flatten(Regex.scan(~r/[IVXLC\d]+[A-Z]*/u, piece))
      end
    end)
  end

  # 1 ↔ I, 12 ↔ XII (a letter suffix kept: "2A" ↔ "IIA")
  defp other_numeral(n) do
    case Regex.run(~r/^(\d+)([A-Z]*)$/, n) do
      [_, d, suffix] ->
        roman(String.to_integer(d)) <> suffix

      nil ->
        case Regex.run(~r/^([IVXLC]+)([A-Z]?)$/, n) do
          [_, r, suffix] -> Integer.to_string(arabic(r)) <> suffix
          nil -> n
        end
    end
  end

  @romans [
    {100, "C"},
    {90, "XC"},
    {50, "L"},
    {40, "XL"},
    {10, "X"},
    {9, "IX"},
    {5, "V"},
    {4, "IV"},
    {1, "I"}
  ]

  defp roman(0), do: ""

  defp roman(n),
    do: with({v, r} <- Enum.find(@romans, fn {v, _} -> v <= n end), do: r <> roman(n - v))

  defp arabic(r) do
    r
    |> String.graphemes()
    |> Enum.map(&%{"I" => 1, "V" => 5, "X" => 10, "L" => 50, "C" => 100}[&1])
    |> Enum.chunk_every(2, 1, [0])
    |> Enum.reduce(0, fn [a, b], acc -> if a < b, do: acc - a, else: acc + a end)
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

  # the clause's lists, then any other provision's (uksi 2019/696: the
  # clause in reg.2, "The following provisions extend to the United
  # Kingdom— …" in reg.3; CV-S05 J)
  defp headed_lists(sections, clause_ref, clause, doc) do
    others =
      for {ref, text} <- sections,
          ref != clause_ref,
          not String.contains?(ref, "("),
          not String.starts_with?(ref, "sch."),
          Regex.match?(@heading, text),
          list <- lists(text, ref, doc),
          do: list

    Enum.uniq(lists(clause, clause_ref, doc) ++ others)
  end

  defp lists(clause, clause_ref, doc) do
    parts = Regex.split(@heading, clause, include_captures: true, trim: true)

    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [head, body] ->
      case Regex.run(@heading, head) do
        nil ->
          []

        match ->
          case list_refs(own_list(cut(body)), clause_ref, doc) do
            [] -> []
            refs -> [{kind(match), place(match), refs}]
          end
      end
    end)
  end

  # (no "also" or "only": widens a default, else decides — `:named`,
  # "The following provisions of these Regulations extend to England and
  # Wales— …" with no default: SI 2025/361, CV-S05)
  defp kind([whole | _]) do
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

  defp place([whole | _]) do
    case Regex.run(~r/\bextends?\s+(?:also\s+)?to (#{@place_list})/iu, whole) do
      [_, list] -> places(list)
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
  defp list_refs(text, clause_ref, doc) do
    for item <-
          String.split(
            no_dots(text),
            ~r/;|,\s*(?=(?:and\s+)?(?:[a-z]|[ivx]{2,4})\s)|,\s*(?=(?:and\s+)?(?:sections?|subsections?|Schedules?|in\s+Schedule|Parts?|paragraphs?\s+[^,;]*?\bof\s+Schedule|regulations?|articles?)\b)/u
          ),
        not Regex.match?(
          ~r/\b(?:so\s+far\s+as|in\s+so\s+far|insofar|except|exception|so\s+much\s+of|to\s+the\s+extent|of\s+this\s+section|(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4})\b/u,
          item
        ),
        ref <- RefList.parse(item, clause_ref) ++ parts(item, doc, clause_ref),
        uniq: true,
        do: ref
  end

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

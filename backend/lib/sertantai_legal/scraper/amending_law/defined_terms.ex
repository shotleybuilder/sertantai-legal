defmodule SertantaiLegal.Scraper.AmendingLaw.DefinedTerms do
  @moduledoc """
  The laws an amending law names by a defined term (lat-refactor LR-08):
  "“the 1989 Act” means the Electricity Act 1989" → "the 1989 act" →
  `%{law: "UK_ukpga_1989_29", title: "Electricity Act 1989"}`. The law comes
  from the definition's `Citation` URI when it has one (structure, not
  prose); the title is the words after "means", or the law's title the term
  stands in apposition to ("the Firearms Act 1968 (in this Act referred to
  as “the principal Act”)"). Only terms meaning a law are kept (LR-41: an
  Act defining "authority" or "a" names no law by them). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @type term_law :: %{law: String.t() | nil, title: String.t() | nil}

  @doc "Defined term (lower case) → the law it means."
  @spec of(Doc.t()) :: %{String.t() => term_law()}
  # (each entry kept only when it means a law, before a later one replaces
  # it: a term mentioned again — "section 66 (meaning of “the 2018 Act” …)"
  # — had replaced its definition with one meaning no law, 2025 c.18;
  # Amending-law reader: yield, 2026-11-27)
  # (never in the text an instruction makes, a BlockAmendment: that is the
  # amended law's definition — "“the EU Tachographs Regulation” means
  # Regulation (EU) No. 165/2014 … as read with the … Regulations 2007" had
  # named a law in SI 2016/248 reg.4(10); yield, 2026-11-27)
  def of(%Doc{roots: roots}) do
    for root <- roots,
        text <-
          xpath(
            root,
            ~x"//*[local-name()='Text'][*[local-name()='Term']][not(ancestor::*[local-name()='BlockAmendment'])]"l
          ),
        term <- xpath(text, ~x"./*[local-name()='Term']"l) do
      raw = Doc.text(term)
      words = Doc.text(text)
      uri = text |> xpath(~x"./*[local-name()='Citation']/@URI"s) |> to_string()
      {String.downcase(raw), %{law: law(uri), title: title(words) || apposition(words, raw)}}
    end
    |> Enum.filter(&law?/1)
    |> Map.new()
    |> Map.merge(roots |> plain() |> Enum.filter(&law?/1) |> Map.new())
  end

  defp law?({name, t}), do: name != "" and (t.law != nil or law_title?(t.title))

  # a definition with no Term markup — “the 2015 Act” (“Deddf 2015”) means
  # the Planning (Wales) Act 2015 (Welsh orders: WSI 2017/546)
  # a definition's end: ";", "." or a list item's ",", each perhaps with
  # "and" / "or":
  # "“the 1981 Act” means the Wildlife and Countryside Act 1981 (c.69),"
  # (asp 2011/6, CV-S05)
  @item_end ~S"(?:[;.,](?:\s*(?:and|or))?)?\s*"

  # (and "The “principal Act” is the Town and Country Planning (Scotland)
  # Act 1997 (c. 8).": asp 2006/17 s.57(1); Amending-law reader: yield,
  # 2026-11-27)
  @plain ~r/^\s*(?:The\s+)?“([^”]+)”\s*(?:\(“[^”]*”\)\s*)?(?:means|is)\s+(?:the\s+)?(.+?)\s*#{@item_end}$/u

  defp plain(roots) do
    for root <- roots,
        text <-
          xpath(
            root,
            ~x"//*[local-name()='Text'][not(*[local-name()='Term'])][not(ancestor::*[local-name()='BlockAmendment'])]"l
          ),
        words = Doc.text(text),
        [_, term, title] <- [Regex.run(@plain, words)],
        do: {String.downcase(term), %{law: nil, title: unchaptered(title)}}
  end

  @law_title ~r/\b(?:Act|Regulations|Order|Rules|Measure)(?: \(Northern Ireland\))? \d{4}$/u

  # … the title itself, not a thing under a law ("a fire and rescue authority
  # under the Fire and Rescue Services Act 2004", "an offence … for the
  # purposes of the Royal Parks (Trading) Act 2000", "that district as
  # defined in section 76 of …": PCA 2017, whose caption "(power of fire and
  # rescue authority …)" then named the 2004 Act for a Localism Act 2011
  # amendment, CV-S05); "code set out in Schedule 3A to …", "development …
  # granted by article 3 of …" (Planning Act 2008)
  # (a bracketed number too: "is defined in article 2(1) of the Renewable
  # Transport Fuel Obligations Order 2007", SI 2011/2937; yield, 2026-11-27)
  @thing_under ~r/^(?:a|an|any|that|those|each|every)\s|\b(?:under|purposes\s+of|meaning\s+of|defined\s+in|set\s+out\s+in|(?:section|article|regulation|Schedule|Part)\s+[\w()]+\s+(?:to|of))\s+(?:the\s+)?[A-Z]/u

  defp law_title?(nil), do: false
  defp law_title?(t), do: Regex.match?(@law_title, t) and not Regex.match?(@thing_under, t)

  # "… the Firearms Act 1968 (in this Act referred to as “the principal Act”)":
  # the law's title just before the parenthesis holding the term (its short
  # words too: "Health and Safety at Work etc.", "Access to Justice",
  # "Damage by Pests", and a bracketed part: "(Scotland)" — 1995/25 Sch. 22
  # para 30 read "Work etc. Act 1974", naming no law: run time 2026-10-26)
  # the bracket names the law ("(in this Act referred to as “…”)", "(“the
  # 1990 Act”)"), never a caption mentioning the term ("(definition of
  # “local authority”)": 1994 c.19 Sch.16 para.103 had defined it as the
  # Local Government (Overseas Assistance) Act 1993; yield, 2026-11-27)
  @naming_bracket ~r/^\s*$|\b(?:referred\s+to|called|cited|known)\b(?:\s+\w+)*\s+as\s*$|\bhereinafter\b|\bas\s*$/iu

  defp apposition(words, term) do
    with [before | _] <- String.split(words, "“#{term}”", parts: 2),
         [_, head, inner] <- Regex.run(~r/^(.*)\(([^()]*)$/su, before),
         true <- inner =~ @naming_bracket,
         [_, t] <-
           Regex.run(
             ~r/([A-Z][\w,'’\-]*(?: (?:[A-Z][\w,'’\-]*|and|of|the|for|at|to|by|in|on|etc\.|\([A-Z][^()]*\)))* (?:Act|Regulations|Order|Rules|Measure) \d{4})\s*$/u,
             head
           ) do
      # "In the Town and Country Planning Act 1990": the title, not the words before it
      t
      |> String.replace(~r/^(?:(?:In|Under|By|For|To|Of|And|The|the|of|and) )+/u, "")
      |> of_the_act(term)
      |> String.trim()
    else
      _ -> nil
    end
  end

  # a term naming an Act stands for the Act, not the Part before its title
  # ("Part I of the Health and Safety at Work etc. Act 1974 (“the 1974
  # Act”)": Offshore Safety Act 1992 s.1(1), CV-06 S7)
  defp of_the_act(t, term) do
    if term =~ ~r/\b(?:Act|Regulations|Order|Rules|Measure)$/u,
      do:
        String.replace(
          t,
          ~r/^(?:(?:Part|Chapter|section|Schedule)\s+\w+\s+(?:to|of)\s+(?:the\s+)?)/u,
          ""
        ),
      else: t
  end

  defp law(uri) do
    case Regex.run(~r"/id/([a-z]+)/(\d{4})/(\d+)", uri) do
      [_, type, year, number] -> "UK_#{type}_#{year}_#{number}"
      nil -> nil
    end
  end

  defp title(words) do
    case Regex.run(~r/\bmeans (?:the )?([^;:]+?)\s*#{@item_end}$/u, words) do
      [_, t] -> t |> String.trim() |> unchaptered()
      nil -> nil
    end
  end

  # "the Town and Country Planning Act 1990 (c. 8)": the title without its
  # chapter, which hid it from the title test (Planning Act 2008's "TCPA
  # 1990", CV-S05)
  # (and a Northern Ireland Order's number: "Order 1997 (NI 19)", NIA 2011/5
  # s.13; an instrument's "(S.I. 2004/3391)"; Amending-law reader: yield,
  # 2026-11-27)
  defp unchaptered(t),
    do:
      String.replace(
        t,
        ~r/\s*\((?:(?:c|asp|anaw|nia|mwa)\.?\s*\d+|N\.?I\.?\s*\d+|S\.(?:S\.|R\.)?I\.?\s*\d{4}\/\d+)\)$/u,
        ""
      )
end

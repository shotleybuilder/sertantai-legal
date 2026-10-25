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
  def of(%Doc{roots: roots}) do
    for root <- roots,
        text <- xpath(root, ~x"//*[local-name()='Text'][*[local-name()='Term']]"l),
        term <- xpath(text, ~x"./*[local-name()='Term']"l),
        into: %{} do
      raw = Doc.text(term)
      name = String.downcase(raw)
      words = Doc.text(text)
      uri = text |> xpath(~x"./*[local-name()='Citation']/@URI"s) |> to_string()
      {name, %{law: law(uri), title: title(words) || apposition(words, raw)}}
    end
    |> Map.merge(plain(roots))
    |> Map.filter(fn {name, t} -> name != "" and (t.law != nil or law_title?(t.title)) end)
  end

  # a definition with no Term markup — “the 2015 Act” (“Deddf 2015”) means
  # the Planning (Wales) Act 2015 (Welsh orders: WSI 2017/546)
  # a definition's end: ";", "." or a list item's ",", each perhaps with
  # "and" / "or":
  # "“the 1981 Act” means the Wildlife and Countryside Act 1981 (c.69),"
  # (asp 2011/6, CV-S05)
  @item_end ~S"(?:[;.,](?:\s*(?:and|or))?)?\s*"

  @plain ~r/^\s*“([^”]+)”\s*(?:\(“[^”]*”\)\s*)?means\s+(?:the\s+)?(.+?)\s*#{@item_end}$/u

  defp plain(roots) do
    for root <- roots,
        text <- xpath(root, ~x"//*[local-name()='Text'][not(*[local-name()='Term'])]"l),
        words = Doc.text(text),
        [_, term, title] <- [Regex.run(@plain, words)],
        into: %{},
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
  @thing_under ~r/^(?:a|an|any|that|those|each|every)\s|\b(?:under|purposes\s+of|meaning\s+of|defined\s+in|set\s+out\s+in|(?:section|article|regulation|Schedule|Part)\s+\w+\s+(?:to|of))\s+(?:the\s+)?[A-Z]/u

  defp law_title?(nil), do: false
  defp law_title?(t), do: Regex.match?(@law_title, t) and not Regex.match?(@thing_under, t)

  # "… the Firearms Act 1968 (in this Act referred to as “the principal Act”)":
  # the law's title just before the parenthesis holding the term
  defp apposition(words, term) do
    with [before | _] <- String.split(words, "“#{term}”", parts: 2),
         [_, head] <- Regex.run(~r/^(.*)\([^()]*$/su, before),
         [_, t] <-
           Regex.run(
             ~r/([A-Z][\w,'’\-]*(?: (?:[A-Z][\w,'’\-]*|and|of|the|for|etc\.|\(Northern Ireland\)))* (?:Act|Regulations|Order|Rules|Measure) \d{4})\s*$/u,
             head
           ) do
      # "In the Town and Country Planning Act 1990": the title, not the words before it
      t
      |> String.replace(~r/^(?:(?:In|Under|By|For|To|Of|And|The|the|of|and) )+/u, "")
      |> String.trim()
    else
      _ -> nil
    end
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
  defp unchaptered(t), do: String.replace(t, ~r/\s*\((?:c|asp|anaw|nia|mwa)\.?\s*\d+\)$/u, "")
end

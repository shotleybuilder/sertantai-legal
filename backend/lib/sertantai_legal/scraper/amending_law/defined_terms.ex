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
    |> Map.filter(fn {name, t} -> name != "" and (t.law != nil or law_title?(t.title)) end)
  end

  @law_title ~r/\b(?:Act|Regulations|Order|Rules|Measure)(?: \(Northern Ireland\))? \d{4}$/u

  defp law_title?(nil), do: false
  defp law_title?(t), do: Regex.match?(@law_title, t)

  # "… the Firearms Act 1968 (in this Act referred to as “the principal Act”)":
  # the law's title just before the parenthesis holding the term
  defp apposition(words, term) do
    with [before | _] <- String.split(words, "“#{term}”", parts: 2),
         [_, head] <- Regex.run(~r/^(.*)\([^()]*$/su, before),
         [_, t] <-
           Regex.run(
             ~r/([A-Z][\w,'’\-]*(?: (?:[A-Z][\w,'’\-]*|and|of|the|for|\(Northern Ireland\)))* (?:Act|Regulations|Order|Rules|Measure) \d{4})\s*$/u,
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
    case Regex.run(~r/\bmeans (?:the )?([^;:]+?)\s*[;.]?\s*$/u, words) do
      [_, t] -> String.trim(t)
      nil -> nil
    end
  end
end

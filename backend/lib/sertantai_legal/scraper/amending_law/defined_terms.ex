defmodule SertantaiLegal.Scraper.AmendingLaw.DefinedTerms do
  @moduledoc """
  The laws an amending law names by a defined term (lat-refactor LR-08):
  "“the 1989 Act” means the Electricity Act 1989" → "the 1989 act" →
  `%{law: "UK_ukpga_1989_29", title: "Electricity Act 1989"}`. The law comes
  from the definition's `Citation` URI when it has one (structure, not
  prose); the title is the words after "means". Pure.
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
      name = term |> Doc.text() |> String.downcase()
      words = Doc.text(text)
      uri = text |> xpath(~x"./*[local-name()='Citation']/@URI"s) |> to_string()
      {name, %{law: law(uri), title: title(words)}}
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

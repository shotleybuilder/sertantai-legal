defmodule SertantaiLegal.Scraper.LawStart.EuWords do
  @moduledoc """
  EU law's commencing words in the form the domestic commencement readers
  read (Jason 2026-11-21, `eu-applies-from-is-the-start`). An EU regulation
  binds from the day it applies, so "It shall apply from 1 January 2010"
  reads as "This Regulation shall come into force on 1 January 2010", and
  "Articles 1 and 2 shall apply from 1 January 2017" as "Articles 1 and 2
  shall come into force on 1 January 2017". "This Regulation shall enter
  into force on …" is left as written: where no apply-from day is stated,
  `LawStart.Eu` dates the law from it (or from EUR-Lex). Applied once, to an
  EU law's rows, where the reader's input is built (`LawStart.Input`). Pure.
  """

  # "It shall apply from", "This Regulation shall apply as from"
  @whole ~r/\b(?:It|This\s+(?:Regulation|Decision))\s+shall\s+apply\s+(?:as\s+)?from\s+/
  # "Articles 1 and 2 shall apply from", "points (2) and (5) of Article 7 … shall apply from"
  @provisions ~r/\bshall\s+apply\s+(?:as\s+)?from\s+(?=(?:the\s+)?\d)/

  @doc "The text with EU apply-from wording in the domestic form; nil stays nil."
  @spec domestic(String.t() | nil) :: String.t() | nil
  def domestic(nil), do: nil

  # (words in quotation marks another law inserts are never this law's own:
  # "the following paragraph shall be added: «… shall apply from 1 December
  # 2010»", EUR 2008/1272)
  @quoted ~r/«[^»]*»?|“[^”]*”?/u

  def domestic(text) do
    @quoted
    |> Regex.split(text, include_captures: true)
    |> Enum.map_join(fn piece ->
      if Regex.match?(~r/^[«“]/u, piece), do: piece, else: own(piece)
    end)
  end

  defp own(text) do
    text
    |> String.replace(@whole, "This Regulation shall come into force on ")
    |> String.replace(@provisions, "shall come into force on ")
  end
end

defmodule SertantaiLegal.Scraper.LawStart.ItemSubject do
  @moduledoc """
  The words of a commencement list item that name its own provisions: the
  item without its description in brackets and without its qualifier. In
  "regulation 4(c) (amendment of regulation 17A of the 2008 Regulations:
  new definition of “valid claim”)" (SI 2025/662 reg.1(2)(a)) they are
  "regulation 4(c)", and in "section 32(3) so far as relating to section
  91ZD of that Act" (2022 c.30 s.170(4)(a)(ii)) "section 32(3)": another
  law named only in the description or the qualifier is no part of what
  the item brings into force. Pure.
  """

  # a description: a bracket of several words (a number's own bracket,
  # "7(2)", has none)
  @description ~r/\s*\((?=(?:[^()]|\([^()]*\))*\s)(?:[^()]|\([^()]*\))*\)/u
  @qualifier ~r/,?\s*\b(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|for\s+the\s+purposes?\s+(?:only\s+)?of|in\s+relation\s+to|with\s+respect\s+to|to\s+the\s+extent|in\s+respect\s+of)\b/i

  @doc """
  `item` before its qualifier, its bracketed descriptions dropped; "" where
  the item opens with its qualifier.
  """
  @spec words(String.t()) :: String.t()
  def words(item) do
    @description
    |> Regex.replace(item, "")
    |> String.split(@qualifier, parts: 2)
    |> hd()
    |> String.trim()
  end
end

defmodule SertantaiLegal.Scraper.Amendment.Reader.Savings do
  @moduledoc """
  A repeal the amending law's own text saves (CV-06 round 1, R2): the
  provision is repealed with savings (D3: repealed_saved), as the feed's
  Savings say for later laws.

  - The table line's own qualification: "The whole section except for the
    purposes of section 135" (SI 1974/1941 on the Factories Act 1961
    s.168), "… except in relation to offences committed before 1st January
    1975" (s.161).
  - A saving in the provision giving the repeals Schedule effect, naming
    the law: "Nothing in this regulation shall affect the operation of any
    provision of the Offices, Shops and Railway Premises Act 1963 as …"
    (SI 1992/3004 reg.27(2)).

  "so far as not repealed by …", "so far as still in operation" limit what
  is repealed; they save nothing; nor "except in so far as it extends to
  Northern Ireland" (SI 1974/1941 on the Factories Act 1961 s.77(2)): where
  the repeal reaches.

  Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

  @qualified ~r/\b(?:except|save)\s+(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|as\s+respects|so\s+far\s+as\s+(?:it|they)\s+(?:relates?|appl(?:y|ies))|(?:in\s+)?so\s+far\s+as\b(?!\s+(?:it|they)\s+extends?\b)|insofar\s+as\b(?!\s+(?:it|they)\s+extends?\b))/i

  @nothing ~r/\bNothing\s+in\s+(?:this|these)\s+(?:regulations?|sections?|articles?|paragraphs?|Schedules?)\b[^.]{0,200}?\baffects?\b[^.]*/i

  @doc "True when a repeals-table line qualifies its repeal with a saving."
  @spec line?(String.t() | nil) :: boolean()
  def line?(nil), do: false
  def line?(line), do: Regex.match?(@qualified, line)

  @doc """
  True when the provision giving the Schedule effect (`intro`, its text)
  saves the law `title` (no year) of `year` from its repeals.
  """
  @spec intro?(String.t() | nil, String.t() | nil, String.t()) :: boolean()
  def intro?(nil, _title, _year), do: false
  def intro?(_intro, nil, _year), do: false

  def intro?(intro, title, year) do
    named = LawNamed.norm("#{title} #{year}")

    @nothing
    |> Regex.scan(intro)
    |> Enum.any?(fn [sentence] -> String.contains?(LawNamed.norm(sentence), named) end)
  end
end

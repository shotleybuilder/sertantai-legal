defmodule SertantaiLegal.Scraper.Amendment.Reader.EuCitation do
  @moduledoc """
  An EU instrument cited by number, as a law named (CV-S05 round 6): the
  reader's "nearest text naming any law" (`LawNamed`) knew UK titles,
  chapters and defined terms only, so "Regulation (EU) No 649/2012 is
  amended as follows" named nothing and the walk back reached an earlier
  Part's UK law (SI 2019/720 Sch. 2 para 168, "After Article 23, insert—",
  had read as COSHH 2002 regs 1–7).

  - "Regulation (EC) No 1907/2006": number / year;
  - "Regulation (EU) 2016/425": year / number;
  - "Directive 89/391/EEC", "Decision 2000/532/EC": year / number (a
    two-digit year: 19YY).

  Only where the citation is what's amended (`naming?/1`). `ref/1` gives
  `%{law: nil, eu: {type, year, number}}`, the type as the register names
  it (`eur`, `eudr`, `eudn`). Pure.
  """

  @pattern ~r/\b(Regulation|Directive|Decision)\s+(?:\((?:EU|EC|EEC|Euratom)(?:,\s*Euratom)?\)\s+)?(?:No\.?\s+(\d+)\/(\d{2,4})\b|(\d{2,4})\/(\d+)(?:\/(?:EEC|EC|EU|Euratom))?\b)/u

  @types %{"Regulation" => "eur", "Directive" => "eudr", "Decision" => "eudn"}

  # where the citation is what's amended — never a passing mention ("for
  # the purpose of complying with Council Directive 91/439/EEC", a
  # definitions list's "Directive 2003/87/EC"), which would stop the walk
  # back before the UK law amended (SI 1996/1974, SI 2020/1369)
  @eu_head "(?:(?:Commission|Council)\\s+)?(?:(?:Implementing|Delegated)\\s+)?(?:Regulation|Directive|Decision)\\b"
  @naming [
    # "Regulation (EU) No 649/2012 is amended as follows"
    Regex.compile!(
      "^\\s*" <> @eu_head <> "[^.;]*?\\b(?:is|are)\\s+(?:further\\s+)?amended\\b",
      "u"
    ),
    # "In Regulation (EU) 2016/425, …"
    Regex.compile!("^\\s*In\\s+" <> @eu_head, "u"),
    # a heading: "Amendment of Regulation (EU) 2016/425"
    Regex.compile!("^\\s*Amendments?\\s+(?:of|to)\\s+(?:the\\s+)?" <> @eu_head, "iu")
  ]

  @doc "The citation's pattern: kind, then number/year (\"No N/Y\") or year/number."
  @spec pattern() :: Regex.t()
  def pattern, do: @pattern

  @doc "Whether a text names its EU citations as the law amended (see `@naming`)."
  @spec naming?(String.t()) :: boolean()
  def naming?(text), do: Enum.any?(@naming, &Regex.match?(&1, text))

  @doc "The citations' matches (`Regex.scan/3` with `opts`) where the text names them as the law amended; else none."
  @spec scan(String.t(), keyword()) :: [list()]
  def scan(text, opts \\ []),
    do: if(naming?(text), do: Regex.scan(@pattern, text, opts), else: [])

  @doc "A citation's match (`pattern/0`'s groups, whole match first) as a law named; nil when not one."
  @spec ref([String.t()]) :: map() | nil
  def ref([_whole, kind, n, y | _]) when n != "",
    do: %{law: nil, eu: {@types[kind], year(y), n}}

  def ref([_whole, kind, _, _, y, n]) when y != "" and n != "",
    do: %{law: nil, eu: {@types[kind], year(y), n}}

  def ref(_), do: nil

  defp year(<<_, _>> = yy), do: if(String.to_integer(yy) >= 50, do: "19" <> yy, else: "20" <> yy)
  defp year(yyyy), do: yyyy
end

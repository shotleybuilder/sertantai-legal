defmodule SertantaiLegal.Scraper.Commencement.Order.Identity do
  @moduledoc """
  Which Act a commencement order names and commences: its own title, and the
  ways it names the Act ("the Act", a defined term, the Act's title).

  Pure; part of the order reader (`Commencement.Order`).
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc, Text}

  alias SertantaiLegal.Scraper.Commencement.Order

  alias SertantaiLegal.Scraper.Commencement.Order.Words

  @doc "The law's title from its own CLML (`dc:title`), without the year: for an Act `uk_lrt` doesn't hold."
  @spec title(Doc.t()) :: String.t() | nil
  def title(doc) do
    case full_title(doc) do
      nil -> nil
      # the year it ends with, never one inside it (SI 2015/1637: "The
      # Deregulation Act 2015 (…) Order 2015" is not the Deregulation Act)
      t -> t |> String.replace(~r/\s+\d{4}\s*$/, "") |> String.trim()
    end
  end

  @doc "The order's own title, with its year."
  @spec full_title(Doc.t()) :: String.t() | nil
  def full_title(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      case root
           |> xpath(
             ~x"//*[local-name()='title' and namespace-uri()='http://purl.org/dc/elements/1.1/']/text()"s
           )
           |> to_string() do
        "" -> nil
        t -> t
      end
    end)
  end

  # ── does the order commence the Act ─────────────────────────────────

  @doc "True when the order commences `act` (its \"the Act\", else its title named in its words)."
  @spec commences?(Doc.t(), Order.act()) :: boolean()
  def commences?(order, act) do
    case DefinedTerms.of(order)["the act"] do
      %{law: law} when is_binary(law) -> law == act.law
      %{title: t} when is_binary(t) -> named?(t, act)
      _ -> Enum.any?(order.ids, &named?(Text.words_of(order, &1), act))
    end
  end

  # the Act's title and year, never as the tail of a longer title: "the
  # Police and Fire Reform (Scotland) Act 2012" is not the Scotland Act 2012
  # (SSI 2013/51, listed for both)
  @before_title ~w(the of to under by in and as with for said a an)

  @doc "True when the words name the Act by its title and year, never inside another law's title."
  @spec named?(String.t(), map()) :: boolean()
  def named?(text, %{title: title, year: year}) when is_binary(title) do
    name = Words.norm("#{title} #{year}")

    ~r/(?:^|(\w+) )#{Regex.escape(name)}(?: |$)/
    |> Regex.scan(Words.norm(text))
    |> Enum.any?(fn
      [_, before] -> before in @before_title
      [_] -> true
    end)
  end

  def named?(_text, _act), do: false

  # the ways the order names the Act: "the Act", a term meaning it ("the
  # 2006 Act"), its title
  @doc "The ways the order names the Act: \"the Act\", a defined term meaning it, its title."
  @spec aliases(Doc.t(), Order.act()) :: [String.t()]
  def aliases(order, act) do
    terms =
      for {term, %{law: l, title: t}} <- DefinedTerms.of(order),
          l == act.law or (is_binary(t) and named?(t, act)),
          do: term

    # "the 1989 Act" names the Act unless the order defines it as another
    # (SI 1997/134, CV-S04)
    year =
      case DefinedTerms.of(order)["the #{act.year} act"] do
        %{law: l} when is_binary(l) and l != act.law -> []
        _ -> ["the #{act.year} act"]
      end

    Enum.uniq(
      ["the act" | terms] ++
        year ++ if(act.title, do: [Words.norm("#{act.title} #{act.year}")], else: [])
    )
  end
end

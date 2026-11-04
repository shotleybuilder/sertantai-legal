defmodule SertantaiLegal.Scraper.MakingLaws do
  @moduledoc """
  Whether a law is making, read from its own text (LAT Change Pipeline,
  step: Making laws). Pure: the law's document (`AmendingLaw.Doc`, body and
  Schedules) comes in as data.

  Each provision with words of its own, outside quoted inserted text, is
  one kind (`kind/2`):

  - `:change` — it amends, revokes, modifies ("shall have effect as if") or
    commences another law or provision (the amending-law reader's clause
    operations and repeals tables);
  - `:requirement` — it states "shall" or "must" on someone, once standard
    phrases are set aside;
  - `:power` — "may";
  - `:standard` — citation, the law's own commencement, interpretation,
    application, offences, and the rest.

  A law with one own requirement is making; one with changes and no own
  requirement or power is not; powers only, or standard wording only, or
  no text, gives no verdict (unknown over guess: the law goes to Jason).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader.{Clauses, RepealTable}
  alias SertantaiLegal.Scraper.LatParser.Xml

  @type kind :: :change | :requirement | :power | :standard
  @type result :: %{
          verdict: :making | :not_making | nil,
          reason: String.t(),
          counts: %{kind() => non_neg_integer()},
          first: %{kind() => String.t()}
        }

  @provision ~r/^(?:(?:section|regulation|article|rule)-\d|schedule-[^-]+-(?:part-[^-]+-)?paragraph-)/
  @quoted ~w(BlockAmendment InlineAmendment)a

  # as the amendment reader's: a modification, not an amendment
  @modification ~r/\b(?:have effect|be read|be construed) as if\b/i
  @amended ~r/\b(?:is|are|shall be) (?:further |hereby )?(?:amended|modified)\b|\b(?:amended|modified) (?:as follows|in accordance with)\b|\b(?:is|are|shall be) (?:hereby )?revoked\b|\brevocations?\b/i
  @commences ~r/\bcomes? into force\b|\bcoming into force\b|\bappointed day\b/i
  # the law's own: its first words name it ("These Regulations …", "This Order
  # may be cited … and comes into force"), never "the Schedule to this Order"
  @own_commencement ~r/^(?:These|This) (?:Regulations|Order|Rules|Act|Scheme|Instrument)\b[^.]*\bcomes? into force\b/

  # phrases using "shall", "must" or "may" that state no requirement or power
  @standard_phrases [
    ~r/\bmay be (?:cited|referred to)\b/i,
    ~r/\bwherever (?:they|it|he|she) may be\b/i,
    ~r/\b(?:as the case may be|as (?:nearly|near|soon) as may be)\b/i,
    ~r/\b(?:shall|must)(?: not| each| also)? (?:be (?:construed|read|treated|deemed|taken|cited|guilty|liable|known)|affect|have (?:the same )?(?:effect|meaning)|mean|include|(?:not )?apply|cease|continue|come into force|expire)\b/i,
    ~r/\bshall be (?:amended|inserted|substituted|omitted|revoked|repealed|added|renumbered|deleted|left out)\b/i
  ]
  @requirement ~r/\b(?:shall|must)\b/i
  # lower case: "1st May 2020" is a date
  @power ~r/\bmay\b/

  @doc "The law's verdict, why, and its provisions counted by kind (nil: no text held)."
  @spec classify(Doc.t() | nil) :: result()
  def classify(nil), do: %{verdict: nil, reason: "no text", counts: %{}, first: %{}}

  def classify(%Doc{} = doc) do
    kinds = for id <- provisions(doc), do: {id, kind(doc, id)}
    counts = Enum.frequencies_by(kinds, &elem(&1, 1))

    first =
      kinds
      |> Enum.reverse()
      |> Map.new(fn {id, k} -> {k, id} end)

    {verdict, reason} = verdict(counts, first)
    %{verdict: verdict, reason: reason, counts: counts, first: first}
  end

  defp verdict(%{requirement: n}, first),
    do: {:making, "#{n} own requirement#{if n > 1, do: "s"} (first #{first.requirement})"}

  defp verdict(%{power: _, change: _}, _), do: {nil, "changes and powers"}
  defp verdict(%{power: _}, _), do: {nil, "powers only"}
  defp verdict(%{change: _}, _), do: {:not_making, "changes only"}
  defp verdict(_, _), do: {nil, "no operative provision"}

  @doc "The law's provisions with words of their own, outside quoted text, in document order."
  @spec provisions(Doc.t()) :: [String.t()]
  def provisions(%Doc{} = doc) do
    quoted = quoted_ids(doc)

    for id <- doc.ids,
        id =~ @provision,
        not MapSet.member?(quoted, id),
        own_words(doc, id) != "",
        do: id
  end

  @doc "A provision's kind (see the moduledoc)."
  @spec kind(Doc.t(), String.t()) :: kind()
  def kind(doc, id) do
    text = Text.of(doc, id)
    words = own_words(text)

    cond do
      change?(doc, id, text, words) -> :change
      unstandard(words) =~ @requirement -> :requirement
      unstandard(words) =~ @power -> :power
      words =~ @commences and not (words =~ @own_commencement) -> :change
      true -> :standard
    end
  end

  defp change?(doc, id, text, words) do
    words =~ @modification or words =~ @amended or RepealTable.repeal_table?(doc, id) or
      Enum.any?(Clauses.clauses(text), &Clauses.operation/1)
  end

  defp own_words(doc, id), do: doc |> Text.of(id) |> own_words()
  defp own_words(nil), do: ""
  defp own_words(%Text{instruction: i}), do: i |> Clauses.unquote_words() |> String.trim()

  defp unstandard(words), do: Enum.reduce(@standard_phrases, words, &Regex.replace(&1, &2, " "))

  # ids inside quoted inserted text: the amended law's provisions, not this law's
  defp quoted_ids(doc) do
    for root <- doc.roots,
        q <- Xml.descendants(root),
        Xml.tag(q) in @quoted,
        el <- Xml.descendants(q),
        id = Xml.attr_or_nil(el, :id),
        into: MapSet.new(),
        do: id
  end
end

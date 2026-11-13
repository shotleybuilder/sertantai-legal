defmodule SertantaiLegal.Scraper.MakingLaws do
  @moduledoc """
  Whether a law is making, read from its own text (LAT Change Pipeline,
  step: Making laws). Pure: the law's document (`AmendingLaw.Doc`, body and
  Schedules) comes in as data.

  Each provision with words of its own, outside quoted inserted text, is
  one kind (`kind/2`):

  - `:change` — it amends, revokes, modifies ("shall have effect as if") or
    commences another law or provision (the amending-law reader's clause
    operations and repeals tables; the commencement reader's sentence forms);
  - `:requirement` — it states "shall" or "must" on someone, once standard
    phrases are set aside;
  - `:designation` — it establishes something with legal effect of its
    own ("A safety zone is established around …": Fire and OH&S Decision 1);
  - `:power` — "may";
  - `:standard` — citation, the law's own commencement, interpretation,
    application, offences, and the rest.

  A law with one own requirement or designation is making; one with changes and no own
  requirement or power is not; powers only, or standard wording only, or
  no text, gives no verdict (unknown over guess: the law goes to Jason).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader.{Clauses, RepealTable}
  alias SertantaiLegal.Scraper.Commencement.SentencePatterns
  alias SertantaiLegal.Scraper.LatParser.Xml

  @type kind :: :change | :requirement | :designation | :power | :standard
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
  # "the appointed day", or "the day appointed for the coming into force"
  @appointed_day ~r/\b(?:appointed day|day appointed)\b/i
  # a commencement of the law itself names it first ("These Regulations …",
  # "This Order may be cited … and comes into force"), never "the Schedule
  # to this Order"
  @names_itself ~r/^(?:These|This) (?:Regulations|Order|Rules|Act|Scheme|Instrument)\b/

  # phrases using "shall", "must" or "may" that state no requirement or power
  @standard_phrases [
    ~r/\bmay be (?:cited|referred to)\b/i,
    ~r/\bwherever (?:they|it|he|she) may be\b/i,
    ~r/\b(?:as the case may be|as (?:nearly|near|soon) as may be)\b/i,
    # an aside of one or two parts may stand between "shall" and its verb
    # ("shall, unless the context otherwise requires, be construed"; "shall,
    # except where the context otherwise requires, or where the reference is
    # otherwise expressly amended, be construed": SI 1974/2013 reg. 6)
    ~r/\b(?:shall|must)(?:, [^,]+(?:, [^,]+)?,)?(?: not| each| also)? (?:be (?:construed|read|treated|deemed|taken|cited|guilty|liable|known|conclusive|received)|affect|have (?:the same )?(?:effect|meaning)|mean|include|(?:not )?apply|cease|continue|expire|extend(?: and apply)?|remain in (?:force|effect))\b/i,
    ~r/\bshall be (?:amended|inserted|substituted|omitted|revoked|repealed|added|renumbered|deleted|left out)\b/i
  ]
  @requirement ~r/\b(?:shall|must)\b/i
  # a lead-in whose verb is in its list items
  @lead_in ~r/\b(?:shall|must)\s*[–—-]\s*$/iu
  # a designation with legal effect of its own: an offshore safety zone,
  # where the Petroleum Act 1987 s.23 forbids entry (Jason 2026-11-13,
  # Fire and OH&S: Making laws, Decision 1)
  @designation ~r/\bsafety zones? (?:is|are) (?:hereby )?established\b/i
  # lower case: "1st May 2020" is a date
  @power ~r/\bmay\b/

  @doc "The law's verdict, why, and its provisions counted by kind (nil: no text held; no provision ids: none upstream)."
  @spec classify(Doc.t() | nil) :: result()
  def classify(nil), do: %{verdict: nil, reason: "no text", counts: %{}, first: %{}}

  def classify(%Doc{} = doc) do
    if Enum.any?(doc.ids, &(&1 =~ @provision)),
      do: classify_provisions(doc),
      else: %{verdict: nil, reason: "no provisions upstream", counts: %{}, first: %{}}
  end

  # legislation.gov.uk holds some laws as a scanned print only: the XML has
  # no provisions (NumberOfProvisions="0")
  defp classify_provisions(doc) do
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

  defp verdict(%{designation: n}, first),
    do: {:making, "#{n} designation#{if n > 1, do: "s"} (first #{first.designation})"}

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
    words = text |> own_words() |> with_items(text)

    cond do
      change?(doc, id, text, words) -> :change
      commencement(words) == :own -> :standard
      # commencement words the reader reads as no statement ("Where …, the
      # relevant provisions shall come into force for the purposes of …")
      SentencePatterns.commencement_words?(words) -> :standard
      words =~ @designation -> :designation
      unstandard(words) =~ @requirement -> :requirement
      unstandard(words) =~ @power -> :power
      true -> :standard
    end
  end

  defp change?(doc, id, text, words) do
    words =~ @modification or words =~ @amended or commencement(words) == :other or
      RepealTable.repeal_table?(doc, id) or Enum.any?(Clauses.clauses(text), &Clauses.operation/1)
  end

  # commencement words are the commencement reader's (`SentencePatterns`):
  # a statement that the law itself comes into force (`:own`), that
  # something else does or an appointed day (`:other`), else nil
  defp commencement(words) do
    cond do
      words =~ @appointed_day -> :other
      not commencement_statement?(words) -> nil
      words =~ @names_itself -> :own
      true -> :other
    end
  end

  defp commencement_statement?(words),
    do:
      SentencePatterns.commencement_words?(words) and
        SentencePatterns.form(words).role == "statement"

  defp own_words(doc, id), do: doc |> Text.of(id) |> own_words()
  defp own_words(nil), do: ""
  defp own_words(%Text{instruction: i}), do: i |> Clauses.unquote_words() |> String.trim()

  # a lead-in ending "shall–" takes its verb from each list item ("a
  # prohibition notice … shall– (a) remain in effect, and (b) be deemed to
  # be …": SSI 2006/475 art. 3), so each item is read as "shall <item>"
  defp with_items(words, %Text{items: [_ | _] = items}) do
    case Regex.split(@lead_in, words, include_captures: true, trim: true) do
      [before, shall] -> before <> Enum.map_join(items, "; ", &"#{lead(shall)} #{&1}")
      _ -> words
    end
  end

  defp with_items(words, _), do: words

  defp lead(shall), do: String.replace(shall, ~r/\s*[–—-]\s*$/u, "")

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

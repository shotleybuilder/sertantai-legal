defmodule SertantaiLegal.Scraper.Amendment.Patterns do
  @moduledoc """
  The amending provisions the read pass reads, as patterns in the
  amendment reader's terms (change vocabulary CV-S06; the CV-S04/S05
  catalogues' shape). Each provision read for an amended law is classed by
  its form and by what `Amendment.Reader.read/4` made of it; one pattern
  per combination (`key/2`):

  - `shape`: `table` (a repeals table), `modification` ("shall have effect
    as if"), `set_out` (the block set out in its own Schedule), `no_verb`
    (no change verb: "The 1989 Act is amended as follows.", "In section
    5—"), or `instruction`;
  - `verb`: the change verbs its clauses use, in order of first use
    (`substituted`, `inserted`, `repealed`, joined by `+`), `renumbered`
    where it renumbers ("renumbered as", "becomes"), or `-`;
  - `quote`: `block` (the quote numbers provisions: inserted paths),
    `words` (quoted words only), or `none`;
  - `place`: `schedule` where the instruction or a provision holding it
    names a Schedule or Annex of the amended law (not read as targets
    while Schedules are not parsed: a v0.1 limit), else `body`;
  - `law`: `named` where the words the reader looks in (the instruction,
    its context, its headings, the text before) name the amended law, else
    `unnamed`;
  - `outcome`: `rules:<operations>:<levels>` (sorted, `+`-joined), or
    `none` (no rule for the law).

  Pure: the document and the law's ref come in as data.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}
  alias SertantaiLegal.Scraper.Amendment.Reader.{Clauses, LawNamed, RepealTable}

  @type form :: %{
          shape: String.t(),
          verb: String.t(),
          quote: String.t(),
          place: String.t(),
          law: String.t()
        }

  # as Reader's: a modification, not an amendment
  @modification ~r/\b(?:have effect|be read|be construed) as if\b/i
  @set_out ~r/\bset out in (?:Part [IVXLC\d]+[A-Z]? of )?Schedule [\dA-Z]+\b/i
  @schedule ~r/\b(?:Schedule|Annex|Appendix)\s+(?-i:[\dIVXLC]+[A-Z]*)\b/i
  @renumbered ~r/\bre-?numbered\b|\bshall become\b|\bbecomes?\s+(?:section|regulation|article|paragraph|sub-?section|sub-?paragraph)\b/i

  @doc "The form of provision `id` of `doc` read for `law` (`terms`: the doc's defined terms)."
  @spec form(Doc.t(), String.t(), map(), Reader.law_ref()) :: form()
  def form(doc, id, terms, law) do
    if RepealTable.repeal_table?(doc, id) do
      %{
        shape: "table",
        verb: "repealed",
        quote: "none",
        place: "body",
        law: table_law(doc, id, terms, law)
      }
    else
      case Text.of(doc, id) do
        %Text{} = text -> text_form(text, Doc.title(doc, id), terms, law)
        nil -> %{shape: "not_held", verb: "-", quote: "none", place: "body", law: "unnamed"}
      end
    end
  end

  defp text_form(text, title, terms, law) do
    i = text.instruction
    verbs = verbs(text)

    shape =
      cond do
        i =~ @modification -> "modification"
        text.inserted == [] and i =~ @set_out -> "set_out"
        verbs == [] -> "no_verb"
        true -> "instruction"
      end

    verb =
      cond do
        Clauses.unquote_words(i) =~ @renumbered -> "renumbered"
        verbs == [] -> "-"
        true -> Enum.join(verbs, "+")
      end

    quote =
      cond do
        text.inserted != [] -> "block"
        text.quoted != "" -> "words"
        true -> "none"
      end

    %{
      shape: shape,
      verb: verb,
      quote: quote,
      place: place(text),
      law: law_named(text, title, terms, law)
    }
  end

  # where it changes: a Schedule or Annex named in its own words or a
  # holding provision's (quotes and captions aside)
  defp place(text) do
    if Enum.any?([text.instruction | text.parents], fn w ->
         w |> Clauses.unquote_words() |> Clauses.no_captions() =~ @schedule
       end),
       do: "schedule",
       else: "body"
  end

  # each clause's verb, in order of first use
  defp verbs(text) do
    for c <- Clauses.clauses(text),
        {op, _} <- [Clauses.operation(c)],
        uniq: true,
        do: op
  end

  # the words the reader looks in for the law (`Reader.of_text/5`)
  defp law_named(text, title, terms, law) do
    texts = Enum.map([text.instruction | Enum.reverse(text.context)], &Clauses.unquote_words/1)
    uncaptioned = Enum.map(texts, &Clauses.uncaptioned/1)
    before = Stream.map(text.before, &Clauses.unquote_words/1)

    named =
      LawNamed.named(Stream.concat(uncaptioned ++ List.wrap(title), before), terms)

    if Enum.any?(named, &LawNamed.law_named?(&1, law)), do: "named", else: "unnamed"
  end

  defp table_law(doc, id, terms, law) do
    words = doc |> Doc.element(id) |> Doc.text()

    if Enum.any?(LawNamed.named([words], terms), &LawNamed.law_named?(&1, law)),
      do: "named",
      else: "unnamed"
  end

  @doc "The outcome of the rules read: `rules:<operations>:<levels>`, or `none`."
  @spec outcome([Rule.t()]) :: String.t()
  def outcome([]), do: "none"

  def outcome(rules) do
    ops = rules |> Enum.map(&Atom.to_string(&1.operation)) |> Enum.uniq() |> Enum.sort()
    levels = rules |> Enum.map(&Atom.to_string(&1.level)) |> Enum.uniq() |> Enum.sort()
    "rules:#{Enum.join(ops, "+")}:#{Enum.join(levels, "+")}"
  end

  @doc "A pattern's key: the form's fields and the outcome, `|`-joined."
  @spec key(form(), String.t()) :: String.t()
  def key(f, outcome), do: Enum.join([f.shape, f.verb, f.quote, f.place, f.law, outcome], "|")

  @doc "The class of provision `id` read for `law`: its pattern key and the rules."
  @spec class(Doc.t(), String.t(), map(), Reader.law_ref()) :: {String.t(), [Rule.t()]}
  def class(doc, id, terms, law) do
    rules = Reader.read(doc, id, terms, [law])
    {key(form(doc, id, terms, law), outcome(rules)), rules}
  end
end

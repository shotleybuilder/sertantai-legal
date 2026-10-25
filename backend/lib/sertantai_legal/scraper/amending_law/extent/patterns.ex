defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns do
  @moduledoc """
  A law's own extent and application sentences as patterns, in the extent
  reader's terms (change vocabulary CV-S05; the CV-S04 catalogue's shape:
  `Commencement.SentencePatterns`). Every sentence of a top-level provision
  saying where the law (or some of it) extends or applies is classed by its
  form and by what `AmendingLaw.Extent.read/1` made of it; one pattern per
  combination:

  - `kind`: `extent` ("extends to", "does not extend to", "the same extent
    as"), `application` ("apply in relation to Wales"), or both;
  - `subject`: `whole` (this Act, these Regulations, the provisions of this
    Order), `following` (a list below), `parts`, `schedules`, `this` (this
    section), `amendments` ("an amendment or repeal … has the same extent
    as the enactment"), `named` (provisions by number), or `other`;
  - `verb`: `extends`, `not_extends`, `same_extent`, `applies`,
    `not_applies`, or `other`;
  - `lead`: `except`, `apart_from`, `subject_to`, or `none`;
  - `places`: how many places it names (0, 1, `many`); `only`, `also`;
  - `outcome`: `default:<code>` (the law's own extent read from it),
    `list:<kind>:<code>` (a list heading read; `same` for the enactments'
    extent), `part_not:<code>`, `applies:<code>` (the law's application),
    or `unread:<why>` — `in_clause` (in the clause read, no statement
    taken), `another_default` (a later default in the clause), `list`,
    `part_not`, `other_provision` (a statement outside the clause read),
    `application` (an application clause not resolved), `not_read` (the
    law's own statement, not read), `provision_extent` /
    `provision_application` (a provision's own: "This section applies only
    to England") — or `none` (the
    words, but no statement: "a provision which extends to Scotland").

  An example is the law flattened to what the reading needs: each top-level
  provision with these words, whole, and the Parts and sections around them
  as empty shells in document order (`example/1`), read alone with
  `classes/1`. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.ApplicationClause
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @places "England and Wales|Great Britain|the United Kingdom|United Kingdom|England|Wales|Scotland|Northern Ireland"
  @extent_words Regex.compile!(
                  # (also "the same extent within the United Kingdom as", "extends
                  # to the part or parts of the United Kingdom", "extends
                  # throughout", "extends as follows": counted, CV-S05 round 4)
                  "\\bextends?\\s+(?:also\\s+|only\\s+)?(?:to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)(?:#{@places})|\\bnot\\s+extend\\s+to\\s+(?:#{@places})|\\bsame\\s+extent\\s+(?:within\\s+the\\s+United\\s+Kingdom\\s+)?as\\b|\\bextends?\\s+to\\s+the\\s+(?:same\\s+)?part\\s+or\\s+parts\\s+of\\s+the\\s+United\\s+Kingdom\\b|\\bextends?\\s+as\\s+follows\\b",
                  "iu"
                )
  @application_words Regex.compile!(
                       "\\b(?:appl(?:y|ies)|ha(?:ve|s)\\s+effect)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|as\\s+respects|to|in)\\s+(?:the\\s+whole\\s+of\\s+)?(?:#{@places})",
                       "iu"
                     )
  @place_re Regex.compile!("\\b(?:#{@places})\\b", "iu")
  # application only where the law, or a part of it, is what applies — not
  # the amended words of another law ("the table as it applies to England")
  @quoted ~r/“[^”]*”|"[^"]*"|‘[^’]*’/u
  # an amending instruction's inserted or substituted words are the other
  # law's ("After subsection (3) insert— … so far as it applies …")
  @instruction ~r/\b(?:insert|substitute|add)\s*[—–:]/iu
  # the words in a relative or conditional clause: a mention, not a statement
  # ("an enactment which extends to Scotland", "so far as they extend to")
  @mention ~r/\b(?:which|that|who|so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as|as)\s+(?:[\w()]+\s+){0,3}(?:do\s+not\s+|does\s+not\s+|shall\s+)?$/iu
  @verb_at ~r/\b(?:extends?|extend|appl(?:y|ies)|ha(?:ve|s)\s+(?:effect|the\s+same\s+extent))\b/iu
  @self_subject ~r/\b(?:these|this)\s+(?:Regulations|Order|Act|Rules|Scheme|Measure|Part|Chapter|Schedule|section|regulation|article|rule)\b|^\s*They\b/iu

  @type form :: %{
          kind: String.t(),
          subject: String.t(),
          verb: String.t(),
          lead: String.t(),
          places: String.t(),
          only: boolean(),
          also: boolean()
        }

  @doc "Whether text speaks of where a law extends or applies."
  @spec words?(String.t() | nil) :: boolean()
  def words?(nil), do: false

  def words?(text) do
    t = String.replace(text, @quoted, " ")

    not Regex.match?(@instruction, t) and
      (Regex.match?(@extent_words, t) or
         (Regex.match?(@application_words, t) and Regex.match?(@self_subject, t)))
  end

  @doc """
  Every top-level provision of the document as `{id, ref, text}`, in order —
  the units `Extent.read/1` chooses its clause and application from.
  """
  @spec provisions(Doc.t()) :: [{String.t(), String.t(), String.t()}]
  def provisions(%Doc{} = doc) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        do: {id, ref, doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" ")}
  end

  @doc """
  Each extent or application sentence of the document with its outcome:
  `{ref, sentence, class}`, in order.
  """
  @spec classes(Doc.t()) :: [{String.t(), String.t(), String.t()}]
  def classes(%Doc{} = doc) do
    e = Extent.read(doc)

    # a provision's territorial versions say the same once: each
    # sentence of a provision read at its first
    {out, _, _} =
      for {id, ref, _text} <- provisions(doc),
          not container?(doc, id),
          unit <- units(doc, id),
          s <- Clause.sentences(unit),
          words?(s),
          reduce: {[], false, MapSet.new()} do
        {acc, default_seen?, seen} ->
          if MapSet.member?(seen, {ref, s}) do
            {acc, default_seen?, seen}
          else
            {class, seen?} = outcome(s, ref, e, doc.type, default_seen?)
            {[{ref, s, class} | acc], seen?, MapSet.put(seen, {ref, s})}
          end
      end

    Enum.reverse(out)
  end

  # the words just before the first verb make it a mention ("an enactment
  # which extends to", "so far as they extend to")
  defp mention?(s) do
    case Regex.run(@verb_at, s, return: :index) do
      [{at, _} | _] -> Regex.match?(@mention, binary_part(s, 0, at))
      nil -> false
    end
  end

  # a Schedule (or a Part of one) whose paragraphs are units of their own
  defp container?(doc, id) do
    case Regex.run(~r/^(schedule(?:-\d+[A-Z]*)?)(?:-part(?:-[^-]+)?)?$/, id) do
      # (its Parts too: a repeals Schedule's "Part I", "Part II")
      [whole, sch | _] ->
        Enum.any?(doc.ids, &String.starts_with?(&1, sch <> "-paragraph-")) or
          (whole == sch and Enum.any?(doc.ids, &(&1 =~ ~r/^#{Regex.escape(sch)}-part-[^-]+$/)))

      nil ->
        false
    end
  end

  # a provision's subsections (its direct children: "section-84-1"), each
  # whole with its lists, else the provision itself; the leading number
  # CLML runs into the words ("841 This Act" → "This Act") dropped
  defp units(doc, id) do
    children = Doc.children(doc, id)

    for el_id <- if(children == [], do: [id], else: children),
        text = doc |> Doc.element(el_id) |> Doc.lines() |> Enum.join(" "),
        do: String.replace(text, ~r/^\s*\d+[A-Z]*\s*(?=[A-Z(])/u, "")
  end

  # {class, whether the clause's default has been taken}
  defp outcome(s, ref, %Extent{} = e, type, default_seen?) do
    statement = Extent.statement(s, type)
    in_clause? = e.ref != nil and e.ref == ref

    cond do
      in_clause? and match?({:default, _}, statement) ->
        {:default, d} = statement

        if not default_seen? and d == e.default,
          do: {"default:#{d}", true},
          else: {"unread:another_default", default_seen?}

      # named provisions' and amendments' own extent, wherever stated
      match?({:list, k, _} when k in [:named, :same, :only, :also, :not], statement) and
          not in_clause? ->
        {:list, kind, place} = statement

        if Enum.any?(e.lists, &match?({^kind, ^place, _}, &1)),
          do: {"list:#{kind}:#{place || "same"}", default_seen?},
          else: {"unread:other_provision", default_seen?}

      in_clause? and match?({:list, _, _}, statement) ->
        {:list, kind, place} = statement

        if Enum.any?(e.lists, &match?({^kind, ^place, _}, &1)),
          do: {"list:#{kind}:#{place || "same"}", default_seen?},
          else: {"unread:list", default_seen?}

      in_clause? and match?({:part_not, _}, statement) ->
        {:part_not, place} = statement

        if Enum.any?(e.lists, &match?({:not, ^place, _}, &1)),
          do: {"part_not:#{place}", default_seen?},
          else: {"unread:part_not", default_seen?}

      Regex.match?(@application_words, s) and ApplicationClause.parse(s) != nil ->
        if e.application,
          do: {"applies:#{e.application}", default_seen?},
          else: {"unread:application", default_seen?}

      in_clause? and e.corresponds and s =~ ~r/\bcorresponds\s+to\s+the\s+repeal\b/i ->
        {"corresponds", default_seen?}

      in_clause? and Regex.match?(@extent_words, s) ->
        {"unread:in_clause", default_seen?}

      statement != nil ->
        {"unread:other_provision", default_seen?}

      mention?(s) ->
        {"none", default_seen?}

      # a provision's own extent or application ("This section applies only
      # to England", "Subsections (3) to (13) above do not extend to
      # Scotland"): the reader reads the law's, not a provision's
      form(s).subject not in ["whole", "following", "amendments", "other"] ->
        {"unread:provision_" <>
           if(Regex.match?(@extent_words, s), do: "extent", else: "application"), default_seen?}

      true ->
        {"unread:not_read", default_seen?}
    end
  end

  @doc "A sentence's form (see the moduledoc)."
  @spec form(String.t()) :: form()
  def form(s) do
    extent? = Regex.match?(@extent_words, s)
    application? = Regex.match?(@application_words, s)

    head =
      case Regex.split(
             ~r/\b(?:extends?|extend|appl(?:y|ies)|ha(?:ve|s)\s+(?:effect|the\s+same\s+extent))\b/iu,
             s,
             parts: 2
           ) do
        [h, _] -> h
        [h] -> h
      end

    %{
      kind:
        cond do
          extent? and application? -> "extent+application"
          extent? -> "extent"
          true -> "application"
        end,
      subject: subject(head),
      verb: verb(s, extent?),
      lead: lead(s),
      places:
        case length(Regex.scan(@place_re, s)) do
          0 -> "0"
          1 -> "1"
          _ -> "many"
        end,
      only: Regex.match?(~r/\bonly\b/i, s),
      also: Regex.match?(~r/\balso\b/i, s)
    }
  end

  defp subject(head) do
    h =
      String.replace(
        head,
        ~r/^(?:\(\w+\)\s*)?(?:subject\s+to|save\s+as|apart\s+from)[^,]*,\s*/i,
        ""
      )

    cond do
      h =~ ~r/\bthe\s+following\b/i ->
        "following"

      h =~ ~r/\b(?:amendments?|repeals?|revocations?|modifications?)\b/i ->
        "amendments"

      h =~ ~r/\bParts?\s+(?:[IVXLC\d]+|\d+)|\bthis\s+Part\b|\bChapters?\b/u ->
        "parts"

      h =~ ~r/\bSchedules?\b/ ->
        "schedules"

      h =~ ~r/\bthis\s+(?:section|regulation|article|rule|paragraph)\b/i ->
        "this"

      h =~ ~r/\b(?:sections?|regulations?|articles?|rules?|paragraphs?)\s+\d/i ->
        "named"

      h =~
          ~r/\b(?:this|these|the\s+provisions\s+of\s+(?:this|these))\s+(?:Act|Regulations|Order|Rules|Scheme|Measure)\b|^\s*(?:\(\w+\)\s*)?(?:It|They)\b/i ->
        "whole"

      true ->
        "other"
    end
  end

  defp verb(s, extent?) do
    cond do
      extent? and s =~ ~r/\bnot\s+extend\b/i -> "not_extends"
      extent? and s =~ ~r/\bsame\s+extent\b/i -> "same_extent"
      extent? -> "extends"
      s =~ ~r/\bnot\s+(?:apply|have\s+effect)\b/i -> "not_applies"
      s =~ ~r/\b(?:appl(?:y|ies)|ha(?:ve|s)\s+effect)\b/i -> "applies"
      true -> "other"
    end
  end

  defp lead(s) do
    cond do
      s =~ ~r/^(?:\(\w+\)\s*)?subject\s+to\b/i -> "subject_to"
      s =~ ~r/\bapart\s+from\b/i -> "apart_from"
      s =~ ~r/\b(?:except|save|other\s+than)\b/i -> "except"
      true -> "none"
    end
  end

  @doc "The pattern key of one sentence: its form and outcome as one key."
  @spec key(form(), String.t()) :: String.t()
  def key(f, class) do
    flag = fn b, name -> if b, do: name, else: "-" end

    Enum.join(
      [
        f.kind,
        f.subject,
        f.verb,
        f.lead,
        "places:" <> f.places,
        flag.(f.only, "only"),
        flag.(f.also, "also"),
        class
      ],
      "|"
    )
  end

  @doc """
  An example: the law flattened to what `Extent.read/1` reads — each
  top-level provision speaking of extent or application, with its words,
  and the Parts and top-level sections (regulations, articles) as empty
  shells, all in document order — as XML.
  """
  @spec example(Doc.t()) :: String.t()
  def example(%Doc{} = doc) do
    words = Map.new(provisions(doc), fn {id, _ref, text} -> {id, text} end)

    elements =
      for id <- doc.ids,
          {keep} = {Map.has_key?(words, id) and words?(words[id]) and not container?(doc, id)},
          shell?(id) or keep,
          do: element(doc, id, keep)

    body = [{:Body, [], elements}]

    [{:Legislation, [], [{:Primary, [], body}]}]
    |> :xmerl.export_simple(:xmerl_xml, prolog: [])
    |> :unicode.characters_to_binary()
  end

  defp shell?(id), do: id =~ ~r/^(?:part-[^-]+|(?:section|regulation|article|rule)-\d+[A-Z]*)$/

  defp element(_doc, id, false), do: {:P1, [id: to_charlist(id)], []}

  # the provision with its subsections, each whole (the units read)
  defp element(doc, id, true) do
    case Doc.children(doc, id) do
      [] ->
        {:P1, [id: to_charlist(id)], [text(doc, id)]}

      children ->
        {:P1, [id: to_charlist(id)],
         for(c <- children, do: {:P2, [id: to_charlist(c)], [text(doc, c)]})}
    end
  end

  defp text(doc, id),
    do: {:Text, [], [doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" ") |> to_charlist()]}

  @doc "What the reader makes of an example (`example/1`'s XML) for `law`."
  @spec read(String.t(), String.t()) :: [{String.t(), String.t(), String.t()}]
  def read(law, xml), do: law |> Doc.new([xml]) |> classes()
end

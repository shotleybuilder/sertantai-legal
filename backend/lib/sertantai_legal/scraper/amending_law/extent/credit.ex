defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Credit do
  @moduledoc """
  Whether the extent reader read a list sentence whole, for the catalogue
  (`Extent.Patterns`; CV-S05 round 8). A sentence stating where named
  provisions extend is credited only when each provision its subject
  names is in a list of the same kind and place: "This article, articles
  6(4) and (5) and 7 and Part 1 of the Schedule extend to …" with only
  articles 6(4), 6(5) and 7 read is a partial read (SI 2016/1142 art.1(3),
  round 7 NEW-3), no longer credited because some list of that kind and
  place exists.

  The subject (the words before its verb) is cut at each provision it
  names ("articles 6(4) and (5) and 7", "Part 1 of the Schedule", "this
  article"); a mention read as no provision leaves the sentence unread.
  Another law's provisions ("section 2 of the Health Act 2006") and a
  qualified mention ("so far as …") are not its own. A subject naming no
  provision ("The amendments made by this Act …") is credited by kind and
  place. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Named, Parts}

  @verb ~r/\b(?:extends?|extend|appl(?:y|ies)|ha(?:ve|s)\s+(?:effect|the\s+same\s+extent))\b/iu
  # each provision named, never the Schedule or Part a mention is "of"
  # (nor the Part a mention is "in": "Sections 260 to 266 in Part 13")
  @mention ~r/(?<!of\s)(?<!of\sthe\s)\b(?:this\s+(?:section|article|regulation|rule|Part)\b|(?:sections?|articles?|regulations?|rules?|paragraphs?|(?<!in\s)Parts?|Chapters?|Schedules?)\s+[\dIVXLC]+[A-Z]*\b)/iu
  @qualified ~r/\b(?:so\s+far|in\s*so\s*far|to\s+the\s+extent)\b/iu
  @aside ~r/\([^()]*\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b[^()]*\)/iu
  # a lead before the subject ("Subject to section 17(6), …")
  @lead ~r/^\s*(?:Subject\s+to|Except\s+as|Without\s+prejudice\s+to)\b[^,]*,/iu
  @other_law ~r/\bof\s+(?:the\s+[A-Z][^,;]*?\b(?:Act|Order|Regulations|Rules|Measure)\b|that\s+Act|the\s+\d{4}\s+Act)/u

  @type list_entry :: {atom(), String.t() | nil, [String.t()]}

  @doc """
  Whether sentence `s` of provision `ref`, stating a `kind` list for
  `place`, was read whole into `lists`.
  """
  @spec list_read?(String.t(), String.t(), Doc.t(), [list_entry()], atom(), String.t() | nil) ::
          boolean()
  def list_read?(s, ref, doc, lists, kind, place) do
    held = for {^kind, ^place, refs} <- lists, r <- refs, do: r

    case own_refs(s, ref, doc) do
      _ when held == [] ->
        Enum.any?(lists, &match?({^kind, ^place, _}, &1))

      :unparsed ->
        false

      [] ->
        true

      # ("*": every provision the law makes: "An amendment or repeal
      # contained in this Act (and … this Part)", ukpga 2007/29 s.212)
      refs ->
        "*" in held or
          Enum.all?(refs, fn r -> Enum.any?(held, &(&1 == r or RefList.covers?(&1, r))) end)
    end
  end

  @doc """
  A list sentence's class: read whole (`list_read?/6`) → "list:kind:place";
  a list of its kind and place read but missing some → "unread:list_partial"
  (CV-S05 round 8, NEW-3) — never on the strength of a Schedule paragraph's
  own statement ("Paragraphs 15 to 17 extend only to England and Wales"
  beside "This paragraph extends only to England and Wales": 2003/39
  Sch.8, round 11); else `unread`.
  """
  @spec list_class(
          String.t(),
          String.t(),
          Doc.t(),
          [list_entry()],
          atom(),
          String.t() | nil,
          String.t() | nil
        ) ::
          String.t() | nil
  def list_class(s, ref, doc, lists, kind, place, unread) do
    cond do
      list_read?(s, ref, doc, lists, kind, place) ->
        "list:#{kind}:#{place || "same"}"

      Enum.any?(lists, &(match?({^kind, ^place, _}, &1) and not own_paragraph?(&1))) ->
        "unread:list_partial"

      true ->
        unread
    end
  end

  # (its sub-paragraphs too, all of one paragraph: "Sub-paragraph (1) does
  # not extend to Northern Ireland", 2003/39 Sch.8 para 70, CV-S05 seed 20
  # batch)
  defp own_paragraph?({_, _, [r | _] = refs}) do
    para = String.replace(r, ~r/\(.*$/, "")

    para =~ ~r/^sch\.[^.]+\.para\.[^.()]+$/ and
      Enum.all?(refs, &(String.replace(&1, ~r/\(.*$/, "") == para))
  end

  defp own_paragraph?(_), do: false

  @doc """
  The provisions the subject of `s` names, or `:unparsed` when one it
  names is read as none.
  """
  @spec own_refs(String.t(), String.t(), Doc.t()) :: [String.t()] | :unparsed
  def own_refs(s, ref, doc) do
    chunks = s |> subject() |> chunks()

    Enum.reduce_while(chunks, [], fn chunk, acc ->
      if chunk =~ @qualified or chunk =~ @other_law,
        do: {:cont, acc},
        else: chunk_read(chunk_refs(chunk, ref, doc), acc)
    end)
    |> case do
      :unparsed -> :unparsed
      refs -> Enum.uniq(refs)
    end
  end

  @doc """
  The first item's list class when every lettered item of `s` speaking of
  extent ("(a)", "(i)": whatever it begins with) is a list statement read
  whole; `"unread:list_partial"` when every item is a list statement of a
  kind and place read but one not whole; else nil (one unread item: the
  sentence is unread).
  """
  @spec items_read(String.t(), String.t(), Doc.t(), [list_entry()], Regex.t()) ::
          String.t() | nil
  def items_read(s, ref, doc, lists, extent_words) do
    items =
      s
      |> String.split(~r/[—–;]\s*(?:and\s*|or\s*)?\(?[a-z]{1,4}\)?\s+/u)
      |> tl()
      |> Enum.filter(&Regex.match?(extent_words, &1))

    found =
      for item <- items do
        case Extent.statement(item, doc.type) do
          {:list, kind, place} ->
            cond do
              list_read?(item, ref, doc, lists, kind, place) -> "list:#{kind}:#{place || "same"}"
              Enum.any?(lists, &match?({^kind, ^place, _}, &1)) -> :partial
              true -> nil
            end

          _ ->
            nil
        end
      end

    cond do
      found == [] or nil in found -> nil
      :partial in found -> "unread:list_partial"
      true -> hd(found)
    end
  end

  # the words before the verb, without a lead or a describing bracket; a
  # heading's ("the following provisions extend …— (a) …", "In Part 3—
  # (a) …") is none: its items are read as items (`items_read/5`)
  defp subject(s) do
    head =
      case Regex.run(@verb, s, return: :index) do
        [{at, _} | _] -> binary_part(s, 0, at)
        nil -> s
      end

    # (what comes before "and the following" is its own: "This section
    # and the following provisions … also extend …": 1993/9 s.48)
    {head, heading?} =
      case String.split(head, ~r/\band\s+the\s+following\b/iu, parts: 2) do
        [own, _] -> {own, false}
        [all] -> {all, all =~ ~r/\bthe\s+following\b/iu}
      end

    # (a heading's lead-in is no subject: "Part 2 Powers of entry The repeals
    # … in the following provisions extend …", ukpga 2012/9 Sch.10)
    if heading? or head =~ ~r/[—–]/u do
      ""
    else
      head
      |> String.replace(@lead, "")
      |> String.replace(@aside, " ")
      |> Named.described_out()
    end
  end

  # the subject cut at each provision it names
  defp chunks(subject) do
    starts = for [{at, _}] <- Regex.scan(@mention, subject, return: :index), do: at
    ends = Enum.drop(starts, 1) ++ [byte_size(subject)]

    for {a, b} <- Enum.zip(starts, ends), do: binary_part(subject, a, b - a)
  end

  defp chunk_read([], _acc), do: {:halt, :unparsed}
  defp chunk_read(refs, acc), do: {:cont, acc ++ refs}

  defp chunk_refs(chunk, ref, doc) do
    self = if chunk =~ ~r/^\s*this\s+(?:article|regulation|rule)\b/iu, do: [ref], else: []

    # (a Part's or Chapter's sections only where the mention is one; in a
    # Schedule, a Part bare or "of this Schedule" is that Schedule's, its
    # heading too: "Part 4 Management of inshore fisheries The repeal … by
    # Part 4 of this Schedule", ukpga 2009/23 Sch.22)
    parts =
      cond do
        String.starts_with?(ref, "sch.") and
          (chunk =~ ~r/\bof\s+this\s+Schedule\b/iu or
             not (chunk =~ ~r/^\s*Parts?\s+\S+\s+of\b/iu)) and chunk =~ ~r/^\s*Parts?\s/iu ->
          [ref |> String.split(".") |> Enum.take(2) |> Enum.join(".")]

        chunk =~ ~r/^\s*(?:this\s+Part|Parts?|Chapters?)\b/iu ->
          Parts.parts(Parts.qualify_chapters(chunk), doc, ref)

        true ->
          []
      end

    Enum.uniq(self ++ RefList.parse(chunk, ref) ++ parts)
  end
end

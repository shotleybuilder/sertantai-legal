defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.SameExceptions do
  @moduledoc """
  The lettered exceptions to a same-extent statement (Fire and OH&S: Extent
  reader, 2026-11-14): "… has the same extent as the provision to which it
  relates, except that— (a) regulation 107(5) (amendment of the Proceeds of
  Crime Act 2002) extends to England and Wales and Scotland only; (b)
  regulation 107(8) extends to England and Wales only, and (c) …" (SI
  2019/742 reg.2(2)); "…, except that— (a) the amendments made by paragraphs
  164 to 176 of that Schedule, in so far as they make provision for ONR
  inquiries, extend to …; (b) …; (c) the amendments made by paragraphs
  182(2) and (4) … apply in relation to England only" (SI 2014/469
  art.3(5)).

  Each item is one of:

  - a plain extent statement of the law's own provisions: read as a list
    (`:only` the place it states, `:not` for "do not extend to");
  - a qualified one ("in so far as …"): its provisions withheld
    (`:unread`), never the whole subject;
  - a provision's application ("apply in relation to England only"): no
    extent, `Extent.Applies` reads it.

  A bracket after a provision is a description, whatever it names
  ("(amendment of the Criminal Finances Act 2017)"). An item of any other
  shape leaves the whole subject unread. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ListItems, Places}

  @place_list Places.place_list()

  # (after the statement's own end: "… to which it relates, except that—")
  @lead ~r/^(?:\s+(?:which|to\s+which|being)\b[^,;—–]*)?\s*,?\s*except\s+that\s*[—–]\s*(?=\(?a\)?\s)/u
  # "—a …;b …, andc …" (`Units.unlettered/1`'s letters)
  @item_start ~r/(?:[—–;]\s*(?:and\s*|or\s*)?\(?[a-z]{1,2}\)?|,\s*and(?:\s*\([a-z]{1,2}\)|[a-z]))\s+/u

  @extent Regex.compile!(
            "^(?<subj>.+?)\\s*,?\\s+(?:shall\\s+)?(?:(?<not>do(?:es)?\\s+not\\s+extend)|extends?)\\s+(?:only\\s+)?to\\s+(?<places>(?>#{@place_list}))(?:\\s+only)?\\s*[.;,]?\\s*(?:and)?\\s*$",
            "su"
          )
  @applies Regex.compile!(
             "^.+?\\s+appl(?:y|ies)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|to)\\s+(?>#{@place_list})(?:\\s+only)?\\s*[.;,]?\\s*(?:and)?\\s*$",
             "su"
           )

  # a description in brackets (words in it), never a number ("(5)")
  @described ~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u
  @made_by ~r/^\s*the\s+(?:amendments?|repeals?|revocations?|modifications?)(?:\s+(?:and|or)\s+(?:amendments?|repeals?|revocations?|modifications?))*\s+(?:made\s+by|in|specified\s+in)\s+/iu

  @type entry :: {:same | :only | :not | :unread, String.t() | nil, [String.t()]}

  @doc """
  The lists of a same-extent statement of `refs` whose words after it
  (`tail`) are lettered exceptions: the same extent with each item's list,
  or the subject unread where an item isn't read; nil when `tail` isn't
  this form.
  """
  @spec lists(String.t(), [String.t()], String.t(), Doc.t()) :: [entry()] | nil
  def lists(tail, refs, ref, %Doc{} = doc) do
    case Regex.split(@lead, tail, parts: 2) do
      [_, body] -> body |> items(refs, ref, doc) |> with_same(refs)
      _ -> nil
    end
  end

  defp items(body, refs, ref, doc) do
    for i <- Regex.split(@item_start, " " <> body, trim: true), do: item(i, refs, ref, doc)
  end

  defp with_same(items, refs) do
    if items == [] or :unread in items,
      do: [{:unread, nil, refs}],
      else: [{:same, nil, refs} | List.flatten(items)]
  end

  # one item's lists, or `:unread`
  defp item(text, refs, ref, doc) do
    cond do
      m = Regex.named_captures(@extent, text) -> extent(m, refs, ref, doc)
      Regex.match?(@applies, text) -> []
      true -> :unread
    end
  end

  defp extent(m, refs, ref, doc) do
    kind = if m["not"] != "", do: :not, else: :only
    read = m["subj"] |> subject(refs) |> ListItems.read(ref, doc)

    case {read.refs, read.unread} do
      {[], []} -> :unread
      {plain, []} -> [{kind, Places.places(m["places"]), plain}]
      {_, withheld} -> [{:unread, nil, read.refs ++ withheld}]
    end
  end

  # the item's own provisions: its description and "the amendments made by"
  # out; "of that Schedule", or none named, the one Schedule the statement
  # is of
  defp subject(subj, refs) do
    subj = subj |> String.replace(@described, " ") |> String.replace(@made_by, "")

    case refs do
      ["sch." <> n] -> in_schedule(subj, n)
      _ -> subj
    end
  end

  defp in_schedule(subj, n) do
    cond do
      subj =~ ~r/\bthat\s+Schedule\b/u ->
        String.replace(subj, ~r/\bthat\s+Schedule\b/u, "Schedule #{n}")

      subj =~ ~r/^\s*paragraphs?\s/u and not (subj =~ ~r/\bSchedule\b/u) ->
        Regex.replace(~r/^(\s*paragraphs?\s+[^,]*)/u, subj, "\\1 of Schedule #{n}")

      true ->
        subj
    end
  end
end

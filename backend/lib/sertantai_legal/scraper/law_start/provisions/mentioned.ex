defmodule SertantaiLegal.Scraper.LawStart.Provisions.Mentioned do
  @moduledoc """
  Provisions named as "mentioned in" a list or a Schedule ("the provisions mentioned in Part 1 of Schedule 2"), and the groups left partly in beside them. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.ListItems
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Treatment}

  # a statement pointing to a subsection's list ("The provisions specified
  # in subsection (2) come into force …"; "… and the provisions specified
  # in subsection (6) below (which come into force on the passing of this
  # Act) …": 1994 c.21 s.68(4)), however it is read: each group holding the
  # provisions the list names in full has beside it those the list limits
  @doc "Groups beside the provisions a statement leaves partly in by mentioning them."
  @spec with_mentioned_partly([map()], String.t(), [map()], String.t()) :: [map()]
  def with_mentioned_partly(groups, s, rows, base) do
    case mentioned_items(s, rows, base) do
      {_named, _excepted, []} -> groups
      {named, _excepted, partly} -> Enum.flat_map(groups, &beside_partly(&1, named, partly))
    end
  end

  defp beside_partly(g, named, partly) do
    if g.refs != [] and g.refs -- named != g.refs,
      do: [g | mentioned_partly(g, partly -- g.refs)],
      else: [g]
  end

  # the provisions the subsection pointed to names with a limit of their
  # own ("in Part 4 of Schedule 5, the repeals to the Environmental
  # Protection Act 1990": CNEA 2005 s.108(2)(h)) come in on the statement's
  # day, partly; country by country where the statement is (s.108(1))
  defp mentioned_partly(_named, []), do: []

  defp mentioned_partly(%{kind: :unread}, _partly), do: []

  defp mentioned_partly(%{treatment: :provision_by_order, territory: place} = named, partly)
       when is_binary(place),
       do: [Map.merge(named, %{kind: :named, refs: partly, excluded: [], limited: true})]

  defp mentioned_partly(named, partly) do
    day = named.date || named.qualified_date

    [
      %{named | kind: :named, refs: partly, excluded: []}
      |> Map.merge(%{treatment: :provision_qualified, date: nil, qualified_date: day})
    ]
  end

  # (once, never from within the subsection: it naming itself would loop —
  # Petroleum Act 1998 s.52)
  @doc "The refs a subject names as \"mentioned in\"; [] when not followed."
  @spec mentioned_refs(String.t(), [map()], String.t(), boolean()) :: [term()]
  def mentioned_refs(_subject, _rows, _base, false), do: []

  def mentioned_refs(subject, rows, base, true),
    do: subject |> mentioned_items(rows, base) |> elem(0)

  # "The provisions mentioned in subsection (3) …": those the subsection
  # lists (Competition Act 1998 s.52(2), CV-S04), each row under it read as
  # a list item — `{the provisions named, those its items except}`: "Part 7
  # above except sections 83(2) and 85", and "the repeals to the
  # Environmental Protection Act 1990, other than the repeal to section 33
  # of that Act" names no section of this Act (CNEA 2005 s.108(2)(h), (n))
  @mentioned ~r/\bprovisions\s+(?:mentioned|specified|listed|referred\s+to)\s+in\s+(?:sub-?section|paragraph)\s+\((\w+)\)/i

  @doc "A subject's mentioned items: `{named, excepted, partly}`."
  @spec mentioned_items(String.t(), [map()], String.t()) :: {[term()], [term()], [term()]}
  def mentioned_items(subject, rows, base) do
    items =
      for [_, n] <- Regex.scan(@mentioned, subject),
          prefix = "#{base}(#{n})",
          r <- rows,
          r.section_id == prefix or String.starts_with?(r.section_id, prefix <> "("),
          do: mentioned_item(Map.get(r, :text) || "", rows, base)

    {Enum.flat_map(items, &elem(&1, 0)), Enum.flat_map(items, &elem(&1, 1)),
     Enum.flat_map(items, &elem(&1, 2))}
  end

  # the subsection's lead-in points back to the statement, and names no
  # provision: "The provisions excepted from subsection (3)(f) are the
  # repeal of …" (1999 c.22 s.108(4))
  @mentioned_lead ~r/^\W*(?:\(\w+\)\s*)?The\s+provisions\s+(?:excepted\s+from|(?:mentioned|specified|listed|referred\s+to)\s+in)\s+(?:sub-?section|paragraph)\s+(?:\(\w+\))+\s+are\b\s*[—–:]?\s*/iu

  defp mentioned_item(text, rows, base) do
    item = @mentioned_lead |> Regex.replace(text, "") |> ListItems.read()

    # (an item's qualified provisions are partly in, never named in full:
    # "in Part 4 of Schedule 5, the repeals to …")
    named = Refs.weighted_refs(item.plain, rows, base, false)
    partly = Refs.weighted_refs(item.qualified, rows, base, false)

    excepted =
      item.excepted
      |> Refs.weighted_refs(rows, Treatment.relative_base(named ++ partly, base), false)
      |> Enum.map(&elem(&1, 0))

    {named, excepted, partly}
  end

  # a Schedule's Part (and paragraph) named after the Schedule: "schedule 7,
  # Part 1, paragraph 6(c)", "schedule 8 Part 3" (SI 2013/3113 reg.1(4)) —
  # written Part first, "paragraph 6(c) of Part 1 of Schedule 7", so the
  # Part is never read as the law's own ("in Schedule 15, Part III and
  # Part V(1)" is `@in_schedule_parts`': AJA 1999 s.108(3)(f))
  @schedule_then_part ~r/(?<![Ii]n\s)\bschedule\s+(\d+[A-Z]*)\s*,?\s+Part\s+([IVXL]+|\d+[A-Z]?)(?:\s*,\s*paragraphs?\s+(\d+[A-Z]*(?:\([^)]+\))*))?/i

  @doc """
  A Schedule's Part (and paragraph) named after the Schedule written Part
  first: "schedule 7, Part 1, paragraph 6(c)" → "paragraph 6(c) of Part 1
  of Schedule 7" (SI 2013/3113 reg.1(4)), so no reader takes the Part for
  the law's own. Pure.
  """
  @spec schedule_part_first(String.t()) :: String.t()
  def schedule_part_first(subject) do
    Regex.replace(@schedule_then_part, subject, fn
      _, n, part, "" -> "Part #{part} of Schedule #{n}"
      _, n, part, para -> "paragraph #{para} of Part #{part} of Schedule #{n}"
    end)
  end

  @in_schedule_parts ~r/\bin\s+Schedule\s+(\d+[A-Z]*)\s*,\s*(Parts?\s+(?:[IVXL]+|\d+)[A-Z]?(?:\(\d+\))*(?:\s*(?:,|and)\s*(?:\(\d+\)|(?:Parts?\s+)?(?:[IVXL]+|\d+)[A-Z]?(?:\(\d+\))*))*)/

  @contained_in ~r/\bthe\s+repeal\s+of\s+[^;.]*?\bcontained\s+in\s+[^,;.]*?\bSchedule\s+\d+[A-Z]*/

  # a Schedule's Parts named after it, each as "Part X of Schedule N" ("in
  # Schedule 15, Part III and Part V(1) and (5)": AJA 1999 s.108(3)(f), a
  # Part's numbered divisions read as the Part); one repeal and where it
  # is ("the repeal of section 67(8) of the Magistrates' Courts Act 1980 …
  # contained in Part V(1) of Schedule 15": s.108(4)) names no Schedule
  @doc "A subject's Schedule words put in Schedule-then-Part order."
  @spec schedule_words(String.t()) :: String.t()
  def schedule_words(subject) do
    subject = String.replace(subject, @contained_in, "")

    Regex.replace(@in_schedule_parts, subject, fn _, schedule, parts ->
      parts
      |> String.replace(~r/\(\d+\)/, "")
      |> then(&Regex.scan(~r/\b(?:[IVXL]+|\d+)[A-Z]?\b/, &1))
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.map_join(" and ", &"Part #{&1} of Schedule #{schedule}")
    end)
  end
end

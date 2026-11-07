defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Mentions do
  @moduledoc """
  The law's own provisions a segment of an extent sentence names
  ("sections 3 to 5", "paragraph 2 of Schedule 4", "this Part"), each
  marked foreign (another law's), excepted, qualified ("so far as …")
  or seen (a reference, not a subject) (`finder.py`'s `mentions`,
  `qualified`, `excepted_at`, `seen`; #192). Shares no code with the
  extent reader.
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{Places, Re, Refs, Structure}
  alias SertantaiLegal.Scraper.Checks.PyCompat

  @type mention :: %{
          refs: MapSet.t(String.t()),
          text: String.t(),
          foreign: boolean(),
          excepted: boolean(),
          qualified: boolean() | :object,
          seen: boolean(),
          kind: String.t()
        }

  @kw "(?:sections?|subsections?|regulations?|articles?|rules?|sub-paragraphs?|paragraphs?|Parts?|Chapters?|Schedules?)"
  @sep "(?:\\s*,\\s*(?:and\\s+|or\\s+)?|\\s+and\\s+|\\s+or\\s+|\\s+to\\s+|\\s*[-–]\\s*(?=\\d))"

  @group Regex.compile!(
           "\\b(#{@kw})\\s+(#{Refs.item_pattern()}(?:#{@sep}#{Refs.item_pattern()})*)",
           "iu"
         )
  @self_ref ~r/\bthis\s+(section|regulation|article|rule|Part|Chapter|Schedule|paragraph)\b/iu
  @foreign ~r/^\s*(?:\([^()]*\)\s*)?(?:,\s*)?(?:of|to|in|under)\s+(?:the\s+(?:Schedule\s+to\s+the\s+)?(?:Ztitle\s+Act|\d{4}\s+(?:Act|Regulations|Order)|principal\s+(?:Act|Regulations|Order)|[A-Z][\w ]*?\b(?:Code|Convention|Treaty)\b)|that\s+(?:Act|Order)|those\s+Regulations|Regulation\s+\((?:EU|EC|EEC)\)|Directive)/u
  @chain Regex.compile!(
           "^\\s*(?:,\\s*|\\s+)(?:and\\s+|of\\s+)?#{@kw}\\s+#{Refs.item_pattern()}",
           "iu"
         )
  @except ~r/\b(?:except|excluding|other\s+than|apart\s+from|with\s+the\s+exception\s+of)\b/iu
  @except_bracket ~r/\(\s*(?:except|excluding|other\s+than|apart\s+from|but\s+not|with\s+the\s+exception\s+of)\b/iu
  @adding_bracket ~r/\(\s*(?:and|with|including|together\s+with|except|excluding|other\s+than|apart\s+from|but\s+not|so\s+far|in\s+so\s+far|insofar)\b/iu
  @reference ~r/\b(?:see(?:\s+also)?|subject\s+to|in\s+relation\s+to|(?:as\s+)?described\s+in|modified\s+by|required\s+by|(?:as\s+)?provided\s+(?:by|in|for\s+in)|under|by\s+virtue\s+of|in\s+accordance\s+with|mentioned\s+in|referred\s+to\s+in|(?<!amendments\s)(?<!amendment\s)(?<!modifications\s)(?<!repeals\s)(?<!revocations\s)(?<!provisions\s)(?<!saving\s)(?:specified|set\s+out)\s+in|within\s+the\s+meaning\s+of|for\s+the\s+purposes\s+of|(?:entry|entries)\s+(?:\w+\s+){0,2}in)\b(?:\s+(?:any\s+)?(?:express\s+)?(?:provision\s+(?:in|of)\s+)?)?\s*(?:the\s+)?$/iu
  @q_after ~r/^\s*(?:\([^()]*\)\s*)?(?:above|below)?\s*(?:(?:of|to)\s+this\s+\w+\s*)?,?\s*(?:but\s+only\s+|only\s+)?(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent)\b/iu
  @q_before ~r/(?:so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that|so\s+much\s+of)\b[^;]*$/iu
  @section_kinds ["section", "regulation", "article", "rule"]

  @doc "`GROUP`: a keyword and its number list (\"sections 3 and 4\")."
  @spec group() :: Regex.t()
  def group, do: @group

  @doc """
  The mentions of `seg` in the sentence of provision `own`, and the
  Schedule a locator named ("in Schedule 2—"), carried to the next
  segment as `sch_lead`.
  """
  @spec mentions(String.t(), String.t(), Structure.t(), String.t() | nil) ::
          {[mention()], String.t() | nil}
  def mentions(seg, own, st, sch_lead \\ nil) do
    seg = seg |> Places.mask_titles("Ztitle Act") |> then(&Regex.replace(~r/“[^”]*”/u, &1, "Q"))
    top = own |> String.split("(") |> hd()

    sch_of_own =
      case Regex.run(~r/^(sch\.\w+)/u, own) do
        [_, s] -> s
        nil -> nil
      end

    ctx = %{seg: seg, top: top, sch_of_own: sch_of_own, st: st}

    {found, sch_lead} =
      @group
      |> Re.all(seg)
      |> Enum.reduce({[], sch_lead}, fn caps, {acc, lead} ->
        case group_mention(caps, ctx, lead) do
          {:skip, lead} -> {acc, lead}
          {:ok, m} -> {[m | acc], lead}
        end
      end)

    selves = for caps <- Re.all(@self_ref, seg), m = self_mention(caps, ctx), do: m
    {Enum.reverse(found) ++ selves, sch_lead}
  end

  defp group_mention(caps, ctx, lead) do
    %{seg: seg} = ctx
    kw = mention_kw(Re.group(caps, seg, 1))
    start = Re.start(caps)
    tail = Re.from(seg, Re.stop(caps))
    before = Re.window(seg, start, 4)

    in_before = Regex.match?(~r/\bin\s+$/iu, before)

    cond do
      owner?(Re.window(seg, start, 24)) ->
        {:skip, lead}

      in_before and section_locator?(kw, tail) ->
        {:skip, lead}

      in_before and container_locator?(kw, tail) ->
        {:skip,
         if(kw == "schedule", do: "sch." <> first_word(Re.group(caps, seg, 2)), else: lead)}

      true ->
        {:ok, group_found(caps, kw, tail, Map.put(ctx, :sch_lead, lead))}
    end
  end

  # a locator: "in regulation 16, paragraphs (4) and (5)"; "in Part 10—"
  defp section_locator?(kw, tail) do
    kw in @section_kinds and
      Re.match?(
        ~r/^\s*(?:,\s*(?:sub)?(?:paragraphs?|subsections?)\s+\(|(?:\([^()]*\)\s*)?[—–])/iu,
        tail
      )
  end

  defp container_locator?(kw, tail) do
    kw in ["part", "chapter", "schedule"] and
      Re.match?(~r/^\s*(?:of\s+\w+\s+\w+\s*)?(?:\([^()]*\)\s*)?[,—–:]/u, tail)
  end

  defp group_found(caps, kw, tail, ctx) do
    %{seg: seg} = ctx
    start = Re.start(caps)
    foreign = foreign?(tail)

    refs =
      if foreign,
        do: MapSet.new(),
        else: Refs.resolve(kw, Re.group(caps, seg, 2), tail, Re.upto(seg, start), ctx)

    %{
      refs: refs,
      text: Re.group(caps, seg, 0),
      foreign: foreign,
      excepted: excepted_at(seg, start),
      qualified: qualified(seg, start, Re.stop(caps)),
      seen: seen(seg, start),
      kind: kw
    }
  end

  defp mention_kw(word) do
    case word |> String.downcase() |> String.trim_trailing("s") do
      "sub-paragraph" -> "subparagraph"
      kw -> kw
    end
  end

  defp first_word(text), do: text |> String.split() |> hd()

  # "of section 3": an owner, not a subject (but "the provisions of")
  defp owner?(pre) do
    Regex.match?(~r/(?<!much )\bof\s+$/u, pre) and
      not Regex.match?(~r/(?:^|[—–;,]\s*|\b(?:a|b|c|d|e)\s+)the\s+provisions\s+of\s+$/u, pre)
  end

  defp foreign?(tail) do
    t2 =
      case Re.match(Refs.of_sch(), tail) || Re.match(Refs.of_part(), tail) do
        nil -> tail
        caps -> Re.from(tail, Re.stop(caps))
      end

    Re.match?(@foreign, unchain(t2)) or Re.match?(@foreign, tail)
  end

  defp unchain(t) do
    case Re.match(@chain, t) do
      nil -> t
      caps -> unchain(Re.from(t, Re.stop(caps)))
    end
  end

  defp self_mention(caps, %{seg: seg} = ctx) do
    start = Re.start(caps)

    # "subsections (1) … of this section": an owner
    if Regex.match?(~r/\b(?:of|to)\s+$/u, Re.window(seg, start, 4)) do
      nil
    else
      %{
        refs: self_refs(String.downcase(Re.group(caps, seg, 1)), ctx),
        text: Re.group(caps, seg, 0),
        foreign: false,
        excepted: excepted_at(seg, start),
        seen: seen(seg, start),
        qualified: qualified(seg, start, Re.stop(caps)),
        kind: "self"
      }
    end
  end

  defp self_refs(kw, %{top: top}) when kw in ["section", "regulation", "article", "rule"],
    do: if(String.starts_with?(top, "sch."), do: MapSet.new(), else: MapSet.new([top]))

  defp self_refs("paragraph", %{top: top}), do: MapSet.new([top])
  defp self_refs("schedule", %{sch_of_own: nil}), do: MapSet.new()
  defp self_refs("schedule", %{sch_of_own: s}), do: MapSet.new([s])

  defp self_refs(kw, %{top: top, st: st}) do
    case Structure.container_of(st, top, kw) do
      nil -> MapSet.new()
      c -> MapSet.new(Structure.held(st, c))
    end
  end

  @doc """
  Whether the mention at `pos` is excepted: within a bracket opened by an
  exception word, or after an unbracketed one with no ";" between (nor
  "including" after it, nor "see" just before it).
  """
  @spec excepted_at(String.t(), non_neg_integer()) :: boolean()
  def excepted_at(seg, pos) do
    upto = Re.upto(seg, pos)

    if Enum.any?(open_brackets(upto), &Re.match?(@except_bracket, Re.from(seg, &1))) do
      true
    else
      flat = flatten(upto)

      case @except |> Re.all(flat) |> List.last() do
        nil ->
          false

        e ->
          after_e = Re.from(flat, Re.stop(e))

          not String.contains?(after_e, ";") and
            not Regex.match?(~r/\b(?:but\s+)?including\b/iu, after_e) and
            not Regex.match?(~r/\bsee\b/u, Re.window(flat, Re.start(e), 10, false))
      end
    end
  end

  # the text with every closed bracket, then an open one at the end, blanked
  defp flatten(text) do
    case Regex.replace(~r/\([^()]*\)/u, text, &Re.blank/1) do
      ^text -> Regex.replace(~r/\([^()]*$/u, text, &Re.blank/1)
      next -> flatten(next)
    end
  end

  # the positions of the brackets still open at the end of `text`
  defp open_brackets(text) do
    text
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.reduce([], fn
      {?(, i}, open -> [i | open]
      {?), _}, [_ | open] -> open
      _, open -> open
    end)
    |> Enum.reverse()
  end

  @doc """
  Whether the mention at `pos` is seen, not stated: inside a describing
  bracket ("(which inserts …)"), never one that adds provisions ("(and
  Schedule 1)"); or a reference ("subject to …", "under regulation 4").
  """
  @spec seen(String.t(), non_neg_integer()) :: boolean()
  def seen(seg, pos) do
    upto = Re.upto(seg, pos)

    Enum.any?(open_brackets(upto), &(not Re.match?(@adding_bracket, Re.from(seg, &1)))) or
      Regex.match?(@reference, upto |> String.split(~r/[,;—–]/u) |> List.last())
  end

  @doc """
  Whether a mention is qualified: a qualifier just after it ("… so far as
  …"), or a leading one ("In so far as regulations 4 … apply"); `:object`
  where the mention is the qualifier's own object ("so far as relating
  to paragraphs 81 …").
  """
  @spec qualified(String.t(), non_neg_integer(), non_neg_integer()) :: boolean() | :object
  def qualified(seg, start, stop) do
    if Re.match?(@q_after, Re.from(seg, stop)), do: true, else: leading(Re.upto(seg, start))
  end

  defp leading(before) do
    prev = @group |> Re.all(before) |> Enum.map(&Re.stop/1) |> Enum.max(fn -> 0 end)
    gap = Re.from(before, prev)

    if Regex.match?(@q_before, gap) and not Regex.match?(~r/(?:extends?|appl(?:y|ies))\b/iu, gap),
      do: leading_kind(PyCompat.rstrip(gap)),
      else: false
  end

  defp leading_kind(g) do
    cond do
      Regex.match?(~r/(?:so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)$/iu, g) -> true
      String.ends_with?(g, ",") -> true
      Regex.match?(~r/\bso\s+much\s+of$/iu, g) -> true
      true -> :object
    end
  end
end

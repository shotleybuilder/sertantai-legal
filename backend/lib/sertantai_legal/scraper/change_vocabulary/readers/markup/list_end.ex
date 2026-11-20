defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.ListEnd do
  @moduledoc """
  Where a note's list of amending pieces ends.

  The amending pieces are those written after the note's amending
  Citation, up to the first words that open another reference: "… by
  Corporation Tax Act 2010 (c. 4), s. 1184(1), Sch. 1 para. 344(2)(b)(ii)
  (with Sch. 2)" (the Capital Allowances Act 2001 s.220) lists two pieces
  and a saving. The list runs through pieces and list words (commas,
  "and", numbers with their brackets, a Schedule's parts) and ends at
  anything else: "(with …)", "(subject to …)", "(as inserted by …)",
  "see", a ";", another Citation ("s. 162(1), Sch. 15 para.6, S.I.
  1991/1042, art.2": the Clean Air Act 1956 s.16A), another instrument's
  number ("(1957 I, p. 1439), 1969/1498, arts. 2(1), 5(6)": the Mines and
  Quarries Act 1954 s.182(1)). The bracket round the instrument's own
  number, straight after the Citation, is no end ("S.I. 1994/426 (N.I. 1)
  arts. 1(2), 71(4)"), nor is a piece marked up under another Citation's
  id (its words are list words).

  `pieces/2` is the list of a note whose pieces are marked up with no
  Operative mark (a mark is read as given; a mark on a first provision:
  `FirstProvisionList`); a piece written before the Citation ("s. 106(6)
  of the … Act") is kept. `words/2` is the list of a note with no
  marked-up piece, for `AmendingLaw.Pointer` to read. Pure.
  """

  @typedoc """
  A note's part in document order: the amending Citation (its words),
  the same law cited again, another Citation, a piece of the amending
  Citation (its SectionRef, whether marked Operative), another Citation's
  piece (its words), words.
  """
  @type token ::
          {:citation, String.t()}
          | :same
          | :another
          | {:piece, String.t(), boolean()}
          | {:other, String.t()}
          | {:text, String.t()}

  # the leading run of a note's words that is still the list: joiners,
  # braces, numbers with their brackets, a Schedule's parts
  @list ~r/^(?:[\s,{}]|and\b|\(?\([A-Za-z0-9]+\)|\d+[A-Z]*(?![\w\/.\-])|Schs?\.|Pts?\.|paras?\.|Group\b|[IVXLC]+\b)*/u

  # the same where pieces are written as words: their kinds ("ss.",
  # "art.", "Sch. 3 para."), ranges, and a number that is no date, no
  # instrument's and no Act's year ("1.4.2002", "1969/1498", "1988 c. 36").
  # legislation.gov.uk's slips are still the list: a stop for a comma
  # ("ss. 4. 6(2) Sch. 2"), a brace closing a bracket ("{ss. 6(3)(c}")
  @written ~r/^(?:[\s,{})]|and\b|to\b|[-–]|\(?\([A-Za-z0-9]+[)}]|\d+[A-Z]*(?![\w\/]|\.\d|\s*\(?c\.)|\.(?=\s*(?:\d|[({]|ss?\.|(?i:regs?|arts?|rules?|Schs?|Pts?|paras?)\b))|(?:ss?|(?i:regs?|arts?|rules?|Schs?|Pts?|paras?|Part|Chs?|Group|Order|Table|Note))\b\.?|[IVXLC]+\b)*/u

  # what may stand between the Citation and its list: the bracket closing
  # round the Citation, the instrument's own number in brackets ("(N.I.
  # 1)", "(1957 I, p. 1439)", "(S.I. 2003/419 (N.I. 6))": no word in it),
  # a comma or stop
  @number "\\((?:[^()a-z]|\\b(?:[a-z]|asp)\\b|\\((?:[^()a-z]|\\b[a-z]\\b)*\\))*\\)"
  @lead Regex.compile!("^[\\s,.)]*(?:#{@number})?[\\s,.)]*", "u")

  @doc "A note's `Commentary` as tokens in document order, for the Citation `citation_id`."
  @spec tokens(tuple(), String.t()) :: [token()]
  def tokens(commentary, citation_id),
    do: walk(commentary, {citation_id, uri(commentary, citation_id)})

  defp walk({:xmlElement, :CitationSubRef, _, _, _, _, _, attrs, _, _, _, _} = el, {id, _uri}) do
    if attr(attrs, :CitationRef) == id,
      do: [{:piece, attr(attrs, :SectionRef) || "", attr(attrs, :Operative) == "true"}],
      else: [{:other, text(el)}]
  end

  defp walk({:xmlElement, :Citation, _, _, _, _, _, attrs, _, _, _, _} = el, {id, uri}) do
    cond do
      attr(attrs, :id) == id -> [{:citation, text(el)}]
      uri != nil and attr(attrs, :URI) == uri -> [:same]
      true -> [:another]
    end
  end

  defp walk({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}, ctx),
    do: Enum.flat_map(children, &walk(&1, ctx))

  defp walk({:xmlText, _, _, _, value, _}, _ctx), do: [{:text, to_string(value)}]
  defp walk(_node, _ctx), do: []

  # the law the Citation `id` links to
  defp uri({:xmlElement, :Citation, _, _, _, _, _, attrs, _, _, _, _}, id),
    do: if(attr(attrs, :id) == id, do: attr(attrs, :URI))

  defp uri({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}, id),
    do: Enum.find_value(children, &uri(&1, id))

  defp uri(_node, _id), do: nil

  @doc """
  The leading run of words between marked-up pieces that is still the
  list; the words are the list's own when the run is all of them.
  """
  @spec run(String.t()) :: String.t()
  def run(text), do: @list |> Regex.run(text) |> hd()

  @doc """
  The SectionRefs of the amending pieces of the Citation `citation_id` in
  a `Commentary`, in order: those before the Citation, and those listed
  after it up to the list's end.
  """
  @spec pieces(tuple(), String.t()) :: [String.t()]
  def pieces(commentary, citation_id) do
    {before, rest} = commentary |> tokens(citation_id) |> Enum.split_while(&(not citation?(&1)))

    for({:piece, ref, _marked} <- before, do: ref) ++ listed(rest)
  end

  @doc """
  The Citation `citation_id`'s own words, and the words listing the
  amending pieces after it, up to the list's end (`{"1999 c. 23", "s. 67,
  Sch. 6 "}` of "1999 c. 23, s. 67, Sch. 6 (with Sch. 7 paras. 3(3),
  5(2)); …"). The Citation's words are given because the list may be
  marked up inside it. nil when the note holds no such Citation, or an
  empty one: the law is then named in the note's words
  (`<Citation/>Employment Act 2002 (c. 22), s. 55(2), 53, …`: the
  Employment Rights Act 1996 s.235(1)).
  """
  @spec words(tuple(), String.t()) :: {String.t(), String.t()} | nil
  def words(commentary, citation_id) do
    case commentary |> tokens(citation_id) |> Enum.drop_while(&(not citation?(&1))) do
      [{:citation, cited} | rest] -> named(cited, rest)
      [] -> nil
    end
  end

  # an empty Citation: the law is named in the words after it
  defp named(cited, rest) do
    if String.trim(cited) == "",
      do: nil,
      else:
        {cited,
         rest |> own_number() |> to_next_citation() |> after_lead() |> written() |> to_close()}
  end

  # the list of a law cited inside a bracket ends where the bracket closes
  # ("(as inserted by … (S.I. 2020/1150), regs. 1, 3)": the Taxes
  # Management Act 1970 Pt. 6): a ")" that closes nothing in the list is
  # not the list's
  defp to_close(words) do
    opens = words |> String.graphemes() |> Enum.count(&(&1 == "("))
    closes = words |> String.graphemes() |> Enum.count(&(&1 == ")"))
    trimmed = String.trim_trailing(words)

    if closes > opens and String.ends_with?(trimmed, ")"),
      do: trimmed |> String.trim_trailing(")") |> to_close(),
      else: words
  end

  defp citation?(token), do: match?({:citation, _words}, token)

  # the instrument cited again in brackets straight after its Citation,
  # as its number ("… Regulations 2019 (S.I. 2019/775) (S.I. 2019/775),
  # reg. 68(5)": the Human Medicines Regulations 2012 reg.61(13)), is no
  # other Citation: the brackets close round nothing
  defp own_number([{:text, open}, :same, {:text, close} | rest] = tokens) do
    if String.trim(open) == "(" and String.starts_with?(close, ")"),
      do: [{:text, open <> close} | rest],
      else: tokens
  end

  defp own_number(tokens), do: tokens

  # the pieces after the Citation: through its own pieces and list words
  # (a piece written in words, or marked up under another Citation's id,
  # is passed over, not read), to the first other words or Citation
  defp listed([{:citation, _} | rest]), do: rest |> own_number() |> from_lead() |> listed()
  defp listed([{:piece, ref, _marked} | rest]), do: [ref | listed(rest)]

  defp listed([{kind, text} | rest]) when kind in [:text, :other],
    do: if(written(text) == text, do: listed(rest), else: [])

  defp listed(_tokens), do: []

  defp from_lead([{:text, text} | rest]), do: [{:text, after_lead(text)} | rest]
  defp from_lead(tokens), do: tokens

  defp to_next_citation(tokens) do
    tokens
    |> Enum.take_while(&(&1 not in [:another, :same] and not citation?(&1)))
    |> Enum.map_join(fn
      {:text, text} -> text
      {:other, text} -> text
      {:piece, _ref, _marked} -> ""
    end)
  end

  defp after_lead(text), do: Regex.replace(@lead, text, "", global: false)

  defp written(text), do: @written |> Regex.run(text) |> hd()

  defp text({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}),
    do: Enum.map_join(children, &text/1)

  defp text({:xmlText, _, _, _, value, _}), do: to_string(value)
  defp text(_node), do: ""

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end

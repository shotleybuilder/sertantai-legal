defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Segments do
  @moduledoc """
  An extent sentence cut into its head and each lettered item, each with
  its own verb (extend / apply / same extent), negation and places, or,
  where it states none, those of the statement it belongs to
  (`finder.py`'s `segments`, `is_label`, `unrelative`, `first_clause`,
  `after_verb_places`, `unbracket`; #192). Shares no code with the
  extent reader.
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{Places, Re}
  alias SertantaiLegal.Scraper.Checks.PyCompat

  @type segment :: %{
          required(:text) => String.t(),
          required(:item) => boolean(),
          optional(atom()) => term()
        }

  @verb ~r/\b(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect|ha(?:s|ve)\s+the\s+same\s+extent|same\s+extent)\b/iu
  @neg ~r/\b(?:do(?:es)?|shall|will|is|are)\s+not\s+(?:\w+\s+)?(?:extend|apply|so\s+extend)|\bceases?\s+to\s+(?:extend|apply)\b/iu
  @same ~r/\bsame\s+(?:application\s+and\s+)?extent\b|\bto\s+which\s+the\s+(?:amended\s+)?enactment\s+extends\b|\bextends?\s+to\s+that\s+part\b/iu
  @qual ~r/\b(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent\s+that|so\s+much\s+of|as\s+relates?\s+to)\b/iu
  @relative ~r/\b(?:which|who)\b[^,;—–]{0,60}?\b(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect)\b|\b(?:that|as)\s+(?:\w+\s+){0,2}?(?:extends?|extending|appl(?:y|ies)|ha(?:s|ve)\s+effect)\b|\bextending\s+to\b|(?<!cease\s)(?<!ceases\s)\bto\s+(?:continue\s+to\s+)?(?:have\s+effect|extend|apply)\b/iu
  @label ~r/(?:(?<=[—–:;,])|(?<=;\s)|(?<=\band)|(?<=\bor)|(?<=,\s)|(?<=—\s))\s*\(?((?:[a-h]|z?[a-z])|[ivx]{1,4})\)?\s+(?=[A-Z(]|the\b|this\b|in\b|any\b|an\b|so\b|sections?\b|paragraphs?\b|regulations?\b|articles?\b|subsections?\b|Parts?\b|Schedules?\b|Chapters?\b)/u
  @save ~r/[;,]?\s*but\s+(?:,\s*)?save\s+as\s+(?:aforesaid|otherwise\s+provided)\b.*$/iu
  @dash_end ~r/[—–]\s*$/u
  @roman_label ~r/\A[ivx]{1,4}\z/u
  @but_split ~r/\s*[;,]?\s*\bbut\b,?\s*(?=.*\b(?:extends?|appl(?:y|ies))\b)/u
  @and_split ~r/,?\s+and\s+(?=(?:this|that|the|those|sections?|subsections?|paragraphs?|regulations?|articles?|Parts?|Schedules?|Chapters?)\b)/u
  @outside ~r/\boutside\s+(?:the\s+)?(?:United\s+Kingdom|Great\s+Britain|England|Wales|Scotland|Northern\s+Ireland)/u
  @place_cut ~r/\bbut\b|;|,\s*and\s+those\b|,?\s*except\s+(?:that|as\s+follows|as\s+set\s+out)\b/u

  @doc "`VERB`: extend, apply, have effect, same extent."
  @spec verb() :: Regex.t()
  def verb, do: @verb

  @doc "`NEG`: does not extend / apply."
  @spec neg() :: Regex.t()
  def neg, do: @neg

  @doc "`SAME`: the same extent."
  @spec same() :: Regex.t()
  def same, do: @same

  @doc "`QUAL`: so far as, to the extent that …"
  @spec qual() :: Regex.t()
  def qual, do: @qual

  @doc "The head and each lettered item of `s`, each with `verb`, `neg`, `same`, `places` (and `label`, `save`, `inherited`)."
  @spec segments(String.t()) :: [segment()]
  def segments(s) do
    s =
      s
      |> then(&Regex.replace(~r/“[^”]*”|"[^"]*"/u, &1, "Q"))
      |> then(&Regex.replace(~r/(?:\s*\.\s*){3,}(?:\s*,)?/u, &1, " "))
      |> then(
        &Regex.replace(
          ~r/\b(sections?|paragraphs?|regulations?|Schedules?)\s*,\s*(?=\d)/u,
          &1,
          "\\1 "
        )
      )
      |> then(&(~r/\.(?=[A-Z])/u |> Re.split1(&1) |> hd()))

    save = Re.search(@save, s)
    body = if save, do: Re.upto(s, Re.start(save)), else: s

    {pieces, labels} =
      body |> cut(Enum.filter(Re.all(@label, body), &label?(body, &1))) |> merge() |> split()

    [head | _] = pieces

    out =
      pieces
      |> Enum.zip(labels)
      |> Enum.with_index()
      |> Enum.map(fn {{p, lab}, i} -> %{text: p, item: i > 0, label: lab} end)
      |> Kernel.++(
        if save, do: [%{text: Re.group(save, s, 0), item: false, save: true}], else: []
      )

    hv = Regex.match?(@verb, unrelative(head))

    if whole_list?(hv, head, out),
      do: [whole_list(s, head, out)],
      else: statements(out, head, hv)
  end

  # "They apply in relation to— (a) England …, and (b) Wales": the items
  # are the head's places, one statement
  defp whole_list?(hv, head, out) do
    hv and not Regex.match?(@same, head) and after_verb_places(head) == nil and length(out) > 1 and
      not Enum.any?(tl(out), &Regex.match?(@verb, &1.text))
  end

  defp whole_list(s, head, out) do
    %{
      text: s,
      item: false,
      verb: true,
      neg: Regex.match?(@neg, head),
      same: Regex.match?(@same, head),
      places: out |> tl() |> Enum.map_join(" ", & &1.text) |> Places.code()
    }
  end

  defp cut(body, cuts) do
    {pieces, labels, at} =
      Enum.reduce(cuts, {[], [nil], 0}, fn c, {ps, ls, at} ->
        {[binary_part(body, at, Re.start(c) - at) | ps], [Re.group(c, body, 1) | ls], Re.stop(c)}
      end)

    {Enum.reverse([Re.from(body, at) | pieces]), Enum.reverse(labels)}
  end

  # an item leading a sub-list ("d subsections (4) and (5) … so far as
  # they relate to— i …; ii …; iii …, extend to Northern Ireland"): its
  # verb is in its last sub-item, one statement
  defp merge({pieces, labels}) do
    pairs = Enum.zip(pieces, labels) |> Enum.with_index()
    merge(pairs, [])
  end

  defp merge([], acc), do: acc |> Enum.reverse() |> Enum.unzip()

  defp merge([{{p, lab}, k} | rest], acc) do
    if k > 0 and leads_sub_list?(p) do
      {subs, rest} =
        Enum.split_while(rest, fn {{_, l}, _} -> Regex.match?(@roman_label, l || "") end)

      merged = Enum.reduce(subs, p, fn {{sp, _}, _}, acc -> acc <> " " <> sp end)
      merge(rest, [{merged, lab} | acc])
    else
      merge(rest, [{p, lab} | acc])
    end
  end

  defp leads_sub_list?(p) do
    not Regex.match?(@verb, p) and Regex.match?(@dash_end, p) and
      not Regex.match?(~r/\bexcept\s*(?:for\s*)?[—–]\s*$/u, p)
  end

  defp split({pieces, labels}) do
    pieces
    |> Enum.zip(labels)
    |> Enum.flat_map(fn {p, lab} ->
      case two_statements(p) do
        [a, b] -> [{a, lab}, {b, nil}]
        [_] -> [{p, lab}]
      end
    end)
    |> Enum.unzip()
  end

  defp two_statements(p) do
    bits = Re.split1(@but_split, p)

    if match?([_, _], bits) and verb?(Enum.at(bits, 0)) and Places.code(Enum.at(bits, 1)) != nil and
         verb?(Enum.at(bits, 1)),
       do: bits,
       else: and_statements(p)
  end

  defp and_statements(p) do
    case Re.split1(@and_split, p) do
      [a, b] = bits ->
        cond do
          not (verb?(a) and after_verb_places(a) != nil and Places.code(b) != nil) -> [p]
          verb?(b) -> bits
          Re.match?(~r/\s*those\b/u, b) -> [a, those_verb(a, b)]
          true -> [p]
        end

      [_] ->
        [p]
    end
  end

  # "and those in Part III of Schedule 1 to Scotland only": the first's verb
  defp those_verb(a, b) do
    verb = Re.group(Re.search(@verb, unrelative(a)), unrelative(a), 0)

    Re.sub1(
      ~r/\s+to\s+(?=(?:the\s+)?(?:England|Wales|Scotland|Northern|United|Great))/u,
      b,
      " #{verb} to "
    )
  end

  defp verb?(text), do: Regex.match?(@verb, unrelative(text))

  # each segment's statement: its own, else (for an item) its parent
  # item's, else the head's, else (where only the last item has one) the last's
  defp statements(out, head, hv) do
    tail_src = tail_source(out, hv)

    out
    |> Enum.map_reduce(nil, fn o, parent ->
      o = own_statement(o)
      statement(o, source(parent, hv, head, tail_src), parent)
    end)
    |> elem(0)
  end

  defp source(nil, true, head, _tail_src), do: head
  defp source(nil, false, _head, tail_src), do: tail_src
  defp source(parent, _hv, _head, _tail_src), do: parent.text

  defp statement(%{item: false} = o, _src, parent), do: {o, parent}

  defp statement(o, src, parent) do
    if src not in [nil, ""] and not (o.verb and stated?(o)),
      do: {inherit(o, src), parent},
      else: {o, next_parent(o, parent)}
  end

  # an item with its own statement ending in a dash leads its sub-items
  defp next_parent(%{verb: false}, parent), do: parent
  defp next_parent(o, _parent), do: if(stated?(o) and Regex.match?(@dash_end, o.text), do: o)

  defp stated?(o), do: o.places != nil or o.same

  defp tail_source(out, hv) do
    last = List.last(out).text

    if not hv and length(out) > 2 and verb?(last) and
         (after_verb_places(last) != nil or Regex.match?(@same, last)) and
         not Enum.any?(out |> tl() |> Enum.drop(-1), &verb?(&1.text)),
       do: last
  end

  defp own_statement(o) do
    Map.merge(o, %{
      verb: verb?(o.text),
      neg: Regex.match?(@neg, first_clause(o.text)),
      same: Regex.match?(@same, o.text),
      places: after_verb_places(o.text)
    })
  end

  # an item's sub-items take its statement ("a the following provisions
  # extend to England and Wales— i …; ii …"), else the head's
  defp inherit(o, src) do
    u = unrelative(src)
    vs = Re.all(@verb, u)
    from = if length(vs) > 1, do: Re.carry_from(src, u, Re.start(List.last(vs))), else: src

    Map.merge(o, %{
      verb: true,
      same: Regex.match?(@same, src),
      places: after_verb_places(from),
      neg: Regex.match?(@neg, from),
      inherited: true
    })
  end

  @doc ~s|"an enactment which extends to Scotland": no statement's verb (`RELATIVE` blanked).|
  @spec unrelative(String.t()) :: String.t()
  def unrelative(text), do: Regex.replace(@relative, text, " ")

  @doc "The statement's first clause: before \"but\", and before \", save / except / subject\" when a verb precedes it."
  @spec first_clause(String.t()) :: String.t()
  def first_clause(text) do
    text = Regex.replace(~r/^\s*[;,]?\s*but\b/u, text, "")
    head = ~r/[;,]?\s*\bbut\b/u |> Regex.split(text) |> hd()

    case Re.search(~r/,\s*(?:save|except|subject)\b/u, head) do
      nil ->
        head

      m ->
        before = Re.upto(head, Re.start(m))
        if verb?(before), do: before, else: head
    end
  end

  @doc "Whether a LABEL match is a label: after a dash, a semicolon, \"and\"/\"or\" (a letter or roman), or a comma (one letter but a, i)."
  @spec label?(String.t(), [{integer(), integer()}]) :: boolean()
  def label?(body, m) do
    lab = Re.group(m, body, 1)
    pre = body |> Re.upto(Re.start(m)) |> PyCompat.rstrip()
    last = pre |> String.codepoints() |> List.last()

    cond do
      pre == "" -> false
      last in ["—", "–", ":", ";"] -> true
      Regex.match?(~r/(?:\band|\bor)$/u, pre) and Re.len(lab) <= 4 -> after_and?(lab)
      last == "," and Re.len(lab) == 1 and lab not in ["a", "i"] -> true
      true -> false
    end
  end

  # `lab in "abc…z"`: a substring of the alphabet ("a", "bc"), or a roman numeral
  defp after_and?(lab),
    do: String.contains?("abcdefghijklmnopqrstuvwxyz", lab) or Regex.match?(@roman_label, lab)

  @doc "The places a statement names after its verb (bracketed and relative words out), or anywhere when it has no verb."
  @spec after_verb_places(String.t()) :: String.t() | nil
  def after_verb_places(text) do
    text = text |> unrelative() |> unbracket() |> then(&Regex.replace(@outside, &1, " "))

    case Re.search(@verb, text) do
      nil ->
        Places.code(text)

      v ->
        text
        |> Re.from(Re.stop(v))
        |> then(&(Regex.split(@place_cut, &1) |> hd()))
        |> Places.code()
    end
  end

  @doc ~s|Bracketed words out ("(as well as to England and Wales …)"), innermost first.|
  @spec unbracket(String.t()) :: String.t()
  def unbracket(text) do
    case Regex.replace(~r/\([^()]*\)/u, text, " ") do
      ^text -> text
      next -> unbracket(next)
    end
  end
end

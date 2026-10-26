defmodule SertantaiLegal.Scraper.Amendment.Reader.LawNamed do
  @moduledoc """
  Which law an amending text names (LR-41; decomposed from
  `Amendment.Reader`, run time 2026-10-25): the nearest text naming any law
  (a defined term, a title — "etc." included —, a chapter), whether a
  reference is a given law, and each clause scoped to its law (its part of
  a clause naming two laws, its brackets and numbers). Pure; calls
  `Reader.Clauses`, `Reader.Targets` and `Reader.Brackets`.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.{Brackets, Clauses, EuCitation, Targets}

  # a law's title in running text; "etc." inside it ("Health and Safety at
  # Work etc. Act 1974", "The Maternity and Parental Leave etc. Regulations
  # 1999 are amended": SI 2013/283, run time 2026-10-25) — the full stop
  # had ended the match, so such a title named no law
  @title_words ~S"[A-Z](?:[\w,'’()\- ]|\betc\.)*? (?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4}"
  @title Regex.compile!(@title_words, "u")
  @title_group Regex.compile!("(" <> @title_words <> ")", "u")

  @doc """
  Each clause with its brackets and numbers: a clause naming none takes
  its predecessor's numbers, and the first clause's place ("in subsection
  (1), paragraph (b) is omitted and in paragraph (c) …" → (1)(c)) at the
  levels above its own; a clause naming another law is that law's
  """
  @spec scoped([Text.t()], [String.t()], Reader.law_ref(), map()) :: [
          %{text: Text.t(), named: [String.t()], numbers: [String.t()], ours?: boolean()}
        ]
  def scoped(clauses, texts, law, terms) do
    [first | _] = clauses
    place = Clauses.located_brackets(first.instruction)
    context = tl(texts)

    {scoped, _} =
      Enum.map_reduce(clauses, {nil, true}, fn c, {prev, ours?} ->
        # captions and quotes aside: a law named there is not the clause's
        unquoted =
          c.instruction |> Clauses.asides() |> Clauses.unquote_words() |> own_part(law, terms)

        ours? =
          case laws(unquoted, terms) do
            [] -> ours?
            refs -> Enum.any?(refs, &law_named?(&1, law))
          end

        numbers =
          case {Targets.numbers([unquoted], law.kind), prev} do
            {{:ok, ns}, _} ->
              ns

            # (never from a caption: "In section 11 (interpretation of
            # sections 3A to 10), in subsection (2)—", 2013/22 s.56(2))
            {:none, nil} ->
              with(
                {:ok, ns} <- Targets.numbers(Enum.map(context, &Clauses.no_captions/1), law.kind),
                do: ns,
                else: (_ -> [])
              )

            {:none, ns} ->
              ns
          end

        own =
          Targets.brackets(%{
            c
            | instruction:
                c.instruction
                |> Clauses.asides()
                |> Clauses.unquote_words()
                |> own_part(law, terms)
                |> Clauses.no_captions()
          })

        named = if c == first, do: own, else: Brackets.above(place, own) ++ own
        named = placed_by(c, named, context) ++ named
        {%{text: c, named: named, numbers: numbers, ours?: ours?}, {numbers, ours?}}
      end)

    Enum.filter(scoped, & &1.ours?)
  end

  # where a clause is beyond its own words (run time 2026-10-26; 1995/25
  # Sch. 22 para 30(6)): its parents' brackets, nearest first, each at the
  # levels above those already found ("(f) in subsection (5)— (i) in
  # paragraph (a) …" → (5)(a)); never a sibling's. "of that subsection"
  # with no subsection found: the last one named before it ("(a) in
  # paragraph (a) of subsection (3) …; (b) in paragraph (c)(ii) of that
  # subsection …" → (3))
  defp placed_by(%Text{} = c, named, context) do
    from_parents =
      Enum.reduce(c.parents, [], fn words, acc ->
        brackets =
          Targets.brackets(%Text{
            id: nil,
            instruction: words |> Clauses.unquote_words() |> Clauses.no_captions() |> lead_in()
          })

        top = top_level(named ++ acc, c.instruction)
        acc ++ Enum.filter(brackets, &(Brackets.bracket_level(&1) < top))
      end)

    found = named ++ from_parents

    that_subsection =
      if c.instruction =~ ~r/\b(?:that|the said)\s+sub-?section\b/i and
           not Enum.any?(found, &(Brackets.bracket_level(&1) == 0)) do
        Enum.find_value(context, [], fn t ->
          case Regex.scan(
                 ~r/\bsub-?section\s+\((\d+[A-Z]*)\)/i,
                 t |> Clauses.unquote_words() |> Clauses.no_captions(),
                 capture: :all_but_first
               ) do
            [] -> nil
            found -> List.last(found)
          end
        end)
      else
        []
      end

    from_parents ++ that_subsection
  end

  # a parent's lead-in, where it changes something first ("In subsection
  # (3), omit the words … and in subsection (5)—": "in subsection (5)";
  # 1994/19 s.18(6)); else its words
  defp lead_in(s) do
    case Regex.run(
           ~r/(?:^|[;,]\s*|\s+and\s+)([Ii]n\s(?:(?![;]|\s+and\s+in\s).)*?)\s*[—–:]\s*$/u,
           s,
           capture: :all_but_first
         ) do
      [lead] -> lead
      nil -> s
    end
  end

  # the highest level among the brackets found (5 when none): a bracket the
  # words call a sub-paragraph is one ("in sub-paragraph (i)" under "in
  # paragraph (b)—": (b)(i), though "i" alone reads as a letter)
  defp top_level([], _instruction), do: 5

  defp top_level(brackets, instruction) do
    subs =
      for [b] <-
            Regex.scan(~r/\bsub-paragraphs?\s+\(([a-z]+)\)/i, instruction,
              capture: :all_but_first
            ),
          do: b

    brackets
    |> Enum.map(&if(&1 in subs, do: 2, else: Brackets.bracket_level(&1)))
    |> Enum.min()
  end

  @doc """
  A clause naming two laws ("Section 7 of the PPVA 1981 and section 68(1)
  and (2) of the RTA 1988 shall cease to have effect"): the law's part is
  the text up to its name from the name before
  """
  @spec own_part(String.t(), Reader.law_ref(), map()) :: String.t()
  def own_part(t, law, terms) do
    spans = law_spans(t, terms)
    ours = Enum.map(spans, fn {_, _, r} -> law_named?(r, law) end)

    if Enum.any?(ours) and not Enum.all?(ours) do
      # the last law named has the rest of the text ("… of the RTA 1988
      # (…) shall cease to have effect")
      last = length(spans) - 1

      spans
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {{_, b, r}, k}, {from, acc} ->
        stop = if k == last, do: byte_size(t), else: b
        {b, if(law_named?(r, law), do: [binary_part(t, from, stop - from) | acc], else: acc)}
      end)
      |> elem(1)
      |> Enum.reverse()
      |> Enum.join(" ")
    else
      t
    end
  end

  @doc """
  Each law named, with its place in the text
  """
  @spec law_spans(String.t(), map()) :: [{non_neg_integer(), non_neg_integer(), map()}]
  def law_spans(t, terms) do
    lower = String.downcase(t)

    defined =
      for {term, law} <- terms,
          law.law != nil or law.title != nil,
          [{a, len}] <-
            Regex.scan(term_re(term), lower, return: :index),
          do: {a, a + len, law}

    titled =
      for [{a, len}] <-
            Regex.scan(
              @title,
              t,
              return: :index
            ),
          do: {a, a + len, %{law: nil, title: binary_part(t, a, len)}}

    chapters =
      for [{a, len}, {ya, yl}, {na, nl}] <-
            Regex.scan(~r/\b(\d{4}) c\. (\d+)/, t, return: :index),
          do: {a, a + len, %{law: nil, chapter: {binary_part(t, ya, yl), binary_part(t, na, nl)}}}

    eu =
      for [{a, len} | _] = m <- EuCitation.scan(t, return: :index),
          ref = EuCitation.ref(Enum.map(m, &part(t, &1))),
          do: {a, a + len, ref}

    # a name inside another ("land" in "Land Compensation Act 1973") is
    # part of it
    (defined ++ titled ++ chapters ++ eu)
    |> Enum.sort()
    |> Enum.reduce([], fn
      {_, b, _}, [{_, pb, _} | _] = acc when b <= pb -> acc
      span, acc -> [span | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  The laws the nearest text naming any law names (LR-41)
  """
  @spec named(Enumerable.t(), map()) :: [map()]
  def named(texts, terms) do
    Enum.find_value(texts, [], fn t ->
      case laws(t, terms) do
        [] -> nil
        refs -> refs
      end
    end)
  end

  # a defined term as a whole word, compiled once per process (it was
  # compiled at every match: 570,639 compiles reading ukpga 1995/25)
  defp term_re(term) do
    key = {__MODULE__, :term_re, term}

    case Process.get(key) do
      nil -> tap(~r/(?<![\w])#{Regex.escape(term)}(?![\w])/u, &Process.put(key, &1))
      re -> re
    end
  end

  defp laws(t, terms) do
    lower = String.downcase(t)

    defined =
      for {term, law} <- terms,
          law.law != nil or law.title != nil,
          Regex.match?(term_re(term), lower),
          do: law

    titled =
      for [x] <-
            Regex.scan(
              @title_group,
              t,
              capture: :all_but_first
            ),
          do: %{law: nil, title: x}

    chapters =
      for [y, n] <- Regex.scan(~r/\b(\d{4}) c\. (\d+)/, t, capture: :all_but_first),
          do: %{law: nil, chapter: {y, n}}

    eu =
      for m <- EuCitation.scan(t),
          ref = EuCitation.ref(m),
          do: ref

    defined ++ titled ++ chapters ++ eu
  end

  defp part(_t, {-1, 0}), do: ""
  defp part(t, {a, len}), do: binary_part(t, a, len)

  @doc """
  Whether a law reference found in the text (a defined term's law, a
  chapter, a title) is `law`.
  """
  @spec law_named?(map(), Reader.law_ref()) :: boolean()
  def law_named?(%{law: name}, law) when is_binary(name), do: name == law.law_name
  def law_named?(%{chapter: {y, n}}, law), do: y == law.year and n == law.number

  def law_named?(%{eu: {type, y, n}}, law),
    do: String.starts_with?(law.law_name, "UK_#{type}_") and y == law.year and n == law.number

  def law_named?(%{title: t}, law) when is_binary(t) and is_binary(law.title),
    do: String.ends_with?(norm(t), norm("#{law.title} #{law.year}"))

  def law_named?(_ref, _law), do: false

  @doc """
  A title as compared: lower case, "the" and punctuation dropped.
  """
  @spec norm(String.t()) :: String.t()
  def norm(t),
    do:
      t
      |> String.downcase()
      |> String.replace(~r/^the /, "")
      |> String.replace(~r/[^a-z0-9]+/, " ")
      |> String.trim()
end

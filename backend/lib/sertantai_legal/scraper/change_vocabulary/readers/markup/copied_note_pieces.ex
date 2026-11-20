defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.CopiedNotePieces do
  @moduledoc """
  A copied note's pieces, named for the note's own Citation.

  Where legislation.gov.uk copies a note, the copy's `Citation` id gains
  "n1" while its `CitationSubRef`s keep the `CitationRef` of the note
  copied from: "… by Regulatory Reform (Forestry) Order 2006 (S.I.
  2006/780), arts. 1(1), 3(3)" (the Forestry Act 1967 s.8(2)(3)), the
  Citation `…00008n1`, its pieces under `…00008`. `mend/1` gives such
  pieces the Citation's own id, so the note is read as any note is: its
  Operative marks, a first-provision list, a territory's instrument.

  A copied piece's marks are the copy's own, its `SectionRef` sometimes
  the copied note's: "Sch. 8 para. 18(3)(b)(i)" under
  `schedule-8-paragraph-18-3-a` (the Local Government Act 1974
  s.26(7)(ba)). Where a copied piece's words contradict its SectionRef,
  the words name the provision, also where they say less ("Sch. 12 para.
  32" under `schedule-12-paragraph-32-2`: the Education Act 2002 s.76(1)). Bare words continue the piece before
  ("3(2)(b)" after "regs. 1(2)"; "(2)(f)" after "Sch. 17 para. 57(1)").
  Words naming no provision, or several ("s. 183(1)(5)(e)"), keep the
  SectionRef.

  A Citation is a copy only when no piece names its id, pieces name the
  id before the copy, and no Citation of the note still holds that id.
  Any other note is returned as it is. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Pointer
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.FirstProvisionList

  @copy ~r/^(.+?)n\d+$/
  @kind_words ~w(schedule sch schs part pt pts paragraph para paras section s ss
                 article art arts regulation reg regs rule rules r rr and)
  @abbreviations %{section: "s.", regulation: "reg.", article: "art.", rule: "rule"}

  @doc "A note's `Commentary` with each copied Citation's pieces named for it."
  @spec mend(tuple()) :: tuple()
  def mend(commentary) do
    case copies(commentary) do
      copies when map_size(copies) == 0 -> commentary
      copies -> commentary |> rewrite({copies, %{}}) |> elem(0)
    end
  end

  # each id before a copy → the copied Citation's id
  defp copies(commentary) do
    citations = collect(commentary, :Citation, :id)
    named = collect(commentary, :CitationSubRef, :CitationRef)

    for id <- citations,
        [_, before] <- [Regex.run(@copy, id)],
        id not in named and before in named and before not in citations,
        into: %{},
        do: {before, id}
  end

  defp collect({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _}, wanted, attribute) do
    own = if name == wanted, do: List.wrap(attr(attrs, attribute)), else: []
    own ++ Enum.flat_map(children, &collect(&1, wanted, attribute))
  end

  defp collect(_node, _wanted, _attribute), do: []

  # the note in document order; the state carries, per copied Citation, the
  # provision its last piece named (what bare words continue)
  defp rewrite({:xmlElement, :CitationSubRef, _, _, _, _, _, attrs, _, _, _, _} = el, state) do
    {copies, last} = state
    before = attr(attrs, :CitationRef)

    case copies[before] do
      nil -> {el, state}
      id -> piece(el, id, {copies, last}, before)
    end
  end

  defp rewrite({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el, state) do
    {children, state} = Enum.map_reduce(children, state, &rewrite/2)
    {put_elem(el, 8, children), state}
  end

  defp rewrite(node, state), do: {node, state}

  defp piece(el, id, {copies, last}, before) do
    stated = attr(elem(el, 7), :SectionRef) || ""
    words = text(el)
    read = read(words, last[before])
    ref = if agree?(stated, words), do: stated, else: section_ref(read) || stated

    el = el |> put(:CitationRef, id) |> put(:SectionRef, ref)
    {el, {copies, Map.put(last, before, read || last[before])}}
  end

  # the SectionRef's numbers end with the words' ("3(3)" under
  # `article-3-3`): the words do not contradict it. Words that say less
  # ("Sch. 12 para. 32" under `…-paragraph-32-2`) do: the copied note's
  # deeper piece is not this note's
  defp agree?(stated, words) do
    said = numbers(words)
    said == [] or Enum.take(numbers(stated), -length(said)) == said
  end

  defp numbers(text) do
    ~r/[A-Za-z0-9]+/
    |> Regex.scan(text)
    |> Enum.map(fn [token] -> String.downcase(token) end)
    |> Enum.reject(&(&1 in @kind_words))
  end

  # the one provision a piece's words name, bare words continuing `last`;
  # nil where they name none or several
  defp read(words, last) do
    with text when is_binary(text) <- in_full(String.trim(words), last),
         [ref] <- Pointer.refs_in(text),
         [_one] <- Pointer.to_refs(ref) do
      ref
    else
      _ -> nil
    end
  end

  defp in_full("(" <> _ = words, last),
    do: last && with_number(last) && with_number(last) <> words

  defp in_full(words, last) do
    if words =~ ~r/^\d/, do: last && kind(last) && kind(last) <> " " <> words, else: words
  end

  defp kind({:schedule, _n, _part, nil, _subs}), do: nil
  defp kind({:schedule, nil, _part, _para, _subs}), do: "Sch. para."
  defp kind({:schedule, n, _part, _para, _subs}), do: "Sch. #{n} para."
  defp kind({kind, _n, _subs}), do: @abbreviations[kind]

  defp with_number({:schedule, _n, _part, para, _subs} = last),
    do: kind(last) && "#{kind(last)} #{para}"

  defp with_number({_kind, n, _subs} = last), do: kind(last) && "#{kind(last)} #{n}"

  defp section_ref(nil), do: nil
  defp section_ref(ref), do: FirstProvisionList.section_ref(ref)

  defp text({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}),
    do: Enum.map_join(children, &text/1)

  defp text({:xmlText, _, _, _, value, _}), do: to_string(value)
  defp text(_node), do: ""

  defp put(el, name, value) do
    attrs =
      Enum.map(elem(el, 7), fn
        {:xmlAttribute, ^name, _, _, _, _, _, _, _, _} = a -> put_elem(a, 8, to_charlist(value))
        a -> a
      end)

    put_elem(el, 7, attrs)
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end

defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ScheduleRest do
  @moduledoc """
  The paragraphs of a Schedule no list names, where its introducing section
  is withheld only for the paragraphs the lists do name (Fire and OH&S:
  Extent reader, 2026-11-14): "(1) Except as provided by subsections (2) to
  (6), this Act extends only to England and Wales. (2) The following
  provisions extend to England and Wales, Scotland and Northern Ireland—
  (a) section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule
  1, and those paragraphs; …" (Policing and Crime Act 2017 s.182). Section 6
  is qualified, so withheld (round 11), and Schedule 1 followed it whole;
  but each qualifier's object is paragraphs of Schedule 1 that a list
  names, so the Schedule's other paragraphs are "provided" for nowhere and
  take the law's default: `{:only, default, paragraphs}`.

  Only where every qualified item naming the section relates to paragraphs
  of the very Schedule it introduces, each of them in a list; the section
  named in no other list; and the law states a default. The section itself,
  and the Schedule cited whole, stay withheld. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.Commencement.Order

  @type list_entry :: {atom(), String.t() | nil, [String.t()]}

  @qualifier ~r/,?\s+(?:in\s+so\s+far|so\s+far|insofar)\s+as\b|\s+to\s+the\s+extent\b/iu
  @relating ~r/^\s*(?:it\s+|they\s+)?relat\w*\s+to\s+(?<obj>paragraphs?\s+(?:(?!\b(?:Schedules?|sections?|Parts?|Act)\b)[^;—–])*?\s+of\s+Schedule\s+(?<n>\d+[A-Z]*))(?:\s*,?\s+and\s+(?:those|that)\s+paragraphs?)?\s*\.?\s*$/u
  @label ~r/^\s*(?:and\s*)?\(?(?!(?:in|of|to|or|as|by|on|at|an|so|no)\s)[a-z]{1,2}\)?\s+(?=\S)/u

  @doc """
  The default's list for each such Schedule's unnamed paragraphs, from the
  unit sentences (`Units.unit_sentences/1`), the `lists` read, the law's
  `default` and each Schedule's introducing section.
  """
  @spec lists(
          [{String.t(), String.t()}],
          [list_entry()],
          String.t() | nil,
          %{String.t() => String.t()},
          Doc.t()
        ) :: [list_entry()]
  def lists(_unit_sentences, _lists, nil, _introduced_by, _doc), do: []

  def lists(unit_sentences, lists, default, introduced_by, %Doc{} = doc) do
    items = qualified_items(unit_sentences)

    for {sch, section} <- Enum.sort(introduced_by),
        withheld_only?(section, lists),
        own_paragraphs_only?(items, section, sch, lists),
        rest = rest(sch, lists, doc),
        rest != [],
        do: {:only, default, rest}
  end

  # the section is in a withheld list and no other
  defp withheld_only?(section, lists) do
    {unread, others} =
      lists
      |> Enum.filter(fn {_, _, items} -> section in items end)
      |> Enum.split_with(&match?({:unread, _, _}, &1))

    unread != [] and others == []
  end

  # every qualified item naming the section relates to the Schedule's own
  # paragraphs, each in a list
  defp own_paragraphs_only?(items, section, sch, lists) do
    case Enum.filter(items, fn {refs, _object} -> section in refs end) do
      [] -> false
      naming -> Enum.all?(naming, fn {_, object} -> own_paragraphs?(object, sch, lists) end)
    end
  end

  defp own_paragraphs?(object, "sch." <> n = sch, lists) do
    with %{"obj" => obj, "n" => ^n} <- Regex.named_captures(@relating, object),
         [_ | _] = paras <- RefList.parse(obj, nil) do
      Enum.all?(paras, &(String.starts_with?(&1, sch <> ".") and listed?(&1, lists)))
    else
      _ -> false
    end
  end

  # each lettered item with a qualifier: `{the provisions before it, the
  # words after it}`
  defp qualified_items(unit_sentences) do
    for {ref, s} <- unit_sentences,
        item <- s |> String.split(~r/[—–;]/u) |> Enum.map(&String.replace(&1, @label, "")),
        [subject, object] <- [Regex.split(@qualifier, item, parts: 2)],
        uniq: true,
        do: {RefList.parse(subject, ref), object}
  end

  # the Schedule's paragraphs no list names, whole or in part
  defp rest(sch, lists, doc) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil and Regex.match?(~r/^#{Regex.escape(sch)}\.para\.[^.(]+$/u, ref),
        not listed?(ref, lists),
        uniq: true,
        do: ref
  end

  defp listed?(ref, lists) do
    Enum.any?(lists, fn {_, _, items} ->
      Enum.any?(items, &(&1 != "*" and (RefList.covers?(&1, ref) or RefList.covers?(ref, &1))))
    end)
  end
end

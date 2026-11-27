defmodule SertantaiLegal.Scraper.AmendingLaw.Locator do
  @moduledoc """
  A pointer's provision ref → the amending law's element ids (lat-refactor
  LR-08). "s. 60(5)(7)" → `section-60-5` (and `-7` when held): a note's
  brackets are a path ("para. 33(c)") or a list of subsections ("(5)(7)"),
  so the full path is tried, else each bracket on its own, else the
  provision. A Schedule paragraph's id carries its Part where the Part
  numbers its paragraphs ("Sch. 26 Pt. 2 para. 10" →
  `schedule-26-part-2-paragraph-10`), else none ("Sch. 6 Pt. II para. 33"
  → `schedule-6-paragraph-33`). Only held ids are returned. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Pointer}

  @prefix %{section: "section", regulation: "regulation", article: "article", rule: "rule"}

  @doc "The held element ids a ref points to; [] when none is held."
  @spec ids(Doc.t(), Pointer.ref()) :: [String.t()]
  def ids(doc, {:schedule, number, _part, nil, _subs}) when is_binary(number),
    do: held(doc, ["schedule-#{number}"])

  # a Schedule numbering its paragraphs by Part carries the Part in its
  # paragraphs' ids ("Sch. 26 Pt. 2 para. 10(2)" →
  # `schedule-26-part-2-paragraph-10-2`: SI 2010/675), else they run through
  # it; a pointer without the Part finds such a paragraph by its shortId
  # ("Sch. 29 para. 3(b)" → `schedule-29-part-1-paragraph-3-b`); and a Part
  # paragraph's sub-paragraphs may carry no Part (`schedule-29-paragraph-2-2`
  # under `schedule-29-part-1-paragraph-2`: SI 2016/1154). Each form is
  # tried for the full path before any coarser id (amending Schedules,
  # 2026-11-27)
  def ids(doc, {:schedule, number, part, para, subs}) when is_binary(number) do
    partless = "schedule-#{number}-paragraph-#{para}"
    own = if part, do: ["schedule-#{number}-part-#{part}-paragraph-#{para}"], else: []
    path(doc, Enum.uniq(own ++ [partless, Map.get(doc.short, partless, partless)]), subs)
  end

  # a law's only Schedule, unnumbered ("S.I. 1976/2004, Sch.": id
  # `schedule`, its paragraphs `schedule-paragraph-N`; CV-06a)
  def ids(doc, {:schedule, nil, _part, nil, _subs}), do: held(doc, ["schedule"])

  def ids(doc, {:schedule, nil, _part, para, subs}),
    do: path(doc, "schedule-paragraph-#{para}", subs)

  def ids(doc, {kind, number, subs}) when is_map_key(@prefix, kind),
    do: path(doc, "#{@prefix[kind]}-#{number}", subs)

  def ids(_doc, _ref), do: []

  # the full path under any of `bases` (one provision's id forms, in order),
  # else each bracket on its own, else the provision
  defp path(doc, bases, subs) when is_list(bases) do
    subs = Enum.map(subs, &String.downcase/1)

    Enum.find_value(
      [
        fn b ->
          if subs == [], do: held(doc, [b]), else: held(doc, [Enum.join([b | subs], "-")])
        end,
        fn b -> if subs == [], do: [], else: held(doc, Enum.map(subs, &"#{b}-#{&1}")) end,
        fn b -> held(doc, [b]) end
      ],
      [],
      fn try -> Enum.find_value(bases, &nonempty(try.(&1))) end
    )
  end

  defp path(doc, base, subs), do: path(doc, [base], subs)

  defp nonempty([]), do: nil
  defp nonempty(ids), do: ids

  defp held(doc, ids), do: Enum.filter(ids, &Map.has_key?(doc.elements, &1))
end

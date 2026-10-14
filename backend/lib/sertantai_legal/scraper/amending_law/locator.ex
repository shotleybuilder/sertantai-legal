defmodule SertantaiLegal.Scraper.AmendingLaw.Locator do
  @moduledoc """
  A pointer's provision ref → the amending law's element ids (lat-refactor
  LR-08). "s. 60(5)(7)" → `section-60-5` (and `-7` when held): a note's
  brackets are a path ("para. 33(c)") or a list of subsections ("(5)(7)"),
  so the full path is tried, else each bracket on its own, else the
  provision. Schedule paragraph ids carry no Part ("Sch. 6 Pt. II para. 33"
  → `schedule-6-paragraph-33`). Only held ids are returned. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Pointer}

  @prefix %{section: "section", regulation: "regulation", article: "article", rule: "rule"}

  @doc "The held element ids a ref points to; [] when none is held."
  @spec ids(Doc.t(), Pointer.ref()) :: [String.t()]
  def ids(doc, {:schedule, number, _part, nil, _subs}) when is_binary(number),
    do: held(doc, ["schedule-#{number}"])

  def ids(doc, {:schedule, number, _part, para, subs}) when is_binary(number),
    do: path(doc, "schedule-#{number}-paragraph-#{para}", subs)

  def ids(doc, {kind, number, subs}) when is_map_key(@prefix, kind),
    do: path(doc, "#{@prefix[kind]}-#{number}", subs)

  def ids(_doc, _ref), do: []

  defp path(doc, base, subs) do
    full = Enum.join([base | Enum.map(subs, &String.downcase/1)], "-")

    cond do
      subs == [] -> held(doc, [base])
      held(doc, [full]) != [] -> [full]
      (each = held(doc, Enum.map(subs, &"#{base}-#{String.downcase(&1)}"))) != [] -> each
      true -> held(doc, [base])
    end
  end

  defp held(doc, ids), do: Enum.filter(ids, &Map.has_key?(doc.elements, &1))
end

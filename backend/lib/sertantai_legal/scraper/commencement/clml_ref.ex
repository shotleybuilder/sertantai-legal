defmodule SertantaiLegal.Scraper.Commencement.ClmlRef do
  @moduledoc """
  A CLML element id as a LAT ref: "section-36-3" → "s.36(3)",
  "schedule-11-paragraph-137-a" → "sch.11.para.137(a)". Its own module so
  what reads a law's CLML as rows (`DocRows`) reaches no order reading
  (`Order` delegates `ref/1` here): an order fix keeps the CLML rows'
  cache (`ClmlRows`). Pure.
  """

  @doc "An amending provision's CLML id as a ref: \"section-36-3\" → \"s.36(3)\", \"schedule-11-paragraph-137-a\" → \"sch.11.para.137(a)\"."
  @spec ref(String.t()) :: String.t() | nil
  def ref(id) do
    case String.split(id, "-") do
      # a Schedule, its Parts (nested kept) and paragraph: "schedule-4-part-2-
      # paragraph-3" → sch.4.pt.2.para.3 (the triple, Jason 2026-10-27:
      # unique where numbering restarts in each Part); an unnumbered Schedule
      # is `sch` ("schedule-paragraph-1" → sch.para.1; CV-S02a K10)
      ["schedule" | rest] ->
        case rest do
          [kind | _] when kind in ["part", "paragraph"] -> schedule_ref("sch", rest)
          [s | more] -> schedule_ref("sch.#{s}", more)
          [] -> "sch"
        end

      [kind, n | subs] when kind in ~w(section regulation article) ->
        "#{prefix(kind)}.#{n}" <> brackets(subs)

      _ ->
        nil
    end
  end

  defp schedule_ref(sch, ["part", p | rest]), do: schedule_ref("#{sch}.pt.#{p}", rest)
  defp schedule_ref(sch, ["paragraph", p | subs]), do: "#{sch}.para.#{p}" <> brackets(subs)
  # (anything else after the Schedule or Part, "schedule-part": that)
  defp schedule_ref(sch, _), do: sch

  @doc "The ref prefix of a provision kind: section → s, regulation → reg, article → reg (LAT's convention for domestic instruments; `art.` is EU's)."
  @spec prefix(String.t()) :: String.t()
  def prefix("section"), do: "s"
  def prefix("regulation"), do: "reg"
  def prefix("article"), do: "reg"

  defp brackets(subs), do: Enum.map_join(subs, &"(#{&1})")
end

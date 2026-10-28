defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.OwnParagraph do
  @moduledoc """
  A Schedule paragraph's own extent (CV-S05 round 11, from the CV-S05c
  census's unread tail: 37 sentences in 13 laws): "This paragraph does not
  extend to Northern Ireland" (Courts Act 2003 Sch.8 para 27) →
  `{:not, "NI", ["sch.8.para.27"]}`; "This paragraph extends only to
  England and Wales" → `{:only, "E+W", […]}`; "Sub-paragraph (1) does not
  extend to Northern Ireland" → its own sub-paragraph. The whole sentence only:
  never with more after its places ("… and to the territorial waters
  adjacent to England and Wales" stays unread). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Places, Units}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @place_list Places.place_list()

  @form Regex.compile!(
          "^\\s*(?<subj>This\\s+paragraph|Sub-?paragraphs?\\s+\\((?:[^().]|\\([^()]*\\))*?\\)(?:\\s+(?:above|below))?)\\s+(?:(?<not>(?:does|shall)\\s+not)\\s+extend\\s+to\\s+(?<p1>(?>#{@place_list}))|(?:shall\\s+)?extends?\\s+(?<only>only\\s+)?to\\s+(?<p2>(?>#{@place_list}))(?<only2>\\s+only)?)\\s*\\.?\\s*$",
          "iu"
        )

  @doc "Each Schedule paragraph's own extent stated in the document."
  @spec lists(Doc.t()) :: [{:not | :only | :named, String.t(), [String.t()]}]
  def lists(%Doc{} = doc) do
    for id <- doc.ids,
        String.starts_with?(id, "schedule-"),
        ref = Order.ref(id),
        ref != nil and ref =~ ~r/^sch\.[^.]+\.para\.[^.()]+$/,
        unit <- Units.units(doc, id),
        unit =~ ~r/\b(?:This\s+paragraph|Sub-?paragraphs?\s+\()/iu,
        s <- Clause.sentences(unit),
        l = list(s, ref),
        l != nil,
        uniq: true,
        do: l
  end

  @doc "The list one sentence of paragraph `ref` states, or nil."
  @spec list(String.t(), String.t()) :: {:not | :only | :named, String.t(), [String.t()]} | nil
  def list(s, ref) do
    case Regex.named_captures(@form, s) do
      nil ->
        nil

      %{"not" => n} = m when n != "" ->
        own({:not, Places.places(m["p1"])}, m["subj"], ref)

      m ->
        kind = if m["only"] != "" or m["only2"] != "", do: :only, else: :named
        own({kind, Places.places(m["p2"])}, m["subj"], ref)
    end
  end

  # "This paragraph": the paragraph; "Sub-paragraph (1)": its own (ukpga
  # 2003/39 Sch.8 para 70, CV-S05 seed 20 batch)
  defp own({kind, place}, subj, ref) do
    refs = if subj =~ ~r/^This\b/iu, do: [ref], else: RefList.parse(subj, ref)
    if refs == [], do: nil, else: {kind, place, refs}
  end
end

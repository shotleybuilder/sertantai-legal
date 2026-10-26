defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Amends do
  @moduledoc """
  The law's provisions amending named Acts, and where they extend (CV-S05
  round 6): "any provision of this Act which amends or repeals any
  provision of the House of Commons Disqualification Act 1975 or the
  Northern Ireland Assembly Disqualification Act 1975 shall extend to
  Northern Ireland" (Employment Protection Act 1975 s.129(6)) → `{:named,
  "NI", refs}`, the refs those of the law's top-level provisions (sections,
  Schedule paragraphs) whose own words name one of those Acts. None found:
  no list (the statement names no provision the law has). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Places, Units}
  alias SertantaiLegal.Scraper.Commencement.Order

  @form Regex.compile!(
          "\\bany\\s+provision\\s+of\\s+this\\s+(?:Act|Order)\\s+which\\s+(?:amends|repeals)(?:\\s+or\\s+(?:amends|repeals))?\\s+(?:any\\s+provision\\s+of\\s+)?(?<acts>.+?)\\s+shall\\s+(?:also\\s+)?extend\\s+to\\s+(?<places>#{Places.place_list()})",
          "iu"
        )

  @title ~r/([A-Z][\w(),'’ -]*? Act \d{4})/u

  @doc "The lists the law's \"any provision … which amends … <Acts> shall extend to …\" statements give, from the unit sentences (`Units.unit_sentences/1`)."
  @spec amends([{String.t(), String.t()}], Doc.t()) :: [{:named, String.t(), [String.t()]}]
  def amends(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        m = Regex.named_captures(@form, s),
        m != nil,
        titles = for([t] <- Regex.scan(@title, m["acts"], capture: :all_but_first), do: t),
        titles != [],
        # (the statement's own provision names them too, amending nothing)
        refs = amending(doc, titles) -- [ref],
        refs != [],
        uniq: true,
        do: {:named, Places.places(m["places"]), refs}
  end

  # the top-level provisions (no subsection: "s.12", "sch.1.para.5") whose
  # own words name one of the titles
  defp amending(doc, titles) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        not (id =~ ~r/-part-|^schedule-[^-]+$/),
        el = Doc.element(doc, id),
        text = el |> Units.own_words() |> Doc.lines() |> Enum.join(" "),
        Enum.any?(titles, &String.contains?(text, String.replace_prefix(&1, "the ", ""))),
        uniq: true,
        do: ref
  end
end

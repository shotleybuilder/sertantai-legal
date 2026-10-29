defmodule SertantaiLegal.Scraper.Commencement.ScheduleEffect do
  @moduledoc """
  A Schedule comes into force with the provision that gives it effect
  (CV-S08 round 2): "Schedule 12 (minor and consequential amendments
  related to Part 3) has effect" in Energy Act 2013 s.116(1), which Part 3's
  order (SI 2014/251) commences; "The statutory provisions referred to in
  Part II of Schedule 7 shall be amended in accordance with that Part" in
  NISR 2003/152 reg.15(2), commenced on its own day.

  Each such sentence is a rule (treatment `:schedule_effect`): scope the
  Schedule (or its Part), `when` `{:with, "<provision> <containers…>"}` —
  the provision and the Parts and Chapters holding it, so its own rules
  reach it (`s.116(1) pt.3`). The evaluator leaves these rules out
  (`Commencement.Evaluator`); an amending provision in the Schedule is
  dated by the introducing provision's commencement where nothing more
  specific dates it (`Readers.AmendingLaw.commencement/2`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}
  alias SertantaiLegal.Scraper.LatParser.Xml

  @has_effect ~r/\bSchedules?\s+(\d+[A-Z]*)\b[^.;]{0,200}?\b(?:has|have|shall\s+have)\s+effect\b/iu
  @amended_by_part ~r/\b(?:provisions|enactments|instruments)\s+(?:referred\s+to|specified|mentioned|listed)\s+in\s+Part\s+([IVXL]+|\d+)\s+of\s+Schedule\s+(\d+[A-Z]*)\b[^.;]{0,80}?\bamended\s+in\s+accordance\s+with\s+that\s+(?:Part|Schedule)\b/iu

  @doc """
  The law's rules giving its Schedules effect, from its rows
  (`OwnClause.doc_rows/1`, or LAT's). With its document, a Schedule's Part
  is its paragraphs (NISR 2003/152: `schedule-7-part-I` holds
  `schedule-7-paragraph-9`, whose ref names no Part).
  """
  @spec rules(String.t(), [map()], Doc.t() | nil) :: [Rule.t()]
  def rules(law_name, rows, doc \\ nil) do
    for r <- rows,
        text = Map.get(r, :text) || "",
        {scope, sentence} <- introduced(text),
        provision = r.section_id |> String.split(":", parts: 2) |> List.last(),
        uniq: true,
        do:
          Rule.new(
            commences: law_name,
            scope: paragraphs(scope, doc),
            when: {:with, Enum.join([provision | containers(r)], " ")},
            source: %{law: law_name, ref: provision, text: sentence},
            treatment: :schedule_effect
          )
  end

  @doc "The introducing provision and its containers a `:schedule_effect` rule names."
  @spec introducer(Rule.t()) :: {String.t(), [String.t()]}
  def introducer(%Rule{when: {:with, chain}}) do
    [provision | containers] = String.split(chain, " ", trim: true)
    {provision, containers}
  end

  defp introduced(text) do
    for([_, n] <- Regex.scan(@has_effect, text), do: {{n, nil}, text}) ++
      for [_, part, n] <- Regex.scan(@amended_by_part, text), do: {{n, part}, text}
  end

  defp paragraphs({n, nil}, _doc), do: ["sch.#{n}"]

  defp paragraphs({n, part}, doc) do
    held =
      doc &&
        Enum.find_value(
          ["schedule-#{n}-part-#{part}", "schedule-#{n}-part-#{arabic(part)}"],
          &Doc.element(doc, &1)
        )

    refs =
      if held,
        do:
          for(
            d <- Xml.descendants(held),
            id = Xml.attr_or_nil(d, :id),
            id != nil,
            id = to_string(id),
            Regex.match?(~r/^schedule-[^-]+-(?:part-[^-]+-)?paragraph-[^-]+$/, id),
            ref = Order.ref(id),
            ref != nil,
            uniq: true,
            do: ref
          ),
        else: []

    if refs == [], do: ["sch.#{n}.pt.#{arabic(part)}"], else: refs
  end

  defp containers(r) do
    part = Map.get(r, :part)
    chapter = Map.get(r, :chapter)
    Enum.reject([part && chapter && "pt.#{part}.ch.#{chapter}", part && "pt.#{part}"], &is_nil/1)
  end

  @roman %{"I" => 1, "V" => 5, "X" => 10, "L" => 50}

  defp arabic(n) do
    if n =~ ~r/^\d+$/ do
      n
    else
      n
      |> String.upcase()
      |> String.graphemes()
      |> Enum.map(&@roman[&1])
      |> Enum.chunk_every(2, 1)
      |> Enum.map(fn
        [a, b] when a < b -> -a
        [a | _] -> a
      end)
      |> Enum.sum()
      |> Integer.to_string()
    end
  end
end

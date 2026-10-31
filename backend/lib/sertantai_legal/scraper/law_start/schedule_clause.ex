defmodule SertantaiLegal.Scraper.LawStart.ScheduleClause do
  @moduledoc """
  A commencement clause handing over to a Schedule (CV-06 round 1, R3):
  "These Regulations … shall come into force in accordance with the
  provisions of Part I of Schedule 1" (SI 1989/2169), whose Part says
  "Regulations 1 to 3 … shall come into force on 1st July 1990 … All the
  other provisions of these Regulations shall come into force on 1st July
  1994". The Part's sentences are read in the clause's place, as the
  clause's own (`LawStart.Provisions`); LAT holds no Schedules, so they
  come from the stored CLML.

  - `redirect/1`: the Schedule (and Part) a clause hands over to, or nil;
  - `sentences/3`: that Schedule's (Part's) text from the Schedules' XML;
  - `inline/2`: the clause with the sentences in its place.

  Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @redirect ~r/\binto\s+(?:force|operation)\s+in\s+accordance\s+with\s+(?:the\s+provisions\s+of\s+)?(?:Part\s+([IVXL]+|\d+)\s+of\s+)?Schedule\s+(\d+[A-Z]?)\b/i

  @doc "The `{schedule, part}` a clause hands over to (part nil for the whole Schedule), or nil."
  @spec redirect(String.t() | nil) :: {String.t(), String.t() | nil} | nil
  def redirect(nil), do: nil

  def redirect(text) do
    case Regex.run(@redirect, text) do
      [_, "", n] -> {n, nil}
      [_, part, n] -> {n, part}
      nil -> nil
    end
  end

  @doc "The text of Schedule `n` (its Part `part`) in the Schedules' XML; nil when not held."
  @spec sentences(String.t() | nil, String.t(), String.t() | nil) :: String.t() | nil
  def sentences(nil, _n, _part), do: nil

  def sentences(xml, n, part) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    case xpath(doc, ~x"//*[local-name()='Schedule'][@id='schedule-#{n}']"e) do
      nil -> nil
      schedule -> schedule |> part(part) |> then(&(&1 && Doc.text(&1)))
    end
  end

  defp part(schedule, nil), do: schedule

  defp part(schedule, part) do
    schedule
    |> xpath(~x".//*[local-name()='Part']"l)
    |> Enum.find(fn p ->
      number = p |> xpath(~x"./*[local-name()='Number']//text()"ls) |> Enum.join()
      number =~ ~r/\bPART\s+#{part}\b/i
    end)
  end

  @doc """
  The clause followed by the Schedule's sentences, its heading dropped
  ("… in accordance with the provisions of Part I of Schedule 1. 1
  Regulations 1 to 3 … shall come into force on 1st July 1990. …"): the
  clause reads as staged, its dates the sentences'; the clause as it is
  when none.
  """
  @spec inline(String.t() | nil, String.t() | nil) :: String.t() | nil
  def inline(text, xml) do
    with {n, part} <- redirect(text),
         sentences when is_binary(sentences) <- sentences(xml, n, part) do
      String.trim_trailing(text) <> " " <> body(sentences)
    else
      _ -> text
    end
  end

  # the Part's text without its heading ("PART I coming into force of the
  # regulations 1 Regulations …" → "1 Regulations …")
  # and its paragraph numbers ("… 1990. 2 Regulation 4 …" → "… 1990.
  # Regulation 4 …": a sentence starts with a capital)
  defp body(sentences) do
    sentences
    |> String.replace(~r/^\s*PART\s+\S+\s+[^0-9]*?(?=\d)/i, "")
    |> String.replace(~r/(^|\.\s+)\d+[A-Z]?\s+(?=[A-Z])/, "\\1")
  end
end

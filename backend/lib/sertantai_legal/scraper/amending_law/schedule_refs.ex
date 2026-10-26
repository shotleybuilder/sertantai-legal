defmodule SertantaiLegal.Scraper.AmendingLaw.ScheduleRefs do
  @moduledoc """
  Each Schedule's introducing section (AR-04, CR-08; moved out of
  `Amendment.Reader`, run time 2026-10-26, so an Act's extent — which uses
  it — doesn't stale with every amendment-reader change): the Schedule's
  own Reference ("Section 174(2)" → section-174), else the section saying
  it has effect ("111 Schedule 7 … has effect"). The one reader of this
  fact: the repeals tables' sources (`Amendment.Collect`), the index and
  an Act's extent (`AmendingLaw.Extent`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @doc """
  Each Schedule's introducing section, by the Schedule's id
  (`"schedule-7" => "section-111"`): the Schedule's own reference
  (`reference/2`, where the schedules are held), else the section saying it
  has effect ("111 Schedule 7, which supplements section 110 …, has
  effect", where only the body is held). The one reader of this fact: the
  repeals tables' sources (`Collect`) and an Act's extent use it.
  """
  @spec references(Doc.t()) :: %{String.t() => String.t()}
  def references(doc) do
    referenced =
      for id <- doc.ids,
          String.match?(id, ~r/^schedule-[^-]+$/),
          ref = reference(doc, id),
          ref != nil,
          into: %{},
          do: {id, ref}

    Map.merge(has_effect(doc), referenced)
  end

  # "111 Schedule 7 … has effect": in a section's own words (not a
  # subsection's, which says it of a Schedule it amends)
  defp has_effect(doc) do
    for id <- doc.ids,
        String.match?(id, ~r/^section-\d+[A-Z]*$/),
        text = doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" "),
        [_, n] <-
          Regex.scan(
            ~r/\bSchedule\s+(\d+[A-Z]*)\b[^.]{0,300}?\b(?:has|shall have) effect\b/u,
            text
          ),
        into: %{},
        do: {"schedule-#{n}", id}
  end

  @doc "The provision giving effect to a Schedule (its Reference, \"Section 108.\" → section-108)."
  @spec reference(Doc.t(), String.t()) :: String.t() | nil
  def reference(doc, id) do
    with el when el != nil <- Doc.element(doc, id),
         [_, n] <-
           Regex.run(
             ~r/Section (\d+[A-Z]*)/,
             el |> xpath(~x"./Reference//text()"ls) |> Enum.join()
           ) do
      "section-#{n}"
    else
      _ -> nil
    end
  end
end

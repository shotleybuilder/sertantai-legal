defmodule SertantaiLegal.Scraper.ChangeCollector.Commencement do
  @moduledoc """
  The commencement collector (lat-refactor LR-33): one law-level record
  saying when the law came into force and which `LawStart` treatment
  decided it. `section_id` nil (the whole instrument; the per-row view
  never carries it), source `law`, operation `commenced`, `effect_type` the
  treatment, `effective_from` its date (nil for a known limit), `evidence`
  the clause's section_id or the metadata field, `affected_ref` the clause.
  `LabelTimeline` takes the law's start from this record alone. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.LawStart

  @doc "The law's commencement record from its `LawStart.input()`."
  @spec records(String.t(), LawStart.input()) :: [Record.t()]
  def records(law_name, input) do
    s = LawStart.resolve(input)

    [
      %Record{
        law_name: law_name,
        via: ["instrument"],
        source: "law",
        evidence: s.evidence || Atom.to_string(s.treatment),
        affected_ref: s.text,
        affecting_law: law_name,
        dated_by_law: if(s.date, do: law_name),
        operation: "commenced",
        effect_type: Atom.to_string(s.treatment),
        effective_from: s.date,
        in_force:
          if(s.date,
            do: [
              %{
                "date" => Date.to_iso8601(s.date),
                "applied" => true,
                "prospective" => false,
                "qualification" => nil
              }
            ],
            else: []
          )
      }
    ]
  end
end

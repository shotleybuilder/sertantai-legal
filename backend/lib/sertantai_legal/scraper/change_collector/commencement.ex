defmodule SertantaiLegal.Scraper.ChangeCollector.Commencement do
  @moduledoc """
  The commencement collector (lat-refactor LR-33, LR-34): when the law and
  its provisions came into force, and which treatment decided it. Source
  `law`, operation `commenced`, `effect_type` the treatment, `effective_from`
  its date (nil for a known limit), `evidence` the clause's section_id or the
  metadata field, `affected_ref` the clause.

  - **The law** (`LawStart`): one law-level record (`section_id` nil).
  - **Its provisions** (`LawStart.Provisions`): one record per row a
    provision-level sentence names (`provision_dated`, `provision_by_order`,
    `provision_qualified`); a sentence it can't resolve is one law-level
    `provision_unread` record.

  `LabelTimeline` takes the law's start from the law-level record and each
  row's start from its provision record; these records are never changes.
  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Provisions

  @doc "The law's commencement records from its `LawStart.input()`."
  @spec records(String.t(), LawStart.input()) :: [Record.t()]
  def records(law_name, input) do
    law = LawStart.resolve(input)
    rows = Map.get(input, :rows, [])

    # one record per row per sentence (the register's key: a row named
    # twice by one sentence — a repeated section_id, an overlapping list
    # item — keeps the first, which starts it)
    provisions =
      for(
        p <- Provisions.assign(rows, Map.get(input, :made), law),
        sid <- if(p.section_ids == [], do: [nil], else: p.section_ids),
        do: record(law_name, sid, p.treatment, p.date, p.evidence, p.text)
      )
      |> Enum.uniq_by(&{&1.section_id, &1.evidence})

    [record(law_name, nil, law.treatment, law.date, law.evidence, law.text) | provisions]
  end

  defp record(law_name, section_id, treatment, date, evidence, text) do
    %Record{
      law_name: law_name,
      section_id: section_id,
      via: ["instrument"],
      source: "law",
      evidence: evidence || Atom.to_string(treatment),
      affected_ref: text,
      affecting_law: law_name,
      dated_by_law: if(date, do: law_name),
      operation: "commenced",
      effect_type: Atom.to_string(treatment),
      effective_from: date,
      in_force:
        if(date,
          do: [
            %{
              "date" => Date.to_iso8601(date),
              "applied" => true,
              "prospective" => false,
              "qualification" => nil
            }
          ],
          else: []
        )
    }
  end
end

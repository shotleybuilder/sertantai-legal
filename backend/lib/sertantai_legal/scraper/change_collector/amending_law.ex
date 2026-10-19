defmodule SertantaiLegal.Scraper.ChangeCollector.AmendingLaw do
  @moduledoc """
  The amending-law collector (lat-refactor LR-08): change records read from
  the amending law's own text, for the rows asked about. For each note on
  such a row (a pointer only: `AmendingLaw.Pointer`), the provisions it
  points to are found in the amending law (`Locator`); a record is made
  only when the law's text names the row's law and provision (`Target`, or
  a repeals table: `RepealTable`) and states an operation (`Operation`).
  Source `law`; the evidence is the provision read. The date is the
  commencement evaluator's for the provision that made the change
  (commencement-rules CR-06, `Commencement.Amending`): the amending law's
  coming-into-force effects first, else its own clause and the orders its
  notes cite, as stored rules; partial entries are kept as in-force
  entries, `effective_from` only once fully in force. Notes give no value.
  Pure: the documents come from `docs` (law → `Doc` | nil), the amending
  laws' rules from `rules:` (law → `[Commencement.Rule]`), the rows' extents from
  `extents:` (section_id → extent).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{
    DefinedTerms,
    Doc,
    Locator,
    Operation,
    Pointer,
    RepealTable,
    RowRef,
    Target,
    Text
  }

  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.Commencement.{Amending, Evaluator}

  @doc """
  Records for `law_name` (title `title`, its LAT `section_ids`) from its
  `notes` (`code`, `text`, `citation_law`, `affected_sections`), for the rows
  in `ask` only. `opts`: `rules:` (amending law → its commencement rules;
  none: undated), `extents:` (section_id → extent).
  """
  @spec records(
          String.t(),
          String.t() | nil,
          [String.t()],
          [map()],
          MapSet.t(),
          (String.t() -> Doc.t() | nil),
          keyword()
        ) :: [Record.t()]
  def records(law_name, title, section_ids, notes, ask, docs, opts \\ []) do
    held = MapSet.new(section_ids)
    {terms, terms_table} = memo(fn doc -> DefinedTerms.of(doc) end)
    rules_of = Keyword.get(opts, :rules, fn _law -> [] end)
    {rules, rules_table} = memo(fn doc -> rules_of.(doc.law_name) end)
    extents = Keyword.get(opts, :extents, %{})

    try do
      collect(law_name, title, notes, ask, docs, held, terms, {rules, extents})
    after
      # per call: a corpus run in one process must not keep them (LR-25)
      :ets.delete(terms_table)
      :ets.delete(rules_table)
    end
  end

  defp collect(law_name, title, notes, ask, docs, held, terms, dating) do
    for note <- notes,
        sid <- Map.get(note, :affected_sections) || [],
        MapSet.member?(ask, sid),
        pointer = Pointer.parse(note),
        doc = pointer.affecting_law && docs.(pointer.affecting_law),
        doc != nil,
        ref <- pointer.provisions,
        id <- Locator.ids(doc, ref),
        rec = read(doc, id, RowRef.new(sid, title), {terms.(doc), dating}, pointer),
        rec != nil,
        MapSet.member?(held, rec.section_id) do
      %{rec | law_name: law_name}
    end
    |> Enum.uniq_by(&{&1.evidence, &1.section_id})
  end

  defp read(doc, id, row, {terms, dating}, pointer) do
    case RepealTable.match(doc, id, row) do
      {:ok, target, type} ->
        record(
          doc,
          id,
          target,
          {"repealed", type},
          {Enum.uniq(Enum.reject([id, RepealTable.reference(doc, id)], &is_nil/1)), dating},
          pointer
        )

      :no_match ->
        nil

      # only a single provision is read as an instruction, never a whole
      # Schedule or Part
      :not_a_table ->
        if provision?(id), do: instruction(doc, id, row, terms, dating, pointer)
    end
  end

  defp instruction(doc, id, row, terms, dating, pointer) do
    text = Text.of(doc, id)

    with op when op != nil <- Operation.of(text),
         {:ok, target} <- Target.match(text, Doc.title(doc, id), terms, row) do
      op = if quoted?(text, target), do: Operation.of_quoted(text), else: op
      record(doc, id, target, op, {[id], dating}, pointer)
    else
      _ -> nil
    end
  end

  # the row is one the instruction's quoted text makes (its provision
  # number among the quote's: "66A" for s.66A(1))
  defp quoted?(%Text{inserted: inserted}, target) do
    case Regex.run(~r/:(?:s|reg|art|rule)\.(\d+[A-Z]*)/, target) do
      [_, n] -> Enum.any?(inserted, &match?([^n | _], &1))
      nil -> false
    end
  end

  defp provision?(id),
    do: Regex.match?(~r/^(?:section|regulation|article|rule)-|^schedule-[^-]+-paragraph-/, id)

  # the first of the provision's ids any rule reaches: a repeals table's own
  # entry before the section introducing it (CR-08: "this section" commenced
  # on passing reaches s.66(8), while Schedule 18's entries came in by order —
  # 1994 c.19)
  defp record(doc, id, target, {op, type}, {dated_ids, {rules, extents}}, pointer) do
    rs = rules.(doc)
    extent = Map.get(extents, target)

    r =
      Enum.reduce_while(dated_ids, nil, fn did, _acc ->
        r = Amending.evaluate(rs, did, target, extent)
        if r.entries == [], do: {:cont, r}, else: {:halt, r}
      end)

    by = dated_by(r)

    %Record{
      law_name: nil,
      section_id: target,
      source: "law",
      evidence: evidence(doc, id),
      affecting_law: doc.law_name,
      affecting_ref: id,
      operation: op,
      effect_type: type,
      effective_from: r.full_from,
      in_force:
        for(
          e <- Evaluator.in_force(r),
          do: %{
            "date" => Date.to_iso8601(e.date),
            "applied" => true,
            "prospective" => false,
            "qualification" => e.qualification
          }
        ),
      prospective: false,
      applied: true,
      dated_by_law: by && by.rule.source.law,
      dated_by_ref: by && by.rule.source.ref,
      pointer: pointer.note_code,
      via: ["law_pointer"]
    }
  end

  # the entry that brought the provision fully into force, else its first
  # dated one
  defp dated_by(%{entries: entries, full_from: full}) do
    dated = Enum.filter(entries, & &1.date)

    (full && Enum.find(dated, &(&1.date == full and full?(&1)))) ||
      (full && Enum.find(dated, &(&1.date == full))) ||
      Enum.min_by(dated, & &1.date, Date, fn -> nil end)
  end

  defp full?(e), do: e.territory == nil and e.purposes == nil

  # ukpga/2000/27/schedule/6/paragraph/33/c
  defp evidence(doc, id) do
    [_, type, year, number] = String.split(doc.law_name, "_", parts: 4)
    Enum.join([type, year, number | String.split(id, "-")], "/")
  end

  # once per amending law within one call: the memo function and its table
  # (the caller deletes it)
  defp memo(fun) do
    table = :ets.new(:memo, [:set, :private])

    {fn doc ->
       case :ets.lookup(table, doc.law_name) do
         [{_, v}] -> v
         [] -> tap(fun.(doc), &:ets.insert(table, {doc.law_name, &1}))
       end
     end, table}
  end
end

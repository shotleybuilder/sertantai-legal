defmodule SertantaiLegal.Scraper.ChangeCollector.AmendingLaw do
  @moduledoc """
  The amending-law collector (lat-refactor LR-08): change records read from
  the amending law's own text, for the rows asked about. For each note on
  such a row (a pointer only: `AmendingLaw.Pointer`), the provisions it
  points to are found in the amending law (`Locator`); a record is made
  only when the law's text names the row's law and provision (`Target`, or
  a repeals table: `RepealTable`) and states an operation (`Operation`). The
  date is the law's own commencement for it (`Commencement`); by order, or
  unread, leaves it empty (hop 2 dates it). Source `law`; the evidence is
  the provision read. Undated, it is dated by the commencing orders its
  note names (hop 2: `CommencingOrder`). Notes give no value. Pure: the
  documents come from `docs` (law → `Doc` | nil), amending laws' titles from
  `titles`.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{
    CommencingOrder,
    Commencement,
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

  @doc """
  Records for `law_name` (title `title`, its LAT `section_ids`) from its
  `notes` (`code`, `text`, `citation_law`, `affected_sections`), for the rows
  in `ask` only.
  """
  @spec records(String.t(), String.t() | nil, [String.t()], [map()], MapSet.t(), (String.t() ->
                                                                                    Doc.t() | nil)) ::
          [Record.t()]
  def records(law_name, title, section_ids, notes, ask, docs, titles \\ fn _ -> nil end) do
    held = MapSet.new(section_ids)
    terms = memo(fn doc -> DefinedTerms.of(doc) end)
    starts = memo(fn doc -> Commencement.provisions(doc) end)

    for note <- notes,
        sid <- Map.get(note, :affected_sections) || [],
        MapSet.member?(ask, sid),
        pointer = Pointer.parse(note),
        doc = pointer.affecting_law && docs.(pointer.affecting_law),
        doc != nil,
        ref <- pointer.provisions,
        id <- Locator.ids(doc, ref),
        rec = read(doc, id, RowRef.new(sid, title), {terms.(doc), starts.(doc)}, pointer),
        rec = rec && hop2(rec, doc, pointer, docs, titles),
        rec != nil,
        MapSet.member?(held, rec.section_id) do
      %{rec | law_name: law_name}
    end
    |> Enum.uniq_by(&{&1.evidence, &1.section_id})
  end

  defp read(doc, id, row, {terms, starts}, pointer) do
    case RepealTable.match(doc, id, row) do
      {:ok, target, type} ->
        record(
          doc,
          id,
          target,
          {"repealed", type},
          {RepealTable.reference(doc, id) || id, starts},
          pointer
        )

      :no_match ->
        nil

      # only a single provision is read as an instruction, never a whole
      # Schedule or Part
      :not_a_table ->
        if provision?(id), do: instruction(doc, id, row, terms, starts, pointer)
    end
  end

  defp instruction(doc, id, row, terms, starts, pointer) do
    text = Text.of(doc, id)

    with op when op != nil <- Operation.of(text),
         {:ok, target} <- Target.match(text, Doc.title(doc, id), terms, row) do
      record(doc, id, target, op, {id, starts}, pointer)
    else
      _ -> nil
    end
  end

  defp provision?(id),
    do: Regex.match?(~r/^(?:section|regulation|article|rule)-|^schedule-[^-]+-paragraph-/, id)

  defp record(doc, id, target, {op, type}, {dated_id, starts}, pointer) do
    {from, by, by_ref} =
      case Commencement.of(doc, dated_id, starts) do
        {:date, d, cid} -> {d, doc.law_name, cid}
        _ -> {nil, nil, nil}
      end

    %Record{
      law_name: nil,
      section_id: target,
      source: "law",
      evidence: evidence(doc, id),
      affecting_law: doc.law_name,
      affecting_ref: id,
      operation: op,
      effect_type: type,
      effective_from: from,
      in_force:
        if(from,
          do: [
            %{
              "date" => Date.to_iso8601(from),
              "applied" => true,
              "prospective" => false,
              "qualification" => nil
            }
          ],
          else: []
        ),
      prospective: false,
      applied: true,
      dated_by_law: by,
      dated_by_ref: by_ref,
      pointer: pointer.note_code,
      via: ["law_pointer"]
    }
  end

  # hop 2: an undated record dated by the commencing orders its note names
  # (CommencingOrder); the latest fully in-force date is effective_from,
  # partial entries are kept as in-force entries
  defp hop2(%Record{effective_from: nil} = rec, doc, pointer, docs, titles) do
    [_, _, year, _] = String.split(doc.law_name, "_", parts: 4)
    act = %{law: doc.law_name, title: titles.(doc.law_name), year: year}

    entries =
      for {si, _refs} <- pointer.commencing,
          order = docs.(si),
          order != nil,
          e <- CommencingOrder.dates(order, act, rec.affecting_ref),
          do: Map.put(e, :law, si)

    case entries do
      [] ->
        rec

      _ ->
        full =
          entries
          |> Enum.filter(&is_nil(&1.qualification))
          |> Enum.max_by(& &1.date, Date, fn -> nil end)

        by = full || Enum.max_by(entries, & &1.date, Date)

        %{
          rec
          | effective_from: full && full.date,
            in_force:
              for(
                e <- entries,
                do: %{
                  "date" => Date.to_iso8601(e.date),
                  "applied" => true,
                  "prospective" => false,
                  "qualification" => e.qualification
                }
              ),
            dated_by_law: by.law,
            dated_by_ref: by.ref
        }
    end
  end

  defp hop2(rec, _doc, _pointer, _docs, _titles), do: rec

  # ukpga/2000/27/schedule/6/paragraph/33/c
  defp evidence(doc, id) do
    [_, type, year, number] = String.split(doc.law_name, "_", parts: 4)
    Enum.join([type, year, number | String.split(id, "-")], "/")
  end

  # defined terms once per amending law
  defp memo(fun) do
    table = :ets.new(:memo, [:set, :private])

    fn doc ->
      case :ets.lookup(table, doc.law_name) do
        [{_, v}] -> v
        [] -> tap(fun.(doc), &:ets.insert(table, {doc.law_name, &1}))
      end
    end
  end
end

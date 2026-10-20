defmodule SertantaiLegal.Scraper.Amendment.Collect do
  @moduledoc """
  The amending-law collector on the amendment ruleset (amendment-rules
  AR-03; the change register's since AR-04): for each note on a row asked
  about (a pointer: which amending provisions to read, one hop), the
  amending law's rules for those provisions are placed by the evaluator
  (`Amendment.Evaluator`: a row inside a provision named lands on that
  provision). Dating is the commencement ruleset's (`Commencement.Amending`).

  The rules come from a `source` per amending law (`sources`: law → source
  | nil): `doc_source/1` reads a parsed document (`Amendment.Reader`), or
  `stored_source/3` serves the rules the read pass stored (`mix lat.amending
  --read`) — no XML at collection. Pure: commencement rules from `rules:`,
  extents from `extents:`, the law's LAT prefix from `prefix:`.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc, Locator, Pointer}
  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Reader, Rule}
  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.Commencement.Amending
  alias SertantaiLegal.Scraper.Commencement.Evaluator, as: When

  @typedoc """
  An amending law as the collector needs it: its `elements` (id → true, for
  `Locator`), each repeals table's introducing section (`references`), and
  its rules for a provision and a law ref (`rules`).
  """
  @type source :: %{
          law: String.t(),
          elements: %{String.t() => any()},
          references: %{String.t() => String.t()},
          rules: (String.t(), Reader.law_ref() -> [Rule.t()])
        }

  @doc """
  Records for `law_name` (title `title`, its LAT `section_ids`) from its
  `notes` (`code`, `text`, `citation_law`, `affected_sections`), for the rows
  in `ask` only.
  """
  @spec records(
          String.t(),
          String.t() | nil,
          [String.t()],
          [map()],
          MapSet.t(),
          (String.t() -> source() | nil),
          keyword()
        ) :: [Record.t()]
  def records(law_name, title, section_ids, notes, ask, sources, opts \\ []) do
    held = MapSet.new(section_ids)
    law = Reader.law_ref(law_name, title, Keyword.get(opts, :prefix) || prefix(section_ids))
    rules_of = Keyword.get(opts, :rules, fn _law -> [] end)
    extents = Keyword.get(opts, :extents, %{})

    for note <- notes,
        sid <- Map.get(note, :affected_sections) || [],
        MapSet.member?(ask, sid),
        pointer = Pointer.parse(note),
        src = pointer.affecting_law && sources.(pointer.affecting_law),
        src != nil,
        ref <- pointer.provisions,
        id <- Locator.ids(src, ref),
        rule <- src.rules.(id, law),
        {:ok, target} <- [Evaluator.reach(rule, sid)],
        MapSet.member?(held, target) do
      record(src, id, rule, target, {rules_of, extents}, pointer)
      |> Map.put(:law_name, law_name)
    end
    |> Enum.uniq_by(&{&1.evidence, &1.section_id})
  end

  @doc """
  A source read from a parsed document: rules read on demand for each law
  ref (memoised in the calling process's dictionary under the document's
  name — call within one collection, as `ChangeCollector.with_doc_cache/1`).
  """
  @spec doc_source(Doc.t()) :: source()
  def doc_source(%Doc{} = doc) do
    %{
      law: doc.law_name,
      elements: doc.elements,
      references: Reader.references(doc),
      rules: fn id, law ->
        memo({doc.law_name, id, law.law_name}, fn -> read(doc, id, [law]) end)
      end
    }
  end

  @doc """
  A source from the read pass's store: `index` (`%{"elements" => [ids],
  "references" => %{id => ref}}`) and the rules `rules` it wrote for the
  amending law.
  """
  @spec stored_source(String.t(), map(), [Rule.t()]) :: source()
  def stored_source(law, index, rules) do
    by = Enum.group_by(rules, &{&1.source.ref, &1.amends})

    %{
      law: law,
      elements: Map.new(index["elements"] || [], &{&1, true}),
      references: index["references"] || %{},
      rules: fn id, ref -> Map.get(by, {id, ref.law_name}, []) end
    }
  end

  @doc "The rules an amending provision (`id` in `doc`) states for `laws` (`Reader.read/4`, its defined terms memoised) — the read pass and `doc_source/1`."
  @spec read(Doc.t(), String.t(), [Reader.law_ref()]) :: [Rule.t()]
  def read(doc, id, laws), do: Reader.read(doc, id, terms(doc), laws)

  defp terms(doc), do: memo({:terms, doc.law_name}, fn -> DefinedTerms.of(doc) end)

  defp memo(key, fun) do
    case Process.get({__MODULE__, key}, :none) do
      :none -> tap(fun.(), &Process.put({__MODULE__, key}, &1))
      v -> v
    end
  end

  @doc "Drop the memoised reads (`doc_source/1`) from the calling process."
  @spec clear() :: :ok
  def clear do
    for {__MODULE__, _} = k <- Process.get_keys(), do: Process.delete(k)
    :ok
  end

  # a repeals table's own entry before the section introducing it (CR-08)
  defp dated_ids(src, id, %Rule{treatment: :repeal_table}),
    do: Enum.uniq(Enum.reject([id, src.references[id]], &is_nil/1))

  defp dated_ids(_src, id, _rule), do: [id]

  defp record(src, id, rule, target, {rules_of, extents}, pointer) do
    rs = rules_of.(src.law)
    extent = Map.get(extents, target)

    r =
      Enum.reduce_while(dated_ids(src, id, rule), nil, fn did, _acc ->
        r = Amending.evaluate(rs, did, target, extent)
        if r.entries == [], do: {:cont, r}, else: {:halt, r}
      end)

    by = dated_by(r)
    op = Atom.to_string(rule.operation)

    %Record{
      law_name: nil,
      section_id: target,
      source: "law",
      evidence: evidence(src.law, id),
      affecting_law: src.law,
      affecting_ref: id,
      operation: op,
      effect_type: if(rule.level == :words, do: "words #{op}", else: op),
      effective_from: r.full_from,
      in_force:
        for(
          e <- When.in_force(r),
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

  defp dated_by(%{entries: entries, full_from: full}) do
    dated = Enum.filter(entries, & &1.date)

    (full && Enum.find(dated, &(&1.date == full and full?(&1)))) ||
      (full && Enum.find(dated, &(&1.date == full))) ||
      Enum.min_by(dated, & &1.date, Date, fn -> nil end)
  end

  defp full?(e), do: e.territory == nil and e.purposes == nil

  # ukpga/2000/27/schedule/6/paragraph/33/c
  defp evidence(law, id) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    Enum.join([type, year, number | String.split(id, "-")], "/")
  end

  # the law's LAT prefix from its rows ("UK_x:reg.1" → "reg")
  defp prefix(section_ids) do
    Enum.find_value(section_ids, "s", fn sid ->
      case Regex.run(~r/:(s|reg|art|rule)\./, sid) do
        [_, p] -> p
        nil -> nil
      end
    end)
  end
end

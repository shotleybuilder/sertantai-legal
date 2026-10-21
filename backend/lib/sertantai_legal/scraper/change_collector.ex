defmodule SertantaiLegal.Scraper.ChangeCollector do
  @moduledoc """
  Fills the change register `lat_change_log` (lat-refactor LR-22/LR-23) for
  a law, offline from the CLML store: parse (store only) → the collectors →
  delete + insert that law's records per collector, in one transaction.

  Collectors: `Feed` (changes-feed effects with their joins), `Markup`
  (change markup no effect explains), the amending law's own text for rows
  the feed doesn't date (LR-08; on the amendment ruleset, AR-04:
  `Amendment.Collect` over the read pass's stored rules, else the document), `Commencement` (the law's
  own start and the `LawStart` treatment that decided it; LR-33). Records are stored compact (`Compact`:
  one per run of consecutive rows) and checked against the per-row joins
  in the DB's row order before writing (`fidelity/3`). Never fetches.
  Thin: the joins and records are the pure collectors'.
  """

  alias SertantaiLegal.Scraper.LatRef
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Collect, Index}
  alias SertantaiLegal.Scraper.Amendment.Store, as: AmendmentRules

  alias SertantaiLegal.Scraper.ChangeCollector.{
    Commencement,
    Compact,
    Feed,
    Markup,
    Record
  }

  alias SertantaiLegal.Scraper.Commencement.Store, as: CommencementRules
  alias SertantaiLegal.Scraper.LatStagedParser
  alias SertantaiLegal.Scraper.LawTerritory

  @doc """
  A law's records from the store, by collector: `records` compact (one per
  run of consecutive rows, `Compact`), `per_row` as joined, and `order` (the
  parse's section_ids in document order).

  Options: `parsed` — the parse's own `%{rows, notes, effects}` (the LR-25
  hook passes what it just persisted, so nothing is parsed twice); else the
  law is parsed from the store. `mode` — the amending-law collector's
  (`:gaps`).
  """
  @spec collect(String.t(), keyword()) ::
          {:ok,
           %{
             records: %{String.t() => [Record.t()]},
             per_row: %{String.t() => [Record.t()]},
             order: [String.t()]
           }}
          | {:error, term()}
  def collect(law_name, opts \\ []) do
    with {:ok, %{rows: rows, notes: notes, effects: effects}} <- parsed(law_name, opts) do
      order = Enum.map(rows, & &1.section_id)

      feed =
        Feed.records(law_name, rows, notes, effects,
          territory: &Collect.territory(&1, law_extent(&1), law_name)
        )

      per_row = %{
        "feed" => feed,
        "markup" => Markup.records(law_name, rows),
        "amending_law" => amending_law(law_name, order, feed, Keyword.get(opts, :mode, :gaps)),
        "commencement" =>
          Commencement.records(law_name, law_start_input(law_name, rows),
            orders: orders_rules(law_name),
            feed_dated: feed_dated(feed)
          )
      }

      {:ok,
       %{
         records: Map.new(per_row, fn {k, recs} -> {k, Compact.compact(recs, order)} end),
         per_row: per_row,
         order: order
       }}
    end
  end

  defp parsed(law_name, opts) do
    case Keyword.get(opts, :parsed) do
      nil -> LatStagedParser.fetch_changes(law_name, store: :only)
      parsed -> {:ok, parsed}
    end
  end

  @doc """
  What `LawStart` decides a law's start from (LR-33): the register's coming
  into force and made date (`uk_lrt`), the stored CLML's metadata, and the
  law's rows (`section_id`, `text`, `part`, `chapter`, in document order).
  """
  @spec law_start_input(String.t(), [map()]) :: SertantaiLegal.Scraper.LawStart.input()
  def law_start_input(law_name, rows) do
    {lrt_date, made} =
      case Repo.query!(
             "SELECT md_coming_into_force_date, md_made_date FROM uk_lrt WHERE name = $1 LIMIT 1",
             [law_name]
           ) do
        %{rows: [[cif, made]]} -> {date(cif), date(made)}
        _ -> {nil, nil}
      end

    head = clml_head(law_name)

    %{
      type_code: law_name |> String.split("_", parts: 3) |> Enum.at(1),
      lrt_date: lrt_date,
      made: made || clml_made(head),
      clml_head: head,
      # V1-02: a commencement table in the law's own Schedule (LAT holds no
      # Schedules), read only when the text cites one
      schedule_tables: schedule_tables(law_name, rows),
      tied_date: tied_date(rows, made || clml_made(head)),
      rows:
        Enum.map(
          rows,
          &%{
            section_id: &1.section_id,
            text: Map.get(&1, :text),
            part: Map.get(&1, :part),
            chapter: Map.get(&1, :chapter)
          }
        )
    }
  end

  defp schedule_tables(law_name, rows) do
    with true <-
           Enum.any?(
             rows,
             &SertantaiLegal.Scraper.LawStart.ScheduleTable.clause?(Map.get(&1, :text))
           ),
         [_, type, year, number] <- String.split(law_name, "_", parts: 4),
         {:ok, gz} <- File.read("data/cache/clml/#{type}/#{year}/#{number}/schedules/data.xml.gz") do
      gz |> :zlib.gunzip() |> SertantaiLegal.Scraper.LawStart.ScheduleTable.parse()
    else
      _ -> %{}
    end
  end

  # V1-02: a law tied to another law's provision ("at the same time as
  # section 83 of the 2022 Act comes into force") starts when that provision
  # came into force — fully, else first — by the other law's own feed (the
  # store; one hop)
  defp tied_date(rows, made) do
    alias SertantaiLegal.Scraper.Commencement.{Effects, Evaluator}
    alias SertantaiLegal.Scraper.LawStart.Clause
    alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

    rows = Enum.map(rows, &%{section_id: &1.section_id, text: Map.get(&1, :text)})

    with %{treatment: :tied_to_other_law, text: text} <- Clause.read(rows, made),
         {title, ref} <- Clause.tied_ref(text, rows),
         other when is_binary(other) <- law_by_title(title),
         [_, t, y, n] <- String.split(other, "_", parts: 4),
         {:ok, effects} <- ChangesFeed.fetch(t, y, n, store: :only) do
      result = Evaluator.evaluate(Effects.rules(other, effects), ref)

      result.full_from ||
        result |> Evaluator.in_force() |> Enum.map(& &1.date) |> Enum.min(Date, fn -> nil end)
    else
      _ -> nil
    end
  end

  # "Building Safety Act 2022" → its register name (title and year, a
  # primary type first)
  defp law_by_title(title) do
    with [_, name, year] <- Regex.run(~r/^(.+?)\s+(\d{4})$/, title),
         %{rows: [[law] | _]} <-
           Repo.query!(
             """
             SELECT name FROM uk_lrt WHERE lower(title_en) = lower($1) AND name LIKE $2
             ORDER BY (split_part(name, '_', 2) IN ('ukpga', 'asp', 'anaw', 'asc', 'nia', 'mwa')) DESC LIMIT 1
             """,
             [name, "%\\_#{year}\\_%"]
           ) do
      law
    else
      _ -> nil
    end
  end

  defp date(%Date{} = d), do: d
  defp date(_other), do: nil

  # the stored CLML's metadata (up to its close: EU metadata runs long)
  defp clml_head(law_name) do
    with [_, type, year, number] <- String.split(law_name, "_", parts: 4),
         [path | _] <-
           Enum.sort(Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/**/data.xml.gz")),
         {:ok, gz} <- File.read(path) do
      xml = :zlib.gunzip(gz)

      case :binary.match(xml, "</ukm:Metadata>") do
        {pos, len} -> binary_part(xml, 0, pos + len)
        :nomatch -> binary_part(xml, 0, min(byte_size(xml), 80_000))
      end
    else
      _ -> nil
    end
  end

  defp clml_made(nil), do: nil

  # an SI's made date; an Act's passing (Royal Assent)
  defp clml_made(head) do
    with [_, d] <- Regex.run(~r/<ukm:(?:Made|EnactmentDate) Date="(\d{4}-\d{2}-\d{2})"/, head),
         {:ok, date} <- Date.from_iso8601(d) do
      date
    else
      _ -> nil
    end
  end

  @doc """
  The amending-law collector's records for a law (LR-08). `mode`: `:gaps`
  — rows whose note names a law with no dated change on the row (or an
  ancestor) in the feed; `:benchmark` — rows that do have one (to compare
  the law's reading with the feed's).
  """
  @spec amending_law(String.t(), [String.t()], [Record.t()], :gaps | :benchmark) :: [Record.t()]
  def amending_law(law_name, section_ids, feed, mode) do
    notes = asked_notes(law_notes(law_name), feed, mode)
    ask = for n <- notes, sid <- n.affected_sections, into: MapSet.new(), do: sid

    if MapSet.size(ask) == 0,
      do: [],
      else:
        with_doc_cache(fn ->
          Collect.records(
            law_name,
            law_title(law_name),
            section_ids,
            notes,
            ask,
            amending_sources(law_name),
            rules: &CommencementRules.for_law/1,
            extents: extents(law_name),
            law_extent: &law_extent/1
          )
        end)
  end

  # each amending law as a source (AR-04): its stored rules when the read
  # pass read it with this reader for this law, else its document (parsed
  # once per law's collection, `with_doc_cache/1`); nil when not held
  defp amending_sources(law_name) do
    stored = Enum.group_by(AmendmentRules.for_law(law_name), & &1.source.law)

    fn amending ->
      key = {__MODULE__, :doc, {:source, amending}}

      case Process.get(key, :none) do
        :none -> tap(source(amending, law_name, stored), &Process.put(key, &1))
        src -> src
      end
    end
  end

  defp source(amending, law_name, stored) do
    index = Index.get(amending)

    cond do
      Index.current?(index, law_name) ->
        Collect.stored_source(amending, index, Map.get(stored, amending, []))

      doc = amending_doc(amending) ->
        Collect.doc_source(doc)

      true ->
        nil
    end
  end

  @doc """
  Run `fun` with the amending-law document cache (`amending_doc/1`) scoped to
  it: each amending law's CLML is parsed once per law's collection and
  dropped afterwards, raise or not. Parsed xmerl documents are large; kept for
  the life of the process they exhausted memory in a corpus run (LR-25: ~130 MB
  per law).
  """
  @spec with_doc_cache((-> result)) :: result when result: term()
  def with_doc_cache(fun) do
    fun.()
  after
    for {__MODULE__, :doc, _} = key <- Process.get_keys(), do: Process.delete(key)
    Collect.clear()
  end

  @doc """
  The notes the amending-law collector reads, on the rows it asks about
  (LR-08): `:gaps` — rows where some note names a law with no dated change
  in the feed on the row or an ancestor; `:benchmark` — rows where one has.
  Every note on a row asked about is read: the feed's own record of a change
  can be unusable for the row (another territory, an effect that is no text
  change), so the amending law's reading of it stays (AR-04).
  """
  @spec asked_notes([map()], [Record.t()], :gaps | :benchmark) :: [map()]
  def asked_notes(notes, feed, mode) do
    dated =
      for r <- feed,
          r.effective_from != nil,
          into: MapSet.new(),
          do: {r.section_id, r.affecting_law}

    want_dated = mode == :benchmark

    # (a `for` match on a boolean would filter out every false: an explicit
    # filter instead)
    ask =
      for n <- notes,
          sid <- n.affected_sections,
          dated?(dated, sid, n.citation_law) == want_dated,
          into: MapSet.new(),
          do: sid

    for n <- notes,
        sids = Enum.filter(n.affected_sections, &MapSet.member?(ask, &1)),
        sids != [],
        do: %{n | affected_sections: sids}
  end

  @doc "True when the row or an ancestor has a dated change by `law` in `dated` ({section_id, law} pairs)."
  @spec dated?(MapSet.t(), String.t(), String.t()) :: boolean()
  def dated?(dated, sid, law),
    do: Enum.any?(LatRef.ancestors(sid), &MapSet.member?(dated, {&1, law}))

  # the law's amendment notes, each with the law it points to
  defp law_notes(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT code, text, coalesce(citation_law, changed_by), affected_sections
        FROM amendment_annotations
        WHERE law_name = $1 AND code_type = 'amendment' AND coalesce(citation_law, changed_by) IS NOT NULL
        """,
        [law_name]
      )

    for [code, text, law, sids] <- rows,
        do: %{code: code, text: text, citation_law: law, affected_sections: sids || []}
  end

  # the law's own commencement orders as rules (CR-07: its by-order rows)
  defp orders_rules(law_name) do
    law_name
    |> CommencementRules.for_law()
    |> Enum.filter(&(&1.treatment in [:order_date, :order_schedule]))
  end

  # rows the law's own feed dates a commencement of (effects first, CR-07)
  defp feed_dated(feed) do
    for r <- feed,
        r.operation == "commenced",
        r.effective_from != nil,
        into: MapSet.new(),
        do: r.section_id
  end

  # the rows' extents, for a commencement by territory (CR-06)
  defp extents(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, extent_code FROM legal_articles WHERE law_name = $1",
        [law_name]
      )

    Map.new(rows, fn [sid, e] -> {sid, e} end)
  end

  # an amending law's register extent (AR-09), once per law's collection
  # (`with_doc_cache/1`)
  # a law's extent for its changes' territory (AR-09): its title's place
  # when it names one ("… (England) Regulations 2023": V1-03, SI 2023/911
  # registers E+W), else the register's geo_extent
  defp law_extent(nil), do: nil

  defp law_extent(law) do
    key = {__MODULE__, :doc, {:extent, law}}

    case Process.get(key, :none) do
      :none ->
        %{rows: rows} =
          Repo.query!("SELECT geo_extent, title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law])

        extent =
          case rows do
            [[geo, title] | _] -> LawTerritory.extent(title, geo)
            _ -> nil
          end

        tap(extent, &Process.put(key, &1))

      e ->
        e
    end
  end

  @doc "The place in a law's own title (V1-03): `LawTerritory.title_place/1`."
  @spec title_place(String.t() | nil) :: String.t() | nil
  defdelegate title_place(title), to: LawTerritory

  defp law_title(law_name) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      %{rows: [[t]]} when is_binary(t) ->
        t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

      _ ->
        nil
    end
  end

  # the amending law's stored CLML (body, Schedules, fragments), parsed once
  # per law's collection (`with_doc_cache/1`); nil when not held
  defp amending_doc(law) do
    key = {__MODULE__, :doc, law}

    case Process.get(key, :none) do
      :none -> tap(read_doc(law), &Process.put(key, &1))
      doc -> doc
    end
  end

  defp read_doc(law) do
    with [_, type, year, number] <- String.split(law, "_", parts: 4),
         [_ | _] = paths <-
           Path.wildcard("data/cache/clml/#{type}/#{year}/#{number}/**/data.xml.gz") do
      Doc.new(law, Enum.map(Enum.sort(paths), &(&1 |> File.read!() |> :zlib.gunzip())))
    else
      _ -> nil
    end
  end

  @doc """
  The fidelity gate (LR-23 D3): expanding the compact records over the
  law's rows in the DB's order (`position`, as the `lat_change_log_rows`
  view does) gives exactly the per-row joins. Returns the differences
  (`{:missing | :extra, key}`); empty when it holds.
  """
  @spec fidelity(%{String.t() => [Record.t()]}, %{String.t() => [Record.t()]}, [String.t()]) ::
          [{:missing | :extra, tuple()}]
  def fidelity(records, per_row, db_order) do
    key = &{&1.section_id, Compact.key(&1)}
    known = MapSet.new(db_order)

    Enum.flat_map(per_row, fn {collector, recs} ->
      want = recs |> Enum.map(key) |> Enum.frequencies()

      got =
        records
        |> Map.get(collector, [])
        |> Enum.filter(&(is_nil(&1.section_id) or MapSet.member?(known, &1.section_id)))
        |> Enum.filter(&(is_nil(&1.section_id_to) or MapSet.member?(known, &1.section_id_to)))
        |> Compact.expand(db_order)
        |> Enum.map(key)
        |> Enum.frequencies()

      for(k <- Map.keys(want), Map.get(got, k) != want[k], do: {:missing, k}) ++
        for(k <- Map.keys(got), not Map.has_key?(want, k), do: {:extra, k})
    end)
  end

  @doc "The law's section_ids in the DB, by `position`."
  @spec db_order(String.t()) :: [String.t()]
  def db_order(law_name) do
    %{rows: rows} =
      Repo.query!("SELECT section_id FROM legal_articles WHERE law_name = $1 ORDER BY position", [
        law_name
      ])

    List.flatten(rows)
  end

  @doc "Replace a law's records for each collector given. Returns rows written."
  @spec write(String.t(), %{String.t() => [Record.t()]}) :: {:ok, non_neg_integer()}
  def write(law_name, by_collector) do
    Repo.transaction(fn ->
      Enum.reduce(by_collector, 0, fn {collector, records}, n ->
        Repo.query!("DELETE FROM lat_change_log WHERE law_name = $1 AND collector = $2", [
          law_name,
          collector
        ])

        now = DateTime.utc_now()

        records
        |> Enum.map(&row(&1, collector, now))
        |> Enum.chunk_every(2000)
        |> Enum.reduce(n, fn chunk, acc ->
          {k, _} = Repo.insert_all("lat_change_log", chunk)
          acc + k
        end)
      end)
    end)
  end

  defp row(%Record{} = r, collector, now) do
    r
    |> Map.from_struct()
    |> Map.update!(:in_force, fn entries -> Enum.map(entries, &Map.new/1) end)
    |> Map.merge(%{id: Ecto.UUID.bingenerate(), collector: collector, collected_at: now})
  end
end

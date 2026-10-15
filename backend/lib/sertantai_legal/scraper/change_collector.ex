defmodule SertantaiLegal.Scraper.ChangeCollector do
  @moduledoc """
  Fills the change register `lat_change_log` (lat-refactor LR-22/LR-23) for
  a law, offline from the CLML store: parse (store only) → the collectors →
  delete + insert that law's records per collector, in one transaction.

  Collectors: `Feed` (changes-feed effects with their joins), `Markup`
  (change markup no effect explains), `AmendingLaw` (the amending law's own
  text, for rows the feed doesn't date; LR-08). Records are stored compact (`Compact`:
  one per run of consecutive rows) and checked against the per-row joins
  in the DB's row order before writing (`fidelity/3`). Never fetches.
  Thin: the joins and records are the pure collectors'.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ChangeCollector.{AmendingLaw, Compact, Feed, Markup, Record}
  alias SertantaiLegal.Scraper.LatStatus
  alias SertantaiLegal.Scraper.LatStagedParser

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
      feed = Feed.records(law_name, rows, notes, effects)

      per_row = %{
        "feed" => feed,
        "markup" => Markup.records(law_name, rows),
        "amending_law" => amending_law(law_name, order, feed, Keyword.get(opts, :mode, :gaps))
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
  The amending-law collector's records for a law (LR-08). `mode`: `:gaps`
  — rows whose note names a law with no dated change on the row (or an
  ancestor) in the feed; `:benchmark` — rows that do have one (to compare
  the law's reading with the feed's).
  """
  @spec amending_law(String.t(), [String.t()], [Record.t()], :gaps | :benchmark) :: [Record.t()]
  def amending_law(law_name, section_ids, feed, mode) do
    notes = law_notes(law_name)

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

    if MapSet.size(ask) == 0,
      do: [],
      else:
        AmendingLaw.records(
          law_name,
          law_title(law_name),
          section_ids,
          notes,
          ask,
          &amending_doc/1,
          &law_title/1
        )
  end

  @doc "True when the row or an ancestor has a dated change by `law` in `dated` ({section_id, law} pairs)."
  @spec dated?(MapSet.t(), String.t(), String.t()) :: boolean()
  def dated?(dated, sid, law),
    do: Enum.any?(LatStatus.ancestors(sid), &MapSet.member?(dated, {&1, law}))

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

  defp law_title(law_name) do
    case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      %{rows: [[t]]} when is_binary(t) ->
        t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

      _ ->
        nil
    end
  end

  # the amending law's stored CLML (body, Schedules, fragments), parsed once
  # per process; nil when not held
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
    key = &{&1.evidence, &1.source, &1.section_id, &1.via, &1.pointer}
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

defmodule Mix.Tasks.Lat.Amending do
  @moduledoc """
  A law's amendment ruleset (amendment-rules AR-01, AR-03), one readable
  line per rule — the law and targets, the operation (words-level or whole
  provisions), its treatment, and the amending provision it came from:

      mix lat.amending --law UK_uksi_2014_1638

      UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C … substitute—”

  The read pass (AR-03) reads each amending law once — the provisions our
  laws' notes and their changes feeds point to (one hop; one deduplicated
  set of pointers, CV-07), for every law they point from — and stores
  its rules (`amendment_rules`) with a small index (`Amendment.Index`:
  element ids, each repeals table's introducing section, the reader version,
  the laws read for), so the collector needs no XML:

      mix lat.amending --read                    # every amending law not read by this reader (resumable)
      mix lat.amending --read --amending A,B     # these amending laws (re-read)
      mix lat.amending --read --limit 20         # the next 20

  An Act's own extent clause (CV-04: `extent_rules`) is read in the same
  pass; for the Acts changing a law, or named Acts, alone:

      mix lat.amending --extents --law UK_ukpga_1990_8
      mix lat.amending --extents --amending UK_ukpga_2005_15
      mix lat.amending --extents --amending A,B --cached   # the enabling cache only, never a fetch

  One amending law at a time, each in its own process: a parsed amending
  law can take gigabytes (a 5-wide run exhausted memory, 2026-10-20).
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, Locator, Pointer}
  alias SertantaiLegal.Scraper.Amendment.{Collect, Index, Reader, Rule, Store}

  @text_kinds ~w(substituted inserted repealed renumbered amended)

  @shortdoc "Print a law's amendment rules; read amending laws into rules"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          read: :boolean,
          amending: :string,
          limit: :integer,
          extents: :boolean,
          cached: :boolean
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:extents] ->
        extents(opts)

      opts[:read] ->
        read(opts)

      opts[:law] ->
        for line <- opts[:law] |> Store.for_law() |> print(opts[:law]), do: Mix.shell().info(line)

      true ->
        Mix.raise(
          "usage: mix lat.amending --law X | --read [--amending A,B] [--limit N] | --extents --law X | --extents --amending A,B"
        )
    end
  end

  @doc "The printed lines for a law's rules."
  @spec print([Rule.t()], String.t()) :: [String.t()]
  def print([], law), do: ["#{law}: no amendment rules (the readers write them: AR-03)"]

  def print(rules, law) do
    groups =
      rules
      |> Enum.group_by(& &1.source.law)
      |> Enum.sort()
      |> Enum.flat_map(fn {source, rs} ->
        ["", "  from #{source}" | Enum.map(rs, &("    " <> Rule.to_text(&1)))]
      end)

    ["#{law}: #{length(rules)} rule(s)" | groups]
  end

  # ── --extents ───────────────────────────────────────────────────────

  # the extent clauses of the laws changing a law (its feed's affecting
  # laws), or of the Acts named, held in the CLML store
  defp extents(opts) do
    acts =
      case {opts[:amending], opts[:law]} do
        {nil, nil} ->
          Mix.raise("--extents needs --law X or --amending A,B")

        {nil, law} ->
          law
          |> SertantaiLegal.Scraper.LatStagedParser.law_effects(store: :only)
          |> Enum.map(& &1.affecting)
          |> Enum.uniq()

        {list, _} ->
          String.split(list, ",", trim: true)
      end
      |> Enum.filter(&(Extent.Store.reads?(&1) and held?(&1)))

    Mix.shell().info("#{length(acts)} laws to read for their extent clause")

    # the parent Acts the SIs' enabling powers lie in, read first (by this
    # reader), so an SI stating no extent is placed by them (CV-07)
    parents =
      for a <- acts,
          not act?(a),
          p <- enabling(a, opts[:cached]),
          law = p["law"],
          Extent.Store.reads?(law) and held?(law) and law not in acts,
          uniq: true,
          do: law

    Mix.shell().info("#{length(parents)} parent Acts of their enabling powers, read first")

    for p <- parents do
      Task.async(fn -> {:ok, _} = Extent.Store.write(p, p |> doc() |> Extent.read()) end)
      |> Task.await(:infinity)
    end

    for {a, i} <- Enum.with_index(acts, 1) do
      # in its own process: the parsed document goes when it exits
      line =
        Task.async(fn ->
          e = a |> doc() |> Extent.read() |> with_powers(a, cached: opts[:cached])
          {:ok, n} = Extent.Store.write(a, e)

          stated =
            cond do
              e.default -> e.default
              e.powers -> "#{e.powers} (by its enabling powers)"
              e.competence -> "#{e.competence} (by its legislature's competence)"
              true -> "no clause"
            end

          "#{a}: #{stated} (#{n} rows)"
        end)
        |> Task.await(:infinity)

      Mix.shell().info("  [#{i}/#{length(acts)}] #{line}")
    end
  end

  # An SI stating no extent extends as far as its enabling powers: its
  # enabling provisions (its introduction: `EnablingCache`, fetched once
  # on a miss), each placed by its parent Act's own extent clause (read
  # first in this run, `extents/1`). CV-07.
  # `cached: true` (the check, `mix lat.extent_check`; `--extents
  # --cached`): the enabling cache only, never a fetch (CV-S05)
  @doc false
  @spec with_powers(Extent.t(), String.t(), keyword()) :: Extent.t()
  def with_powers(e, law, opts \\ [])

  # (with lists too: "Regulation 12 and Schedule 10 extend to England and
  # Wales and Scotland" names those only; the rest extend as far as the
  # powers — SI 2019/758, CV-S05)
  def with_powers(%Extent{default: nil} = e, law, opts) do
    if Extent.Store.reads?(law) and not act?(law) do
      provisions = enabling(law, opts[:cached])
      parents = provisions |> Enum.map(& &1["law"]) |> Enum.uniq()
      e = %{e | powers: Extent.from_powers(provisions, Extent.Store.for_laws(parents))}

      # with neither, a devolved instrument extends as far as its
      # legislature's competence
      if e.powers, do: e, else: %{e | competence: Extent.competence(law)}
    else
      # a devolved legislature's Act stating none extends as far as its
      # competence too (asp, nia, anaw, asc; CV-S05: agent round 1)
      if act?(law), do: %{e | competence: Extent.competence(law)}, else: e
    end
  end

  def with_powers(e, _law, _opts), do: e

  defp enabling(law, true) do
    case SertantaiLegal.Scraper.EnactedBy.EnablingCache.cached(law) do
      {:ok, ps} -> ps
      :none -> []
    end
  end

  defp enabling(law, _),
    do: SertantaiLegal.Scraper.EnactedBy.EnablingCache.get(law, retry_empty: true)

  defp act?(law),
    do: (String.split(law, "_") |> Enum.at(1)) in ~w(ukpga asp anaw asc nia apni)

  # ── --read ──────────────────────────────────────────────────────────

  defp read(opts) do
    Mix.shell().info("reading the changes feeds of our LAT laws for their pointers …")
    feed = feed_pointers()

    laws =
      case opts[:amending] do
        nil -> amending_laws(feed) |> Enum.filter(&to_read?(&1, Map.get(feed, &1)))
        list -> String.split(list, ",", trim: true)
      end

    Mix.shell().info("#{length(laws)} amending laws to read")
    laws = if opts[:limit], do: Enum.take(laws, opts[:limit]), else: laws

    for {a, i} <- Enum.with_index(laws, 1) do
      entry = Map.get(feed, a, %{laws: MapSet.new(), refs: []})

      # in its own process: the parsed document goes when it exits
      {n, ids} = Task.async(fn -> read_one(a, entry) end) |> Task.await(:infinity)
      mem = div(:erlang.memory(:total), 1_048_576)
      Mix.shell().info("  [#{i}/#{length(laws)}] #{a}: #{ids} provisions, #{n} rules (#{mem} MB)")
    end
  end

  # the laws our LAT laws' amendment notes, or their changes feeds, point
  # to, held in the CLML store
  defp amending_laws(feed) do
    Repo.query!("""
    SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
    WHERE code_type = 'amendment' AND coalesce(citation_law, changed_by) ~ '^UK_'
      AND law_name IN (SELECT DISTINCT law_name FROM legal_articles)
    """).rows
    |> List.flatten()
    |> Kernel.++(Map.keys(feed))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.filter(&held?/1)
  end

  # each amending law's pointers from the changes feeds of our LAT laws
  # (stored pages): the laws it changes and the provisions each effect
  # names as its own (CV-07)
  defp feed_pointers do
    Repo.query!("SELECT DISTINCT law_name FROM legal_articles").rows
    |> List.flatten()
    |> Enum.flat_map(fn law ->
      for e <- SertantaiLegal.Scraper.LatStagedParser.law_effects(law, store: :only) || [],
          is_binary(e.affecting) and e.affecting =~ ~r/^UK_/,
          # text changes only: the instructions this reader reads (a
          # commencement order's "coming into force" is the commencement
          # read pass's)
          SertantaiLegal.Scraper.EffectKind.kind(e.type, nil) in @text_kinds,
          do: {e.affecting, law, Pointer.refs_in(e.affecting_provisions)}
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Map.new(fn {a, rows} ->
      {a,
       %{
         laws: MapSet.new(rows, &elem(&1, 1)),
         refs: rows |> Enum.flat_map(&elem(&1, 2)) |> Enum.uniq()
       }}
    end)
  end

  # read again when the reader changed, or the feed points to provisions
  # the last reading didn't (an index from before CV-07 read the notes'
  # pointers only)
  defp to_read?(amending, feed_entry) do
    index = Index.get(amending)

    cond do
      not Index.fresh?(index) ->
        true

      feed_entry == nil ->
        false

      true ->
        read = MapSet.new(index["pointers"] || note_pointers(amending))
        not MapSet.subset?(MapSet.new(pointer_keys(feed_entry.refs)), read)
    end
  end

  defp note_pointers(amending) do
    for n <- notes_pointing_to(amending),
        p = Pointer.parse(n),
        p.affecting_law == amending,
        key <- pointer_keys(p.provisions),
        uniq: true,
        do: key
  end

  # a pointer as the index records it ("sch.2.para.10(2)(a)")
  defp pointer_keys(refs), do: refs |> Enum.flat_map(&Pointer.to_refs/1) |> Enum.uniq()

  defp read_one(amending, feed_entry) do
    case doc(amending) do
      nil ->
        {0, 0}

      doc ->
        notes = notes_pointing_to(amending)

        laws =
          notes
          |> Enum.map(& &1.law_name)
          |> Kernel.++(MapSet.to_list(feed_entry.laws))
          |> Enum.uniq()
          |> Enum.map(&law_ref/1)

        # one set of pointers: the notes' and the feed's, deduplicated
        refs =
          for(
            n <- notes,
            p = Pointer.parse(n),
            p.affecting_law == amending,
            ref <- p.provisions,
            do: ref
          ) ++ feed_entry.refs

        refs = Enum.uniq(refs)
        ids = for ref <- refs, id <- Locator.ids(doc, ref), uniq: true, do: id

        rules = Enum.flat_map(ids, &Collect.read(doc, &1, laws))
        {:ok, n} = Store.write(amending, rules)

        # an Act's own extent clause, from the same document (CV-04)
        if Extent.Store.reads?(amending), do: Extent.Store.write(amending, Extent.read(doc))

        :ok = Index.write(amending, doc, Enum.map(laws, & &1.law_name), pointer_keys(refs))

        {n, length(ids)}
    end
  end

  # the note's pointer law as the collector reads it: its Citation, else the
  # law its text names (`ChangeCollector.law_notes/1`)
  defp notes_pointing_to(amending) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, code, text, coalesce(citation_law, changed_by), affected_sections
        FROM amendment_annotations
        WHERE code_type = 'amendment' AND coalesce(citation_law, changed_by) = $1
          AND law_name IN (SELECT DISTINCT law_name FROM legal_articles)
        """,
        [amending]
      )

    for [law, code, text, cl, sids] <- rows,
        do: %{
          law_name: law,
          code: code,
          text: text,
          citation_law: cl,
          affected_sections: sids || []
        }
  end

  # a LAT law's ref: its title (no year) and its rows' prefix
  defp law_ref(law) do
    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) ->
          t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

        _ ->
          nil
      end

    prefix =
      case Repo.query!(
             "SELECT substring(section_id from ':(s|reg|art|rule)\\.') FROM legal_articles WHERE law_name = $1 AND section_id ~ ':(s|reg|art|rule)\\.' LIMIT 1",
             [law]
           ) do
        %{rows: [[p]]} when is_binary(p) -> p
        _ -> "s"
      end

    Reader.law_ref(law, title, prefix)
  end

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, _, _, _] -> ClmlStore.law_files(law) != []
      _ -> false
    end
  end

  defp doc(law) do
    case ClmlStore.law_docs(law) do
      [] -> nil
      xmls -> Doc.new(law, xmls)
    end
  end
end

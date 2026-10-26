defmodule SertantaiLegal.Scraper.Amendment.ReadPass do
  @moduledoc """
  The amendment read pass (amendment-rules AR-03, `mix lat.amending
  --read`), one amending law at a time: which amending laws to read (our
  LAT laws' notes and changes feeds point to them, held in the CLML store;
  CV-07), whether a stored reading is stale, reading one (`read/2`, no
  writes) and storing it (`write/2`: rules, an Act's extent clause, the
  index). Reading apart from writing, so a preview (`--preview`) and the
  pass report the same diff (`ReadReport`) — run time, 2026-10-25.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, Pointer}
  alias SertantaiLegal.Scraper.Amendment.{Index, ReadLaw, Rule, Store}
  alias SertantaiLegal.Scraper.LatStagedParser
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @type feed_entry :: %{laws: MapSet.t(String.t()), refs: [Pointer.ref()]}
  @type reading :: %{
          amending: String.t(),
          doc: Doc.t(),
          laws: [String.t()],
          refs: [Pointer.ref()],
          ids: [String.t()],
          rules: [Rule.t()]
        }

  @doc """
  Each amending law's pointers from the changes feeds of our LAT laws
  (stored pages, `FeedCache`): the laws it changes and the provisions each
  text-changing effect names as its own.
  """
  @spec feed_pointers() :: %{String.t() => feed_entry()}
  def feed_pointers do
    Repo.query!("SELECT DISTINCT law_name FROM legal_articles").rows
    |> List.flatten()
    |> Enum.flat_map(fn law ->
      for e <- LatStagedParser.law_effects(law, store: :only) || [],
          is_binary(e.affecting) and e.affecting =~ ~r/^UK_/,
          ReadLaw.text_effect?(e),
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

  @doc "The laws our LAT laws' amendment notes, or their changes feeds, point to, held in the CLML store."
  @spec amending_laws(%{String.t() => feed_entry()}) :: [String.t()]
  def amending_laws(feed) do
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

  @doc """
  Whether `amending` is to be read again: its index is stale (another
  reader, or the text held changed), or the feed points to provisions the
  last reading didn't.
  """
  @spec stale?(String.t(), feed_entry() | nil) :: boolean()
  def stale?(amending, feed_entry) do
    index = Index.get(amending)

    cond do
      not Index.fresh?(amending, index) ->
        true

      feed_entry == nil ->
        false

      true ->
        read = MapSet.new(index["pointers"] || note_pointers(amending))
        not MapSet.subset?(MapSet.new(pointer_keys(feed_entry.refs)), read)
    end
  end

  @doc "Read `amending` (nothing written); nil when its text isn't held."
  @spec read(String.t(), feed_entry()) :: reading() | nil
  def read(amending, feed_entry) do
    case ReadLaw.doc(amending) do
      nil ->
        nil

      doc ->
        notes = ReadLaw.notes(amending)

        laws =
          notes
          |> Enum.map(& &1.law_name)
          |> Kernel.++(MapSet.to_list(feed_entry.laws))
          |> Enum.uniq()

        # one set of pointers: the notes' and the feed's, deduplicated
        refs = Enum.uniq(ReadLaw.note_refs(amending, notes) ++ feed_entry.refs)
        {rules, ids} = ReadLaw.rules(doc, Enum.map(laws, &ReadLaw.law_ref/1), refs)
        %{amending: amending, doc: doc, laws: laws, refs: refs, ids: ids, rules: rules}
    end
  end

  @doc """
  Store a reading: its rules, an Act's own extent clause (CV-04), the
  index. With `stored` (the source's rules as stored, read before), rules
  and extent the same as stored are not written again; the index always
  is, stamped with this reader (run time 2026-10-26).
  """
  @spec write(reading(), [Rule.t()] | nil) :: {:ok, non_neg_integer()}
  def write(%{amending: amending, doc: doc} = r, stored \\ nil) do
    {:ok, n} =
      case stored do
        nil -> Store.write(amending, r.rules)
        _ -> with {:ok, n, _} <- Store.write_changed(amending, r.rules, stored), do: {:ok, n}
      end

    # (with its powers or competence, from what is held: never a fetch;
    # the reading from `Extent.ReadCache`, kept across amendment-reader
    # changes: run time 2026-10-26)
    if Extent.Store.reads?(amending) do
      read =
        case Extent.ReadCache.law(amending, doc: doc) do
          %{read: read} -> read
          nil -> Extent.ReadCache.read(doc)
        end

      {:ok, _, _} = Extent.Store.write_read(amending, read, cached: true)
    end

    :ok = Index.write(amending, doc, r.laws, pointer_keys(r.refs))
    {:ok, n}
  end

  @regression "test/fixtures/amendment_read/regression.txt"

  @doc """
  The regression set (`--regression`): amending laws whose reading has gone
  wrong before (`#{@regression}`, one per line with why) and the golden
  laws' amending laws.
  """
  @spec regression_laws() :: [String.t()]
  def regression_laws do
    listed =
      @regression
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.replace(~r/#.*/, "") |> String.trim()))
      |> Enum.reject(&(&1 == ""))

    {golden, _} = Code.eval_file("test/fixtures/change_vocabulary/golden.exs")

    behind_golden =
      for law <- golden |> Enum.map(& &1.law) |> Enum.uniq(),
          r <- Store.for_law(law),
          uniq: true,
          do: r.source.law

    Enum.uniq(listed ++ behind_golden)
  end

  @doc "A pointer as the index records it (\"sch.2.para.10(2)(a)\")."
  @spec pointer_keys([Pointer.ref()]) :: [String.t()]
  def pointer_keys(refs), do: refs |> Enum.flat_map(&Pointer.to_refs/1) |> Enum.uniq()

  defp note_pointers(amending),
    do: amending |> ReadLaw.note_refs(ReadLaw.notes(amending)) |> pointer_keys()

  @doc "The size of the law's stored text in bytes: the read pass starts the largest first."
  @spec weight(String.t()) :: non_neg_integer()
  def weight(law),
    do: law |> ClmlStore.law_files() |> Enum.map(&File.stat!(&1).size) |> Enum.sum()

  @doc "Whether the law's text is held in the CLML store."
  @spec held?(String.t()) :: boolean()
  def held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, _, _, _] -> ClmlStore.law_files(law) != []
      _ -> false
    end
  end
end

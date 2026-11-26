defmodule SertantaiLegal.Scraper.ChangeVocabulary.Store.Inputs do
  @moduledoc """
  What a law's change build read, fingerprinted (CV-S11): recorded on each
  `changes_built` event by the build, and taken again by `mix lat.stale` so
  `ChangeStaleness` can say which input moved.

  - `:lat_rows` — the law's LAT rows the changes are placed on (section
    id, extent, XML id), digested
  - `:law_text` — the stored law text's content (`ClmlStore.digest/2`)
  - `:feed` — the stored changes-feed pages' content
  - `:amendment_rules`, `:commencement_rules`, `:extent_rules` — each
    store's latest `read_at` over the rows the build reads: the amendment
    rules on the law; the commencement rules commencing the law or a law
    whose commencement it read (`sources`: the amending laws, their rules'
    sources, the laws its notes cite); the extent rules of those laws and
    its affecting laws

  `:affecting` and `:commencement_sources` are recorded too, so the rules
  can be fingerprinted again without a build. `readers/3` says which of
  those readings were made by other reader code (#193): `read_at` moves
  only when a reading is written, so a reader fix that is never re-run
  leaves the build looking current. DB and file reads only.

  (#193: the commencement fingerprint read rules *from* `sources`, not
  rules commencing them, so a re-read order moved nothing; the extent
  fingerprint missed the rules' sources and cited laws the build reads.)
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion, as: ExtentReadVersion
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore
  alias SertantaiLegal.Scraper.Amendment.Index
  alias SertantaiLegal.Scraper.Commencement.Store, as: CommencementStore
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @keys [:lat_rows, :law_text, :feed, :amendment_rules, :commencement_rules, :extent_rules]

  @doc "The fingerprints `of/3` takes (the lists it records beside them aside)."
  @spec keys() :: [atom()]
  def keys, do: @keys

  @doc "The fingerprint of `law`'s inputs, given the laws the build read beside it."
  @spec of(String.t(), [String.t()], [String.t()]) :: map()
  def of(law, affecting, sources) do
    %{
      lat_rows: lat_rows(law),
      law_text: law |> ClmlStore.law_files() |> digest(),
      feed: law |> feed_files() |> digest(),
      amendment_rules:
        latest("SELECT max(read_at) FROM amendment_rules WHERE amends = $1", [law]),
      commencement_rules:
        latest("SELECT max(read_at) FROM commencement_rules WHERE commences = ANY($1)", [
          commenced(law, sources)
        ]),
      extent_rules:
        latest("SELECT max(read_at) FROM extent_rules WHERE source_law = ANY($1)", [
          extended(affecting, sources)
        ]),
      affecting: Enum.sort(affecting),
      commencement_sources: Enum.sort(sources)
    }
  end

  @doc """
  The readers whose readings the build read are by other reader code, or
  were read before the code was recorded (`reader_version` nil):
  `:commencement_reader` (each rule's own read path's `Commencement.ReadVersion`), `:extent_reader`
  (`Extent.ReadVersion`, or a law whose extent the build would read with
  its text held but no `extent_rules`: not read, so the build has no extent
  from it; the Extent reader stamps session), `:amending_reader` (an
  amending law of the law's text changes, its text held, whose index is not
  current for the law: stale or never read; the build reads stored rules
  only, the Amending-law reader stamps session). Taken now, never recorded.
  """
  @spec readers(String.t(), [String.t()], [String.t()]) :: [
          :commencement_reader | :extent_reader | :amending_reader
        ]
  def readers(law, affecting, sources) do
    [
      {:commencement_reader, commencement_stale?(commenced(law, sources))},
      {:extent_reader,
       other_code?("extent_rules WHERE source_law = ANY($1)", [
         extended(affecting, sources),
         ExtentReadVersion.current()
       ]) or extent_unread?(extended(affecting, sources))},
      {:amending_reader, amending_stale?(law)}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp commenced(law, sources), do: Enum.uniq([law | sources])

  # a law the build would read the extent of, its text held, never read
  defp extent_unread?(laws) do
    Repo.query!(
      "SELECT l FROM unnest($1::text[]) l WHERE NOT EXISTS (SELECT 1 FROM extent_rules WHERE source_law = l)",
      [Enum.filter(laws, &ExtentStore.reads?/1)]
    ).rows
    |> Enum.any?(fn [l] -> ClmlStore.law_files(l) != [] end)
  end

  defp extended(affecting, sources), do: Enum.uniq(affecting ++ sources)

  # an amending law of the law's text changes (its stored rules' sources,
  # and the feed's amending laws on its changes other than commencements),
  # its text held, whose index is not current for the law: read by other
  # code, from other text, for other laws only, or never read
  defp amending_stale?(law) do
    law
    |> text_amenders()
    |> Enum.any?(&(ClmlStore.law_files(&1) != [] and not Index.current?(&1, Index.get(&1), law)))
  end

  defp text_amenders(law) do
    Repo.query!(
      """
      SELECT DISTINCT source_law FROM amendment_rules WHERE amends = $1
      UNION
      SELECT DISTINCT cl.value->>'v' FROM provision_changes pc
      JOIN provision_change_claims cl ON cl.change_id = pc.id
      WHERE pc.law_name = $1 AND pc.operation IS DISTINCT FROM 'commenced'
        AND cl.source = 'feed' AND cl.attribute = 'by'
      """,
      [law],
      timeout: :infinity
    ).rows
    |> List.flatten()
    |> Enum.filter(&(is_binary(&1) and &1 =~ ~r/^UK_/))
  end

  # each rule against its own read path's version (`CommencementStore.stale_condition/1`)
  defp commencement_stale?(laws) do
    {stale, params} = CommencementStore.stale_condition(2)

    Repo.query!(
      "SELECT EXISTS (SELECT 1 FROM commencement_rules WHERE commences = ANY($1) AND #{stale})",
      [laws | params]
    ).rows == [[true]]
  end

  defp other_code?(from, params) do
    Repo.query!(
      "SELECT EXISTS (SELECT 1 FROM #{from} AND reader_version IS DISTINCT FROM $2)",
      params
    ).rows == [[true]]
  end

  defp lat_rows(law) do
    Repo.query!(
      """
      SELECT md5(string_agg(section_id || '|' || coalesce(extent_code, '') || '|' ||
                            coalesce(source_xml_id, ''), ',' ORDER BY section_id))
      FROM legal_articles WHERE law_name = $1 AND section_id IS NOT NULL
      """,
      [law]
    ).rows
    |> hd()
    |> hd()
  end

  defp feed_files(law) do
    case String.split(law, "_", parts: 4) do
      [_, type, year, number] -> ClmlStore.feed_files(type, year, number)
      _ -> []
    end
  end

  # nil when nothing is held, so "absent then and now" hasn't moved
  defp digest([]), do: nil

  defp digest(files) do
    files
    |> Enum.map(&:erlang.md5(File.read!(&1)))
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp latest(sql, params) do
    case Repo.query!(sql, params).rows do
      [[%DateTime{} = t]] -> DateTime.to_iso8601(t)
      [[%NaiveDateTime{} = t]] -> NaiveDateTime.to_iso8601(t)
      _ -> nil
    end
  end
end
